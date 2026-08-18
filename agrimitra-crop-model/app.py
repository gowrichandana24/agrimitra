import os
import traceback
import pandas as pd
import joblib
from flask import Flask, request, jsonify
from flask_cors import CORS

BASE_DIR = os.path.dirname(__file__)
DATASET_DIR = os.path.join(BASE_DIR, 'dataset')
MODELS_DIR = os.path.join(BASE_DIR, 'models')

app = Flask(__name__)
CORS(app)

model = joblib.load(os.path.join(MODELS_DIR, 'crop_rf_model.pkl'))

soil_df = pd.read_csv(os.path.join(DATASET_DIR, 'soil_npk_ph_lookup.csv'))
rotation_df = pd.read_csv(os.path.join(DATASET_DIR, 'crop_family_rotation_rules.csv'))

CROP_RANGES = {
    'Rice': (152, 300), 'Wheat': (50, 100), 'Maize': (60, 110),
    'Sorghum': (40, 90), 'Pearl Millet': (30, 60), 'Finger Millet': (51, 100),
    'Chickpea': (20, 59), 'Lentil': (20, 50), 'Pigeon Pea': (60, 109),
    'Black Gram': (50, 90), 'Green Gram': (45, 85), 'Soybean': (70, 120),
    'Groundnut': (50, 99), 'Mustard': (30, 60), 'Sunflower': (40, 78),
    'Sesame': (35, 70), 'Cotton': (61, 110), 'Sugarcane': (151, 249),
    'Tomato': (40, 90), 'Brinjal': (51, 100), 'Chili': (40, 90),
    'Potato': (40, 80),
}
_CROP_RANGES_LOWER = {k.lower(): (k, v) for k, v in CROP_RANGES.items()}

REGIONAL_RAINFALL = {
    'Black Soil':    {'low': 500, 'high': 700, 'label': 'Deccan Plateau monsoon average'},
    'Red Soil':      {'low': 400, 'high': 600, 'label': 'South Indian semi-arid average'},
    'Alluvial Soil': {'low': 800, 'high': 1200, 'label': 'Gangetic Plains monsoon average'},
    'Sandy Soil':    {'low': 200, 'high': 400, 'label': 'Western India arid average'},
    'Clay Soil':     {'low': 800, 'high': 1200, 'label': 'Coastal belt monsoon average'},
    'Laterite Soil': {'low': 1000, 'high': 1500, 'label': 'Western Ghats high-rainfall average'},
}

NITROGEN_DEPLETERS = {
    'Rice', 'Wheat', 'Maize', 'Sorghum', 'Pearl Millet',
    'Finger Millet', 'Cotton', 'Sugarcane',
    'Tomato', 'Brinjal', 'Chili', 'Potato',
}
NITROGEN_FIXERS = {
    'Chickpea', 'Lentil', 'Pigeon Pea', 'Black Gram',
    'Green Gram', 'Soybean',
}
LEGUMES = NITROGEN_FIXERS

SOIL_SUITABLE_CROPS = {
    'Black Soil': ['Cotton', 'Sorghum', 'Sunflower', 'Chickpea', 'Sugarcane'],
    'Red Soil': ['Groundnut', 'Finger Millet', 'Pearl Millet', 'Pigeon Pea', 'Sesame'],
    'Alluvial Soil': ['Rice', 'Wheat', 'Sugarcane', 'Chickpea', 'Pigeon Pea',
                       'Black Gram', 'Green Gram', 'Soybean', 'Mustard'],
    'Sandy Soil': ['Groundnut', 'Pearl Millet', 'Sesame', 'Green Gram'],
    'Clay Soil': ['Rice', 'Wheat', 'Sugarcane'],
    'Laterite Soil': ['Cotton', 'Rice', 'Wheat', 'Black Gram', 'Green Gram'],
}


def estimate_soil_values(soil_type):
    match = soil_df[soil_df['soil_type'].str.lower() == soil_type.strip().lower()]
    if match.empty:
        available = ', '.join(soil_df['soil_type'].tolist())
        raise ValueError(f"Unknown soil type '{soil_type}'. Available: {available}")
    row = match.iloc[0]
    return {'N': row['N_est'], 'P': row['P_est'], 'K': row['K_est'], 'ph': row['ph_est']}


