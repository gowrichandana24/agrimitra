const mongoose = require('mongoose');

const alertSchema = new mongoose.Schema({
  farmerId: { type: String },
  deviceId: { type: String, required: true },
  type: { type: String, required: true }, // e.g. 'CRITICAL_DRY', 'HIGH_TEMP', 'HEAVY_RAIN_EXPECTED'
  severity: { type: String, enum: ['info', 'warning', 'critical'], default: 'warning' },
  message: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
  acknowledged: { type: Boolean, default: false }
});

module.exports = mongoose.model('Alert', alertSchema);