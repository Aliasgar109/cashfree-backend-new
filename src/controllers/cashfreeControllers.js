const axios = require('axios');
const cashfreeConfig = require('../config/cashfree');

exports.createOrder = async (req, res) => {
  try {
    const { order_id, order_amount, customer_details, order_meta, payment_methods } = req.body;

    // Validate required fields
    if (!order_id || !order_amount || !customer_details) {
      return res.status(400).json({ 
        success: false,
        error: 'Missing required fields',
        required: ['order_id', 'order_amount', 'customer_details']
      });
    }

    const orderPayload = {
      order_id,
      order_amount,
      order_currency: "INR",
      customer_details,
      order_meta: order_meta || {
        return_url: `${process.env.APP_URL || 'https://jafary-channel-1e3af.web.app'}/payment-return`,
        notify_url: `${process.env.APP_URL || 'https://jafary-channel-1e3af.web.app'}/api/webhook/cashfree`,
      },
      order_expiry_time: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
      payment_methods: payment_methods || ["cc", "dc", "upi", "nb", "wallet"]
    };

    console.log('Creating Cashfree order:', { order_id, order_amount });

    const response = await axios.post(`${cashfreeConfig.baseUrl}/orders`, orderPayload, {
      headers: {
        'Content-Type': 'application/json',
        'x-client-id': process.env.CASHFREE_APP_ID,
        'x-client-secret': process.env.CASHFREE_SECRET_KEY,
        'x-api-version': '2022-09-01'
      }
    });

    console.log('Cashfree order created successfully:', response.data.order_id);

    res.json({
      success: true,
      payment_session_id: response.data.payment_session_id,
      order_status: response.data.order_status,
      order_id: response.data.order_id,
      order_amount: response.data.order_amount,
      message: 'Order created successfully'
    });

  } catch (error) {
    console.error('Create Order Error:', error.response?.data || error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to create order',
      details: error.response?.data?.message || error.message
    });
  }
};

exports.verifyPayment = async (req, res) => {
  try {
    const { order_id } = req.body;

    if (!order_id) {
      return res.status(400).json({ 
        success: false,
        error: 'Order ID is required' 
      });
    }

    console.log('Verifying payment for order:', order_id);

    const response = await axios.get(`${cashfreeConfig.baseUrl}/orders/${order_id}`, {
      headers: {
        'Content-Type': 'application/json',
        'x-client-id': process.env.CASHFREE_APP_ID,
        'x-client-secret': process.env.CASHFREE_SECRET_KEY,
        'x-api-version': '2022-09-01'
      }
    });

    let paymentDetails = null;
    if (response.data.order_status === 'PAID') {
      const paymentResponse = await axios.get(`${cashfreeConfig.baseUrl}/orders/${order_id}/payments`, {
        headers: {
          'Content-Type': 'application/json',
          'x-client-id': process.env.CASHFREE_APP_ID,
          'x-client-secret': process.env.CASHFREE_SECRET_KEY,
          'x-api-version': '2022-09-01'
        }
      });

      if (paymentResponse.data.length > 0) {
        paymentDetails = paymentResponse.data[0];
      }
    }

    console.log('Payment verification completed:', {
      order_id,
      status: response.data.order_status,
      payment_status: paymentDetails?.payment_status
    });

    res.json({
      success: true,
      order_id: response.data.order_id,
      order_status: response.data.order_status,
      order_amount: response.data.order_amount,
      payment_status: paymentDetails?.payment_status || null,
      cf_payment_id: paymentDetails?.cf_payment_id || null,
      payment_amount: paymentDetails?.payment_amount || null,
      payment_method: paymentDetails?.payment_method || null,
      bank_reference: paymentDetails?.bank_reference || null,
      payment_time: paymentDetails?.payment_time || null,
      failure_reason: paymentDetails?.failure_reason || null,
      message: 'Payment verification completed'
    });

  } catch (error) {
    console.error('Verify Payment Error:', error.response?.data || error.message);
    res.status(500).json({
      success: false,
      error: 'Failed to verify payment',
      details: error.response?.data?.message || error.message
    });
  }
};
