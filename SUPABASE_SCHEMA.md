--# 🗄️ Supabase Database Schema for TV Subscription App

--This document contains the complete database schema for the TV Subscription App, designed to work with Supabase (PostgreSQL).

--## 📋 **Table Overview**

--| Table | Purpose | Key Features |
--|-------|---------|--------------|
--| `users` | User management and authentication | Role-based access, profile data |
--| `payments` | Payment tracking and management | Multiple payment methods, approval workflow |
--| `wallet_transactions` | Wallet balance tracking | Credit/debit transactions, balance history |
--| `receipts` | Receipt generation and storage | PDF storage, multi-language support |
--| `settings` | App configuration | Fee structure, reminder settings |
--| `reminders` | Payment reminder system | Automated notifications, escalation |
--| `notifications` | User notifications | Push, WhatsApp, SMS support |
--| `notification_history` | Notification tracking | Delivery status, channel results |
--| `audit_logs` | Activity tracking | User actions, system events |
--| `areas` | Geographic area management | Area-specific settings, collectors |

---

--## 🏗️ **Database Schema**

--### **1. Users Table**

--```sql
-- Users table for authentication and profile management
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone_number VARCHAR(15) NOT NULL,
    address TEXT NOT NULL,
    area VARCHAR(50) NOT NULL,
    role user_role NOT NULL DEFAULT 'USER',
    preferred_language VARCHAR(5) NOT NULL DEFAULT 'en',
    wallet_balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_payment_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Enum for user roles
--CREATE TYPE user_role AS ENUM ('USER', 'COLLECTOR', 'ADMIN');

-- Indexes for performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_phone_number ON users(phone_number);
CREATE INDEX idx_users_area ON users(area);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
--```

--### **2. Payments Table**

--```sql
-- Payments table for tracking all payment transactions
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
    extra_charges DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    payment_method payment_method_type NOT NULL,
    status payment_status_type NOT NULL DEFAULT 'PENDING',
    transaction_id VARCHAR(50),
    screenshot_url TEXT,
    receipt_number VARCHAR(20) UNIQUE NOT NULL,
    year INTEGER NOT NULL,
    wallet_amount_used DECIMAL(10,2),
    upi_amount_paid DECIMAL(10,2),
    approved_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Enums for payment types
--CREATE TYPE payment_method_type AS ENUM ('UPI', 'CASH', 'WALLET', 'COMBINED');
--CREATE TYPE payment_status_type AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- Indexes for performance
CREATE INDEX idx_payments_user_id ON payments(user_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_method ON payments(payment_method);
CREATE INDEX idx_payments_year ON payments(year);
CREATE INDEX idx_payments_created_at ON payments(created_at);
CREATE INDEX idx_payments_receipt_number ON payments(receipt_number);

-- Trigger to update updated_at timestamp
CREATE TRIGGER update_payments_updated_at 
    BEFORE UPDATE ON payments 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Check constraint for combined payments
ALTER TABLE payments ADD CONSTRAINT check_combined_payment_amounts 
    CHECK (
        (payment_method != 'COMBINED') OR 
        (wallet_amount_used IS NOT NULL AND upi_amount_paid IS NOT NULL)
    );

-- Check constraint for UPI payments requiring transaction ID
ALTER TABLE payments ADD CONSTRAINT check_upi_transaction_id 
    CHECK (
        (payment_method NOT IN ('UPI', 'COMBINED')) OR 
        (transaction_id IS NOT NULL AND transaction_id != '')
    );
--```

--### **3. Wallet Transactions Table**

