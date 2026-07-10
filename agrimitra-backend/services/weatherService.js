const https = require('https');

function fetchWeather(lat, lon) {
  return new Promise((resolve, reject) => {
    const url = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&units=metric&appid=${process.env.OPENWEATHER_KEY}`;

    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          if (parsed.cod && parsed.cod !== '200') {
            return reject(new Error(parsed.message || 'OpenWeather API error'));
          }
          resolve(parsed);
        } catch (err) {
          reject(err);
        }
      });
    }).on('error', reject);
  });
}

// Extracts today's Tmax, Tmin, Tmean and rain probability from the forecast response
function extractTodayStats(forecastData) {
  const today = new Date().toISOString().split('T')[0]; // e.g. "2026-07-08"

  const todaySlots = forecastData.list.filter((slot) =>
    slot.dt_txt.startsWith(today)
  );

  if (todaySlots.length === 0) {
    throw new Error('No forecast slots found for today');
  }

  const temps = todaySlots.map((slot) => slot.main.temp);
  const tMax = Math.max(...temps);
  const tMin = Math.min(...temps);
  const tMean = temps.reduce((a, b) => a + b, 0) / temps.length;

  // rain probability: highest "pop" (probability of precipitation) value for today, as a %
  const rainProbability = Math.max(...todaySlots.map((slot) => (slot.pop || 0) * 100));

  return {
    tMax: Number(tMax.toFixed(1)),
    tMin: Number(tMin.toFixed(1)),
    tMean: Number(tMean.toFixed(1)),
    rainProbability: Number(rainProbability.toFixed(0))
  };
}

module.exports = { fetchWeather, extractTodayStats };