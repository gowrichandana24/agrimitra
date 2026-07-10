require('dotenv').config();
const { getIrrigationRecommendation } = require('./services/irrigationService');

getIrrigationRecommendation({
  lat: 12.9716,
  lon: 77.5946,
  cropType: 'tomato',
  growthStage: 'mid',
  soilMoisture: 85 // pretend the sensor read 35%
})
  .then((result) => console.log('Irrigation recommendation:', result))
  .catch((err) => console.error('Error:', err.message));