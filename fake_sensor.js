const mqtt = require('mqtt');
const client = mqtt.connect('mqtts://f5895315d583447086b9e6364424fb1c.s1.eu.hivemq.cloud:8883', {
  username: 'agridosth',
  password: 'AgriDosth@2026'
});

client.on('connect', () => {
  console.log('Fake sensor connected, publishing every 10 seconds for testing');
  setInterval(() => {
    const fakeReading = {
      deviceId: "esp32-01",
      moisture: Math.floor(Math.random() * 100),
      //moisture: 5, // TEMPORARY: forcing a critical-low reading to test alerts
      temperature: (20 + Math.random() * 15).toFixed(1),
      humidity: (40 + Math.random() * 30).toFixed(1),
      timestamp: new Date().toISOString()
    };
    client.publish('farm/esp32-01/sensors', JSON.stringify(fakeReading));
    console.log('Published:', fakeReading);
  }, 10000);
});

client.on('error', (err) => console.error('Fake sensor MQTT error:', err));