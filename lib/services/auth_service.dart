import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'supabase_user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseUserService _userService = SupabaseUserService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  // Get auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with username and password
  Future<User?> signUpWithUsername({
    required String username,
    required String password,
    required String name,
    required String phoneNumber,
    required String address,
    required String area,
    String preferredLanguage = 'en',
  }) async {
    try {
      // Check if username already exists
      if (await usernameExists(username)) {
        throw Exception('Username already exists. Please choose a different username.');
      }

      // Check if phone number already exists
      if (await phoneNumberExists(phoneNumber)) {
        throw Exception('Phone number already registered. Please use a different phone number.');
      }

      // Create a unique email for Firebase Auth (Firebase requires email)
      final uniqueEmail = '${username}@tvapp.local';
      
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: uniqueEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create user account');
      }

      // Create user model and store in Supabase
      final userModel = UserModel(
        id: user.uid,
        username: username,
        name: name,
        phoneNumber: phoneNumber,
        address: address,
        area: area,
        role: UserRole.USER,
        preferredLanguage: preferredLanguage,
        createdAt: DateTime.now(),
      );

      await _userService.createUser(userModel);

      return user;
    } catch (e) {
      throw Exception('Failed to sign up: ${e.toString()}');
    }
  }

  // Sign in with username and password
  Future<User?> signInWithUsername(String username, String password) async {
    try {
      // Find user by username in Supabase
      final userData = await _userService.getUserByUsername(username);

      if (userData == null) {
        throw Exception('Username not found');
      }
      
      // Create the unique email used during signup
      final email = '${username}@tvapp.local';
      
      // Sign in with Firebase Auth using the unique email
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential.user;
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  // Check if username exists
  Future<bool> usernameExists(String username) async {
    try {
      final userData = await _userService.getUserByUsername(username);
      return userData != null;
    } catch (e) {
      return false;
    }
  }

  // Check if phone number exists
  Future<bool> phoneNumberExists(String phoneNumber) async {
    try {
      final userData = await _userService.getUserByPhone(phoneNumber);
      return userData != null;
    } catch (e) {
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user data from Supabase
  Future<UserModel?> getUserData(String userId) async {
    try {
      return await _userService.getUserById(userId);
    } catch (e) {
      return null;
    }
  }

  // Get ID token
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      return null;
    }
  }

  // Refresh token
  Future<void> refreshToken() async {
    try {
      await _auth.currentUser?.getIdToken(true);
    } catch (e) {
      // Handle token refresh error
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Delete user data from Supabase
        await _userService.deleteUser(user.uid);
        // Delete Firebase Auth user
        await user.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete account: ${e.toString()}');
    }
  }

  // DEPRECATED: Old OTP-based methods (kept for backward compatibility)
  @deprecated
  Future<bool> sendOTP(String phoneNumber) async {
    throw UnsupportedError('OTP authentication is no longer supported. Use username/password authentication.');
  }

  @deprecated
  Future<User?> verifyOTP(String otp) async {
    throw UnsupportedError('OTP authentication is no longer supported. Use username/password authentication.');
  }

  @deprecated
  Future<User?> signInWithPassword(String phoneNumber, String password) async {
    throw UnsupportedError('Phone-based authentication is no longer supported. Use username/password authentication.');
  }

  @deprecated
  Future<void> setupPasswordAuth(String password) async {
    throw UnsupportedError('Phone-based authentication is no longer supported. Use username/password authentication.');
  }

  @deprecated
  Future<bool> userExists(String phoneNumber) async {
    throw UnsupportedError('Phone-based user lookup is no longer supported. Use username-based lookup.');
  }

  @deprecated
  Future<User?> signInWithEmail(String email, String password) async {
    throw UnsupportedError('Email-based authentication is no longer supported. Use username/password authentication.');
  }

  @deprecated
  Future<bool> emailExists(String email) async {
    throw UnsupportedError('Email-based user lookup is no longer supported. Use username-based lookup.');
  }

  @deprecated
  Future<bool> resetPassword(String email) async {
    throw UnsupportedError('Email-based password reset is no longer supported. Contact support for password reset.');
  }
}
