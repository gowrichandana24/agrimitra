"""
Crop Price Prediction API
Flask backend for price estimation with optional image-based crop detection.
"""

import os
import re
import traceback
from datetime import datetime, date
from flask import Flask, request, jsonify
from flask_cors import CORS
import pandas as pd
import tensorflow as tf
import numpy as np
from PIL import Image
import io

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(BASE_DIR, 'models')
DATASET_DIR = os.path.join(BASE_DIR, 'dataset', 'agmarknet_prices')

app = Flask(__name__)
CORS(app)

# Load model and class labels at startup
model = None
class_names = None
IMG_SIZE = 224

# Price dataset loaded at startup
price_df = None


def load_model():
    """Load the trained crop identifier model and class labels."""
    global model, class_names

    model_path = os.path.join(MODELS_DIR, 'crop_identifier.h5')
    labels_path = os.path.join(MODELS_DIR, 'class_labels.json')

    if os.path.exists(model_path):
        import json
        model = tf.keras.models.load_model(model_path)
        with open(labels_path, 'r') as f:
            class_names = json.load(f)
        print(f"Loaded crop identifier model from {model_path}")
        print(f"Classes: {class_names}")
    else:
        print(f"WARNING: Model not found at {model_path}")
        print("Image detection will be unavailable")


PRICE_CSV_PATHS = [
    os.path.join(DATASET_DIR, 'Agriculture_price_dataset.csv'),
    os.path.join(DATASET_DIR, 'agmarknet_api_data.csv'),
]


