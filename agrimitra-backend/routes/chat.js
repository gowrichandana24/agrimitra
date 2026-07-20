const express = require('express');
const router = express.Router();
const { askFarmAssistant, loadHistory } = require('../services/chatService');

router.post('/:deviceId/ask', async (req, res) => {
  try {
    const { question, language } = req.body;

    if (!question || question.trim() === '') {
      return res.status(400).json({ message: 'Question is required' });
    }

    const answer = await askFarmAssistant(req.farmerId, req.params.deviceId, question, language);
    res.json({ question, answer });
  } catch (err) {
    console.error('Chat route error:', err);
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

// Fetch this farmer's chat history, to reload it when the chat screen opens
router.get('/history', async (req, res) => {
  try {
    const history = await loadHistory(req.farmerId, 50);
    res.json(history);
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
});

module.exports = router;