def _get_rotation_reason(crop, previous_crop, soil_type):
    prev_is_depleter = previous_crop in NITROGEN_DEPLETERS
    crop_is_legume = crop in LEGUMES
    suitable_set = set(SOIL_SUITABLE_CROPS.get(soil_type, []))
    soil_match = crop in suitable_set

    if crop_is_legume and prev_is_depleter:
        base = f"Nitrogen-fixing legume, ideal after nitrogen-depleting {previous_crop}"
        return f"{base}, well-suited for {soil_type}" if soil_match else base

    if previous_crop in LEGUMES and crop not in LEGUMES:
        base = f"Non-legume benefits from nitrogen fixed by {previous_crop}"
        return f"{base}, well-suited for {soil_type}" if soil_match else base

    crop_match = rotation_df[rotation_df['crop'].str.lower() == crop.lower()]
    prev_match = rotation_df[rotation_df['crop'].str.lower() == previous_crop.lower()]
    if not crop_match.empty and not prev_match.empty:
        if crop_match.iloc[0]['family'] != prev_match.iloc[0]['family']:
            base = f"Suitable rotation: different family from {previous_crop}"
            return f"{base}, well-suited for {soil_type}" if soil_match else base

    if soil_match:
        return f"Agronomically suited for {soil_type}, rotation-compatible with {previous_crop}"

    return f"RF model pick, rotation-compatible with {previous_crop}"


TIER_SCORE = {-3: 100, -2: 67, -1: 33, 0: 0}


def _compute_overall_fit_score(crop, rf_confidence, soil_type, previous_crop):
    """Compute a single 0-100 score from all ranking factors.

    Rotation tier is the primary factor (78% weight) to ensure strict
    monotonicity with the final ranking. Soil-suitability (7%) and
    RF confidence (15%) are secondary tiebreakers within each tier.
    """
    tier = _rotation_sort_key(crop, previous_crop, soil_type)
    rotation_score = TIER_SCORE[tier]
    soil_score = 100 if crop in SOIL_SUITABLE_CROPS.get(soil_type, []) else 0
    rf_score = rf_confidence * 100
    overall = rotation_score * 0.78 + soil_score * 0.07 + rf_score * 0.15
    return round(overall)


def _rotation_sort_key(crop, previous_crop, soil_type):
    """Return discrete tier for ranking: -3 (best) to 0 (worst)."""
    suitable_set = set(SOIL_SUITABLE_CROPS.get(soil_type, []))
    crop_is_legume = crop in LEGUMES
    soil_suitable = crop in suitable_set
    score = 0
    if previous_crop in NITROGEN_DEPLETERS and crop_is_legume:
        score -= 2
    if previous_crop in LEGUMES and not crop_is_legume:
        score -= 1
    if soil_suitable:
        score -= 1
    return score


def recommend_crop(soil_type, previous_crop, temperature, humidity, rainfall):
    soil_vals = estimate_soil_values(soil_type)

    input_df = pd.DataFrame([{
        'N': soil_vals['N'], 'P': soil_vals['P'], 'K': soil_vals['K'],
        'temperature': temperature, 'humidity': humidity,
        'ph': soil_vals['ph'], 'rainfall': rainfall
    }])

    probabilities = model.predict_proba(input_df)[0]
    classes = model.classes_

    top_n = min(10, len(classes))
    top_idx = probabilities.argsort()[-top_n:][::-1]
    rf_pool = [classes[i] for i in top_idx]
    rf_confidences = {classes[i]: round(float(probabilities[i]), 3) for i in top_idx}

    prev_match = rotation_df[rotation_df['crop'].str.lower() == previous_crop.strip().lower()]
    prev_family = prev_match.iloc[0]['family'] if not prev_match.empty else None

    eligible = []
    for crop in rf_pool:
        crop_match = rotation_df[rotation_df['crop'].str.lower() == crop.lower()]
        if not crop_match.empty and prev_family and crop_match.iloc[0]['family'] == prev_family:
            continue
        eligible.append(crop)

    eligible.sort(key=lambda c: _rotation_sort_key(c, previous_crop, soil_type))
    final = eligible[:3]

    result = []
    for rank, crop in enumerate(final, start=1):
        overall = _compute_overall_fit_score(crop, rf_confidences[crop], soil_type, previous_crop)
        # Tiebreaker ensures strictly monotonic integer scores after rounding.
        # Rank 1 gets +2, rank 2 gets +1, rank 3 gets +0.
        overall += (len(final) - rank)
        result.append({
            'rank': rank,
            'crop': crop,
            'overall_fit_score': round(overall),
            'model_confidence': rf_confidences[crop],
            'rotation_fit_reason': _get_rotation_reason(crop, previous_crop, soil_type),
        })

    return result


