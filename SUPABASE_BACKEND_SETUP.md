# Supabase Backend Setup for Cashfree Integration

This guide will help you set up the Supabase Edge Functions for Cashfree payment processing.

## 🚀 Quick Deployment

### Option 1: Using Scripts (Recommended)

**Windows:**
```bash
deploy-functions.bat
```

**Linux/Mac:**
```bash
chmod +x deploy-functions.sh
./deploy-functions.sh
```

### Option 2: Manual Deployment

```bash
# Deploy each function individually
supabase functions deploy create-cashfree-order
supabase functions deploy verify-cashfree-payment
supabase functions deploy cashfree-webhook
```

## 🔧 Environment Variables Setup

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Settings** > **Edge Functions**
4. Add the following environment variables:

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `CASHFREE_CLIENT_ID` | Your Cashfree Client ID | `839859e6e4b7de41bdfa6044658938` |
| `CASHFREE_CLIENT_SECRET` | Your Cashfree Client Secret | `690757b12b5225ab35ef7c09d5b1be8c6544accf` |
| `CASHFREE_WEBHOOK_SECRET` | Your Cashfree Webhook Secret | `your-webhook-secret` |
| `CASHFREE_ENV` | Environment (sandbox/production) | `sandbox` |
| `SUPABASE_URL` | Your Supabase project URL | `https://rsaylanpqnenfecsevoj.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | Your Supabase service role key | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` |

## 📋 Function Endpoints

After deployment, your functions will be available at:

- **Create Order**: `https://rsaylanpqnenfecsevoj.supabase.co/functions/v1/create-cashfree-order`
- **Verify Payment**: `https://rsaylanpqnenfecsevoj.supabase.co/functions/v1/verify-cashfree-payment`
- **Webhook**: `https://rsaylanpqnenfecsevoj.supabase.co/functions/v1/cashfree-webhook`

## 🧪 Testing the Functions

### Test Create Order

```bash
curl -X POST https://rsaylanpqnenfecsevoj.supabase.co/functions/v1/create-cashfree-order \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "orderId": "TEST_ORDER_123",
    "orderAmount": 100.00,
    "customerId": "CUST_123",
    "customerEmail": "test@example.com",
    "customerPhone": "9876543210",
    "customerName": "Test User"
  }'
```

### Test Verify Payment

```bash
curl -X POST https://rsaylanpqnenfecsevoj.supabase.co/functions/v1/verify-cashfree-payment \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "orderId": "TEST_ORDER_123"
  }'
```

## 🔗 Webhook Configuration

1. Go to your [Cashfree Dashboard](https://merchant.cashfree.com/merchant/settings/webhook)
2. Add webhook URL: `https://rsaylanpqnenfecsevoj.supabase.co/functions/v1/cashfree-webhook`
3. Select events: `order.paid`, `order.failed`, `order.expired`
4. Copy the webhook secret and add it to Supabase environment variables

## 📱 Flutter Integration

The Flutter app is already configured to use these endpoints. The `SupabaseCashfreeService` class handles all communication with the Edge Functions.

### Usage Example

```dart
final cashfreeService = SupabaseCashfreeService();

// Create order
final result = await cashfreeService.createOrder(
  orderId: 'ORDER_123',
  amount: 100.00,
  customerId: 'CUST_123',
  customerEmail: 'user@example.com',
  customerPhone: '9876543210',
  customerName: 'John Doe',
);

if (result.isSuccess) {
  final orderData = result.data!;
  print('Order created: ${orderData['order_id']}');
} else {
  print('Error: ${result.error?.userMessage}');
}
```

## 🚨 Troubleshooting

### Common Issues

1. **Function not found**: Make sure you've deployed all functions
2. **Authentication error**: Check your Supabase anon key
3. **Cashfree API errors**: Verify your Cashfree credentials
4. **Webhook not working**: Check webhook URL and secret

### Debug Steps

1. Check function logs in Supabase dashboard
2. Verify environment variables are set correctly
3. Test functions individually using curl or Postman
4. Check Cashfree dashboard for API errors

## 📞 Support

If you encounter issues:

1. Check the Supabase function logs
2. Verify all environment variables are set
3. Test with Cashfree sandbox credentials first
4. Ensure your Supabase project has Edge Functions enabled

## ✅ Checklist

- [ ] Deploy all three Edge Functions
- [ ] Set all environment variables in Supabase
- [ ] Configure webhook in Cashfree dashboard
- [ ] Test create order function
- [ ] Test verify payment function
- [ ] Test webhook endpoint
- [ ] Update Flutter app configuration
- [ ] Test end-to-end payment flow
