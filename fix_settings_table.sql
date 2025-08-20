-- Fix settings table by adding missing columns
-- This script bypasses RLS and uses proper permissions

-- Temporarily disable RLS for settings table
ALTER TABLE settings DISABLE ROW LEVEL SECURITY;

-- Create settings_audit table if it doesn't exist
CREATE TABLE IF NOT EXISTS settings_audit (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    field_name VARCHAR(100) NOT NULL,
    old_value TEXT,
    new_value TEXT NOT NULL,
    updated_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    notes TEXT
);

-- Disable RLS for settings_audit table
ALTER TABLE settings_audit DISABLE ROW LEVEL SECURITY;

-- Add missing columns to settings table
ALTER TABLE settings ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100);
ALTER TABLE settings ADD COLUMN IF NOT EXISTS merchant_name VARCHAR(100);
ALTER TABLE settings ADD COLUMN IF NOT EXISTS merchant_code VARCHAR(50);
ALTER TABLE settings ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE settings ADD COLUMN IF NOT EXISTS last_updated_by VARCHAR(100);

-- Set default values for existing records
UPDATE settings 
SET 
    upi_id = 'your-tv-channel@upi',
    merchant_name = 'Your TV Channel Name',
    merchant_code = 'TVCHANNEL',
    created_at = NOW(),
    last_updated_by = NULL
WHERE id = 'app_settings' AND upi_id IS NULL;

-- Insert default settings if none exist
INSERT INTO settings (
    id, 
    yearly_fee, 
    late_fees_percentage, 
    wire_charge_per_meter, 
    auto_approval_enabled, 
    reminder_days_before, 
    supported_languages,
    upi_id,
    merchant_name,
    merchant_code,
    created_at,
    last_updated
) 
VALUES (
    'app_settings', 
    1.00, 
    10.00, 
    5.00, 
    false, 
    30, 
    ARRAY['en', 'gu'],
    'your-tv-channel@upi',
    'Your TV Channel Name',
    'TVCHANNEL',
    NOW(),
    NOW()
) 
ON CONFLICT (id) DO NOTHING;

-- Re-enable RLS for settings table
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- Re-enable RLS for settings_audit table
ALTER TABLE settings_audit ENABLE ROW LEVEL SECURITY;
