const express = require('express');
const router = express.Router();
const webhookController = require('../controllers/webhookController');

// Handle Cashfree webhook
router.post('/cashfree', webhookController.handleCashfreeWebhook);

module.exports = router;
