const express = require('express');
const router = express.Router();
const SensorLog = require('../models/SensorLog');
const Farmer = require('../models/Farmer');

// GET latest reading for a device
router.get('/:deviceId/latest', async (req, res) => {
  try {
    const farmer = await Farmer.findById(req.farmerId);
    if (!farmer) {
      return res.status(404).json({ message: 'Farmer not found' });
    }
    const latest = await SensorLog.findOne({ deviceId: req.params.deviceId })
      .sort({ timestamp: -1 });
    res.json(latest || {});
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

// GET history for a device (last 50 readings, most recent first)
router.get('/:deviceId/history', async (req, res) => {
  try {
    const farmer = await Farmer.findById(req.farmerId);
    if (!farmer) {
      return res.status(404).json({ message: 'Farmer not found' });
    }
    const history = await SensorLog.find({ deviceId: req.params.deviceId })
      .sort({ timestamp: -1 })
      .limit(50);
    res.json(history);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

module.exports = router;