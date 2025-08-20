import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/supabase_config.dart';

/// Base service class for Supabase operations
/// Provides common functionality for all Supabase-based services
abstract class SupabaseService {
  /// Get Supabase client
  SupabaseClient get supabase => SupabaseConfig.client;
  
  /// Get current Firebase user ID (used as foreign key in Supabase)
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;
  
  /// Check if user is authenticated
  bool get isAuthenticated => currentUserId != null;
  
  /// Get current user's phone number from Firebase
  String? get currentUserPhone => FirebaseAuth.instance.currentUser?.phoneNumber;
  
  /// Handle Supabase errors and convert to user-friendly messages
  String handleSupabaseError(dynamic error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case '23505': // Unique violation
          return 'This record already exists';
        case '23503': // Foreign key violation
          return 'Referenced record not found';
        case '42501': // Insufficient privilege
          return 'You do not have permission to perform this action';
        default:
          return error.message ?? 'Database error occurred';
      }
    }
    
    if (error is StorageException) {
      switch (error.statusCode) {
        case '404':
          return 'File not found';
        case '413':
          return 'File too large';
        case '415':
          return 'File type not supported';
        default:
          return error.message ?? 'Storage error occurred';
      }
    }
    
    return error.toString();
  }
  
  /// Execute a database operation with error handling
  Future<T> executeWithErrorHandling<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } catch (error) {
      final errorMessage = handleSupabaseError(error);
      throw Exception(errorMessage);
    }
  }
  
  /// Get user profile data from Supabase using Firebase UID
  Future<Map<String, dynamic>?> getUserProfile([String? userId]) async {
    final uid = userId ?? currentUserId;
    if (uid == null) return null;
    
    try {
      final response = await supabase
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('firebase_uid', uid)
          .maybeSingle();
      
      if (response == null) return null;
      
      return Map<String, dynamic>.from(response);
    } catch (error) {
      final errorMessage = handleSupabaseError(error);
      throw Exception(errorMessage);
    }
  }
  
  /// Create or update user profile in Supabase
  Future<void> upsertUserProfile(Map<String, dynamic> userData) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    await executeWithErrorHandling(() async {
      await supabase
          .from(SupabaseConfig.usersTable)
          .upsert({
            ...userData,
            'firebase_uid': currentUserId,
            'phone_number': currentUserPhone,
            'updated_at': DateTime.now().toIso8601String(),
          });
    });
  }
}