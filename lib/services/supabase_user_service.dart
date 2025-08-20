import '../models/user_model.dart';
import '../config/supabase_config.dart';
import 'supabase_service.dart';

/// User service using Supabase for data operations
/// Firebase Auth is still used for authentication
class SupabaseUserService extends SupabaseService {
  
  /// Create a new user profile in Supabase
  /// Uses Firebase UID as the primary identifier
  Future<void> createUser(UserModel user) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for user creation
      final adminClient = SupabaseConfig.adminClient;
      await adminClient.from(SupabaseConfig.usersTable).insert({
        'firebase_uid': currentUserId,
        'username': user.username,
        'phone_number': user.phoneNumber,
        'name': user.name,
        'address': user.address,
        'area': user.area,
        'role': user.role.toString().split('.').last,
        'preferred_language': user.preferredLanguage,
        'is_active': user.isActive,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    });
  }
  
  /// Get user by Firebase UID
  Future<UserModel?> getUserById(String firebaseUid) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for user lookup
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('firebase_uid', firebaseUid)
          .maybeSingle();
      
      if (response == null) return null;
      
      return UserModel.fromSupabase(response);
    });
  }
  
  /// Get user by phone number
  Future<UserModel?> getUserByPhone(String phoneNumber) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for user lookup
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('phone_number', phoneNumber)
          .maybeSingle();
      
      if (response == null) return null;
      
      return UserModel.fromSupabase(response);
    });
  }

  /// Get user by username
  Future<UserModel?> getUserByUsername(String username) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for user lookup
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('username', username)
          .maybeSingle();
      
      if (response == null) return null;
      
      return UserModel.fromSupabase(response);
    });
  }
  
  /// Update user profile
  Future<void> updateUser(UserModel user) async {
    if (!isAuthenticated) throw Exception('User not authenticated');
    
    await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for user updates
      final adminClient = SupabaseConfig.adminClient;
      await adminClient
          .from(SupabaseConfig.usersTable)
          .update({
            'name': user.name,
            'role': user.role.toString().split('.').last,
            'is_active': user.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('firebase_uid', currentUserId!);
    });
  }
  
  /// Delete user (soft delete by setting is_active to false)
  Future<void> deleteUser(String firebaseUid) async {
    await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for user deletion
      final adminClient = SupabaseConfig.adminClient;
      await adminClient
          .from(SupabaseConfig.usersTable)
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('firebase_uid', firebaseUid);
    });
  }
  
  /// Get all users (admin only)
  Future<List<UserModel>> getAllUsers() async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for admin operations
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);
      
      return response
          .map<UserModel>((data) => UserModel.fromSupabase(data))
          .toList();
    }) ?? [];
  }

  /// Get user by phone number (alias for getUserByPhone)
  Future<UserModel?> getUserByPhoneNumber(String phoneNumber) async {
    return await getUserByPhone(phoneNumber);
  }

  /// Search users by name
  Future<List<UserModel>> searchUsersByName(String query) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for user search
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from(SupabaseConfig.usersTable)
          .select()
          .ilike('name', '%$query%')
          .eq('is_active', true)
          .order('name', ascending: true);
      
      return response
          .map<UserModel>((data) => UserModel.fromSupabase(data))
          .toList();
    }) ?? [];
  }

  /// Get all areas
  Future<List<String>> getAllAreas() async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for area lookup
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from(SupabaseConfig.usersTable)
          .select('area')
          .not('area', 'is', null)
          .eq('is_active', true);
      
      final areas = response
          .map<String>((data) => data['area'] as String)
          .where((area) => area.isNotEmpty)
          .toSet()
          .toList();
      
      areas.sort();
      return areas;
    }) ?? [];
  }

  /// Update user model (alias for updateUser)
  Future<void> updateUserModel(UserModel user) async {
    return await updateUser(user);
  }
  
  /// Get users by role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for role-based user lookup
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('role', role.toString().split('.').last)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      
      return response
          .map<UserModel>((data) => UserModel.fromSupabase(data))
          .toList();
    }) ?? [];
  }
  
  /// Check if user exists by Firebase UID
  Future<bool> userExists(String firebaseUid) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for user existence check
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from(SupabaseConfig.usersTable)
          .select('firebase_uid')
          .eq('firebase_uid', firebaseUid)
          .maybeSingle();
      
      return response != null;
    }) ?? false;
  }
  
  /// Get current user profile
  Future<UserModel?> getCurrentUser() async {
    if (!isAuthenticated) return null;
    return await getUserById(currentUserId!);
  }
  
  /// Update user's last login timestamp
  Future<void> updateLastLogin() async {
    if (!isAuthenticated) return;
    
    await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for login timestamp update
      final adminClient = SupabaseConfig.adminClient;
      await adminClient
          .from(SupabaseConfig.usersTable)
          .update({
            'last_login_at': DateTime.now().toIso8601String(),
          })
          .eq('firebase_uid', currentUserId!);
    });
  }
}