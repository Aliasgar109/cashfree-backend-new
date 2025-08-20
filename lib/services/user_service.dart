import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore;
  final String _collection = 'users';

  UserService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // CRUD Operations

  /// Create a new user in Firestore
  Future<String> createUser(UserModel user) async {
    try {
      final docRef = await _firestore.collection(_collection).add(user.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  /// Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  /// Get user by phone number
  Future<UserModel?> getUserByPhoneNumber(String phoneNumber) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return UserModel.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user by phone: $e');
    }
  }

  /// Update user information
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection(_collection).doc(userId).update(updates);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  /// Update user model
  Future<void> updateUserModel(UserModel user) async {
    try {
      await _firestore.collection(_collection).doc(user.id).update(user.toFirestore());
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  /// Delete user (soft delete by setting isActive to false)
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  /// Permanently delete user (hard delete)
  Future<void> permanentlyDeleteUser(String userId) async {
    try {
      await _firestore.collection(_collection).doc(userId).delete();
    } catch (e) {
      throw Exception('Failed to permanently delete user: $e');
    }
  }

  // Search and Filtering Operations

  /// Get all users with optional filtering
  Future<List<UserModel>> getAllUsers({
    String? area,
    UserRole? role,
    bool? isActive,
    int? limit,
  }) async {
    try {
      Query query = _firestore.collection(_collection);

      if (area != null) {
        query = query.where('area', isEqualTo: area);
      }
      
      if (role != null) {
        query = query.where('role', isEqualTo: role.toString().split('.').last);
      }
      
      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  /// Search users by name (case-insensitive partial match)
  Future<List<UserModel>> searchUsersByName(String searchTerm) async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      
      final users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .where((user) => user.name.toLowerCase().contains(searchTerm.toLowerCase()))
          .toList();
      
      return users;
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  /// Get users by area
  Future<List<UserModel>> getUsersByArea(String area) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('area', isEqualTo: area)
          .where('isActive', isEqualTo: true)
          .get();
      
      return query.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get users by area: $e');
    }
  }

  /// Get users by role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    try {
      final query = await _firestore
          .collection(_collection)
          .where('role', isEqualTo: role.toString().split('.').last)
          .where('isActive', isEqualTo: true)
          .get();
      
      return query.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get users by role: $e');
    }
  }

  /// Get all unique areas
  Future<List<String>> getAllAreas() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      final areas = querySnapshot.docs
          .map((doc) => doc.data()['area'] as String?)
          .where((area) => area != null)
          .cast<String>()
          .toSet()
          .toList();
      
      areas.sort();
      return areas;
    } catch (e) {
      throw Exception('Failed to get areas: $e');
    }
  }

  // Role-based Permission Checking

  /// Check if user has permission to perform admin operations
  Future<bool> hasAdminPermission(String userId) async {
    try {
      final user = await getUserById(userId);
      return user?.role == UserRole.ADMIN;
    } catch (e) {
      return false;
    }
  }

  /// Check if user has permission to perform collector operations
  Future<bool> hasCollectorPermission(String userId) async {
    try {
      final user = await getUserById(userId);
      return user?.role == UserRole.COLLECTOR || user?.role == UserRole.ADMIN;
    } catch (e) {
      return false;
    }
  }

  /// Check if user can manage other users
  Future<bool> canManageUsers(String userId) async {
    try {
      final user = await getUserById(userId);
      return user?.role == UserRole.ADMIN;
    } catch (e) {
      return false;
    }
  }

  /// Check if user can view user data
  Future<bool> canViewUser(String requestingUserId, String targetUserId) async {
    try {
      // Users can always view their own data
      if (requestingUserId == targetUserId) {
        return true;
      }

      // Check if requesting user has admin or collector permissions
      final requestingUser = await getUserById(requestingUserId);
      return requestingUser?.role == UserRole.ADMIN || 
             requestingUser?.role == UserRole.COLLECTOR;
    } catch (e) {
      return false;
    }
  }

  /// Check if user can edit user data
  Future<bool> canEditUser(String requestingUserId, String targetUserId) async {
    try {
      // Users can edit their own basic data (not role)
      if (requestingUserId == targetUserId) {
        return true;
      }

      // Only admins can edit other users
      final requestingUser = await getUserById(requestingUserId);
      return requestingUser?.role == UserRole.ADMIN;
    } catch (e) {
      return false;
    }
  }

  /// Check if user can delete users
  Future<bool> canDeleteUser(String requestingUserId) async {
    try {
      final requestingUser = await getUserById(requestingUserId);
      return requestingUser?.role == UserRole.ADMIN;
    } catch (e) {
      return false;
    }
  }

  /// Check if user can change roles
  Future<bool> canChangeUserRole(String requestingUserId) async {
    try {
      final requestingUser = await getUserById(requestingUserId);
      return requestingUser?.role == UserRole.ADMIN;
    } catch (e) {
      return false;
    }
  }

  // Utility Methods

  /// Update wallet balance
  Future<void> updateWalletBalance(String userId, double newBalance) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'walletBalance': newBalance,
      });
    } catch (e) {
      throw Exception('Failed to update wallet balance: $e');
    }
  }

  /// Update last payment date
  Future<void> updateLastPaymentDate(String userId, DateTime paymentDate) async {
    try {
      await _firestore.collection(_collection).doc(userId).update({
        'lastPaymentDate': Timestamp.fromDate(paymentDate),
      });
    } catch (e) {
      throw Exception('Failed to update last payment date: $e');
    }
  }

  /// Check if phone number is already registered
  Future<bool> isPhoneNumberRegistered(String phoneNumber) async {
    try {
      final user = await getUserByPhoneNumber(phoneNumber);
      return user != null;
    } catch (e) {
      return false;
    }
  }

  /// Get user count by role
  Future<Map<UserRole, int>> getUserCountByRole() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();
      
      final counts = <UserRole, int>{
        UserRole.USER: 0,
        UserRole.COLLECTOR: 0,
        UserRole.ADMIN: 0,
      };

      for (final doc in querySnapshot.docs) {
        final user = UserModel.fromFirestore(doc);
        counts[user.role] = (counts[user.role] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      throw Exception('Failed to get user count by role: $e');
    }
  }

  /// Stream of users for real-time updates
  Stream<List<UserModel>> getUsersStream({
    String? area,
    UserRole? role,
    bool? isActive,
  }) {
    Query query = _firestore.collection(_collection);

    if (area != null) {
      query = query.where('area', isEqualTo: area);
    }
    
    if (role != null) {
      query = query.where('role', isEqualTo: role.toString().split('.').last);
    }
    
    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  /// Stream of single user for real-time updates
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection(_collection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }
}