def normalize_commodity(name):
    """lowercase + strip parenthetical qualifiers + collapse whitespace."""
    s = str(name).strip().lower()
    s = re.sub(r'\([^)]*\)', '', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s


# Alias terms per model crop. Matching rule: a row is accepted only when its
# Commodity field, after normalize_commodity(), EXACTLY equals the crop name
# or one of these aliases - never a substring/token match (this is what
# caused the watermelon/muskmelon contamination).
CROP_SEARCH_TERMS = {
    'corn': ['maize'],
    'eggplant': ['brinjal'],
    'cucumber': ['cucumber', 'cucumbar', 'long melon'],
    'bell pepper': ['capsicum'],
    'chilli pepper': ['chilli pepper', 'green chilli'],
    'jalepeno': ['jalepeno', 'jalapeno'],
    'raddish': ['raddish', 'radish'],
    'soy beans': ['soy beans', 'soybean', 'soyabean'],
    'sweetcorn': ['sweetcorn', 'sweet corn'],
    'sweetpotato': ['sweetpotato', 'sweet potato'],
    'watermelon': ['watermelon', 'water melon'],
    # Same-produce variety names (exact normalized equality only):
    'banana': ['banana', 'banana - green'],
    'peas': ['peas', 'green peas', 'white peas'],
}


def load_price_data():
    """
    Load and combine all Agmarknet price CSVs into one global DataFrame.
    Drops exact duplicate rows across files before use.
    """
    global price_df

    frames = []
    for csv_path in PRICE_CSV_PATHS:
        if not os.path.exists(csv_path):
            print(f"WARNING: Price dataset not found at {csv_path} - skipping")
            continue
        df = pd.read_csv(csv_path)
        df.columns = [c.strip() for c in df.columns]
        frames.append(df)
        print(f"Loaded {len(df):>9,} rows from {os.path.basename(csv_path)}")

    if not frames:
        print("ERROR: no price datasets found")
        print("Price estimates will return 'no data available'")
        return

    price_df = pd.concat(frames, ignore_index=True)
    rows_before = len(price_df)
    price_df = price_df.drop_duplicates()
    rows_dropped = rows_before - len(price_df)
    print(f"Combined: {rows_before:,} rows -> {len(price_df):,} after dropping "
          f"{rows_dropped:,} exact duplicate rows")

    # Normalize string columns for reliable matching
    for col in ['STATE', 'District Name', 'Market Name', 'Commodity']:
        price_df[col] = (
            price_df[col].astype(str).str.strip().str.lower()
        )

    # Canonicalize duplicate state spellings (case-insensitive match on the
    # already-lowercased values). Unmapped states get Title Case so display
    # is consistent everywhere (/locations, /predict-price, /price-history).
    STATE_CANONICAL_ALIASES = {
        'goa': 'Goa',
        'gao': 'Goa',
        'kerala': 'Kerala',
        'keralam': 'Kerala',
        'tamil nadu': 'Tamil Nadu',
        'tamilnadu': 'Tamil Nadu',
        'chhattisgarh': 'Chhattisgarh',
        'chattisgarh': 'Chhattisgarh',
        'delhi': 'Delhi',
        'nct of delhi': 'Delhi',
        'odisha': 'Odisha',
        'orissa': 'Odisha',
        'uttarakhand': 'Uttarakhand',
        'uttrakhand': 'Uttarakhand',
        'jammu & kashmir': 'Jammu & Kashmir',
        'jammu and kashmir': 'Jammu & Kashmir',
    }
    price_df['STATE'] = price_df['STATE'].map(
        lambda s: STATE_CANONICAL_ALIASES.get(s, s.title())
    )

    # Parse Price Date to datetime
    price_df['Price Date'] = pd.to_datetime(
        price_df['Price Date'], format='mixed', errors='coerce'
    )

    # Drop future-dated rows: presenting prices dated after today as real
    # market history is misleading. Uses the actual current date.
    today = pd.Timestamp(date.today())
    rows_before_future = len(price_df)
    price_df = price_df[
        price_df['Price Date'].isna() | (price_df['Price Date'] <= today)
    ]
    print(f"Removed {rows_before_future - len(price_df):,} future-dated rows "
          f"(Price Date > {today.date()})")

    # Ensure numeric columns are actually numeric
    for col in ['Min_Price', 'Max_Price', 'Modal_Price']:
        price_df[col] = pd.to_numeric(price_df[col], errors='coerce')

    # Precompute normalized commodity for exact alias matching
    price_df['_cnorm'] = price_df['Commodity'].map(normalize_commodity)

    print(f"  Commodities: {price_df['Commodity'].nunique()}")
    dates = price_df['Price Date'].dropna()
    if not dates.empty:
        print(f"  Date range: {dates.min().date()} to {dates.max().date()}")


def preprocess_image(image_bytes):
    """Preprocess image bytes for MobileNetV2 prediction."""
    img = Image.open(io.BytesIO(image_bytes)).convert('RGB')
    img = img.resize((IMG_SIZE, IMG_SIZE))
    img_array = tf.keras.utils.img_to_array(img)
    img_array = tf.expand_dims(img_array, 0)
    # MobileNetV2 expects [-1, 1] input range
    img_array = tf.keras.applications.mobilenet_v2.preprocess_input(img_array)
    return img_array


def detect_crop_from_image(image_bytes):
    """
    Run crop detection on image bytes.
    Returns (predicted_class_name, confidence) or (None, 0.0) on failure.
    """
    if model is None:
        return None, 0.0

    try:
        img_array = preprocess_image(image_bytes)
        predictions = model.predict(img_array, verbose=0)
        predicted_idx = np.argmax(predictions[0])
        confidence = float(predictions[0][predicted_idx])
        return class_names[predicted_idx], confidence
    except Exception as e:
        print(f"Image detection error: {e}")
        return None, 0.0


def _rows_for_crop(crop):
    """
    Shared crop matcher: normalized Commodity must EXACTLY equal the crop
    name or one of its alias terms (never a substring/token match).
    Used by get_price_estimate() and /price-history.
    """
    crop_lower = crop.strip().lower()
    terms = {normalize_commodity(crop_lower)}
    for t in CROP_SEARCH_TERMS.get(crop_lower, []):
        terms.add(normalize_commodity(t))
    return price_df[price_df['_cnorm'].isin(terms)]


def get_price_estimate(crop, location, date):
    """
    Look up real Agmarknet prices for the given crop and location.
    Simple version: exact commodity match, substring location match on STATE.
    """
    no_data = {
        'price_per_quintal': None,
        'min_price': None,
        'max_price': None,
        'currency': 'INR',
        'source': 'no data available',
        'n_records_used': 0,
        'note': f'No Agmarknet price data found for "{crop}"',
    }

    if price_df is None:
        return no_data

    df = _rows_for_crop(crop)

    if df.empty:
        return no_data

    # Location matching: accepts plain "state" or cascading "district, state".
    # Each comma-separated part is substring-matched against STATE or
    # District Name (case-insensitive).
    location_lower = location.strip().lower() if location else ''
    location_matched = False

    if location_lower:
        parts = [p.strip() for p in location_lower.split(',') if p.strip()]
        matched_mask = pd.Series(False, index=df.index)
        for part in parts:
            part_match = (
                df['STATE'].str.contains(part, case=False, na=False)
                | df['District Name'].str.contains(part, case=False, na=False)
            )
            if part_match.any():
                matched_mask |= part_match
        if matched_mask.any():
            df = df[matched_mask]
            location_matched = True

    # IQR-based outlier filtering on price columns (Q1-1.5*IQR .. Q3+1.5*IQR).
    # Applied per column on the location-filtered set, BEFORE computing any
    # statistics. NaN-priced rows are kept here (mean/min/max skip NaNs
    # anyway); if filtering empties the set entirely, fall back to unfiltered.
    def apply_iqr_filter(data):
        out = data
        for col in ('Min_Price', 'Max_Price', 'Modal_Price'):
            s = out[col].dropna()
            if s.empty:
                continue
            q1 = s.quantile(0.25)
            q3 = s.quantile(0.75)
            iqr = q3 - q1
            lo = q1 - 1.5 * iqr
            hi = q3 + 1.5 * iqr
            out = out[out[col].isna() | out[col].between(lo, hi)]
        return out

    df_stats = apply_iqr_filter(df)
    if df_stats.empty:
        df_stats = df

    modal_mean = df_stats['Modal_Price'].dropna()
    if modal_mean.empty:
        return no_data

    return {
        'price_per_quintal': round(float(modal_mean.mean())),
        'min_price': round(float(df_stats['Min_Price'].min())),
        'max_price': round(float(df_stats['Max_Price'].max())),
        'currency': 'INR',
        'source': 'Agmarknet dataset - location-matched' if location_matched else 'Agmarknet dataset - national average',
        'n_records_used': len(df_stats),
    }


@app.route('/predict-price', methods=['POST'])
def predict_price():
    """Predict crop price with optional image-based crop detection."""
    try:
        # Handle both multipart form data and JSON
        if request.content_type and 'multipart/form-data' in request.content_type:
            crop = request.form.get('crop', '').strip()
            location = request.form.get('location', '').strip()
            date = request.form.get('date', '').strip()
            image_file = request.files.get('image')
            # Diagnostic logging: confirm whether an image actually arrived
            if image_file is not None:
                payload = image_file.stream.read()
                print(
                    f"[predict-price] IMAGE RECEIVED: field={image_file.name} "
                    f"filename={image_file.filename} "
                    f"content_type={image_file.mimetype} bytes={len(payload)}"
                )
                image_file.stream.seek(0)
            else:
                print("[predict-price] NO IMAGE received (field 'image' missing)")
        else:
            data = request.get_json() or {}
            crop = data.get('crop', '').strip()
            location = data.get('location', '').strip()
            date = data.get('date', '').strip()
            image_file = None

        # Location is always required. Crop may be omitted ONLY when an image
        # is provided, so image detection can fill it in.
        if not location:
            return jsonify({'error': 'Missing required field: location'}), 400
        if not crop and not image_file:
            return jsonify({'error': 'Missing required field: crop'}), 400

        # Default date to today if not provided
        if not date:
            date = datetime.now().strftime('%Y-%m-%d')

        # Image detection — 3-tier confidence logic
        image_detected_crop = None
        image_confidence = 0.0
        note = None

        if image_file:
            image_bytes = image_file.read()
            detected, confidence = detect_crop_from_image(image_bytes)

            if detected:
                image_detected_crop = detected
                image_confidence = round(confidence, 4)

                if not crop:
                    # No manual crop selection — detection found a crop.
                    # Ask the farmer to confirm before proceeding to pricing.
                    return jsonify({
                        'needs_confirmation': True,
                        'image_detected_crop': detected,
                        'image_confidence': image_confidence,
                        'note': (
                            f"Image detected: {detected} ({confidence:.0%} confidence). "
                            "Should we use this as the crop for pricing?"
                        )
                    })
                elif confidence >= 0.65 and detected.lower() != crop.lower():
                    # High confidence — override farmer's selection
                    note = (
                        f"Image detected: {detected} ({confidence:.0%} confidence) "
                        f"— overriding your selection ({crop})"
                    )
                    crop = detected
                elif confidence >= 0.4 and detected.lower() != crop.lower():
                    # Medium confidence — informational only, do NOT override
                    note = (
                        f"Image suggests this may be {detected} ({confidence:.0%} confidence) "
                        f"— using your selected crop ({crop}) for pricing"
                    )
                elif detected.lower() == crop.lower():
                    # Model agrees with farmer
                    note = f"Image confirmed crop selection: {crop}"
                else:
                    # Low confidence (<0.4) — ignore detection entirely
                    note = "Image unclear — using your selected crop"
            else:
                # Model returned nothing (very low confidence or error)
                note = ("Image unclear — could not identify the crop"
                        if not crop
                        else "Image unclear — using your selected crop")

        # Get price estimate
        price_estimate = get_price_estimate(crop, location, date)

        response = {
            'crop_used': crop,
            'image_detected_crop': image_detected_crop,
            'image_confidence': image_confidence,
            'location': location,
            'date': date,
            'price_estimate': price_estimate,
            'note': note
        }

        return jsonify(response)

    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/locations', methods=['GET'])
def locations():
    """All unique STATE values with their sorted unique District Name values."""
    try:
        if price_df is None:
            return jsonify({'error': 'Price dataset not loaded'}), 503

        states = {}
        for state, districts in price_df.groupby('STATE')['District Name']:
            uniq = sorted({
                str(d).strip() for d in districts
                if pd.notna(d) and str(d).strip()
            })
            states[str(state)] = uniq

        return jsonify({'states': states})
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/price-history', methods=['GET'])
def price_history():
    """
    Most recent 7 distinct dates with actual price records for a crop in a
    state (optionally narrowed to one district), oldest to newest.
    Multiple market records on the same date are averaged into one point.
    """
    try:
        if price_df is None:
            return jsonify({'error': 'Price dataset not loaded'}), 503

        crop = request.args.get('crop', '').strip()
        state = request.args.get('state', '').strip()
        district = request.args.get('district', '').strip()

        if not crop:
            return jsonify({'error': 'Missing required param: crop'}), 400
        if not state:
            return jsonify({'error': 'Missing required param: state'}), 400

        location_used = f'{district}, {state}' if district else state
        unavailable = {
            'crop': crop,
            'location_used': location_used,
            'data_available': False,
            'date_range_note': f'No price data found for "{crop}" in {location_used}',
            'history': [],
        }

        df = _rows_for_crop(crop)
        if df.empty:
            return jsonify(unavailable)

        df = df[df['STATE'].str.casefold() == state.casefold()]
        if district:
            df = df[df['District Name'] == normalize_commodity(district)]
        if df.empty:
            return jsonify(unavailable)

        df = df.dropna(subset=['Price Date', 'Modal_Price'])
        if df.empty:
            return jsonify(unavailable)

        recent_dates = set(df['Price Date'].nlargest(7))

        history = []
        for d in sorted(recent_dates):
            day = df[df['Price Date'] == d]
            history.append({
                'date': d.strftime('%Y-%m-%d'),
                'modal_price': round(float(day['Modal_Price'].mean())),
                'min_price': round(float(day['Min_Price'].min())),
                'max_price': round(float(day['Max_Price'].max())),
            })

        return jsonify({
            'crop': crop,
            'location_used': location_used,
            'data_available': True,
            'date_range_note':
                f"Showing most recent available data: "
                f"{history[0]['date']} to {history[-1]['date']}",
            'history': history,
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/price-forecast', methods=['GET'])
def price_forecast():
    """
    6-day forward price projection: fit a degree-1 linear trend on the last
    ~21 days of actual modal prices for crop+location, then extend it 6 days
    past the last real date. Reports the R-squared of the fit so callers can
    judge how reliable the trend is. /price-history remains unchanged.
    """
    try:
        if price_df is None:
            return jsonify({'error': 'Price dataset not loaded'}), 503

        crop = request.args.get('crop', '').strip()
        state = request.args.get('state', '').strip()
        district = request.args.get('district', '').strip()

        if not crop:
            return jsonify({'error': 'Missing required param: crop'}), 400
        if not state:
            return jsonify({'error': 'Missing required param: state'}), 400

        location_used = f'{district}, {state}' if district else state
        unavailable = {
            'crop': crop,
            'location_used': location_used,
            'data_available': False,
            'note': f'Not enough historical data to forecast "{crop}" '
                    f'in {location_used}',
            'trend_confidence': None,
            'historical': [],
            'forecast': [],
        }

        df = _rows_for_crop(crop)
        if df.empty:
            return jsonify(unavailable)

        df = df[df['STATE'].str.casefold() == state.casefold()]
        if district:
            df = df[df['District Name'] == normalize_commodity(district)]

        df = df.dropna(subset=['Price Date', 'Modal_Price'])
        if df.empty:
            return jsonify(unavailable)

        # Most recent window of up to 21 calendar days of records
        max_date = df['Price Date'].max()
        window_start = max_date - pd.Timedelta(days=20)
        recent = df[df['Price Date'] >= window_start]

        daily = recent.groupby('Price Date')['Modal_Price'].mean()
        daily = daily.sort_index()

        hist_dates = list(daily.index)
        if len(hist_dates) < 5:
            unavailable['note'] = (
                f'Only {len(hist_dates)} day(s) of recent price data for '
                f'"{crop}" in {location_used} — not enough to project a '
                f'trend reliably'
            )
            return jsonify(unavailable)

        x = np.array([(d - hist_dates[0]).days for d in hist_dates],
                     dtype=float)
        y = daily.to_numpy(dtype=float)

        coeffs = np.polyfit(x, y, 1)
        poly = np.poly1d(coeffs)
        y_hat = poly(x)

        ss_res = float(np.sum((y - y_hat) ** 2))
        ss_tot = float(np.sum((y - y.mean()) ** 2))
        r_squared = 1.0 if ss_tot == 0 else max(0.0, 1.0 - ss_res / ss_tot)

        # Volatility indicator: std deviation of recent modal prices
        volatility_stddev = round(float(np.std(y)), 1)

        historical = [
            {
                'date': d.strftime('%Y-%m-%d'),
                'modal_price': round(float(v)),
            }
            for d, v in zip(hist_dates, y)
        ]

        forecast = []
        last_date = hist_dates[-1]
        MIN_RELIABLE_R2 = 0.4

        if r_squared < MIN_RELIABLE_R2:
            # Trend too weak to trust a slope: flat median projection instead
            typical = float(np.median(y))
            for i in range(1, 7):
                day = last_date + pd.Timedelta(days=i)
                forecast.append({
                    'date': day.strftime('%Y-%m-%d'),
                    'predicted_price': max(0, round(typical)),
                })
            note = (
                f'Price trend is too volatile/unclear to project a reliable '
                f'direction (R²={r_squared:.3f}). Showing the recent typical '
                f'price instead of a trend projection.'
            )
        else:
            for i in range(1, 7):
                day = last_date + pd.Timedelta(days=i)
                xi = (day - hist_dates[0]).days
                predicted = max(0, round(float(poly(xi))))
                forecast.append({
                    'date': day.strftime('%Y-%m-%d'),
                    'predicted_price': predicted,
                })
            note = f'Linear trend projection based on the last {len(hist_dates)} days of actual market data — not a guarantee, actual prices depend on many factors'

        return jsonify({
            'crop': crop,
            'location_used': location_used,
            'data_available': True,
            'trend_confidence': round(r_squared, 3),
            'volatility_stddev': volatility_stddev,
            'note': note,
            'historical': historical,
            'forecast': forecast,
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/', methods=['GET'])
def health_check():
    return jsonify({'status': 'Crop price prediction service is running'})


if __name__ == '__main__':
    load_model()
    load_price_data()
    port = 5002
    print(f"\n  Registered routes:")
    for rule in app.url_map.iter_rules():
        print(f"    {rule.methods - {'OPTIONS', 'HEAD'}} {rule.rule}")
    print(f"\n  CORS enabled for all origins")
    print(f"  Starting on http://0.0.0.0:{port}\n")
    app.run(host='0.0.0.0', port=port, debug=False)
