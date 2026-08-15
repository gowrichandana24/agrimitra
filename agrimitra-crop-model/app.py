import os
import pandas as pd
import joblib
from flask import Flask, request, jsonify

BASE_DIR = os.path.dirname(__file__)
DATASET_DIR = os.path.join(BASE_DIR, 'dataset')
MODELS_DIR = os.path.join(BASE_DIR, 'models')

app = Flask(__name__)
model = joblib.load(os.path.join(MODELS_DIR, 'crop_rf_model.pkl'))

soil_df = pd.read_csv(os.path.join(DATASET_DIR, 'soil_npk_ph_lookup.csv'))
rotation_df = pd.read_csv(os.path.join(DATASET_DIR, 'crop_family_rotation_rules.csv'))


def estimate_soil_values(soil_type: str) -> dict:
    match = soil_df[soil_df['soil_type'].str.lower() == soil_type.strip().lower()]
    if match.empty:
        available = ', '.join(soil_df['soil_type'].tolist())
        raise ValueError(f"Unknown soil type '{soil_type}'. Available: {available}")
    row = match.iloc[0]
    return {
        'N': row['N_est'],
        'P': row['P_est'],
        'K': row['K_est'],
        'ph': row['ph_est']
    }


def get_rotation_candidates(previous_crop: str, rf_top3: list) -> list:
    prev_match = rotation_df[rotation_df['crop'].str.lower() == previous_crop.strip().lower()]
    if prev_match.empty:
        return rf_top3

    prev_family = prev_match.iloc[0]['family']

    filtered = []
    excluded = []
    for crop in rf_top3:
        crop_match = rotation_df[rotation_df['crop'].str.lower() == crop.lower()]
        if not crop_match.empty and crop_match.iloc[0]['family'] == prev_family:
            excluded.append(crop)
        else:
            filtered.append(crop)

    def crop_sort_key(crop):
        crop_match = rotation_df[rotation_df['crop'].str.lower() == crop.lower()]
        if not crop_match.empty and 'Fixer' in crop_match.iloc[0]['nitrogen_behavior']:
            return 0
        return 1

    filtered.sort(key=crop_sort_key)
    return filtered, excluded


def recommend_crop(soil_type: str, previous_crop: str, temperature: float,
                   humidity: float, rainfall: float) -> list:
    soil_vals = estimate_soil_values(soil_type)

    input_df = pd.DataFrame([{
        'N': soil_vals['N'],
        'P': soil_vals['P'],
        'K': soil_vals['K'],
        'temperature': temperature,
        'humidity': humidity,
        'ph': soil_vals['ph'],
        'rainfall': rainfall
    }])

    probabilities = model.predict_proba(input_df)[0]
    classes = model.classes_
    top3_idx = probabilities.argsort()[-3:][::-1]
    rf_top3 = [classes[i] for i in top3_idx]
    rf_confidences = {classes[i]: round(float(probabilities[i]), 3) for i in top3_idx}

    filtered, excluded = get_rotation_candidates(previous_crop, rf_top3)

    reasons = {}
    for crop in filtered:
        crop_match = rotation_df[rotation_df['crop'].str.lower() == crop.lower()]
        if not crop_match.empty:
            nb = crop_match.iloc[0]['nitrogen_behavior']
            if 'Fixer' in nb:
                reasons[crop] = "Fixes nitrogen in soil, replenishes after previous crop"
            else:
                reasons[crop] = "Suitable rotation: different family from " + previous_crop
        else:
            reasons[crop] = "RF top pick, rotation-compatible"

    for crop in excluded:
        reasons[crop] = "Excluded: same family as " + previous_crop

    result = []
    rank = 1
    for crop in filtered:
        result.append({
            'rank': rank,
            'crop': crop,
            'confidence': rf_confidences[crop],
            'reason': reasons[crop]
        })
        rank += 1

    for crop in excluded:
        result.append({
            'rank': rank,
            'crop': crop,
            'confidence': rf_confidences[crop],
            'reason': reasons[crop]
        })
        rank += 1

    return result


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
    app.run(host='0.0.0.0', port=5001, debug=True)
