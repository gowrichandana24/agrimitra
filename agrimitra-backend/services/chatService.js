const { GoogleGenerativeAI } = require('@google/generative-ai');
const SensorLog = require('../models/SensorLog');
const { getIrrigationRecommendation } = require('./irrigationService');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

async function getFarmContext(deviceId) {
  const latest = await SensorLog.findOne({ deviceId }).sort({ timestamp: -1 });

  if (!latest) {
    return null;
  }

  const irrigation = await getIrrigationRecommendation({
    lat: 12.9716,
    lon: 77.5946,
    cropType: 'tomato',
    growthStage: 'mid',
    soilMoisture: latest.moisture
  });

  return { latest, irrigation };
}

async function askFarmAssistant(deviceId, question) {
  const context = await getFarmContext(deviceId);

  if (!context) {
    return "I don't have any sensor data for this farm yet, so I can't give a grounded answer.";
  }

  const { latest, irrigation } = context;

  const prompt = `
You are AgriMitra, a knowledgeable farming assistant for Indian farmers, able to help with any agriculture-related question — not just irrigation.

You can answer using two types of information:
1. This specific farm's real-time data (given below) — use this whenever the question is about this farm's current conditions, soil, or irrigation.
2. Your own general agricultural knowledge — use this for broader questions about crops, pests, diseases, fertilizers, crop rotation, farming practices, government schemes, market practices, or general farming advice.

LANGUAGE RULE:
- Respond in the SAME language the farmer's question is written in. If the question is in English, respond in English. If it is in Hindi, respond in Hindi. If it is in Kannada, respond in Kannada. Do not switch languages unless the farmer does.

IMPORTANT SAFETY RULES:
- For questions about specific pesticide or fertilizer DOSAGES, or diagnosing a plant disease/pest from a description alone, give general guidance only, and clearly recommend the farmer consult their local Krishi Vigyan Kendra (KVK) or agricultural extension officer for an exact, safe recommendation. Do not state a specific dosage number as if certain.
- Keep answers short, practical, and in plain language suitable for a farmer who may not be familiar with technical terms.
- If you don't know something confidently, say so honestly instead of guessing.

Current farm data (use only when relevant to the question):
- Soil moisture: ${latest.moisture}%
- Temperature: ${latest.temperature}°C
- Humidity: ${latest.humidity}%
- Today's ET0 (water loss estimate): ${irrigation.ET0} mm
- Crop water demand today: ${irrigation.cropWaterDemandMm} mm
- Rain probability today: ${irrigation.rainProbability}%
- Irrigation recommendation: ${irrigation.shouldIrrigate ? 'Irrigation needed' : 'No irrigation needed'} — ${irrigation.reason}

Farmer's question: "${question}"
`;

  const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
  const result = await model.generateContent(prompt);
  const responseText = result.response.text();

  return responseText;
}

module.exports = { askFarmAssistant };