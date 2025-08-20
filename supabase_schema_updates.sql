-- 🗄️ Supabase Schema Updates for Enhanced TV Subscription App
-- This file contains all necessary updates to support the new Supabase services

-- ============================================================================
-- 📋 TABLE UPDATES
-- ============================================================================

-- 1. Update users table to support Firebase UID
ALTER TABLE users ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(255) UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS login_count INTEGER DEFAULT 0;

-- Create index for Firebase UID lookups
CREATE INDEX IF NOT EXISTS idx_users_firebase_uid ON users(firebase_uid);

-- 2. Update payments table with new fields
ALTER TABLE payments ADD COLUMN IF NOT EXISTS service_period_start DATE;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS service_period_end DATE;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS late_fees DECIMAL(10,2) DEFAULT 0.00;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS wire_charges DECIMAL(10,2) DEFAULT 0.00;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS total_amount DECIMAL(10,2);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS upi_transaction_id VARCHAR(100);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS paid_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS user_firebase_uid VARCHAR(255);

-- Create indexes for new payment fields
CREATE INDEX IF NOT EXISTS idx_payments_service_period ON payments(service_period_start, service_period_end);
CREATE INDEX IF NOT EXISTS idx_payments_user_firebase_uid ON payments(user_firebase_uid);
CREATE INDEX IF NOT EXISTS idx_payments_paid_at ON payments(paid_at);

-- 3. Update receipts table with new fields
ALTER TABLE receipts ADD COLUMN IF NOT EXISTS user_firebase_uid VARCHAR(255);
ALTER TABLE receipts ADD COLUMN IF NOT EXISTS amount DECIMAL(10,2);
ALTER TABLE receipts ADD COLUMN IF NOT EXISTS extra_charges DECIMAL(10,2) DEFAULT 0.00;
ALTER TABLE receipts ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50);
ALTER TABLE receipts ADD COLUMN IF NOT EXISTS year INTEGER;

-- Create indexes for new receipt fields
CREATE INDEX IF NOT EXISTS idx_receipts_user_firebase_uid ON receipts(user_firebase_uid);
CREATE INDEX IF NOT EXISTS idx_receipts_year ON receipts(year);

-- 4. Update reminders table structure
ALTER TABLE reminders ADD COLUMN IF NOT EXISTS payment_id UUID REFERENCES payments(id);
ALTER TABLE reminders ADD COLUMN IF NOT EXISTS custom_message TEXT;
ALTER TABLE reminders ADD COLUMN IF NOT EXISTS metadata JSONB;
ALTER TABLE reminders ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE reminders ADD COLUMN IF NOT EXISTS user_firebase_uid VARCHAR(255);

-- Create indexes for new reminder fields
CREATE INDEX IF NOT EXISTS idx_reminders_payment_id ON reminders(payment_id);
CREATE INDEX IF NOT EXISTS idx_reminders_user_firebase_uid ON reminders(user_firebase_uid);

-- ============================================================================
-- 🆕 NEW TABLES
-- ============================================================================

-- 5. Create reminder_history table
CREATE TABLE IF NOT EXISTS reminder_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_firebase_uid VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    message TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'
);

-- Indexes for reminder_history
CREATE INDEX IF NOT EXISTS idx_reminder_history_user_firebase_uid ON reminder_history(user_firebase_uid);
CREATE INDEX IF NOT EXISTS idx_reminder_history_type ON reminder_history(type);
CREATE INDEX IF NOT EXISTS idx_reminder_history_status ON reminder_history(status);
CREATE INDEX IF NOT EXISTS idx_reminder_history_created_at ON reminder_history(created_at);

-- 6. Create settings_audit table
CREATE TABLE IF NOT EXISTS settings_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    field_name VARCHAR(100) NOT NULL,
    old_value TEXT,
    new_value TEXT NOT NULL,
    updated_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    notes TEXT
);