--```sql
-- Wallet transactions for tracking balance changes
CREATE TABLE wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount DECIMAL(10,2) NOT NULL,
    type transaction_type NOT NULL,
    status transaction_status NOT NULL DEFAULT 'PENDING',
    description VARCHAR(200) NOT NULL,
    reference_id UUID, -- Payment ID or recharge transaction ID
    upi_transaction_id VARCHAR(50),
    balance_before DECIMAL(10,2) NOT NULL,
  balance_after DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Enums for transaction types
--CREATE TYPE transaction_type AS ENUM ('CREDIT', 'DEBIT');
--CREATE TYPE transaction_status AS ENUM ('PENDING', 'COMPLETED', 'FAILED');

-- Indexes for performance
CREATE INDEX idx_wallet_transactions_user_id ON wallet_transactions(user_id);
CREATE INDEX idx_wallet_transactions_type ON wallet_transactions(type);
CREATE INDEX idx_wallet_transactions_status ON wallet_transactions(status);
CREATE INDEX idx_wallet_transactions_created_at ON wallet_transactions(created_at);
CREATE INDEX idx_wallet_transactions_reference_id ON wallet_transactions(reference_id);

-- Trigger to update updated_at timestamp
CREATE TRIGGER update_wallet_transactions_updated_at 
    BEFORE UPDATE ON wallet_transactions 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Check constraint for balance calculation
ALTER TABLE wallet_transactions ADD CONSTRAINT check_balance_calculation 
    CHECK (
        (type = 'CREDIT' AND balance_after = balance_before + amount) OR
        (type = 'DEBIT' AND balance_after = balance_before - amount)
    );
--```

--### **4. Receipts Table**

--```sql
-- Receipts for storing generated receipt information
CREATE TABLE receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    receipt_number VARCHAR(20) UNIQUE NOT NULL,
    pdf_url TEXT NOT NULL,
    language VARCHAR(5) NOT NULL DEFAULT 'en',
    generated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_receipts_payment_id ON receipts(payment_id);
CREATE INDEX idx_receipts_receipt_number ON receipts(receipt_number);
CREATE INDEX idx_receipts_language ON receipts(language);
CREATE INDEX idx_receipts_generated_at ON receipts(generated_at);

-- Check constraint for supported languages
ALTER TABLE receipts ADD CONSTRAINT check_supported_languages 
    CHECK (language IN ('en', 'gu'));
--```

--### **5. Settings Table**

---```sql
-- App settings and configuration
CREATE TABLE settings (
    id VARCHAR(50) PRIMARY KEY DEFAULT 'app_settings',
    yearly_fee DECIMAL(10,2) NOT NULL DEFAULT 1000.00,
    late_fees_percentage DECIMAL(5,2) NOT NULL DEFAULT 10.00,
    wire_charge_per_meter DECIMAL(10,2) NOT NULL DEFAULT 5.00,
    auto_approval_enabled BOOLEAN NOT NULL DEFAULT false,
    reminder_days_before INTEGER NOT NULL DEFAULT 30,
    supported_languages TEXT[] NOT NULL DEFAULT ARRAY['en', 'gu'],
    last_updated TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_updated_by UUID REFERENCES users(id)
);

-- Indexes for performance
CREATE INDEX idx_settings_last_updated ON settings(last_updated);

-- Check constraints
ALTER TABLE settings ADD CONSTRAINT check_yearly_fee_positive 
    CHECK (yearly_fee > 0);
ALTER TABLE settings ADD CONSTRAINT check_late_fees_percentage 
    CHECK (late_fees_percentage >= 0 AND late_fees_percentage <= 100);
ALTER TABLE settings ADD CONSTRAINT check_wire_charge_positive 
    CHECK (wire_charge_per_meter >= 0);
ALTER TABLE settings ADD CONSTRAINT check_reminder_days_positive 
    CHECK (reminder_days_before > 0);
--```

--### **6. Reminders Table**

--```sql
-- Payment reminders and notifications
CREATE TABLE reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    scheduled_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status reminder_status NOT NULL DEFAULT 'scheduled',
    reminder_type reminder_type_enum NOT NULL DEFAULT 'payment_due',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    sent_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Enums for reminder types
--CREATE TYPE reminder_status AS ENUM ('scheduled', 'sent', 'failed', 'cancelled');
--CREATE TYPE reminder_type_enum AS ENUM ('payment_due', 'overdue', 'final_notice');

-- Indexes for performance
CREATE INDEX idx_reminders_user_id ON reminders(user_id);
CREATE INDEX idx_reminders_status ON reminders(status);
CREATE INDEX idx_reminders_scheduled_date ON reminders(scheduled_date);
CREATE INDEX idx_reminders_year ON reminders(year);

-- Trigger to update updated_at timestamp
CREATE TRIGGER update_reminders_updated_at 
    BEFORE UPDATE ON reminders 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
--```