@app.route('/rainfall-estimate', methods=['GET'])
def rainfall_estimate():
    try:
        soil_type = request.args.get('soil_type', '')
        crop = request.args.get('crop', '')
        print(f"[rainfall-estimate] soil_type='{soil_type}' crop='{crop}'")

        if soil_type:
            normalized = soil_type.strip()
            if normalized not in REGIONAL_RAINFALL:
                available = ', '.join(REGIONAL_RAINFALL.keys())
                return jsonify({'error': f'No rainfall data for soil type: {soil_type}. Available: {available}'}), 404
            info = REGIONAL_RAINFALL[normalized]
            estimated = round((info['low'] + info['high']) / 2)
            return jsonify({
                'rainfall_mm': estimated,
                'source': info['label'],
                'type': 'regional_seasonal_average',
            })

        if crop:
            normalized = crop.strip().lower()
            if normalized not in _CROP_RANGES_LOWER:
                return jsonify({'error': f'No rainfall data for crop: {crop}'}), 404
            canonical_name, (low, high) = _CROP_RANGES_LOWER[normalized]
            estimated = round((low + high) / 2)
            return jsonify({
                'rainfall_mm': estimated,
                'source': f'{canonical_name} water requirement from training data',
                'type': 'crop_water_requirement',
            })

        return jsonify({'error': 'Missing required parameter: soil_type or crop'}), 400

    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.get_json()
        required = ['N', 'P', 'K', 'ph', 'temperature', 'humidity', 'rainfall']
        missing = [f for f in required if f not in data]
        if missing:
            return jsonify({'error': f'Missing fields: {missing}'}), 400

        input_df = pd.DataFrame([{
            'N': data['N'], 'P': data['P'], 'K': data['K'],
            'temperature': data['temperature'], 'humidity': data['humidity'],
            'ph': data['ph'], 'rainfall': data['rainfall'],
        }])

        probabilities = model.predict_proba(input_df)[0]
        classes = model.classes_
        top3_idx = probabilities.argsort()[-3:][::-1]

        return jsonify({
            'recommended_crop': classes[top3_idx[0]],
            'top_3': [
                {'crop': classes[i], 'confidence': round(float(probabilities[i]), 3)}
                for i in top3_idx
            ],
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/recommend-crop', methods=['POST'])
def recommend_crop_endpoint():
    try:
        data = request.get_json()

        required_fields = ['soil_type', 'previous_crop', 'temperature', 'humidity', 'rainfall']
        missing = [f for f in required_fields if f not in data]
        if missing:
            return jsonify({'error': f'Missing fields: {missing}'}), 400

        recommendations = recommend_crop(
            soil_type=data['soil_type'],
            previous_crop=data['previous_crop'],
            temperature=data['temperature'],
            humidity=data['humidity'],
            rainfall=data['rainfall']
        )

        return jsonify({
            'input': {
                'soil_type': data['soil_type'],
                'previous_crop': data['previous_crop'],
                'temperature': data['temperature'],
                'humidity': data['humidity'],
                'rainfall': data['rainfall']
            },
            'recommendations': recommendations
        })

    except ValueError as e:
        return jsonify({'error': str(e)}), 400
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/', methods=['GET'])
def health_check():
    return jsonify({'status': 'Crop recommendation service is running'})


if __name__ == '__main__':
    port = 5001
    print(f"\n  Registered routes:")
    for rule in app.url_map.iter_rules():
        print(f"    {rule.methods - {'OPTIONS', 'HEAD'}} {rule.rule}")
    print(f"\n  CORS enabled for all origins")
    print(f"  Starting on http://0.0.0.0:{port}\n")
    app.run(host='0.0.0.0', port=port, debug=True)
