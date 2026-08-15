const mqtt = require('mqtt');
const SensorLog = require('../models/SensorLog');
const Farmer = require('../models/Farmer');
const { checkSensorAlerts } = require('./alertService');

let mqttActive = false;

function isMqttActive() {
  return mqttActive;
}

function startMqttListener() {
  const mqttUrl = process.env.MQTT_URL;

  if (!mqttUrl) {
    console.log('MQTT broker URL not configured — sensor live-data features disabled');
    return;
  }

  const client = mqtt.connect(mqttUrl, {
    username: process.env.MQTT_USER,
    password: process.env.MQTT_PASS,
    connectTimeout: 5000,
    reconnectPeriod: 0
  });

  let loggedFailure = false;

  client.on('connect', () => {
    mqttActive = true;
    console.log('Connected to MQTT broker');
    client.subscribe('farm/+/sensors', (err) => {
      if (err) console.error('Subscribe error:', err);
      else console.log('Subscribed to farm/+/sensors');
    });
  });

  client.on('error', (err) => {
    if (!loggedFailure) {
      console.error(`MQTT broker unreachable — sensor live-data features disabled (${err.message})`);
      loggedFailure = true;
    }
    mqttActive = false;
    client.end(true);
  });

  client.on('close', () => {
    if (!loggedFailure) {
      console.error('MQTT broker unreachable — sensor live-data features disabled');
      loggedFailure = true;
    }
    mqttActive = false;
  });

  client.on('message', async (topic, message) => {
    try {
      const data = JSON.parse(message.toString());

      const farmer = await Farmer.findOne({ deviceId: data.deviceId });
      const farmerId = farmer ? String(farmer._id) : undefined;

      const log = new SensorLog({
        farmerId,
        deviceId: data.deviceId,
        moisture: data.moisture,
        temperature: data.temperature,
        humidity: data.humidity,
        timestamp: data.timestamp || new Date()
      });
      await log.save();
      console.log('Saved sensor log:', data.deviceId, data.moisture);

      await checkSensorAlerts(data.deviceId, { moisture: data.moisture, temperature: data.temperature }, farmerId);
    } catch (err) {
      console.error('Error saving sensor log:', err.message);
    }
  });
}

module.exports = startMqttListener;
module.exports.isMqttActive = isMqttActive;
