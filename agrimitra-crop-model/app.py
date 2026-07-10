from flask import Flask, request, jsonify
import joblib
import pandas as pd

app = Flask(__name__)
model = joblib.load('crop_model.pkl')

@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.get_json()

        required_fields = ['N', 'P', 'K', 'temperature', 'humidity', 'ph', 'rainfall']
        missing = [f for f in required_fields if f not in data]
        if missing:
            return jsonify({'error': f'Missing fields: {missing}'}), 400

        input_df = pd.DataFrame([{
            'N': data['N'],
            'P': data['P'],
            'K': data['K'],
            'temperature': data['temperature'],
            'humidity': data['humidity'],
            'ph': data['ph'],
            'rainfall': data['rainfall']
        }])

        prediction = model.predict(input_df)[0]

        probabilities = model.predict_proba(input_df)[0]
        classes = model.classes_
        top3_idx = probabilities.argsort()[-3:][::-1]
        top3 = [{'crop': classes[i], 'confidence': round(float(probabilities[i]), 3)} for i in top3_idx]

        return jsonify({
            'recommended_crop': prediction,
            'top_3': top3
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/', methods=['GET'])
def health_check():
    return jsonify({'status': 'Crop recommendation service is running'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)