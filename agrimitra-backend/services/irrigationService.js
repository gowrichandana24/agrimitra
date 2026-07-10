const { calculateET0 } = require('./et0Calculator');
const { fetchWeather, extractTodayStats } = require('./weatherService');

const CROP_KC = {
  tomato: { initial: 0.6, mid: 1.15, late: 0.8 },
  ragi: { initial: 0.5, mid: 1.0, late: 0.6 },
  paddy: { initial: 1.05, mid: 1.2, late: 0.9 }
};

// NEW: simple in-memory cache, keyed by lat,lon
const weatherCache = {};
const CACHE_DURATION_MS = 45 * 60 * 1000; // 45 minutes

async function getCachedWeatherStats(lat, lon) {
  const key = `${lat},${lon}`;
  const cached = weatherCache[key];

  if (cached && (Date.now() - cached.fetchedAt) < CACHE_DURATION_MS) {
    return cached.stats; // reuse recent data, no API call
  }

  const forecast = await fetchWeather(lat, lon);
  const stats = extractTodayStats(forecast);

  weatherCache[key] = { stats, fetchedAt: Date.now() };
  return stats;
}

function getDayOfYear(date = new Date()) {
  const start = new Date(date.getFullYear(), 0, 0);
  const diff = date - start;
  return Math.floor(diff / (1000 * 60 * 60 * 24));
}

async function getIrrigationRecommendation({ lat, lon, cropType = 'tomato', growthStage = 'mid', soilMoisture }) {
  const { tMax, tMin, tMean, rainProbability } = await getCachedWeatherStats(lat, lon);

  const dayOfYear = getDayOfYear();
  const { ET0 } = calculateET0({ tMax, tMin, tMean, latitude: lat, dayOfYear });

  const kc = CROP_KC[cropType]?.[growthStage] || 1.0;
  const cropWaterDemandMm = Number((ET0 * kc).toFixed(2));

  let shouldIrrigate = true;
  let reason = '';

  if (rainProbability >= 60) {
    shouldIrrigate = false;
    reason = `Rain is likely today (${rainProbability}% chance), skipping irrigation.`;
  } else if (soilMoisture >= 70) {
    shouldIrrigate = false;
    reason = `Soil moisture is already high (${soilMoisture}%), skipping irrigation.`;
  } else {
    reason = `Crop needs approximately ${cropWaterDemandMm}mm of water today based on weather conditions.`;
  }

  return {
    ET0,
    cropWaterDemandMm,
    tMax,
    tMin,
    tMean,
    rainProbability,
    soilMoisture,
    shouldIrrigate,
    reason
  };
}

module.exports = { getIrrigationRecommendation };