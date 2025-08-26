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

    // Verify webhook signature
    const payload = JSON.stringify(req.body);
    const hmac = crypto
      .createHmac('sha256', process.env.CASHFREE_WEBHOOK_SECRET)
      .update(payload)
      .digest('base64');

    if (hmac !== signature) {
      console.error('Invalid webhook signature');
      return res.status(401).json({ 
        success: false,
        error: 'Invalid webhook signature' 
      });
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

    // TODO: Update your database with payment status
    // Example: Update payment status in your database
    console.log('Processing webhook for order:', {
      orderId,
      orderStatus,
      paymentStatus,
      cf_payment_id: webhookData.cf_payment_id,
      failure_reason: webhookData.failure_reason
    });

    // Here you would typically:
    // 1. Find the payment record in your database
    // 2. Update the payment status based on orderStatus and paymentStatus
    // 3. Send notifications to the user
    // 4. Update any related records

    // Example database update logic:
    /*
    const updateData = {
      updatedAt: new Date(),
      cashfreeOrderId: orderId,
      cashfreePaymentId: webhookData.cf_payment_id || null,
      paymentGateway: 'cashfree',
      gatewayResponse: webhookData
    };

    if (orderStatus === 'PAID' && paymentStatus === 'SUCCESS') {
      updateData.status = 'APPROVED';
      updateData.approvedAt = new Date();
      updateData.approvedBy = 'CASHFREE_WEBHOOK';
      updateData.transactionId = webhookData.cf_payment_id;
      updateData.paidAt = new Date();
    } else if (orderStatus === 'EXPIRED' || paymentStatus === 'FAILED') {
      updateData.status = 'REJECTED';
      updateData.rejectionReason = webhookData.failure_reason || 'Payment failed';
    }

    // Update your database here
    // await updatePaymentStatus(orderId, updateData);
    */

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
