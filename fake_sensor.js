const path = require('path');
require('dotenv').config({ path: path.join(__dirname, 'agrimitra-backend', '.env') });
const mqtt = require('mqtt');
const client = mqtt.connect(process.env.MQTT_URL, {
  username: process.env.MQTT_USER,
  password: process.env.MQTT_PASS
});

client.on('connect', () => {
  console.log('Fake sensor connected, publishing every 10 seconds for testing');
  setInterval(() => {
    const fakeReading = {
      deviceId: "esp32-01",
      moisture: Math.floor(Math.random() * 100),
      temperature: (20 + Math.random() * 15).toFixed(1),
      humidity: (40 + Math.random() * 30).toFixed(1),
      timestamp: new Date().toISOString()
    };
    client.publish('farm/esp32-01/sensors', JSON.stringify(fakeReading));
    console.log('Published:', fakeReading);
  }, 10000);
});

client.on('error', (err) => console.error('Fake sensor MQTT error:', err));