const express = require('express');
const router = express.Router();
const SensorLog = require('../models/SensorLog');
const Farmer = require('../models/Farmer');
const { getIrrigationRecommendation } = require('../services/irrigationService');
const { checkWeatherAlerts } = require('../services/alertService');
const { computeGrowthStatus } = require('../services/cropKnowledge');

const DEFAULT_LAT = 12.9716;
const DEFAULT_LON = 77.5946;

// GET irrigation recommendation for a device, using its latest real soil moisture reading
router.get('/:deviceId/recommendation', async (req, res) => {
  try {
    const latest = await SensorLog.findOne({ deviceId: req.params.deviceId })
      .sort({ timestamp: -1 });

    if (!latest) {
      return res.status(404).json({ message: 'No sensor data found for this device' });
    }

    const farmer = await Farmer.findById(req.farmerId);
    if (!farmer) {
      return res.status(404).json({ message: 'Farmer profile not found' });
    }

    const cropType = farmer.currentCrop || 'tomato';
    const lat = farmer.location?.lat ?? DEFAULT_LAT;
    const lon = farmer.location?.lon ?? DEFAULT_LON;

    let growthStage = 'mid';
    if (farmer.currentCrop && farmer.plantingDate) {
      const status = computeGrowthStatus(farmer.currentCrop, farmer.plantingDate);
      growthStage = status.stage;
    }

    const recommendation = await getIrrigationRecommendation({
      lat,
      lon,
      cropType,
      growthStage,
      soilMoisture: latest.moisture
    });

    await checkWeatherAlerts(req.params.deviceId, recommendation, req.farmerId);

    res.json(recommendation);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

module.exports = router;