-- Indexes for settings_audit
CREATE INDEX IF NOT EXISTS idx_settings_audit_field_name ON settings_audit(field_name);
CREATE INDEX IF NOT EXISTS idx_settings_audit_updated_by ON settings_audit(updated_by);
CREATE INDEX IF NOT EXISTS idx_settings_audit_created_at ON settings_audit(created_at);

-- ============================================================================
-- 🔧 STORED PROCEDURES & FUNCTIONS
-- ============================================================================

-- Clean up any existing functions that might conflict
DROP FUNCTION IF EXISTS add_wallet_funds(VARCHAR(255), DECIMAL(10,2), VARCHAR(255), VARCHAR(50), TEXT, JSONB);
DROP FUNCTION IF EXISTS deduct_wallet_funds(VARCHAR(255), DECIMAL(10,2), VARCHAR(255), VARCHAR(100), TEXT, JSONB);
DROP FUNCTION IF EXISTS transfer_wallet_funds(VARCHAR(255), VARCHAR(255), DECIMAL(10,2), VARCHAR(255), TEXT, JSONB);
DROP FUNCTION IF EXISTS get_wallet_statistics(VARCHAR(255));
DROP FUNCTION IF EXISTS get_users_for_reminder(DATE, INTEGER);
DROP FUNCTION IF EXISTS get_overdue_payments_for_reminder();
DROP FUNCTION IF EXISTS get_reminder_statistics(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE);
DROP FUNCTION IF EXISTS generate_payment_summary_report(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, VARCHAR(50), VARCHAR(50));
DROP FUNCTION IF EXISTS generate_user_payment_report(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, VARCHAR(50), VARCHAR(20));
DROP FUNCTION IF EXISTS generate_monthly_revenue_report(INTEGER, VARCHAR(50));
DROP FUNCTION IF EXISTS generate_area_collection_report(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE);
DROP FUNCTION IF EXISTS generate_overdue_payments_report(VARCHAR(50), INTEGER);
DROP FUNCTION IF EXISTS generate_overdue_payments_report(VARCHAR(50));
DROP FUNCTION IF EXISTS generate_collection_efficiency_report(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, VARCHAR(255));
DROP FUNCTION IF EXISTS get_dashboard_analytics(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE);
DROP FUNCTION IF EXISTS calculate_payment_total();
DROP FUNCTION IF EXISTS log_settings_change();

-- 7. Wallet Functions
CREATE OR REPLACE FUNCTION add_wallet_funds(
    user_firebase_uid VARCHAR(255),
    amount DECIMAL(10,2),
    transaction_id VARCHAR(255),
    payment_method VARCHAR(50),
    description TEXT DEFAULT 'Wallet top-up',
    metadata JSONB DEFAULT '{}'
) RETURNS VARCHAR(255) AS $$
DECLARE
    user_record RECORD;
    new_balance DECIMAL(10,2);
    wallet_transaction_id UUID;
BEGIN
    -- Get user record
    SELECT * INTO user_record FROM users WHERE firebase_uid = add_wallet_funds.user_firebase_uid;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Calculate new balance
    new_balance := user_record.wallet_balance + amount;
    
    -- Update user wallet balance
    UPDATE users SET wallet_balance = new_balance WHERE firebase_uid = add_wallet_funds.user_firebase_uid;
    
    -- Create wallet transaction record
    INSERT INTO wallet_transactions (
        user_id,
        amount,
        type,
        status,
        description,
        reference_id,
        balance_before,
        balance_after,
        created_at
    ) VALUES (
        user_record.id,
        amount,
        'CREDIT',
        'COMPLETED',
        description,
        transaction_id::UUID,
        user_record.wallet_balance,
        new_balance,
        NOW()
    ) RETURNING id INTO wallet_transaction_id;
    
    RETURN wallet_transaction_id::VARCHAR(255);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION deduct_wallet_funds(
    user_firebase_uid VARCHAR(255),
    amount DECIMAL(10,2),
    transaction_id VARCHAR(255),
    purpose VARCHAR(100),
    description TEXT DEFAULT 'Wallet payment',
    metadata JSONB DEFAULT '{}'
) RETURNS VARCHAR(255) AS $$
DECLARE
    user_record RECORD;
    new_balance DECIMAL(10,2);
    wallet_transaction_id UUID;
