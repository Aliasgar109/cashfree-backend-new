# 🧪 Test Accounts for TV Subscription App

This file contains test accounts for all three user roles in the TV Subscription App. Use these accounts to test the username-only authentication system.

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

## 🚀 **How to Use These Test Accounts**

### **1. Create Accounts (First Time Setup)**
```dart
// Use the registration screen to create these accounts
// Or run the auth_service_example.dart to create them programmatically
```

### **2. Sign In**
```dart
// Use the login screen with username + password
// Example: username: "admin", password: "admin123"
```

### **3. Test Different Roles**
- **Admin:** Access admin dashboard, manage users, approve payments
- **User:** Access user dashboard, make payments, view history
- **Collector:** Access collector dashboard, enter cash payments

---

## 📱 **Quick Test Flow**

### **Step 1: Create Accounts**
1. Open the app
2. Go to "Sign Up"
3. Create each account using the credentials above
4. Verify accounts are created successfully

### **Step 2: Test Login**
1. Go to "Sign In"
2. Try logging in with each account
3. Verify correct dashboard loads for each role

### **Step 3: Test Role-Based Access**
1. **Admin Account:**
   - Should see admin dashboard
   - Access to user management
   - Payment approval features
   
2. **User Account:**
   - Should see user dashboard
   - Payment options
   - Settings access
   
3. **Collector Account:**
   - Should see collector dashboard
   - Cash entry options
   - Collection reports

---

## 🔧 **Technical Details**

### **Firebase Internal Emails**
These accounts use Firebase Auth internally with generated emails:
- **Admin:** `admin@tvapp.local`
- **User:** `testuser@tvapp.local`
- **Collector:** `collector@tvapp.local`

### **Database Structure**
Each account creates a document in the `users` collection with:
- `id`: Firebase Auth UID
- `username`: The username used for login
- `role`: UserRole enum (ADMIN, USER, COLLECTOR)
- `isActive`: true
- `createdAt`: Timestamp

---

## ⚠️ **Important Notes**

1. **These are test accounts** - Don't use in production
2. **Passwords are simple** - Only for testing purposes
3. **Phone numbers are fake** - Don't try to call them
4. **Delete after testing** - Clean up test data when done

---

## 🧹 **Cleanup After Testing**

When you're done testing, you can delete these accounts:

```dart
// In admin dashboard or programmatically
await authService.deleteAccount(); // For each account
```

---

## 📞 **Support**

If you encounter any issues with these test accounts:
1. Check Firebase console for authentication errors
2. Verify Firestore rules allow read/write
3. Ensure all required fields are populated
4. Check app logs for detailed error messages

---

**Happy Testing! 🎉**
