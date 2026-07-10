require('dotenv').config();
const mongoose = require('mongoose');
const { askFarmAssistant } = require('./services/chatService');

mongoose.connect(process.env.MONGO_URI).then(async () => {
  const answer = await askFarmAssistant('esp32-01', 'Should I water my crop today?');
  console.log('Assistant answer:', answer);
  process.exit(0);
});