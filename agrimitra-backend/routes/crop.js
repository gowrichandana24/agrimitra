const express = require('express');
const router = express.Router();
const axios = require('axios');
const SensorLog = require('../models/SensorLog');
const Farmer = require('../models/Farmer');
const { fetchWeather, extractTodayStats } = require('../services/weatherService');

const DEFAULT_LAT = 12.9716;
const DEFAULT_LON = 77.5946;

router.get('/:deviceId/recommend', async (req, res) => {
  try {
    const latest = await SensorLog.findOne({ deviceId: req.params.deviceId })
      .sort({ timestamp: -1 });

    if (!latest) {
      return res.status(404).json({ message: 'No sensor data found for this device' });
    }

    const farmer = await Farmer.findById(req.farmerId);
    const lat = farmer?.location?.lat ?? DEFAULT_LAT;
    const lon = farmer?.location?.lon ?? DEFAULT_LON;

    // N, P, K, and pH aren't measured by current sensors — these are reasonable
    // soil defaults. Swap in real sensor values when available.
    const payload = {
      N: 70,
      P: 40,
      K: 45,
      ph: 6.5,
      temperature: latest.temperature,
      humidity: latest.humidity,
      rainfall: 120
    };

    // Try to get real rainfall from weather data
    try {
      const forecast = await fetchWeather(lat, lon);
      const todayStats = extractTodayStats(forecast);
      // Use rain probability as a proxy for expected rainfall intensity
      // A probability of 100% roughly maps to ~15mm, 0% to 0mm
      payload.rainfall = Math.round(todayStats.rainProbability * 0.15);
    } catch (_) {
      // Weather fetch failed — keep default rainfall value
    }

    const response = await axios.post('http://localhost:5001/predict', payload);

    res.json(response.data);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

module.exports = router;