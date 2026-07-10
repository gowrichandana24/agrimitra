const express = require('express');
const router = express.Router();
const SensorLog = require('../models/SensorLog');
const { getIrrigationRecommendation } = require('../services/irrigationService');
const { checkWeatherAlerts } = require('../services/alertService');

// GET irrigation recommendation for a device, using its latest real soil moisture reading
router.get('/:deviceId/recommendation', async (req, res) => {
  try {
    const latest = await SensorLog.findOne({ deviceId: req.params.deviceId })
      .sort({ timestamp: -1 });

    if (!latest) {
      return res.status(404).json({ message: 'No sensor data found for this device' });
    }

    // For now, farm location and crop info are hardcoded (Bengaluru, tomato, mid-stage).
    // Later this can come from a Farm/Device profile stored per-farmer.
    const recommendation = await getIrrigationRecommendation({
      lat: 12.9716,
      lon: 77.5946,
      cropType: 'tomato',
      growthStage: 'mid',
      soilMoisture: latest.moisture
    });

    await checkWeatherAlerts(req.params.deviceId, recommendation);

    res.json(recommendation);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

module.exports = router;