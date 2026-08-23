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
suitability_df = pd.read_csv(os.path.join(DATASET_DIR, 'crop_soil_suitability_matrix.csv'))

# {(crop_lower, soil_type): {'fao_class': ..., 'score': ..., 'justification': ...}}
SUITABILITY_MATRIX = {}
for _, row in suitability_df.iterrows():
    key = (row['crop'].strip().lower(), row['soil_type'].strip())
    SUITABILITY_MATRIX[key] = {
        'fao_class': row['fao_class'],
        'score': int(row['suitability_score']),
        'justification': row['justification'],
    }


def get_soil_suitability_score(crop, soil_type):
    """Return graded FAO suitability score (0-100) for a crop on a soil type."""
    key = (crop.strip().lower(), soil_type.strip())
    entry = SUITABILITY_MATRIX.get(key)
    return entry['score'] if entry else 40  # default S3 if missing

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
    'Green Gram', 'Soybean', 'Groundnut',
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

TIER_SCORE = {-3: 100, -2: 67, -1: 33, 0: 0}


def estimate_soil_values(soil_type):
    match = soil_df[soil_df['soil_type'].str.lower() == soil_type.strip().lower()]
    if match.empty:
        available = ', '.join(soil_df['soil_type'].tolist())
        raise ValueError(f"Unknown soil type '{soil_type}'. Available: {available}")
    row = match.iloc[0]
    return {'N': row['N_est'], 'P': row['P_est'], 'K': row['K_est'], 'ph': row['ph_est']}


def _get_crop_family(crop):
    """Return the plant family for a crop from rotation_df."""
    match = rotation_df[rotation_df['crop'].str.lower() == crop.lower()]
    return match.iloc[0]['family'] if not match.empty else None


def _get_nitrogen_behavior(crop):
    """Return 'Fixer', 'Depleter', or 'Neutral' for a crop."""
    if crop in NITROGEN_FIXERS:
        return 'Fixer'
    if crop in NITROGEN_DEPLETERS:
        return 'Depleter'
    return 'Neutral'


def _get_score_breakdown(crop, rf_confidence, soil_type, previous_crop):
    """Return the three-component score breakdown (each 0-100)."""
    tier = _rotation_sort_key(crop, previous_crop, soil_type)
    rotation_score = TIER_SCORE[tier]
    soil_score = get_soil_suitability_score(crop, soil_type)
    rf_score = round(rf_confidence * 100)
    return {
        'model_confidence': rf_score,
        'soil_suitability': soil_score,
        'rotation_benefit': rotation_score,
    }


def _compute_overall_fit_score(score_breakdown):
    """Derive overall_fit_score (0-100) from the three breakdown components.

    Uses exact weights: 40% model_confidence, 35% soil_suitability,
    25% rotation_benefit. The result always matches the breakdown.
    """
    mc = score_breakdown['model_confidence']
    ss = score_breakdown['soil_suitability']
    rb = score_breakdown['rotation_benefit']
    return round(0.40 * mc + 0.35 * ss + 0.25 * rb)


