const { calculateET0 } = require('./services/et0Calculator');

// Made-up but realistic numbers for a hot day in Bengaluru (latitude ~13°N), mid-July (day 189)
const result = calculateET0({
  tMax: 32,
  tMin: 22,
  tMean: 27,
  latitude: 13,
  dayOfYear: 189
});

console.log('Test result:', result);