-- Add unique constraint on phone_number to ensure one phone number per user
-- This prevents multiple users from registering with the same phone number

-- First, check if there are any duplicate phone numbers
SELECT phone_number, COUNT(*) as count
FROM users 
WHERE is_active = true 
GROUP BY phone_number 
HAVING COUNT(*) > 1;

-- If duplicates exist, you'll need to resolve them before adding the constraint
-- For now, we'll add the constraint and it will fail if duplicates exist

-- Add unique constraint on phone_number
ALTER TABLE users ADD CONSTRAINT unique_phone_number UNIQUE (phone_number);

-- Create a unique index for better performance
CREATE UNIQUE INDEX idx_users_phone_number_unique ON users (phone_number) WHERE is_active = true;

-- Add a comment explaining the constraint
COMMENT ON CONSTRAINT unique_phone_number ON users IS 'Ensures each phone number can only be used once for registration';
