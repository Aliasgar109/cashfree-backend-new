const express = require('express');
const router = express.Router();

// Test route
router.get('/test', (req, res) => {
  res.json({ message: 'Webhook routes working!' });
});

// Handle Cashfree webhook
router.post('/cashfree', (req, res) => {
  try {
    res.json({ 
      success: true, 
      message: 'Webhook endpoint reached',
      body: req.body 
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
