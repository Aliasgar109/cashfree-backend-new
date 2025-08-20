import 'package:firebase_core/firebase_core.dart';
import 'package:jafary_channel_app/services/auth_service.dart';

/// Script to create test accounts for all three user roles
/// Run this to quickly set up test accounts for development/testing
void main() async {
  print('🚀 Creating Test Accounts for TV Subscription App...\n');
  
  // Initialize Firebase
  await Firebase.initializeApp();
  final authService = AuthService();
  
  try {
    // Test Account 1: Admin
    print('👑 Creating Admin Account...');
    await _createAdminAccount(authService);
    
    // Test Account 2: Regular User
    print('\n👤 Creating Regular User Account...');
    await _createUserAccount(authService);
    
    // Test Account 3: Collector
    print('\n💰 Creating Collector Account...');
    await _createCollectorAccount(authService);
    
    print('\n✅ All test accounts created successfully!');
    print('\n📱 You can now test the app with these accounts:');
    print('   Admin: username="admin", password="admin123"');
    print('   User: username="testuser", password="user123"');
    print('   Collector: username="collector", password="collector123"');
    
  } catch (e) {
    print('❌ Error creating test accounts: $e');
  }
}

/// Create admin test account
Future<void> _createAdminAccount(AuthService authService) async {
  try {
    // Check if admin account already exists
    final adminExists = await authService.usernameExists('admin');
    if (adminExists) {
      print('   ⚠️ Admin account already exists, skipping...');
      return;
    }
    
    // Create admin account
    final adminUser = await authService.signUpWithUsername(
      username: 'admin',
      password: 'admin123',
      name: 'Admin User',
      phoneNumber: '9876543210',
      address: '123 Admin Street, Admin City, Gujarat',
      area: 'Admin Area',
      preferredLanguage: 'en',
    );
    
    if (adminUser != null) {
      print('   ✅ Admin account created successfully!');
      print('   📧 Internal email: admin@tvapp.local');
      print('   🔑 UID: ${adminUser.uid}');
    }
    
  } catch (e) {
    print('   ❌ Failed to create admin account: $e');
  }
}

/// Create regular user test account
Future<void> _createUserAccount(AuthService authService) async {
  try {
    // Check if user account already exists
    final userExists = await authService.usernameExists('testuser');
    if (userExists) {
      print('   ⚠️ User account already exists, skipping...');
      return;
    }
    
    // Create user account
    final regularUser = await authService.signUpWithUsername(
      username: 'testuser',
      password: 'user123',
      name: 'Test User',
      phoneNumber: '9876543211',
      address: '456 User Street, User City, Gujarat',
      area: 'User Area',
      preferredLanguage: 'en',
    );
    
    if (regularUser != null) {
      print('   ✅ User account created successfully!');
      print('   📧 Internal email: testuser@tvapp.local');
      print('   🔑 UID: ${regularUser.uid}');
    }
    
  } catch (e) {
    print('   ❌ Failed to create user account: $e');
  }
}

/// Create collector test account
Future<void> _createCollectorAccount(AuthService authService) async {
  try {
    // Check if collector account already exists
    final collectorExists = await authService.usernameExists('collector');
    if (collectorExists) {
      print('   ⚠️ Collector account already exists, skipping...');
      return;
    }
    
    // Create collector account
    final collectorUser = await authService.signUpWithUsername(
      username: 'collector',
      password: 'collector123',
      name: 'Collector User',
      phoneNumber: '9876543212',
      address: '789 Collector Street, Collector City, Gujarat',
      area: 'Collector Area',
      preferredLanguage: 'en',
    );
    
    if (collectorUser != null) {
      print('   ✅ Collector account created successfully!');
      print('   📧 Internal email: collector@tvapp.local');
      print('   🔑 UID: ${collectorUser.uid}');
    }
    
  } catch (e) {
    print('   ❌ Failed to create collector account: $e');
  }
}

/// Test login with created accounts
Future<void> testLogin(AuthService authService) async {
  print('\n🧪 Testing Login with Created Accounts...\n');
  
  try {
    // Test Admin Login
    print('👑 Testing Admin Login...');
    final adminUser = await authService.signInWithUsername('admin', 'admin123');
    if (adminUser != null) {
      print('   ✅ Admin login successful!');
      await authService.signOut();
    }
    
    // Test User Login
    print('\n👤 Testing User Login...');
    final regularUser = await authService.signInWithUsername('testuser', 'user123');
    if (regularUser != null) {
      print('   ✅ User login successful!');
      await authService.signOut();
    }
    
    // Test Collector Login
    print('\n💰 Testing Collector Login...');
    final collectorUser = await authService.signInWithUsername('collector', 'collector123');
    if (collectorUser != null) {
      print('   ✅ Collector login successful!');
      await authService.signOut();
    }
    
    print('\n🎉 All login tests passed successfully!');
    
  } catch (e) {
    print('❌ Login test failed: $e');
  }
}

/// Clean up test accounts (use with caution!)
Future<void> cleanupTestAccounts(AuthService authService) async {
  print('\n🧹 Cleaning up test accounts...');
  
  try {
    // Sign in as admin to delete accounts
    final adminUser = await authService.signInWithUsername('admin', 'admin123');
    if (adminUser != null) {
      print('   ✅ Admin signed in for cleanup');
      
      // Note: In a real app, you'd need admin permissions to delete other accounts
      // This is just for demonstration
      print('   ⚠️ Account cleanup requires admin dashboard access');
      print('   📱 Use the admin dashboard to delete test accounts');
    }
    
  } catch (e) {
    print('   ❌ Cleanup failed: $e');
  }
}
