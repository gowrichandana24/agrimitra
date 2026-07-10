require('dotenv').config();
const { fetchWeather, extractTodayStats } = require('./services/weatherService');

// Bengaluru coordinates - change if your test farm is elsewhere
const LAT = 12.9716;
const LON = 77.5946;

fetchWeather(LAT, LON)
  .then((data) => {
    const stats = extractTodayStats(data);
    console.log('Today\'s weather stats:', stats);
  })
  .catch((err) => console.error('Weather fetch error:', err.message));