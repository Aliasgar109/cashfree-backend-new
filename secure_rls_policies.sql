-- 🛡️ SECURE RLS POLICIES - BEST SECURITY APPROACH
-- Run this in your Supabase SQL Editor

-- ==========================================
-- STEP 1: Clean up existing policies
-- ==========================================

-- Drop all existing problematic policies
DROP POLICY IF EXISTS "Users can view own profile" ON users;
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Admins can view all users" ON users;
DROP POLICY IF EXISTS "Admins can update all users" ON users;
DROP POLICY IF EXISTS "Collectors can view users in their area" ON users;

DROP POLICY IF EXISTS "Users can view own payments" ON payments;
DROP POLICY IF EXISTS "Users can create own payments" ON payments;
DROP POLICY IF EXISTS "Admins can view all payments" ON payments;
DROP POLICY IF EXISTS "Admins can update payments" ON payments;
DROP POLICY IF EXISTS "Collectors can view payments in their area" ON payments;

DROP POLICY IF EXISTS "Users can view own wallet transactions" ON wallet_transactions;
DROP POLICY IF EXISTS "Users can create own wallet transactions" ON wallet_transactions;
DROP POLICY IF EXISTS "Admins can view all wallet transactions" ON wallet_transactions;

-- ==========================================
-- STEP 2: Create user role helper function
-- ==========================================

-- Function to get user role safely without infinite recursion
CREATE OR REPLACE FUNCTION get_user_role(user_uuid UUID)
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    -- Use a simple query with security definer to avoid RLS recursion
    SELECT role INTO user_role 
    FROM users 
    WHERE id = user_uuid 
    LIMIT 1;
    
    RETURN COALESCE(user_role, 'USER');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==========================================
-- STEP 3: USERS TABLE - Secure Policies
-- ==========================================

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policy 1: Users can view their own profile
CREATE POLICY "users_view_own" ON users
    FOR SELECT 
    USING (auth.uid() = id);

-- Policy 2: Users can update their own profile (limited fields)
CREATE POLICY "users_update_own" ON users
    FOR UPDATE 
    USING (auth.uid() = id)
    WITH CHECK (
        auth.uid() = id AND
        -- Prevent role escalation - users cannot change their own role
        (OLD.role = NEW.role OR auth.uid() IN (
            SELECT id FROM users WHERE role = 'ADMIN' AND id = auth.uid()
        ))
    );

-- Policy 3: Service role can access all (for our Flutter app backend operations)
CREATE POLICY "service_full_access_users" ON users
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- ==========================================
-- STEP 4: PAYMENTS TABLE - Secure Policies  
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
-- STEP 5: WALLET TRANSACTIONS - Secure Policies
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
-- STEP 6: OTHER TABLES - Secure Policies
-- ==========================================

-- Settings table - Admin only
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "settings_admin_only" ON settings
    FOR ALL 
    USING (
        auth.uid() IN (
            SELECT id FROM users WHERE role = 'ADMIN' AND id = auth.uid()
        ) OR
        auth.jwt() ->> 'role' = 'service_role'
    );

-- Notifications - Users can view their own
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_view_own" ON notifications
    FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "service_full_access_notifications" ON notifications
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- Receipts - Users can view their own payment receipts
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "receipts_view_own" ON receipts
    FOR SELECT 
    USING (
        auth.uid() IN (
            SELECT user_id FROM payments WHERE id = receipts.payment_id
        )
    );

CREATE POLICY "service_full_access_receipts" ON receipts
    FOR ALL 
    USING (auth.jwt() ->> 'role' = 'service_role')
    WITH CHECK (auth.jwt() ->> 'role' = 'service_role');

-- Audit logs - Admin only
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "audit_admin_only" ON audit_logs
    FOR SELECT 
    USING (
        auth.uid() IN (
            SELECT id FROM users WHERE role = 'ADMIN' AND id = auth.uid()
        ) OR
        auth.jwt() ->> 'role' = 'service_role'
    );

-- ==========================================
-- STEP 7: Grant necessary permissions
-- ==========================================

-- Allow authenticated users to execute the helper function
GRANT EXECUTE ON FUNCTION get_user_role(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_role(UUID) TO service_role;

-- ==========================================
-- STEP 8: Create service key for backend operations
-- ==========================================

-- Note: You'll need to use the service_role key in your Flutter app
-- for admin operations that need to bypass RLS
-- Get this from: Supabase Dashboard → Settings → API → service_role key
