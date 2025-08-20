import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { USER, COLLECTOR, ADMIN }

class UserModel {
  final String id;
  final String username;  // Primary identifier for authentication
  final String name;
  final String phoneNumber;
  final String address;
  final String area;
  final UserRole role;
  final String preferredLanguage;
  final DateTime createdAt;
  final DateTime? lastPaymentDate;
  final double walletBalance;
  final bool isActive;

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.phoneNumber,
    required this.address,
    required this.area,
    required this.role,
    required this.preferredLanguage,
    required this.createdAt,
    this.lastPaymentDate,
    this.walletBalance = 0.0,
    this.isActive = true,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      username: data['username'] ?? '',
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      address: data['address'] ?? '',
      area: data['area'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == data['role'],
        orElse: () => UserRole.USER,
      ),
      preferredLanguage: data['preferredLanguage'] ?? 'en',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastPaymentDate: data['lastPaymentDate'] != null
          ? (data['lastPaymentDate'] as Timestamp).toDate()
          : null,
      walletBalance: (data['walletBalance'] ?? 0.0).toDouble(),
      isActive: data['isActive'] ?? true,
    );
  }

  factory UserModel.fromSupabase(Map<String, dynamic> data) {
    return UserModel(
      id: data['id'] ?? '',
      username: data['username'] ?? '',
      name: data['name'] ?? '',
      phoneNumber: data['phone_number'] ?? '',
      address: data['address'] ?? '',
      area: data['area'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == data['role'],
        orElse: () => UserRole.USER,
      ),
      preferredLanguage: data['preferred_language'] ?? 'en',
      createdAt: DateTime.parse(data['created_at'] ?? DateTime.now().toIso8601String()),
      lastPaymentDate: data['last_payment_date'] != null
          ? DateTime.parse(data['last_payment_date'])
          : null,
      walletBalance: (data['wallet_balance'] ?? 0.0).toDouble(),
      isActive: data['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'name': name,
      'phoneNumber': phoneNumber,
      'address': address,
      'area': area,
      'role': role.toString(),
      'preferredLanguage': preferredLanguage,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastPaymentDate': lastPaymentDate != null
          ? Timestamp.fromDate(lastPaymentDate!)
          : null,
      'walletBalance': walletBalance,
      'isActive': isActive,
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      'username': username,
      'name': name,
      'phone_number': phoneNumber,
      'address': address,
      'area': area,
      'role': role.toString().split('.').last,
      'preferred_language': preferredLanguage,
      'created_at': createdAt.toIso8601String(),
      'last_payment_date': lastPaymentDate?.toIso8601String(),
      'wallet_balance': walletBalance,
      'is_active': isActive,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? name,
    String? phoneNumber,
    String? address,
    String? area,
    UserRole? role,
    String? preferredLanguage,
    DateTime? createdAt,
    DateTime? lastPaymentDate,
    double? walletBalance,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      area: area ?? this.area,
      role: role ?? this.role,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      createdAt: createdAt ?? this.createdAt,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      walletBalance: walletBalance ?? this.walletBalance,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username;

  @override
  int get hashCode => id.hashCode ^ username.hashCode;

  @override
  String toString() {
    return 'UserModel{id: $id, username: $username, name: $name, role: $role}';
  }

  // Validation methods
  static String? validateUsername(String? username) {
    if (username == null || username.trim().isEmpty) {
      return 'Username is required';
    }
    if (username.trim().length < 3) {
      return 'Username must be at least 3 characters long';
    }
    if (username.trim().length > 20) {
      return 'Username must be less than 20 characters';
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!usernameRegex.hasMatch(username.trim())) {
      return 'Username can only contain letters, numbers, underscores, and hyphens';
    }
    return null;
  }

  static String? validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Name is required';
    }
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }
    return null;
  }

  static String? validatePhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^[0-9]{10}$');
    if (!phoneRegex.hasMatch(phoneNumber.trim())) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  static String? validateAddress(String? address) {
    if (address == null || address.trim().isEmpty) {
      return 'Address is required';
    }
    if (address.trim().length < 10) {
      return 'Address must be at least 10 characters long';
    }
    return null;
  }

  static String? validateArea(String? area) {
    if (area == null || area.trim().isEmpty) {
      return 'Area is required';
    }
    if (area.trim().length < 2) {
      return 'Area must be at least 2 characters long';
    }
    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  Map<String, String?> validate() {
    return {
      'username': validateUsername(username),
      'name': validateName(name),
      'phoneNumber': validatePhoneNumber(phoneNumber),
      'address': validateAddress(address),
      'area': validateArea(area),
    };
  }

  // Utility method to format phone number
  String get formattedPhoneNumber {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleanPhone.startsWith('+91')) {
      return cleanPhone;
    } else if (cleanPhone.startsWith('91') && cleanPhone.length == 12) {
      return '+$cleanPhone';
    } else {
      return '+91$cleanPhone';
    }
  }
}