--### **7. Notifications Table**

--```sql
-- User notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
    language VARCHAR(5) NOT NULL DEFAULT 'en',
    payment_id UUID REFERENCES payments(id),
    status VARCHAR(50),
    amount DECIMAL(10,2),
    year INTEGER,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);
CREATE INDEX idx_notifications_payment_id ON notifications(payment_id);

-- Trigger to update updated_at timestamp
CREATE TRIGGER update_notifications_updated_at 
    BEFORE UPDATE ON notifications 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
--```

--### **8. Notification History Table**

--```sql
-- Notification delivery tracking
CREATE TABLE notification_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    channels TEXT[] NOT NULL,
    results JSONB NOT NULL DEFAULT '{}',
    success BOOLEAN NOT NULL DEFAULT false,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_notification_history_notification_id ON notification_history(notification_id);
CREATE INDEX idx_notification_history_user_id ON notification_history(user_id);
CREATE INDEX idx_notification_history_timestamp ON notification_history(timestamp);
CREATE INDEX idx_notification_history_success ON notification_history(success);
--```

--### **9. Audit Logs Table**

--```sql
-- System audit trail
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(50),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_table_name ON audit_logs(table_name);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
--```

--### **10. Areas Table**

--```sql
-- Geographic areas and their settings
CREATE TABLE areas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    collector_id UUID REFERENCES users(id),
    total_users INTEGER NOT NULL DEFAULT 0,
    total_collected DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    collection_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_areas_name ON areas(name);
CREATE INDEX idx_areas_collector_id ON areas(collector_id);
CREATE INDEX idx_areas_is_active ON areas(is_active);

-- Trigger to update updated_at timestamp
CREATE TRIGGER update_areas_updated_at 
    BEFORE UPDATE ON areas 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();
--```

---

--## 🔐 **Row Level Security (RLS)**

--### **Users Table RLS**

--```sql
-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Users can view their own profile
CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

-- Admins can view all users
CREATE POLICY "Admins can view all users" ON users
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
    )
  );

-- Admins can update all users
CREATE POLICY "Admins can update all users" ON users
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- Collectors can view users in their area
CREATE POLICY "Collectors can view users in their area" ON users
  FOR SELECT USING (
    EXISTS (
            SELECT 1 FROM users collector
            WHERE collector.id = auth.uid() 
            AND collector.role = 'COLLECTOR'
            AND collector.area = users.area
        )
    );
--```

--### **Payments Table RLS**

--```sql
-- Enable RLS
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Users can view their own payments
CREATE POLICY "Users can view own payments" ON payments
    FOR SELECT USING (auth.uid() = user_id);

-- Users can create their own payments
CREATE POLICY "Users can create own payments" ON payments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admins can view all payments
CREATE POLICY "Admins can view all payments" ON payments
    FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- Admins can update payment status
CREATE POLICY "Admins can update payments" ON payments
    FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- Collectors can view payments in their area
CREATE POLICY "Collectors can view payments in their area" ON payments
  FOR SELECT USING (
    EXISTS (
            SELECT 1 FROM users collector
            JOIN users payer ON payer.id = payments.user_id
            WHERE collector.id = auth.uid() 
            AND collector.role = 'COLLECTOR'
            AND collector.area = payer.area
        )
    );
--```

--### **Wallet Transactions RLS**

--```sql
-- Enable RLS
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Users can view their own transactions
CREATE POLICY "Users can view own wallet transactions" ON wallet_transactions
    FOR SELECT USING (auth.uid() = user_id);

-- Users can create their own transactions
CREATE POLICY "Users can create own wallet transactions" ON wallet_transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admins can view all transactions
CREATE POLICY "Admins can view all wallet transactions" ON wallet_transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );
--```

---

--## 📊 **Views for Common Queries**

---### **User Payment Summary View**