BEGIN
    -- Get user record
    SELECT * INTO user_record FROM users WHERE firebase_uid = deduct_wallet_funds.user_firebase_uid;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Check sufficient balance
    IF user_record.wallet_balance < amount THEN
        RAISE EXCEPTION 'Insufficient wallet balance';
    END IF;
    
    -- Calculate new balance
    new_balance := user_record.wallet_balance - amount;
    
    -- Update user wallet balance
    UPDATE users SET wallet_balance = new_balance WHERE firebase_uid = deduct_wallet_funds.user_firebase_uid;
    
    -- Create wallet transaction record
    INSERT INTO wallet_transactions (
        user_id,
        amount,
        type,
        status,
        description,
        reference_id,
        balance_before,
        balance_after,
        created_at
    ) VALUES (
        user_record.id,
        amount,
        'DEBIT',
        'COMPLETED',
        description,
        transaction_id::UUID,
        user_record.wallet_balance,
        new_balance,
        NOW()
    ) RETURNING id INTO wallet_transaction_id;
    
    RETURN wallet_transaction_id::VARCHAR(255);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transfer_wallet_funds(
    from_firebase_uid VARCHAR(255),
    to_firebase_uid VARCHAR(255),
    amount DECIMAL(10,2),
    transfer_id VARCHAR(255),
    description TEXT DEFAULT 'Wallet transfer',
    metadata JSONB DEFAULT '{}'
) RETURNS JSONB AS $$
DECLARE
    from_user RECORD;
    to_user RECORD;
    from_transaction_id UUID;
    to_transaction_id UUID;
BEGIN
    -- Get both users
    SELECT * INTO from_user FROM users WHERE firebase_uid = transfer_wallet_funds.from_firebase_uid;
    SELECT * INTO to_user FROM users WHERE firebase_uid = transfer_wallet_funds.to_firebase_uid;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'One or both users not found';
    END IF;
    
    -- Check sufficient balance
    IF from_user.wallet_balance < amount THEN
        RAISE EXCEPTION 'Insufficient wallet balance';
    END IF;
    
    -- Deduct from sender
    PERFORM deduct_wallet_funds(from_firebase_uid, amount, transfer_id, 'TRANSFER_OUT', description);
    
    -- Add to receiver
    PERFORM add_wallet_funds(to_firebase_uid, amount, transfer_id, 'TRANSFER_IN', description);
    
    RETURN jsonb_build_object(
        'from_transaction_id', from_transaction_id,
        'to_transaction_id', to_transaction_id,
        'amount', amount,
        'status', 'COMPLETED'
    );
END;
$$ LANGUAGE plpgsql;

-- 8. Receipt Functions
-- Drop existing function if it exists with different parameters
DROP FUNCTION IF EXISTS generate_receipt_number(INTEGER);
DROP FUNCTION IF EXISTS generate_receipt_number(integer);

CREATE OR REPLACE FUNCTION generate_receipt_number(receipt_year INTEGER) RETURNS VARCHAR(20) AS $$
DECLARE
    next_number INTEGER;
    receipt_number VARCHAR(20);
BEGIN
    -- Get next number for the year
    SELECT COALESCE(MAX(CAST(SUBSTRING(receipt_number FROM 8) AS INTEGER)), 0) + 1
    INTO next_number
    FROM receipts 
    WHERE year = receipt_year;
    
    -- Format: RCP2024001
    receipt_number := 'RCP' || receipt_year::TEXT || LPAD(next_number::TEXT, 3, '0');
    
    RETURN receipt_number;
END;
$$ LANGUAGE plpgsql;

-- 9. Wallet Statistics Function
CREATE OR REPLACE FUNCTION get_wallet_statistics(user_firebase_uid VARCHAR(255)) RETURNS JSONB AS $$
DECLARE
    user_record RECORD;
    stats JSONB;
