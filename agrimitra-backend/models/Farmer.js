const mongoose = require('mongoose');

const farmerSchema = new mongoose.Schema({
  name: { type: String, required: true },
  phone: { type: String, required: true, unique: true },
  passwordHash: { type: String, required: true },
  farmName: { type: String },
  deviceId: { type: String, default: null },
  currentCrop: { type: String, default: null },
  plantingDate: { type: Date, default: null },
  location: {
    lat: { type: Number, default: 12.9716 },
    lon: { type: Number, default: 77.5946 }
  },
  preferredLanguage: { type: String, default: 'en-IN' },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Farmer', farmerSchema);