---```sql
CREATE VIEW user_payment_summary AS
SELECT 
    u.id,
    u.username,
    u.name,
    u.area,
    u.wallet_balance,
    COUNT(p.id) as total_payments,
    COUNT(CASE WHEN p.status = 'APPROVED' THEN 1 END) as approved_payments,
    COUNT(CASE WHEN p.status = 'PENDING' THEN 1 END) as pending_payments,
    SUM(CASE WHEN p.status = 'APPROVED' THEN p.amount + p.extra_charges ELSE 0 END) as total_paid,
    MAX(p.created_at) as last_payment_date
FROM users u
LEFT JOIN payments p ON u.id = p.user_id
WHERE u.is_active = true
GROUP BY u.id, u.username, u.name, u.area, u.wallet_balance;
--```

--### **Area Collection Summary View**

--```sql
CREATE VIEW area_collection_summary AS
SELECT 
    u.area,
    COUNT(DISTINCT u.id) as total_users,
    COUNT(DISTINCT CASE WHEN p.status = 'APPROVED' THEN u.id END) as paid_users,
    COUNT(DISTINCT CASE WHEN p.status = 'PENDING' THEN u.id END) as pending_users,
    SUM(CASE WHEN p.status = 'APPROVED' THEN p.amount + p.extra_charges ELSE 0 END) as total_collected,
    SUM(CASE WHEN p.status = 'PENDING' THEN p.amount + p.extra_charges ELSE 0 END) as pending_amount,
    ROUND(
        (COUNT(DISTINCT CASE WHEN p.status = 'APPROVED' THEN u.id END)::DECIMAL / 
         COUNT(DISTINCT u.id)::DECIMAL) * 100, 2
    ) as collection_percentage
FROM users u
LEFT JOIN payments p ON u.id = p.user_id AND p.year = EXTRACT(YEAR FROM NOW())
WHERE u.is_active = true
GROUP BY u.area;
--```

--### **Payment Approval Queue View**

--```sql
CREATE VIEW payment_approval_queue AS
SELECT 
    p.id,
    p.receipt_number,
    p.amount + p.extra_charges as total_amount,
    p.payment_method,
    p.created_at,
    u.name as user_name,
    u.phone_number,
    u.area,
    p.transaction_id,
    p.screenshot_url
FROM payments p
JOIN users u ON p.user_id = u.id
WHERE p.status = 'PENDING'
AND p.payment_method IN ('UPI', 'COMBINED')
ORDER BY p.created_at ASC;
--```

---

--## 🔧 **Functions and Triggers**

--### **Update User Wallet Balance Function**

--```sql
CREATE OR REPLACE FUNCTION update_user_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- Update user's wallet balance when wallet transaction is completed
    IF NEW.status = 'COMPLETED' AND OLD.status != 'COMPLETED' THEN
    UPDATE users 
        SET wallet_balance = NEW.balance_after,
        updated_at = NOW()
    WHERE id = NEW.user_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update user wallet balance
CREATE TRIGGER trigger_update_user_wallet_balance
    AFTER UPDATE ON wallet_transactions
  FOR EACH ROW
    EXECUTE FUNCTION update_user_wallet_balance();
--```

--### **Generate Receipt Number Function**

--```sql
CREATE OR REPLACE FUNCTION generate_receipt_number(year_param INTEGER)
RETURNS VARCHAR(20) AS $$
DECLARE
    next_sequence INTEGER;
    receipt_num VARCHAR(20);
BEGIN
    -- Get next sequence number for the year
    SELECT COALESCE(MAX(CAST(SUBSTRING(receipt_number FROM 8) AS INTEGER)), 0) + 1
    INTO next_sequence
    FROM receipts r
    JOIN payments p ON r.payment_id = p.id
    WHERE p.year = year_param;
    
    -- Format: RCP2024001
    receipt_num := 'RCP' || year_param || LPAD(next_sequence::TEXT, 3, '0');
    
    RETURN receipt_num;
END;
$$ LANGUAGE plpgsql;
--```

--### **Audit Log Trigger Function**

--```sql
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_logs (user_id, action, table_name, record_id, new_values)
        VALUES (auth.uid(), 'INSERT', TG_TABLE_NAME, NEW.id, to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values, new_values)
        VALUES (auth.uid(), 'UPDATE', TG_TABLE_NAME, NEW.id, to_jsonb(OLD), to_jsonb(NEW));
  RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_logs (user_id, action, table_name, record_id, old_values)
        VALUES (auth.uid(), 'DELETE', TG_TABLE_NAME, OLD.id, to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit trigger to all tables
CREATE TRIGGER audit_users_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_payments_trigger
    AFTER INSERT OR UPDATE OR DELETE ON payments
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_wallet_transactions_trigger
    AFTER INSERT OR UPDATE OR DELETE ON wallet_transactions
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
--```

