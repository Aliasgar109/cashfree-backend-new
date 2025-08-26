@echo off
echo 🚀 Deploying Supabase Edge Functions...

echo 📦 Deploying create-cashfree-order function...
supabase functions deploy create-cashfree-order

echo 📦 Deploying verify-cashfree-payment function...
supabase functions deploy verify-cashfree-payment

echo 📦 Deploying cashfree-webhook function...
supabase functions deploy cashfree-webhook

echo ✅ All functions deployed successfully!

echo.
echo 🔧 Next steps:
echo 1. Go to your Supabase dashboard
echo 2. Navigate to Settings ^> Edge Functions
echo 3. Set the following environment variables:
echo    - CASHFREE_CLIENT_ID: Your Cashfree Client ID
echo    - CASHFREE_CLIENT_SECRET: Your Cashfree Client Secret
echo    - CASHFREE_WEBHOOK_SECRET: Your Cashfree Webhook Secret
echo    - CASHFREE_ENV: 'sandbox' or 'production'
echo    - SUPABASE_URL: Your Supabase project URL
echo    - SUPABASE_SERVICE_ROLE_KEY: Your Supabase service role key
echo.
echo 4. Test the functions using the Supabase dashboard
pause
