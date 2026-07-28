require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const startMqttListener = require('./services/mqttListener');
const sensorRoutes = require('./routes/sensors');
const irrigationRoutes = require('./routes/irrigation');
const chatRoutes = require('./routes/chat');
const cropRoutes = require('./routes/crop');
const authRoutes = require('./routes/auth');
const verifyToken = require('./middleware/auth');
const alertRoutes = require('./routes/alerts');
const calendarRoutes = require('./routes/calendar');
const app = express();
app.use(cors());
app.use(express.json());
app.use('/api/sensors', verifyToken, sensorRoutes);
app.use('/api/irrigation', verifyToken, irrigationRoutes);
app.use('/api/crop', verifyToken, cropRoutes);
app.use('/api/chat', verifyToken, chatRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/alerts', verifyToken, alertRoutes);
app.use('/api/calendar', verifyToken, calendarRoutes);


mongoose.connect(process.env.MONGO_URI)
  .then(() => {
    console.log('MongoDB connected');
    startMqttListener();
  })
  .catch((err) => console.error('MongoDB connection error:', err));

app.get('/', (req, res) => {
  res.send('AgriMitra backend is running');
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));