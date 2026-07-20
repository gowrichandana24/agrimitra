const { GoogleGenerativeAI } = require('@google/generative-ai');
const SensorLog = require('../models/SensorLog');
const ChatMessage = require('../models/ChatMessage');
const Farmer = require('../models/Farmer');
const { getIrrigationRecommendation } = require('./irrigationService');
const { computeGrowthStatus } = require('./cropKnowledge');

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

const DEFAULT_LAT = 12.9716;
const DEFAULT_LON = 77.5946;

const LANGUAGE_NAMES = {
  'en-IN': 'English',
  'hi-IN': 'Hindi',
  'ta-IN': 'Tamil',
  'ml-IN': 'Malayalam',
  'kn-IN': 'Kannada'
};

function getSystemInstruction(languageCode) {
  const langName = LANGUAGE_NAMES[languageCode] || 'English';
  return `
You are AgriMitra, a knowledgeable, friendly AI assistant for farmers.

CRITICAL LANGUAGE RULE:
- You MUST respond ONLY in ${langName}. Every single word of your response must be in ${langName}.
- Do NOT mix English with ${langName}. Write your entire response in ${langName} script/words.
- This applies even if the farmer's question is in a different language.

For agriculture-specific questions (crops, soil, irrigation, pests, fertilizers, weather impact on farming, etc.), you will be given this specific farm's current live sensor and weather data at the start of each message. Use that data to ground your answer whenever it's relevant. For non-agriculture questions, just answer normally using your own knowledge — you don't need farm data for those.

SAFETY RULES:
- For questions about specific pesticide or fertilizer DOSAGES, or diagnosing a plant disease/pest from a description alone, give general guidance only, and clearly recommend the farmer consult their local Krishi Vigyan Kendra (KVK) or agricultural extension officer for an exact, safe recommendation. Do not state a specific dosage number as if certain.
- Keep answers short, practical, and easy to understand for a farmer.
- Responses will be spoken aloud by text-to-speech, so keep sentences natural and conversational.
- If you don't know something confidently, say so honestly instead of guessing.

Remember earlier parts of this conversation and refer back to them naturally when relevant.
`;
}

async function getFarmContextBlock(farmerId, deviceId) {
  const farmer = await Farmer.findById(farmerId);

  const latest = await SensorLog.findOne({ deviceId }).sort({ timestamp: -1 });

  if (!latest && !farmer) {
    return "[No live farm sensor data or farmer profile available right now.]";
  }

  const cropType = farmer?.currentCrop || 'tomato';
  const lat = farmer?.location?.lat ?? DEFAULT_LAT;
  const lon = farmer?.location?.lon ?? DEFAULT_LON;

  let growthStage = 'mid';
  let growthInfo = null;
  if (farmer?.currentCrop && farmer?.plantingDate) {
    const status = computeGrowthStatus(farmer.currentCrop, farmer.plantingDate);
    growthStage = status.stage;
    growthInfo = status;
  }

  let contextParts = [];

  if (farmer) {
    contextParts.push(`- Farm: ${farmer.farmName || 'Not specified'}`);
    contextParts.push(`- Growing: ${cropType}`);
    if (farmer.plantingDate) {
      contextParts.push(`- Planted on: ${new Date(farmer.plantingDate).toISOString().split('T')[0]}`);
    }
    if (growthInfo) {
      contextParts.push(`- Growth stage: ${growthInfo.stage} (day ${growthInfo.daysSincePlanting} of ${growthInfo.durationDays}, ~${growthInfo.daysToHarvest} days to harvest)`);
    }
  }

  if (latest) {
    contextParts.push(`- Soil moisture: ${latest.moisture}%`);
    contextParts.push(`- Temperature: ${latest.temperature}°C`);
    contextParts.push(`- Humidity: ${latest.humidity}%`);

    try {
      const irrigation = await getIrrigationRecommendation({
        lat,
        lon,
        cropType,
        growthStage,
        soilMoisture: latest.moisture
      });

      contextParts.push(`- Today's ET0 (water loss estimate): ${irrigation.ET0} mm`);
      contextParts.push(`- Crop water demand today: ${irrigation.cropWaterDemandMm} mm`);
      contextParts.push(`- Rain probability today: ${irrigation.rainProbability}%`);
      contextParts.push(`- Irrigation recommendation: ${irrigation.shouldIrrigate ? 'Irrigation needed' : 'No irrigation needed'} — ${irrigation.reason}`);
    } catch (_) {
      contextParts.push(`- Weather/irrigation data unavailable`);
    }
  } else {
    contextParts.push(`- No live sensor readings available right now`);
  }

  return `[Current farm data — use only if this message is agriculture-related:\n${contextParts.join('\n')}]`;
}

// Loads the last N turns of this farmer's chat history from the database
async function loadHistory(farmerId, limit = 10) {
  const recent = await ChatMessage.find({ farmerId })
    .sort({ createdAt: -1 })
    .limit(limit);
  return recent.reverse(); // oldest first, for correct conversation order
}

async function askFarmAssistant(farmerId, deviceId, question, language = 'en-IN') {
  const history = await loadHistory(farmerId);

  const model = genAI.getGenerativeModel({
    model: 'gemini-2.5-flash',
    systemInstruction: getSystemInstruction(language)
  });

  const geminiHistory = history.map((h) => ({
    role: h.role,
    parts: [{ text: h.text }]
  }));

  const chat = model.startChat({ history: geminiHistory });

  const farmContext = await getFarmContextBlock(farmerId, deviceId);
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