---

--## 📱 **API Endpoints (Supabase Functions)**

--### **User Management Functions**

--```sql
-- Get user profile
CREATE OR REPLACE FUNCTION get_user_profile(user_uuid UUID)
RETURNS TABLE (
    id UUID,
    username TEXT,
    name TEXT,
    phone_number TEXT,
    address TEXT,
    area TEXT,
    role TEXT,
    wallet_balance DECIMAL,
    last_payment_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.name,
        u.phone_number,
        u.address,
        u.area,
        u.role::TEXT,
        u.wallet_balance,
        u.last_payment_date
    FROM users u
    WHERE u.id = user_uuid
    AND u.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
--```

--### **Payment Functions**

---```sql
-- Get user payments with filters
CREATE OR REPLACE FUNCTION get_user_payments(
    user_uuid UUID,
    status_filter TEXT DEFAULT NULL,
    year_filter INTEGER DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    amount DECIMAL,
    extra_charges DECIMAL,
    payment_method TEXT,
    status TEXT,
    receipt_number TEXT,
    year INTEGER,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.amount,
        p.extra_charges,
        p.payment_method::TEXT,
        p.status::TEXT,
        p.receipt_number,
        p.year,
        p.created_at
    FROM payments p
    WHERE p.user_id = user_uuid
    AND (status_filter IS NULL OR p.status::TEXT = status_filter)
    AND (year_filter IS NULL OR p.year = year_filter)
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
--

## 🚀 **Setup Instructions**

### **1. Create Database**

```bash
# Connect to your Supabase project
supabase init
supabase start
```

### **2. Run Schema**

```bash
# Apply the schema
supabase db reset
```

### **3. Insert Initial Data**

```sql
-- Insert default settings
INSERT INTO settings (id, yearly_fee, late_fees_percentage, wire_charge_per_meter)
VALUES ('app_settings', 1000.00, 10.00, 5.00);

-- Insert default areas
INSERT INTO areas (name, description) VALUES 
('Downtown', 'Central business district'),
('Uptown', 'Residential area'),
('Suburbs', 'Outer residential area');

-- Insert admin user (replace with your admin details)
INSERT INTO users (username, name, phone_number, address, area, role)
VALUES ('admin', 'Admin User', '9876543210', 'Admin Address', 'Downtown', 'ADMIN');
```

### **4. Configure Authentication**

```sql
-- Enable email confirmation
UPDATE auth.config SET enable_confirmations = true;

-- Set up custom claims for role-based access
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO users (id, username, name, phone_number, address, area, role)
    VALUES (
        NEW.id,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'name',
        NEW.raw_user_meta_data->>'phone_number',
        NEW.raw_user_meta_data->>'address',
        NEW.raw_user_meta_data->>'area',
        'USER'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user registration
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();
```

---

## 🔍 **Testing the Schema**

### **Test Queries**

```sql
-- Test user creation
INSERT INTO users (username, name, phone_number, address, area, role)
VALUES ('testuser', 'Test User', '9876543211', 'Test Address', 'Downtown', 'USER')
RETURNING *;

-- Test payment creation
INSERT INTO payments (user_id, amount, payment_method, receipt_number, year)
VALUES (
    (SELECT id FROM users WHERE username = 'testuser'),
    1000.00,
    'UPI',
    'RCP2024001',
    2024
) RETURNING *;

-- Test wallet transaction
INSERT INTO wallet_transactions (user_id, amount, type, description, balance_before, balance_after)
VALUES (
    (SELECT id FROM users WHERE username = 'testuser'),
    500.00,
    'CREDIT',
    'Wallet recharge',
    0.00,
    500.00
) RETURNING *;
```

---

## 📚 **Additional Resources**

- [Supabase Documentation](https://supabase.com/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)

---

**This schema provides a robust foundation for the TV Subscription App with proper security, performance optimization, and scalability considerations.**