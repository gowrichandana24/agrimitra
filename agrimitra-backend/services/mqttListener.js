const mqtt = require('mqtt');
const SensorLog = require('../models/SensorLog');
const { checkSensorAlerts } = require('./alertService');

function startMqttListener() {
  const client = mqtt.connect(process.env.MQTT_URL, {
    username: process.env.MQTT_USER,
    password: process.env.MQTT_PASS
  });

  client.on('connect', () => {
    console.log('Connected to MQTT broker');
    client.subscribe('farm/+/sensors', (err) => {
      if (err) console.error('Subscribe error:', err);
      else console.log('Subscribed to farm/+/sensors');
    });
  });

 client.on('message', async (topic, message) => {
  try {
    const data = JSON.parse(message.toString());
    const log = new SensorLog({
      deviceId: data.deviceId,
      moisture: data.moisture,
      temperature: data.temperature,
      humidity: data.humidity,
      timestamp: data.timestamp || new Date()
    });
    await log.save();
    console.log('Saved sensor log:', data.deviceId, data.moisture);

    await checkSensorAlerts(data.deviceId, { moisture: data.moisture, temperature: data.temperature });
  } catch (err) {
    console.error('Error saving sensor log:', err.message);
  }
});

  client.on('error', (err) => console.error('MQTT error:', err));
}

module.exports = startMqttListener;