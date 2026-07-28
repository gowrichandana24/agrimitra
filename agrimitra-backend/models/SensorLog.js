const mongoose = require('mongoose');

const sensorLogSchema = new mongoose.Schema({
  farmerId: { type: String },
  deviceId: { type: String, required: true },
  moisture: { type: Number, required: true },
  temperature: { type: Number },
  humidity: { type: Number },
  timestamp: { type: Date, default: Date.now }
});

module.exports = mongoose.model('SensorLog', sensorLogSchema);