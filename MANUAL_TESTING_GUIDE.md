# 🧪 Manual Testing Guide for TV Subscription App

Since the automatic account creation script can't run due to Flutter environment constraints, here's how to manually test the username-only authentication system.

## 🔐 **Test Account Credentials**

### 👑 **Admin Account**
- **Username:** `admin`
- **Password:** `admin123`
- **Role:** Admin
- **Name:** Admin User
- **Phone:** 9876543210
- **Address:** 123 Admin Street, Admin City, Gujarat
- **Area:** Admin Area
- **Language:** English

### 👤 **Regular User Account**
- **Username:** `testuser`
- **Password:** `user123`
- **Role:** User
- **Name:** Test User
- **Phone:** 9876543211
- **Address:** 456 User Street, User City, Gujarat
- **Area:** User Area
- **Language:** English

### 💰 **Collector Account**
- **Username:** `collector`
- **Password:** `collector123`
- **Role:** Collector
- **Name:** Collector User
- **Phone:** 9876543212
- **Address:** 789 Collector Street, Collector City, Gujarat
- **Area:** Collector Area
- **Language:** English

---

## 📱 **Step-by-Step Testing Process**

### **Phase 1: Account Creation**

#### **1.1 Create Admin Account**
1. Open the app
2. Navigate to "Sign Up" screen
3. Fill in the form with admin details:
   - Username: `admin`
   - Password: `admin123`
   - Confirm Password: `admin123`
   - Name: `Admin User`
   - Phone: `9876543210`
   - Address: `123 Admin Street, Admin City, Gujarat`
   - Area: `Admin Area`
   - Language: `English`
4. Tap "Create Account"
5. Verify success message appears
6. You should be redirected to login screen

#### **1.2 Create User Account**
1. Go back to "Sign Up" screen
2. Fill in the form with user details:
   - Username: `testuser`
   - Password: `user123`
   - Confirm Password: `user123`
   - Name: `Test User`
   - Phone: `9876543211`
   - Address: `456 User Street, User City, Gujarat`
   - Area: `User Area`
   - Language: `English`
3. Tap "Create Account"
4. Verify success message appears
5. You should be redirected to login screen

#### **1.3 Create Collector Account**
1. Go back to "Sign Up" screen
2. Fill in the form with collector details:
   - Username: `collector`
   - Password: `collector123`
   - Confirm Password: `collector123`
   - Name: `Collector User`
   - Phone: `9876543212`
   - Address: `789 Collector Street, Collector City, Gujarat`
   - Area: `Collector Area`
   - Language: `English`
3. Tap "Create Account"
4. Verify success message appears
5. You should be redirected to login screen

---

### **Phase 2: Account Testing**

#### **2.1 Test Admin Login**
1. Go to "Sign In" screen
2. Enter credentials:
   - Username: `admin`
   - Password: `admin123`
3. Tap "Sign In"
4. **Expected Result:** Should navigate to admin dashboard
5. Verify admin features are accessible:
   - User management
   - Payment approval
   - Reports
   - Settings

#### **2.2 Test User Login**
1. Sign out from admin account
2. Go to "Sign In" screen
3. Enter credentials:
   - Username: `testuser`
   - Password: `user123`
4. Tap "Sign In"
5. **Expected Result:** Should navigate to user dashboard
6. Verify user features are accessible:
   - Payment options
   - Payment history
   - Settings
   - Wallet balance

#### **2.3 Test Collector Login**
1. Sign out from user account
2. Go to "Sign In" screen
3. Enter credentials:
   - Username: `collector`
   - Password: `collector123`
4. Tap "Sign In"
5. **Expected Result:** Should navigate to collector dashboard
6. Verify collector features are accessible:
   - Cash entry
   - Collection reports
   - Area management

---

### **Phase 3: Feature Testing**

