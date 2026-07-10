const express = require('express');
const router = express.Router();
const FarmEvent = require('../models/FarmEvent');

// Create a new calendar event/reminder
router.post('/', async (req, res) => {
  try {
    const { deviceId, title, type, eventDate, notes } = req.body;

    if (!deviceId || !title || !eventDate) {
      return res.status(400).json({ message: 'deviceId, title, and eventDate are required' });
    }

    const event = new FarmEvent({
      farmerId: req.farmerId, // comes from the auth middleware, not the request body
      deviceId,
      title,
      type: type || 'custom',
      eventDate: new Date(eventDate),
      notes
    });

    await event.save();
    res.status(201).json(event);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

// Get upcoming events (not completed, sorted soonest first)
router.get('/:deviceId/upcoming', async (req, res) => {
  try {
    const events = await FarmEvent.find({
      farmerId: req.farmerId,
      deviceId: req.params.deviceId,
      completed: false
    }).sort({ eventDate: 1 });

    res.json(events);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

// Get all events (including completed) - useful for a full history view
router.get('/:deviceId/all', async (req, res) => {
  try {
    const events = await FarmEvent.find({
      farmerId: req.farmerId,
      deviceId: req.params.deviceId
    }).sort({ eventDate: -1 });

    res.json(events);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

// Mark an event as completed
router.patch('/:eventId/complete', async (req, res) => {
  try {
    const event = await FarmEvent.findOneAndUpdate(
      { _id: req.params.eventId, farmerId: req.farmerId }, // farmer can only complete their own events
      { completed: true },
      { new: true }
    );
    if (!event) return res.status(404).json({ message: 'Event not found' });
    res.json(event);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

// Delete an event
router.delete('/:eventId', async (req, res) => {
  try {
    const event = await FarmEvent.findOneAndDelete({ _id: req.params.eventId, farmerId: req.farmerId });
    if (!event) return res.status(404).json({ message: 'Event not found' });
    res.json({ message: 'Event deleted' });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

module.exports = router;