module.exports = {
  baseUrl: process.env.NODE_ENV === 'production' 
    ? 'https://api.cashfree.com/pg'
    : 'https://sandbox.cashfree.com/pg',
  appId: process.env.CASHFREE_APP_ID,
  secretKey: process.env.CASHFREE_SECRET_KEY,
  webhookSecret: process.env.CASHFREE_WEBHOOK_SECRET,
  environment: process.env.NODE_ENV || 'development'
};
