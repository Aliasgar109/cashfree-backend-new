import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jafary_channel_app/config/supabase_config.dart';

/// Hybrid authentication service that uses Firebase for auth and Supabase for database
class HybridAuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  late final SupabaseClient _supabaseClient;

  HybridAuthService() {
    _supabaseClient = SupabaseConfig.client;
  }

  /// Sign up with username and password using Firebase Auth + Supabase DB
  Future<firebase_auth.User?> signUpWithUsername({
    required String username,
    required String password,
    required String name,
    required String phoneNumber,
    required String address,
    required String area,
    String preferredLanguage = 'en',
  }) async {
    try {
      // 1. Create Firebase Auth user with unique email
      final uniqueEmail = '${username}@tvapp.local';
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: uniqueEmail,
        password: password,
      );
      
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Failed to create Firebase user account');
      }

      // 2. Get Firebase JWT token
      final firebaseJWT = await firebaseUser.getIdToken();
      if (firebaseJWT == null) {
        throw Exception('Failed to get JWT token');
      }
      
      // 3. Set Supabase session with Firebase JWT
      await _supabaseClient.auth.setSession(firebaseJWT);
      
      // 4. Create user profile in Supabase
      final userModel = {
        'id': firebaseUser.uid,
        'username': username,
        'name': name,
        'phone_number': phoneNumber,
        'address': address,
        'area': area,
        'role': 'USER',
        'preferred_language': preferredLanguage,
        'wallet_balance': 0.0,
        'is_active': true,
      };
      
      await _supabaseClient
          .from(SupabaseConfig.usersTable)
          .insert(userModel);
      
      return firebaseUser;
    } catch (e) {
      throw Exception('Failed to sign up: ${e.toString()}');
    }
  }

  /// Sign in with username and password
  Future<firebase_auth.User?> signInWithUsername(String username, String password) async {
    try {
      // 1. Sign in with Firebase using unique email
      final uniqueEmail = '${username}@tvapp.local';
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: uniqueEmail,
        password: password,
      );
      
      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Failed to sign in');
      }

      // 2. Get Firebase JWT token
      final firebaseJWT = await firebaseUser.getIdToken();
      if (firebaseJWT == null) {
        throw Exception('Failed to get JWT token');
      }
      
      // 3. Set Supabase session with Firebase JWT
      await _supabaseClient.auth.setSession(firebaseJWT);
      
      return firebaseUser;
    } catch (e) {
      throw Exception('Failed to sign in: ${e.toString()}');
    }
  }

  /// Sign out from both Firebase and Supabase
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _supabaseClient.auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  /// Check if username already exists in Supabase
  Future<bool> usernameExists(String username) async {
    try {
      final response = await _supabaseClient
          .from(SupabaseConfig.usersTable)
          .select('username')
          .eq('username', username)
          .limit(1);
      
      return response.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check username: ${e.toString()}');
    }
  }

  /// Get current Firebase user
  firebase_auth.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Get current Supabase user
  User? get currentSupabaseUser => _supabaseClient.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => _firebaseAuth.currentUser != null;

  /// Get user ID
  String? get userId => _firebaseAuth.currentUser?.uid;

  /// Stream of authentication state changes
  Stream<firebase_auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();
}