#### **3.1 Test Username Validation**
1. Try to create account with invalid username:
   - Too short: `ab` (should fail)
   - Too long: `verylongusername123456789` (should fail)
   - Special characters: `user@123` (should fail)
   - Valid: `validuser` (should pass)

#### **3.2 Test Password Validation**
1. Try to create account with invalid password:
   - Too short: `123` (should fail)
   - Valid: `password123` (should pass)

#### **3.3 Test Phone Validation**
1. Try to create account with invalid phone:
   - Too short: `123` (should fail)
   - Too long: `123456789012` (should fail)
   - Letters: `abc123def` (should fail)
   - Valid: `9876543210` (should pass)

#### **3.4 Test Duplicate Username**
1. Try to create another account with username `admin`
2. **Expected Result:** Should show error "Username already exists"

---

### **Phase 4: Error Handling Testing**

#### **4.1 Test Wrong Password**
1. Try to login with correct username but wrong password
2. **Expected Result:** Should show error message

#### **4.2 Test Non-existent Username**
1. Try to login with username that doesn't exist
2. **Expected Result:** Should show error message

#### **4.3 Test Forgot Password**
1. Go to "Forgot Password" screen
2. Enter username: `admin`
3. Tap "Reset Password"
4. **Expected Result:** Should show message about contacting support

---

## ✅ **Success Criteria**

### **Account Creation**
- [ ] All three accounts can be created successfully
- [ ] Success messages appear after creation
- [ ] Redirects to login screen after creation
- [ ] No email field is present in registration

### **Login Functionality**
- [ ] All three accounts can login successfully
- [ ] Correct dashboards load for each role
- [ ] Role-based access control works
- [ ] Username-only authentication works

### **Validation**
- [ ] Username validation works (length, characters)
- [ ] Password validation works (minimum length)
- [ ] Phone validation works (10 digits)
- [ ] Duplicate username prevention works

### **Error Handling**
- [ ] Wrong password shows appropriate error
- [ ] Non-existent username shows appropriate error
- [ ] Forgot password shows appropriate message

---

## 🐛 **Common Issues & Solutions**

### **Issue: "Username already exists"**
- **Cause:** Trying to create account with existing username
- **Solution:** Use different username or delete existing account first

### **Issue: "Invalid username format"**
- **Cause:** Username contains invalid characters
- **Solution:** Use only letters, numbers, underscores, and hyphens

### **Issue: "Password too short"**
- **Cause:** Password less than 6 characters
- **Solution:** Use password with at least 6 characters

### **Issue: "Invalid phone number"**
- **Cause:** Phone number not exactly 10 digits
- **Solution:** Use exactly 10 digits (e.g., 9876543210)

---

## 📊 **Testing Checklist**

- [ ] **Admin Account Creation** ✅
- [ ] **User Account Creation** ✅
- [ ] **Collector Account Creation** ✅
- [ ] **Admin Login** ✅
- [ ] **User Login** ✅
- [ ] **Collector Login** ✅
- [ ] **Username Validation** ✅
- [ ] **Password Validation** ✅
- [ ] **Phone Validation** ✅
- [ ] **Duplicate Username Prevention** ✅
- [ ] **Wrong Password Error** ✅
- [ ] **Non-existent Username Error** ✅
- [ ] **Forgot Password Flow** ✅
- [ ] **Role-based Access Control** ✅

---

## 🎯 **Testing Tips**

1. **Test one account at a time** - Don't create all accounts simultaneously
2. **Verify each step** - Check success/error messages at each stage
3. **Test edge cases** - Try invalid inputs to test validation
4. **Check navigation** - Ensure correct dashboards load for each role
5. **Test logout** - Verify you can sign out and sign back in

---

## 🚨 **Important Notes**

- **These are test accounts** - Don't use in production
- **Simple passwords** - Only for testing purposes
- **Fake phone numbers** - Don't try to call them
- **Clean up after testing** - Delete test accounts when done

---

**Happy Testing! 🎉**

If you encounter any issues, check the app logs and verify that Firebase is properly configured.
