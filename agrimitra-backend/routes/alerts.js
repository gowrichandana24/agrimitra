const express = require('express');
const router = express.Router();
const Alert = require('../models/Alert');

// Get recent alerts for a device (most recent first)
router.get('/:deviceId', async (req, res) => {
  try {
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
    const alert = await Alert.findByIdAndUpdate(
      req.params.alertId,
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