BEGIN
    -- Get user record
    SELECT * INTO user_record FROM users WHERE firebase_uid = get_wallet_statistics.user_firebase_uid;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Calculate statistics
    SELECT jsonb_build_object(
        'total_credits', COALESCE(SUM(CASE WHEN type = 'CREDIT' THEN amount ELSE 0 END), 0),
        'total_debits', COALESCE(SUM(CASE WHEN type = 'DEBIT' THEN amount ELSE 0 END), 0),
        'current_balance', user_record.wallet_balance,
        'total_transactions', COUNT(*),
        'last_transaction_date', MAX(created_at)
    ) INTO stats
    FROM wallet_transactions
    WHERE user_id = user_record.id;
    
    RETURN stats;
END;
$$ LANGUAGE plpgsql;

-- 10. Reminder Functions
CREATE OR REPLACE FUNCTION get_users_for_reminder(
    reminder_date DATE,
    days_before INTEGER
) RETURNS TABLE(
    firebase_uid VARCHAR(255),
    name VARCHAR(100),
    phone_number VARCHAR(15),
    payment_id UUID,
    amount DECIMAL(10,2),
    due_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.firebase_uid,
        u.name,
        u.phone_number,
        p.id as payment_id,
        p.amount,
        p.service_period_start as due_date
    FROM users u
    JOIN payments p ON u.firebase_uid = p.user_firebase_uid
    WHERE p.status = 'PENDING'
    AND p.service_period_start BETWEEN reminder_date - INTERVAL '1 day' AND reminder_date + INTERVAL '1 day'
    AND u.is_active = true;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_overdue_payments_for_reminder() RETURNS TABLE(
    user_firebase_uid VARCHAR(255),
    id UUID,
    amount DECIMAL(10,2),
    days_overdue INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.user_firebase_uid,
        p.id,
        p.amount,
        EXTRACT(DAY FROM NOW() - p.service_period_start)::INTEGER as days_overdue
    FROM payments p
    WHERE p.status = 'PENDING'
    AND p.service_period_start < CURRENT_DATE
    AND p.user_firebase_uid IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_reminder_statistics(
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    stats JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_sent', COUNT(CASE WHEN status = 'SENT' THEN 1 END),
        'total_scheduled', COUNT(CASE WHEN status = 'SCHEDULED' THEN 1 END),
        'total_delivered', COUNT(CASE WHEN status = 'DELIVERED' THEN 1 END),
        'total_failed', COUNT(CASE WHEN status = 'FAILED' THEN 1 END),
        'last_reminder_sent', MAX(CASE WHEN status = 'SENT' THEN created_at END)
    ) INTO stats
    FROM reminder_history
    WHERE (start_date IS NULL OR created_at >= start_date)
    AND (end_date IS NULL OR created_at <= end_date);
    
    RETURN stats;
END;
$$ LANGUAGE plpgsql;

-- 11. Report Functions
CREATE OR REPLACE FUNCTION generate_payment_summary_report(
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    area_filter VARCHAR(50) DEFAULT NULL,
    status_filter VARCHAR(50) DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    report JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_payments', COUNT(*),
        'total_amount', COALESCE(SUM(total_amount), 0),
        'pending_payments', COUNT(CASE WHEN status = 'PENDING' THEN 1 END),
        'pending_amount', COALESCE(SUM(CASE WHEN status = 'PENDING' THEN total_amount ELSE 0 END), 0),
        'approved_payments', COUNT(CASE WHEN status = 'APPROVED' THEN 1 END),
        'approved_amount', COALESCE(SUM(CASE WHEN status = 'APPROVED' THEN total_amount ELSE 0 END), 0),
        'rejected_payments', COUNT(CASE WHEN status = 'REJECTED' THEN 1 END),
        'rejected_amount', COALESCE(SUM(CASE WHEN status = 'REJECTED' THEN total_amount ELSE 0 END), 0),
        'total_late_fees', COALESCE(SUM(late_fees), 0),
        'total_extra_charges', COALESCE(SUM(extra_charges), 0),
        'total_wire_charges', COALESCE(SUM(wire_charges), 0)
    ) INTO report
    FROM payments p
    JOIN users u ON p.user_firebase_uid = u.firebase_uid
    WHERE (start_date IS NULL OR p.created_at >= start_date)
    AND (end_date IS NULL OR p.created_at <= end_date)
    AND (area_filter IS NULL OR u.area = area_filter)
    AND (status_filter IS NULL OR p.status = status_filter);
    
    RETURN report;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_user_payment_report(
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    area_filter VARCHAR(50) DEFAULT NULL,
    role_filter VARCHAR(20) DEFAULT NULL
) RETURNS TABLE(
    user_id VARCHAR(255),
    user_name VARCHAR(100),
    phone_number VARCHAR(15),
    area VARCHAR(50),
    role VARCHAR(20),
    total_payments BIGINT,
    total_amount_paid DECIMAL(12,2),
    pending_payments BIGINT,
    pending_amount DECIMAL(12,2),
    overdue_payments BIGINT,
    overdue_amount DECIMAL(12,2),
    last_payment_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.firebase_uid as user_id,
        u.name as user_name,
        u.phone_number,
        u.area,
        u.role,
        COUNT(p.id) as total_payments,
        COALESCE(SUM(CASE WHEN p.status = 'APPROVED' THEN p.total_amount ELSE 0 END), 0) as total_amount_paid,
        COUNT(CASE WHEN p.status = 'PENDING' THEN 1 END) as pending_payments,
        COALESCE(SUM(CASE WHEN p.status = 'PENDING' THEN p.total_amount ELSE 0 END), 0) as pending_amount,
        COUNT(CASE WHEN p.status = 'PENDING' AND p.service_period_start < CURRENT_DATE THEN 1 END) as overdue_payments,
        COALESCE(SUM(CASE WHEN p.status = 'PENDING' AND p.service_period_start < CURRENT_DATE THEN p.total_amount ELSE 0 END), 0) as overdue_amount,
        MAX(CASE WHEN p.status = 'APPROVED' THEN p.paid_at END) as last_payment_date
    FROM users u
    LEFT JOIN payments p ON u.firebase_uid = p.user_firebase_uid
    WHERE (start_date IS NULL OR p.created_at >= start_date)
    AND (end_date IS NULL OR p.created_at <= end_date)
    AND (area_filter IS NULL OR u.area = area_filter)
    AND (role_filter IS NULL OR u.role = role_filter)
    GROUP BY u.firebase_uid, u.name, u.phone_number, u.area, u.role;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_monthly_revenue_report(
    report_year INTEGER,
    area_filter VARCHAR(50) DEFAULT NULL
) RETURNS TABLE(
    month INTEGER,
    year INTEGER,
    revenue DECIMAL(12,2),
    payment_count BIGINT,
    average_payment DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        EXTRACT(MONTH FROM p.paid_at)::INTEGER as month,
        EXTRACT(YEAR FROM p.paid_at)::INTEGER as year,
        COALESCE(SUM(p.total_amount), 0) as revenue,
        COUNT(p.id) as payment_count,
        COALESCE(AVG(p.total_amount), 0) as average_payment
    FROM payments p
    JOIN users u ON p.user_firebase_uid = u.firebase_uid
    WHERE p.status = 'APPROVED'
    AND EXTRACT(YEAR FROM p.paid_at) = report_year
    AND (area_filter IS NULL OR u.area = area_filter)
    GROUP BY EXTRACT(MONTH FROM p.paid_at), EXTRACT(YEAR FROM p.paid_at)
    ORDER BY month;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_area_collection_report(
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURNS TABLE(
    area VARCHAR(50),
    total_users BIGINT,
    total_payments BIGINT,
    total_amount DECIMAL(12,2),
    collection_rate DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.area,
        COUNT(DISTINCT u.firebase_uid) as total_users,
        COUNT(p.id) as total_payments,
        COALESCE(SUM(CASE WHEN p.status = 'APPROVED' THEN p.total_amount ELSE 0 END), 0) as total_amount,
        CASE 
            WHEN COUNT(p.id) > 0 THEN 
                (COUNT(CASE WHEN p.status = 'APPROVED' THEN 1 END)::DECIMAL / COUNT(p.id)::DECIMAL) * 100
            ELSE 0 
        END as collection_rate
    FROM users u
    LEFT JOIN payments p ON u.firebase_uid = p.user_firebase_uid
    WHERE (start_date IS NULL OR p.created_at >= start_date)
    AND (end_date IS NULL OR p.created_at <= end_date)
    GROUP BY u.area
    ORDER BY total_amount DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_overdue_payments_report(
    area_filter VARCHAR(50) DEFAULT NULL,
    min_days_past_due INTEGER DEFAULT NULL
) RETURNS TABLE(
    user_id VARCHAR(255),
    user_name VARCHAR(100),
    phone_number VARCHAR(15),
    area VARCHAR(50),
    payment_id UUID,
    amount DECIMAL(10,2),
    due_date DATE,
    days_past_due INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.firebase_uid as user_id,
        u.name as user_name,
        u.phone_number,
        u.area,
        p.id as payment_id,
        p.total_amount as amount,
        p.service_period_start as due_date,
        EXTRACT(DAY FROM CURRENT_DATE - p.service_period_start)::INTEGER as days_past_due
    FROM users u
    JOIN payments p ON u.firebase_uid = p.user_firebase_uid
    WHERE p.status = 'PENDING'
    AND p.service_period_start < CURRENT_DATE
    AND (area_filter IS NULL OR u.area = area_filter)
    AND (min_days_past_due IS NULL OR EXTRACT(DAY FROM CURRENT_DATE - p.service_period_start) >= min_days_past_due)
    ORDER BY days_past_due DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_collection_efficiency_report(
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    collector_firebase_uid VARCHAR(255) DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    report JSONB;
BEGIN
    SELECT jsonb_build_object(
        'collector_id', COALESCE(collector_firebase_uid, 'ALL'),
        'collector_name', COALESCE(u.name, 'All Collectors'),
        'total_assigned', COUNT(DISTINCT u2.firebase_uid),
        'total_collected', COUNT(CASE WHEN p.status = 'APPROVED' THEN 1 END),
        'collection_rate', CASE 
            WHEN COUNT(p.id) > 0 THEN 
                (COUNT(CASE WHEN p.status = 'APPROVED' THEN 1 END)::DECIMAL / COUNT(p.id)::DECIMAL) * 100
            ELSE 0 
        END,
        'total_amount_collected', COALESCE(SUM(CASE WHEN p.status = 'APPROVED' THEN p.total_amount ELSE 0 END), 0),
        'average_collection_time', COALESCE(AVG(EXTRACT(EPOCH FROM (p.paid_at - p.created_at))/86400), 0)
    ) INTO report
    FROM users u
    LEFT JOIN users u2 ON u.area = u2.area AND u2.role = 'USER'
    LEFT JOIN payments p ON u2.firebase_uid = p.user_firebase_uid
    WHERE u.role = 'COLLECTOR'
    AND (collector_firebase_uid IS NULL OR u.firebase_uid = collector_firebase_uid)
    AND (start_date IS NULL OR p.created_at >= start_date)
    AND (end_date IS NULL OR p.created_at <= end_date);
    
    RETURN report;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_dashboard_analytics(
    start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    analytics JSONB;
BEGIN
    SELECT jsonb_build_object(
        'total_revenue', COALESCE(SUM(CASE WHEN p.status = 'APPROVED' THEN p.total_amount ELSE 0 END), 0),
        'total_users', COUNT(DISTINCT u.firebase_uid),
        'total_payments', COUNT(p.id),
        'pending_amount', COALESCE(SUM(CASE WHEN p.status = 'PENDING' THEN p.total_amount ELSE 0 END), 0),
        'collection_rate', CASE 
            WHEN COUNT(p.id) > 0 THEN 
                (COUNT(CASE WHEN p.status = 'APPROVED' THEN 1 END)::DECIMAL / COUNT(p.id)::DECIMAL) * 100
            ELSE 0 
        END,
        'revenue_chart', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'month', EXTRACT(MONTH FROM p2.paid_at)::INTEGER,
                    'year', EXTRACT(YEAR FROM p2.paid_at)::INTEGER,
                    'revenue', COALESCE(SUM(p2.total_amount), 0),
                    'payment_count', COUNT(p2.id),
                    'average_payment', COALESCE(AVG(p2.total_amount), 0)
                )
            )
            FROM payments p2
            WHERE p2.status = 'APPROVED'
            AND (start_date IS NULL OR p2.paid_at >= start_date)
            AND (end_date IS NULL OR p2.paid_at <= end_date)
            GROUP BY EXTRACT(MONTH FROM p2.paid_at), EXTRACT(YEAR FROM p2.paid_at)
            ORDER BY EXTRACT(YEAR FROM p2.paid_at), EXTRACT(MONTH FROM p2.paid_at)
        )
    ) INTO analytics
    FROM users u
    LEFT JOIN payments p ON u.firebase_uid = p.user_firebase_uid
    WHERE (start_date IS NULL OR p.created_at >= start_date)
    AND (end_date IS NULL OR p.created_at <= end_date);
    
    RETURN analytics;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 🔐 ROW LEVEL SECURITY UPDATES
-- ============================================================================

-- Update RLS policies for new tables
ALTER TABLE reminder_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings_audit ENABLE ROW LEVEL SECURITY;

-- Reminder history policies
CREATE POLICY "Users can view own reminder history" ON reminder_history
    FOR SELECT USING (auth.uid()::TEXT = user_firebase_uid);

CREATE POLICY "Admins can view all reminder history" ON reminder_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE firebase_uid = auth.uid()::TEXT AND role = 'ADMIN'
        )
    );

-- Settings audit policies
CREATE POLICY "Admins can view settings audit" ON settings_audit
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE firebase_uid = auth.uid()::TEXT AND role = 'ADMIN'
        )
    );

-- Update existing policies to use firebase_uid
DROP POLICY IF EXISTS "Users can view own profile" ON users;
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid()::TEXT = firebase_uid);

DROP POLICY IF EXISTS "Users can update own profile" ON users;
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid()::TEXT = firebase_uid);

