const mongoose = require('mongoose');

const chatMessageSchema = new mongoose.Schema({
  farmerId: { type: String, required: true },
  role: { type: String, enum: ['user', 'model'], required: true },
  text: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('ChatMessage', chatMessageSchema);