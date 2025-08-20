# 🚨 Quick Fix for Function Parameter Error

## ❌ **Errors You Encountered:**

### **Error 1:**
```
ERROR: 42P13: cannot change name of input parameter "year_param"
HINT: Use DROP FUNCTION generate_receipt_number(integer) first.
```

### **Error 2:**
```
ERROR: 42P13: parameter name "days_past_due" used more than once
CONTEXT: compilation of PL/pgSQL function "generate_overdue_payments_report" near line 1
```

## ✅ **Solutions Applied:**

I've updated the `supabase_schema_updates.sql` file to handle these issues by:

1. **Adding function cleanup** - Drops all existing functions before creating new ones
2. **Handling parameter conflicts** - Specifically handles the `generate_receipt_number` function
3. **Fixing parameter name conflicts** - Renamed `days_past_due` parameter to `min_days_past_due` to avoid conflicts with return table column
4. **Adding trigger cleanup** - Drops existing triggers to prevent conflicts

## 🔧 **What Was Fixed:**

### **Before (Causing Error):**
```sql
CREATE OR REPLACE FUNCTION generate_receipt_number(receipt_year INTEGER) ...
```

### **After (Fixed):**

**For Error 1:**
```sql
-- Drop existing function if it exists with different parameters
DROP FUNCTION IF EXISTS generate_receipt_number(INTEGER);
DROP FUNCTION IF EXISTS generate_receipt_number(integer);

CREATE OR REPLACE FUNCTION generate_receipt_number(receipt_year INTEGER) ...
```

**For Error 2:**
```sql
-- Fixed parameter name conflict
CREATE OR REPLACE FUNCTION generate_overdue_payments_report(
    area_filter VARCHAR(50) DEFAULT NULL,
    min_days_past_due INTEGER DEFAULT NULL  -- Changed from days_past_due
) RETURNS TABLE(
    -- ... other columns ...
    days_past_due INTEGER  -- This stays the same in return table
) AS $$
```

## 🚀 **Next Steps:**

1. **Use the updated schema file** - The `supabase_schema_updates.sql` is now fixed
2. **Run the SQL again** - It should work without errors now
3. **If you still get errors** - Run this command first in Supabase SQL Editor:

```sql
-- Manual cleanup if needed
DROP FUNCTION IF EXISTS generate_receipt_number(INTEGER);
DROP FUNCTION IF EXISTS generate_receipt_number(integer);
DROP FUNCTION IF EXISTS generate_receipt_number(INT);
```

## 🎯 **Why These Happened:**

**Error 1:**
- You had an existing function with the same name but different parameter names
- PostgreSQL doesn't allow changing parameter names in `CREATE OR REPLACE`
- The solution is to drop the old function first, then create the new one

**Error 2:**
- The parameter name `days_past_due` was used both as a function parameter and as a column name in the return table
- PostgreSQL doesn't allow the same name to be used for both parameter and return column
- The solution is to rename the parameter to avoid the conflict

## ✅ **The Updated Schema File Now:**

- ✅ **Handles all function conflicts** automatically
- ✅ **Drops existing functions** before creating new ones
- ✅ **Includes trigger cleanup** to prevent trigger conflicts
- ✅ **Uses safe DROP IF EXISTS** statements

**🎉 Your schema update should now work perfectly!**
