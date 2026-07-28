const express = require('express');
const router = express.Router();
const Alert = require('../models/Alert');
const Farmer = require('../models/Farmer');

// Get recent alerts for a device (most recent first)
router.get('/:deviceId', async (req, res) => {
  try {
    const farmer = await Farmer.findById(req.farmerId);
    if (!farmer) {
      return res.status(404).json({ message: 'Farmer not found' });
    }
    if (!farmer.deviceId) {
      return res.status(403).json({ message: 'No device linked to this account yet' });
    }
    if (farmer.deviceId !== req.params.deviceId) {
      return res.status(403).json({ message: 'Access denied: device not associated with this account' });
    }

    const alerts = await Alert.find({ deviceId: req.params.deviceId })
      .sort({ createdAt: -1 })
      .limit(20);
    res.json(alerts);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

// Mark an alert as acknowledged/read
router.patch('/:alertId/acknowledge', async (req, res) => {
  try {
    const alert = await Alert.findOneAndUpdate(
      { _id: req.params.alertId, farmerId: req.farmerId },
      { acknowledged: true },
      { new: true }
    );
    if (!alert) return res.status(404).json({ message: 'Alert not found' });
    res.json(alert);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

module.exports = router;