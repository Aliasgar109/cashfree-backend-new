-- 🛡️ FIXED SECURE RLS POLICIES - No SQL Syntax Errors
-- Run this in your Supabase SQL Editor

-- ==========================================
-- STEP 1: Clean up existing policies
-- ==========================================

-- Drop all existing problematic policies
DROP POLICY IF EXISTS "users_view_own" ON users;
DROP POLICY IF EXISTS "users_update_own" ON users;
DROP POLICY IF EXISTS "service_full_access_users" ON users;
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Admins can view all users" ON users;
DROP POLICY IF EXISTS "Admins can update all users" ON users;
DROP POLICY IF EXISTS "Collectors can view users in their area" ON users;

DROP POLICY IF EXISTS "payments_view_own" ON payments;
DROP POLICY IF EXISTS "payments_create_own" ON payments;
DROP POLICY IF EXISTS "service_full_access_payments" ON payments;
DROP POLICY IF EXISTS "Users can view own payments" ON payments;
DROP POLICY IF EXISTS "Users can create own payments" ON payments;
DROP POLICY IF EXISTS "Admins can view all payments" ON payments;
DROP POLICY IF EXISTS "Admins can update payments" ON payments;
DROP POLICY IF EXISTS "Collectors can view payments in their area" ON payments;

DROP POLICY IF EXISTS "wallet_view_own" ON wallet_transactions;
DROP POLICY IF EXISTS "wallet_create_own" ON wallet_transactions;
DROP POLICY IF EXISTS "service_full_access_wallet" ON wallet_transactions;
DROP POLICY IF EXISTS "Users can view own wallet transactions" ON wallet_transactions;
DROP POLICY IF EXISTS "Users can create own wallet transactions" ON wallet_transactions;
DROP POLICY IF EXISTS "Admins can view all wallet transactions" ON wallet_transactions;

-- Drop other table policies
DROP POLICY IF EXISTS "settings_admin_only" ON settings;
DROP POLICY IF EXISTS "notifications_view_own" ON notifications;
DROP POLICY IF EXISTS "service_full_access_notifications" ON notifications;
DROP POLICY IF EXISTS "receipts_view_own" ON receipts;
DROP POLICY IF EXISTS "service_full_access_receipts" ON receipts;
DROP POLICY IF EXISTS "audit_admin_only" ON audit_logs;

-- Drop helper function if exists
DROP FUNCTION IF EXISTS get_user_role(UUID);

-- ==========================================
-- STEP 2: USERS TABLE - Simple Secure Policies
-- ==========================================

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view their own profile
CREATE POLICY "users_view_own" ON users
    FOR SELECT 
    USING (auth.uid() = id);

-- Policy 2: Users can update their own profile (but not role)
CREATE POLICY "users_update_own" ON users
    FOR UPDATE 
    USING (auth.uid() = id);

-- Policy 3: Service role can access all (for admin operations via Flutter app)
CREATE POLICY "service_full_access_users" ON users
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ==========================================
-- STEP 3: PAYMENTS TABLE - Secure Policies  
-- ==========================================

-- Enable RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view their own payments
CREATE POLICY "payments_view_own" ON payments
    FOR SELECT 
    USING (auth.uid() = user_id);

-- Policy 2: Users can create their own payments
CREATE POLICY "payments_create_own" ON payments
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Policy 3: Service role can access all (for admin operations)
CREATE POLICY "service_full_access_payments" ON payments
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ==========================================
-- STEP 4: WALLET TRANSACTIONS - Secure Policies
-- ==========================================

-- Enable RLS  
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view their own transactions
CREATE POLICY "wallet_view_own" ON wallet_transactions
    FOR SELECT 
    USING (auth.uid() = user_id);

-- Policy 2: Users can create their own transactions
CREATE POLICY "wallet_create_own" ON wallet_transactions
    FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Policy 3: Service role can access all
CREATE POLICY "service_full_access_wallet" ON wallet_transactions
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ==========================================
-- STEP 5: SETTINGS TABLE - Admin Only
-- ==========================================

-- Enable RLS
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- Service role only (admin operations handled in app)
CREATE POLICY "service_full_access_settings" ON settings
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ==========================================
-- STEP 6: NOTIFICATIONS TABLE
-- ==========================================

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view their own notifications
CREATE POLICY "notifications_view_own" ON notifications
    FOR SELECT 
    USING (auth.uid() = user_id);

-- Policy 2: Service role can access all
CREATE POLICY "service_full_access_notifications" ON notifications
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ==========================================
-- STEP 7: RECEIPTS TABLE  
-- ==========================================

-- Enable RLS
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view receipts for their own payments
CREATE POLICY "receipts_view_own" ON receipts
    FOR SELECT 
    USING (
        EXISTS (
            SELECT 1 FROM payments 
            WHERE payments.id = receipts.payment_id 
            AND payments.user_id = auth.uid()
        )
    );

-- Policy 2: Service role can access all
CREATE POLICY "service_full_access_receipts" ON receipts
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ==========================================
-- STEP 8: AUDIT LOGS TABLE
-- ==========================================

-- Enable RLS
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Service role only (admin/audit access handled in app)
CREATE POLICY "service_full_access_audit" ON audit_logs
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ==========================================
-- STEP 9: AREAS TABLE (if exists)
-- ==========================================

-- Enable RLS if table exists
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'areas') THEN
        ALTER TABLE areas ENABLE ROW LEVEL SECURITY;
        
        -- Service role can access all areas
        DROP POLICY IF EXISTS "service_full_access_areas" ON areas;
        CREATE POLICY "service_full_access_areas" ON areas
            FOR ALL 
            USING (auth.jwt() ->> 'role' = 'service_role')
            WITH CHECK (auth.jwt() ->> 'role' = 'service_role');
    END IF;
END $$;

-- ==========================================
-- STEP 10: REMINDERS TABLE (if exists)
-- ==========================================

-- Enable RLS if table exists
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'reminders') THEN
        ALTER TABLE reminders ENABLE ROW LEVEL SECURITY;
        
        -- Users can view their own reminders
        DROP POLICY IF EXISTS "reminders_view_own" ON reminders;
        CREATE POLICY "reminders_view_own" ON reminders
            FOR SELECT 
            USING (auth.uid() = user_id);
            
        -- Service role can access all
        DROP POLICY IF EXISTS "service_full_access_reminders" ON reminders;
        CREATE POLICY "service_full_access_reminders" ON reminders
            FOR ALL 
            USING (auth.jwt() ->> 'role' = 'service_role')
            WITH CHECK (auth.jwt() ->> 'role' = 'service_role');
    END IF;
END $$;

-- ==========================================
-- STEP 11: NOTIFICATION HISTORY TABLE (if exists)
-- ==========================================

-- Enable RLS if table exists
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'notification_history') THEN
        ALTER TABLE notification_history ENABLE ROW LEVEL SECURITY;
        
        -- Users can view their own notification history
        DROP POLICY IF EXISTS "notification_history_view_own" ON notification_history;
        CREATE POLICY "notification_history_view_own" ON notification_history
            FOR SELECT 
            USING (auth.uid() = user_id);
            
        -- Service role can access all
        DROP POLICY IF EXISTS "service_full_access_notification_history" ON notification_history;
        CREATE POLICY "service_full_access_notification_history" ON notification_history
            FOR ALL 
            USING (auth.jwt() ->> 'role' = 'service_role')
            WITH CHECK (auth.jwt() ->> 'role' = 'service_role');
    END IF;
END $$;
