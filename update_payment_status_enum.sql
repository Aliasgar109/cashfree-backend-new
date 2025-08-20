-- Update payment status enum to include INCOMPLETE status
-- This script adds the new INCOMPLETE status to the payment_status_type enum

-- First, drop all views that depend on the status column
DROP VIEW IF EXISTS user_payment_summary;
DROP VIEW IF EXISTS area_collection_summary;
DROP VIEW IF EXISTS payment_summary;
DROP VIEW IF EXISTS admin_dashboard_summary;
DROP VIEW IF EXISTS payment_approval_queue;

-- Drop the default constraint on the status column
ALTER TABLE payments ALTER COLUMN status DROP DEFAULT;

-- Create a new enum type with the additional value
CREATE TYPE payment_status_type_new AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'INCOMPLETE');

-- Update the payments table to use the new enum type
ALTER TABLE payments 
  ALTER COLUMN status TYPE payment_status_type_new 
  USING status::text::payment_status_type_new;

-- Drop the old enum type
DROP TYPE payment_status_type;

-- Rename the new enum type to the original name
ALTER TYPE payment_status_type_new RENAME TO payment_status_type;

-- Re-add the default constraint with the new enum type
ALTER TABLE payments ALTER COLUMN status SET DEFAULT 'PENDING'::payment_status_type;

-- Recreate the user_payment_summary view with the updated enum
CREATE OR REPLACE VIEW user_payment_summary AS
SELECT 
    u.id as user_id,
    u.username,
    u.phone_number,
    u.area,
    u.role,
    COUNT(p.id) as total_payments,
    COUNT(CASE WHEN p.status = 'APPROVED' THEN 1 END) as approved_payments,
    COUNT(CASE WHEN p.status = 'PENDING' THEN 1 END) as pending_payments,
    COUNT(CASE WHEN p.status = 'REJECTED' THEN 1 END) as rejected_payments,
    SUM(CASE WHEN p.status = 'APPROVED' THEN p.amount + p.extra_charges ELSE 0 END) as total_paid_amount,
    MAX(CASE WHEN p.status = 'APPROVED' THEN p.created_at END) as last_payment_date
FROM users u
LEFT JOIN payments p ON u.id = p.user_id
WHERE u.is_active = true
GROUP BY u.id, u.username, u.phone_number, u.area, u.role;

-- Recreate the area_collection_summary view with the updated enum
CREATE OR REPLACE VIEW area_collection_summary AS
SELECT 
    u.area,
    COUNT(DISTINCT u.id) as total_users,
    COUNT(p.id) as total_payments,
    COUNT(CASE WHEN p.status = 'APPROVED' THEN 1 END) as approved_payments,
    COUNT(CASE WHEN p.status = 'PENDING' THEN 1 END) as pending_payments,
    COUNT(CASE WHEN p.status = 'REJECTED' THEN 1 END) as rejected_payments,
    SUM(CASE WHEN p.status = 'APPROVED' THEN p.amount + p.extra_charges ELSE 0 END) as total_collected_amount,
    AVG(CASE WHEN p.status = 'APPROVED' THEN p.amount + p.extra_charges END) as avg_payment_amount
FROM users u
LEFT JOIN payments p ON u.id = p.user_id
WHERE u.is_active = true AND u.role = 'USER'
GROUP BY u.area
ORDER BY total_collected_amount DESC;

-- Recreate the payment_approval_queue view with the updated enum
CREATE OR REPLACE VIEW payment_approval_queue AS
SELECT 
    p.id as payment_id,
    p.receipt_number,
    p.amount,
    p.extra_charges,
    p.amount + p.extra_charges as total_amount,
    p.payment_method,
    p.status,
    p.created_at,
    p.transaction_id,
    p.screenshot_url,
    u.id as user_id,
    u.username,
    u.phone_number,
    u.area,
    u.role
FROM payments p
JOIN users u ON p.user_id = u.id
WHERE p.status = 'PENDING'
ORDER BY p.created_at ASC;

-- Update any existing incomplete payments (those without transaction_id for UPI payments)
-- This is optional - you can run this if you want to mark existing incomplete payments
-- UPDATE payments 
-- SET status = 'INCOMPLETE'::payment_status_type 
-- WHERE status = 'PENDING'::payment_status_type 
--   AND (payment_method = 'UPI' OR payment_method = 'COMBINED')
--   AND (transaction_id IS NULL OR transaction_id LIKE 'TEMP_%');
