const { GoogleGenerativeAI } = require('@google/generative-ai');
const SensorLog = require('../models/SensorLog');
const ChatMessage = require('../models/ChatMessage');
const { getIrrigationRecommendation } = require('./irrigationService');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const SYSTEM_INSTRUCTION = `
You are AgriMitra, a knowledgeable, friendly AI assistant. You can help with absolutely any topic the farmer asks about — general knowledge, everyday questions, casual conversation — just like a general-purpose assistant.

For agriculture-specific questions (crops, soil, irrigation, pests, fertilizers, weather impact on farming, etc.), you will be given this specific farm's current live sensor and weather data at the start of each message. Use that data to ground your answer whenever it's relevant. For non-agriculture questions, just answer normally using your own knowledge — you don't need farm data for those.

LANGUAGE RULE:
- Respond in the SAME language the farmer's question is written in.

SAFETY RULES:
- For questions about specific pesticide or fertilizer DOSAGES, or diagnosing a plant disease/pest from a description alone, give general guidance only, and clearly recommend the farmer consult their local Krishi Vigyan Kendra (KVK) or agricultural extension officer for an exact, safe recommendation. Do not state a specific dosage number as if certain.
- Keep answers short, practical, and in plain, friendly language.
- If you don't know something confidently, say so honestly instead of guessing.

Remember earlier parts of this conversation and refer back to them naturally when relevant, the way a real assistant would.
`;

async function getFarmContextBlock(deviceId) {
  const latest = await SensorLog.findOne({ deviceId }).sort({ timestamp: -1 });

  if (!latest) {
    return "[No live farm sensor data available right now.]";
  }

  const irrigation = await getIrrigationRecommendation({
    lat: 12.9716,
    lon: 77.5946,
    cropType: 'tomato',
    growthStage: 'mid',
    soilMoisture: latest.moisture
  });

  return `[Current farm data — use only if this message is agriculture-related:
- Soil moisture: ${latest.moisture}%
- Temperature: ${latest.temperature}°C
- Humidity: ${latest.humidity}%
- Today's ET0 (water loss estimate): ${irrigation.ET0} mm
- Crop water demand today: ${irrigation.cropWaterDemandMm} mm
- Rain probability today: ${irrigation.rainProbability}%
- Irrigation recommendation: ${irrigation.shouldIrrigate ? 'Irrigation needed' : 'No irrigation needed'} — ${irrigation.reason}]`;
}

// Loads the last N turns of this farmer's chat history from the database
async function loadHistory(farmerId, limit = 10) {
  const recent = await ChatMessage.find({ farmerId })
    .sort({ createdAt: -1 })
    .limit(limit);
  return recent.reverse(); // oldest first, for correct conversation order
}

async function askFarmAssistant(farmerId, deviceId, question) {
  const history = await loadHistory(farmerId);

  const model = genAI.getGenerativeModel({
    model: 'gemini-2.5-flash',
    systemInstruction: SYSTEM_INSTRUCTION
  });

  const geminiHistory = history.map((h) => ({
    role: h.role,
    parts: [{ text: h.text }]
  }));

  const chat = model.startChat({ history: geminiHistory });

  const farmContext = await getFarmContextBlock(deviceId);
  const turnMessage = `${farmContext}\n\nFarmer: ${question}`;

  let result;
  let attempts = 0;
  while (attempts < 2) {
    try {
      result = await chat.sendMessage(turnMessage);
      break;
    } catch (err) {
      attempts++;
      if (err.message?.includes('503') && attempts < 2) {
        await new Promise((r) => setTimeout(r, 1500));
      } else {
        throw err;
      }
    }
  }

  const answerText = result.response.text();

  // Save both sides of this turn to the database
  await ChatMessage.create({ farmerId, role: 'user', text: question });
  await ChatMessage.create({ farmerId, role: 'model', text: answerText });

  return answerText;
}

module.exports = { askFarmAssistant, loadHistory };