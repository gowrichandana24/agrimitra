const express = require('express');
const router = express.Router();
const axios = require('axios');
const SensorLog = require('../models/SensorLog');

// You'll need axios installed in the backend if you haven't already:
// npm install axios

router.get('/:deviceId/recommend', async (req, res) => {
  try {
    const latest = await SensorLog.findOne({ deviceId: req.params.deviceId })
      .sort({ timestamp: -1 });

    if (!latest) {
      return res.status(404).json({ message: 'No sensor data found for this device' });
    }

    // N, P, K, and pH aren't things your current sensors measure yet,
    // so for now we use reasonable placeholder soil values alongside
    // your REAL temperature and humidity readings. Swapping in real
    // NPK/pH sensor values later is a one-line change here.
    const payload = {
      N: 70,
      P: 40,
      K: 45,
      ph: 6.5,
      temperature: latest.temperature,
      humidity: latest.humidity,
      rainfall: 120 // placeholder until wired to OpenWeather's rainfall data
    };

    const response = await axios.post('http://localhost:5001/predict', payload);

    res.json(response.data);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

module.exports = router;