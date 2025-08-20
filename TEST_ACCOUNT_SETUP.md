# Test Account Setup Guide

## Overview
This guide helps you set up and test the new username/password authentication system for the TV Subscription App.

## What We've Implemented

### ✅ New Authentication System
- **Username/Email + Password** authentication (replaces phone OTP)
- **Firebase Authentication** with email/password
- **User registration** with comprehensive form
- **Password reset** via email
- **Login with username OR email**

### ✅ Updated Files
1. **UserModel** - Added username and email fields
2. **AuthService** - New signup/login methods
3. **LoginScreen** - Username/email + password login
4. **UserRegistrationScreen** - Complete signup form
5. **ForgotPasswordScreen** - Password reset functionality
6. **InputValidator** - Added validation methods

## Testing the App

### Prerequisites
1. **Firebase Project** - Must be configured
2. **Firebase Authentication** - Email/Password enabled
3. **Firestore Database** - For user data storage

### Step 1: Firebase Setup
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create/select your project
3. Enable **Authentication** → **Sign-in method** → **Email/Password**
4. Enable **Firestore Database** in test mode

### Step 2: Test Account Creation
1. **Run the app** on your device/emulator
2. **Navigate to Sign Up** screen
3. **Create a test account** with:
   - Username: `testuser`
   - Email: `test@example.com`
   - Password: `password123`
   - Name: `Test User`
   - Phone: `9876543210`
   - Address: `123 Test Street, Test City`
   - Area: `Test Area`

### Step 3: Test Login
1. **Sign out** (if logged in)
2. **Navigate to Login** screen
3. **Test both login methods**:
   - **Username login**: `testuser` + `password123`
   - **Email login**: `test@example.com` + `password123`

### Step 4: Test Password Reset
1. **Go to Forgot Password** screen
2. **Enter email**: `test@example.com`
3. **Check email** for reset link (Firebase sends to console in test mode)

## Test Account Credentials

### Primary Test Account
- **Username**: `testuser`
- **Email**: `test@example.com`
- **Password**: `password123`

### Admin Test Account (if needed)
- **Username**: `admin`
- **Email**: `admin@tvapp.com`
- **Password**: `admin123`

### Collector Test Account (if needed)
- **Username**: `collector`
- **Email**: `collector@tvapp.com`
- **Password**: `collector123`

## Firebase Console Testing

### Authentication Testing
- Go to **Authentication** → **Users**
- You'll see test users created
- Can manually create users for testing

### Firestore Testing
- Go to **Firestore Database** → **Data**
- Check `users` collection
- Verify user data structure

## Common Issues & Solutions

### Issue: "Firebase not initialized"
**Solution**: Ensure `google-services.json` is in `android/app/`

### Issue: "Authentication failed"
**Solution**: Check Firebase Console → Authentication → Sign-in methods

### Issue: "Permission denied"
**Solution**: Check Firestore rules in Firebase Console

### Issue: "Username already exists"
**Solution**: Use different username or check Firestore for duplicates

## Development Notes

### Current Features
- ✅ User registration with validation
- ✅ Login with username/email
- ✅ Password reset via email
- ✅ Form validation and error handling
- ✅ Modern UI with Material Design 3

### Future Enhancements
- 🔄 Email verification
- 🔄 Password strength requirements
- 🔄 Social login (Google, Facebook)
- 🔄 Two-factor authentication
- 🔄 Account deletion

### Security Features
- ✅ Password hashing (Firebase handles)
- ✅ Input validation and sanitization
- ✅ Secure password reset flow
- ✅ Session management

## Testing Checklist

- [ ] App launches without errors
- [ ] Sign up form validates all fields
- [ ] User account created in Firebase
- [ ] Login works with username
- [ ] Login works with email
- [ ] Password reset sends email
- [ ] Form validation shows proper errors
- [ ] Navigation between screens works
- [ ] User data stored in Firestore
- [ ] App handles network errors gracefully

## Support

If you encounter issues:
1. Check Firebase Console for errors
2. Verify Firebase configuration
3. Check app logs for detailed error messages
4. Ensure all dependencies are properly installed

---

**Happy Testing! 🚀**
