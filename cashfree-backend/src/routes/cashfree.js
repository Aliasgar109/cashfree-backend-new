const express = require('express');
const router = express.Router();
const cashfreeController = require('../controllers/cashfreeController');

// Create Cashfree order
router.post('/create-order', cashfreeController.createOrder);

// Verify payment status
router.post('/verify-payment', cashfreeController.verifyPayment);

module.exports = router;
