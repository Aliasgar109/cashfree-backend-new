const express = require('express');
const router = express.Router();

// Test route
router.get('/test', (req, res) => {
  res.json({ message: 'Cashfree routes working!' });
});

// Create Cashfree order
router.post('/create-order', (req, res) => {
  try {
    res.json({ 
      success: true, 
      message: 'Create order endpoint reached',
      body: req.body 
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Verify payment status
router.post('/verify-payment', (req, res) => {
  try {
    res.json({ 
      success: true, 
      message: 'Verify payment endpoint reached',
      body: req.body 
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
