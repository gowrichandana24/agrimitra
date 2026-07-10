const express = require('express');
const router = express.Router();
const { askFarmAssistant } = require('../services/chatService');

router.post('/:deviceId/ask', async (req, res) => {
  try {
    const { question } = req.body;

    if (!question || question.trim() === '') {
      return res.status(400).json({ message: 'Question is required' });
    }

    const answer = await askFarmAssistant(req.params.deviceId, question);
    res.json({ question, answer });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

module.exports = router;