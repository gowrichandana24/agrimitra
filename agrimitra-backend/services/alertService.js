const Alert = require('../models/Alert');

const THROTTLE_MINUTES = 30; // don't repeat the same alert type more than once per 30 min

async function shouldCreateAlert(deviceId, type) {
  const recent = await Alert.findOne({
    deviceId,
    type,
    createdAt: { $gte: new Date(Date.now() - THROTTLE_MINUTES * 60 * 1000) }
  });
  return !recent; // only create if nothing recent of this type
}

async function createAlert(deviceId, type, severity, message, farmerId) {
  const shouldCreate = await shouldCreateAlert(deviceId, type);
  if (!shouldCreate) return null;

  const alert = new Alert({ farmerId, deviceId, type, severity, message });
  await alert.save();
  console.log(`Alert created [${severity}]: ${message}`);
  return alert;
}

// Checks based on raw sensor readings (moisture, temperature, humidity)
async function checkSensorAlerts(deviceId, reading, farmerId) {
  const { moisture, temperature } = reading;

  if (moisture < 15) {
    await createAlert(
      deviceId,
      'CRITICAL_DRY',
      'critical',
      `Soil moisture critically low at ${moisture}%. Irrigation needed urgently.`,
      farmerId
    );
  }

  if (temperature > 38) {
    await createAlert(
      deviceId,
      'HIGH_TEMP',
      'warning',
      `Temperature is very high at ${temperature}°C. Crop may be under heat stress.`,
      farmerId
    );
  }
}

// Checks based on the irrigation recommendation (has weather/rain data)
async function checkWeatherAlerts(deviceId, irrigationRec, farmerId) {
  if (irrigationRec.rainProbability >= 70) {
    await createAlert(
      deviceId,
      'HEAVY_RAIN_EXPECTED',
      'info',
      `Heavy rain expected today (${irrigationRec.rainProbability}% chance). Consider delaying any planned fieldwork.`,
      farmerId
    );
  }
}

module.exports = { checkSensorAlerts, checkWeatherAlerts };