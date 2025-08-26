const crypto = require('crypto');

exports.handleCashfreeWebhook = async (req, res) => {
  try {
    const webhookData = req.body;
    const signature = req.headers['x-webhook-signature'];

    console.log('Webhook received:', {
      order_id: webhookData.order_id,
      order_status: webhookData.order_status,
      payment_status: webhookData.payment_status,
      timestamp: new Date().toISOString()
    });

    // Check if webhook secret is configured
    const webhookSecret = process.env.CASHFREE_WEBHOOK_SECRET;
    if (!webhookSecret) {
      console.warn('Webhook secret not configured - skipping signature verification');
    } else if (signature) {
      // Verify webhook signature if secret is available
      const payload = JSON.stringify(req.body);
      const hmac = crypto
        .createHmac('sha256', webhookSecret)
        .update(payload)
        .digest('base64');

      if (hmac !== signature) {
        console.error('Invalid webhook signature');
        return res.status(401).json({ 
          success: false,
          error: 'Invalid webhook signature' 
        });
      }
    }

    const orderId = webhookData.order_id;
    const orderStatus = webhookData.order_status;
    const paymentStatus = webhookData.payment_status;

    if (!orderId) {
      return res.status(400).json({ 
        success: false,
        error: 'Order ID not found in webhook' 
      });
    }

    console.log('Processing webhook for order:', {
      orderId,
      orderStatus,
      paymentStatus,
      cf_payment_id: webhookData.cf_payment_id,
      failure_reason: webhookData.failure_reason
    });

    // Process the webhook based on status
    if (orderStatus === 'PAID' && paymentStatus === 'SUCCESS') {
      console.log('✅ Payment successful for order:', orderId);
      // TODO: Update your database - mark payment as successful
    } else if (orderStatus === 'EXPIRED' || paymentStatus === 'FAILED') {
      console.log('❌ Payment failed for order:', orderId);
      // TODO: Update your database - mark payment as failed
    } else {
      console.log('ℹ️ Payment status update for order:', orderId, orderStatus);
      // TODO: Update your database with new status
    }

    console.log('✅ Webhook processed successfully for order:', orderId);

    res.json({
      success: true,
      message: 'Webhook processed successfully',
      order_id: orderId,
      processed: true
    });

  } catch (error) {
    console.error('Webhook Error:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      details: error.message
    });
  }
};