def _get_dynamic_reasons(crop, previous_crop, soil_type, rainfall):
    """Generate a list of specific, data-driven reason strings."""
    reasons = []

    # 1. Family rotation
    crop_family = _get_crop_family(crop)
    prev_family = _get_crop_family(previous_crop)
    if crop_family and prev_family:
        if crop_family != prev_family:
            reasons.append(
                f"Different plant family from {previous_crop} ({prev_family}) "
                f"— breaks pest and disease buildup"
            )
        else:
            reasons.append(
                f"Same family as {previous_crop} ({crop_family}) "
                f"— rotate with caution to avoid soil-borne disease"
            )

    # 2. Nitrogen behavior
    crop_nitrogen = _get_nitrogen_behavior(crop)
    prev_nitrogen = _get_nitrogen_behavior(previous_crop)
    if crop_nitrogen == 'Fixer' and prev_nitrogen == 'Depleter':
        reasons.append(
            f"Nitrogen behavior: {crop_nitrogen} — "
            f"restores nitrogen depleted by {previous_crop}"
        )
    elif crop_nitrogen == 'Depleter' and prev_nitrogen == 'Fixer':
        reasons.append(
            f"Nitrogen behavior: {crop_nitrogen} — "
            f"consumes nitrogen enriched by {previous_crop}"
        )
    elif crop_nitrogen == 'Fixer' and prev_nitrogen == 'Fixer':
        reasons.append(
            f"Nitrogen behavior: {crop_nitrogen} — "
            f"consecutive fixers build strong soil nitrogen reserves"
        )
    elif crop_nitrogen == 'Depleter' and prev_nitrogen == 'Depleter':
        reasons.append(
            f"Nitrogen behavior: {crop_nitrogen} — "
            f"consecutive depleters may require extra fertiliser input"
        )
    elif crop_nitrogen == 'Fixer':
        reasons.append(
            f"Nitrogen behavior: {crop_nitrogen} — "
            f"improves soil fertility for future crops"
        )
    else:
        reasons.append(
            f"Nitrogen behavior: {crop_nitrogen} — "
            f"standard nitrogen management with {previous_crop}"
        )

    # 3. Soil suitability (graded FAO classification)
    key = (crop.strip().lower(), soil_type.strip())
    entry = SUITABILITY_MATRIX.get(key)
    if entry:
        fao = entry['fao_class']
        score = entry['score']
        if score >= 70:
            label = "Well-suited"
        elif score >= 40:
            label = "Marginally suited"
        else:
            label = "Not suited"
        reasons.append(
            f"Soil suitability: {label} ({fao}, score {score}/100) "
            f"- {entry['justification']}"
        )

    # 4. Water requirement vs regional rainfall
    crop_range = CROP_RANGES.get(crop)
    if crop_range and rainfall is not None:
        low, high = crop_range
        regional = REGIONAL_RAINFALL.get(soil_type, {})
        reg_label = regional.get('label', 'the region')
        if rainfall >= low and rainfall <= high:
            reasons.append(
                f"Estimated water need ({low}-{high}mm) fits the region's "
                f"~{int(rainfall)}mm ({reg_label})"
            )
        elif rainfall < low:
            reasons.append(
                f"Needs {low}-{high}mm water — region averages ~{int(rainfall)}mm "
                f"({reg_label}), irrigation may be needed"
            )
        else:
            reasons.append(
                f"Needs {low}-{high}mm water — region averages ~{int(rainfall)}mm "
                f"({reg_label}), good drainage recommended"
            )

    return reasons


def _get_expected_benefit(crop, previous_crop, soil_type):
    """Return a short one-line practical takeaway."""
    crop_nitrogen = _get_nitrogen_behavior(crop)
    prev_nitrogen = _get_nitrogen_behavior(previous_crop)
    crop_family = _get_crop_family(crop)
    prev_family = _get_crop_family(previous_crop)
    soil_score = get_soil_suitability_score(crop, soil_type)

    if crop_nitrogen == 'Fixer' and prev_nitrogen == 'Depleter':
        return f"Restores nitrogen depleted by {previous_crop}"
    if crop_nitrogen == 'Depleter' and prev_nitrogen == 'Fixer':
        return f"Consumes nitrogen enriched by {previous_crop}"
    if crop_family and prev_family and crop_family != prev_family:
        return f"Diversifies pest exposure while matching soil moisture needs"
    if soil_score >= 70:
        return f"Naturally thrives in {soil_type}, reducing input costs"
    if soil_score >= 40:
        return f"Can grow on {soil_type} with moderate soil amendments"
    return f"High-confidence model pick despite limited soil suitability"


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
        breakdown = _get_score_breakdown(crop, rf_confidences[crop], soil_type, previous_crop)
        overall = _compute_overall_fit_score(breakdown)
        # Tiebreaker ensures strictly monotonic integer scores after rounding.
        # Rank 1 gets +2, rank 2 gets +1, rank 3 gets +0.
        overall += (len(final) - rank)
        result.append({
            'rank': rank,
            'crop': crop,
            'overall_fit_score': round(overall),
            'score_breakdown': breakdown,
            'reasons': _get_dynamic_reasons(crop, previous_crop, soil_type, rainfall),
            'expected_benefit': _get_expected_benefit(crop, previous_crop, soil_type),
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