-- ============================================================================
-- 📊 TRIGGERS FOR AUTOMATION
-- ============================================================================

-- Drop existing triggers that might conflict
DROP TRIGGER IF EXISTS trigger_calculate_payment_total ON payments;
DROP TRIGGER IF EXISTS trigger_log_settings_change ON settings;

-- Trigger to automatically calculate total_amount for payments
CREATE OR REPLACE FUNCTION calculate_payment_total() RETURNS TRIGGER AS $$
BEGIN
    NEW.total_amount := COALESCE(NEW.amount, 0) + COALESCE(NEW.late_fees, 0) + COALESCE(NEW.extra_charges, 0) + COALESCE(NEW.wire_charges, 0);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calculate_payment_total
    BEFORE INSERT OR UPDATE ON payments
    FOR EACH ROW
    EXECUTE FUNCTION calculate_payment_total();

-- Trigger to log settings changes
CREATE OR REPLACE FUNCTION log_settings_change() RETURNS TRIGGER AS $$
BEGIN
    IF OLD IS DISTINCT FROM NEW THEN
        INSERT INTO settings_audit (
            field_name,
            old_value,
            new_value,
            updated_by,
            notes
        ) VALUES (
            'settings_update',
            row_to_json(OLD)::TEXT,
            row_to_json(NEW)::TEXT,
            COALESCE(NEW.last_updated_by, 'system'),
            'Settings updated'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_log_settings_change
    AFTER UPDATE ON settings
    FOR EACH ROW
    EXECUTE FUNCTION log_settings_change();

-- ============================================================================
-- ✅ COMPLETION MESSAGE
-- ============================================================================

-- This completes the schema updates for the enhanced TV Subscription App
-- All new tables, functions, and policies have been created
-- The app is now ready to use all the new Supabase services!
