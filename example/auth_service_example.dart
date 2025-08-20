import 'package:firebase_core/firebase_core.dart';
import 'package:jafary_channel_app/services/auth_service.dart';

/// Example usage of AuthService
/// This demonstrates how to use the new username-only authentication service
void main() async {
  // Initialize Firebase (required before using AuthService)
  await Firebase.initializeApp();
  
  final authService = AuthService();
  
  // Example 1: User Registration Flow
  await userRegistrationExample(authService);
  
  // Example 2: Username Authentication
  await authenticationExample(authService);
  
  // Example 3: User Management
  await userManagementExample(authService);
  
  // Example 4: Password Reset
  await passwordResetExample(authService);
}

/// Example of user registration
Future<void> userRegistrationExample(AuthService authService) async {
  try {
    print('=== User Registration Example ===');
    
    // Example user data
    const username = 'testuser';
    const password = 'securePassword123';
    const name = 'Test User';
    const phoneNumber = '9876543210';
    const address = '123 Test Street, Test City';
    const area = 'Test Area';
    
    // Check if username already exists
    print('Checking if username "$username" is available...');
    final usernameExists = await authService.usernameExists(username);
    if (usernameExists) {
      print('Username "$username" is already taken');
      return;
    }
    print('Username "$username" is available');
    
    // Register new user
    print('Creating new user account...');
    final user = await authService.signUpWithUsername(
      username: username,
      password: password,
      name: name,
      phoneNumber: phoneNumber,
      address: address,
      area: area,
      preferredLanguage: 'en',
    );
    
    if (user != null) {
      print('✅ User registration successful!');
      print('User ID: ${user.uid}');
      print('Username: $username');
    }
    
  } catch (e) {
    print('❌ User Registration failed: $e');
  }
}

/// Example of username authentication
Future<void> authenticationExample(AuthService authService) async {
  try {
    print('\n=== Authentication Example ===');
    
    const username = 'testuser';
    const password = 'securePassword123';
    
    // Sign in with username
    print('Signing in with username "$username"...');
    final user = await authService.signInWithUsername(username, password);
    
    if (user != null) {
      print('✅ Username authentication successful!');
      print('User ID: ${user.uid}');
    }
    
  } catch (e) {
    print('❌ Authentication failed: $e');
  }
}

/// Example of user management operations
Future<void> userManagementExample(AuthService authService) async {
  try {
    print('\n=== User Management Example ===');
    
    // Get current user
    final currentUser = authService.currentUser;
    if (currentUser != null) {
      print('Current user: ${currentUser.uid}');
      
      // Get user data from Firestore
      final userData = await authService.getUserData(currentUser.uid);
      if (userData != null) {
        print('User data: ${userData.name} (${userData.phoneNumber})');
        print('Username: ${userData.username}');
        print('Role: ${userData.role}');
        print('Wallet Balance: ₹${userData.walletBalance}');
      }
      
      // Get ID token
      final token = await authService.getIdToken();
      if (token != null) {
        print('ID Token obtained (length: ${token.length})');
      }
      
      // Refresh token
      await authService.refreshToken();
      print('Token refreshed successfully');
    }
    
    // Check authentication state
    print('Is authenticated: ${authService.isAuthenticated}');
    
    // Listen to auth state changes
    authService.authStateChanges.listen((user) {
      if (user != null) {
        print('User signed in: ${user.uid}');
      } else {
        print('User signed out');
      }
    });
    
  } catch (e) {
    print('❌ User Management failed: $e');
  }
}

/// Example of password reset
Future<void> passwordResetExample(AuthService authService) async {
  try {
    print('\n=== Password Reset Example ===');
    
    const username = 'testuser';
    
    print('Requesting password reset for username "$username"...');
    print('Note: Since we use username-only authentication, password reset requires contacting support.');
    print('This is a limitation of Firebase Auth which requires email for password reset.');
    
  } catch (e) {
    print('❌ Password reset failed: $e');
  }
}

/// Example of error handling
Future<void> errorHandlingExample(AuthService authService) async {
  print('\n=== Error Handling Examples ===');
  
  // Try to sign in with non-existent username
  try {
    await authService.signInWithUsername('nonexistent', 'password');
  } catch (e) {
    print('Expected error for non-existent username: $e');
  }
  
  // Try to sign in with wrong password
  try {
    await authService.signInWithUsername('testuser', 'wrongpassword');
  } catch (e) {
    print('Expected error for wrong password: $e');
  }
  
  // Try to register with existing username
  try {
    await authService.signUpWithUsername(
      username: 'testuser', // This username already exists
      password: 'password123',
      name: 'Test User',
      phoneNumber: '9876543210',
      address: '123 Test Street',
      area: 'Test Area',
    );
  } catch (e) {
    print('Expected error for existing username: $e');
  }
}

/// Example of checking user availability
Future<void> userAvailabilityExample(AuthService authService) async {
  print('\n=== User Availability Check Example ===');
  
  final testUsernames = ['testuser', 'newuser', 'admin', 'collector'];
  
  print('Checking username availability:');
  for (final username in testUsernames) {
    final exists = await authService.usernameExists(username);
    print('  "$username": ${exists ? "❌ Taken" : "✅ Available"}');
  }
}