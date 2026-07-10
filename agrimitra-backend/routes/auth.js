const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const Farmer = require('../models/Farmer');

// Register a new farmer
router.post('/register', async (req, res) => {
  try {
    const { name, phone, password, farmName } = req.body;

    if (!name || !phone || !password) {
      return res.status(400).json({ message: 'Name, phone, and password are required' });
    }

    const existing = await Farmer.findOne({ phone });
    if (existing) {
      return res.status(409).json({ message: 'A farmer with this phone number already exists' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const farmer = new Farmer({ name, phone, passwordHash, farmName });
    await farmer.save();

    res.status(201).json({ message: 'Farmer registered successfully', farmerId: farmer._id });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

// Log in an existing farmer
router.post('/login', async (req, res) => {
  try {
    const { phone, password } = req.body;

    if (!phone || !password) {
      return res.status(400).json({ message: 'Phone and password are required' });
    }

    const farmer = await Farmer.findOne({ phone });
    if (!farmer) {
      return res.status(401).json({ message: 'Invalid phone number or password' });
    }

    const match = await bcrypt.compare(password, farmer.passwordHash);
    if (!match) {
      return res.status(401).json({ message: 'Invalid phone number or password' });
    }

    const token = jwt.sign(
      { farmerId: farmer._id, phone: farmer.phone },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      message: 'Login successful',
      token,
      farmer: { id: farmer._id, name: farmer.name, farmName: farmer.farmName }
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

module.exports = router;