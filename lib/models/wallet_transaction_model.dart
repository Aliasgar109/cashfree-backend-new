import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { CREDIT, DEBIT }

enum TransactionStatus { PENDING, COMPLETED, FAILED }

class WalletTransactionModel {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final TransactionStatus status;
  final String description;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? referenceId; // Payment ID or recharge transaction ID
  final String? upiTransactionId;
  final double balanceAfter;
  final double balanceBefore;

  WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    this.status = TransactionStatus.PENDING,
    required this.description,
    required this.createdAt,
    this.completedAt,
    this.referenceId,
    this.upiTransactionId,
    required this.balanceAfter,
    required this.balanceBefore,
  });

  // Validation methods
  static String? validateUserId(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return 'User ID is required';
    }
    return null;
  }

  static String? validateAmount(double? amount) {
    if (amount == null || amount <= 0) {
      return 'Amount must be greater than 0';
    }
    if (amount > 100000) {
      return 'Amount cannot exceed ₹1,00,000';
    }
    return null;
  }

  static String? validateDescription(String? description) {
    if (description == null || description.trim().isEmpty) {
      return 'Description is required';
    }
    if (description.trim().length > 200) {
      return 'Description must be less than 200 characters';
    }
    return null;
  }

  static String? validateReferenceId(String? referenceId) {
    if (referenceId != null && referenceId.trim().isEmpty) {
      return 'Reference ID cannot be empty if provided';
    }
    return null;
  }

  static String? validateUpiTransactionId(String? upiTransactionId) {
    if (upiTransactionId != null) {
      if (upiTransactionId.trim().isEmpty) {
        return 'UPI Transaction ID cannot be empty if provided';
      }
      if (upiTransactionId.trim().length < 8) {
        return 'UPI Transaction ID must be at least 8 characters';
      }
      if (upiTransactionId.trim().length > 50) {
        return 'UPI Transaction ID must be less than 50 characters';
      }
    }
    return null;
  }

  static String? validateBalance(double? balance) {
    if (balance == null) {
      return 'Balance is required';
    }
    if (balance < 0) {
      return 'Balance cannot be negative';
    }
    return null;
  }

  // Validation for the entire wallet transaction model
  Map<String, String> validate() {
    final errors = <String, String>{};
    
    final userIdError = validateUserId(userId);
    if (userIdError != null) errors['userId'] = userIdError;
    
    final amountError = validateAmount(amount);
    if (amountError != null) errors['amount'] = amountError;
    
    final descriptionError = validateDescription(description);
    if (descriptionError != null) errors['description'] = descriptionError;
    
    final referenceIdError = validateReferenceId(referenceId);
    if (referenceIdError != null) errors['referenceId'] = referenceIdError;
    
    final upiTransactionIdError = validateUpiTransactionId(upiTransactionId);
    if (upiTransactionIdError != null) errors['upiTransactionId'] = upiTransactionIdError;
    
    final balanceAfterError = validateBalance(balanceAfter);
    if (balanceAfterError != null) errors['balanceAfter'] = balanceAfterError;
    
    final balanceBeforeError = validateBalance(balanceBefore);
    if (balanceBeforeError != null) errors['balanceBefore'] = balanceBeforeError;
    
    // Validate balance calculation
    if (type == TransactionType.CREDIT) {
      final expectedBalance = balanceBefore + amount;
      if ((balanceAfter - expectedBalance).abs() > 0.01) {
        errors['balanceCalculation'] = 'Balance calculation is incorrect for credit transaction';
      }
    } else if (type == TransactionType.DEBIT) {
      final expectedBalance = balanceBefore - amount;
      if ((balanceAfter - expectedBalance).abs() > 0.01) {
        errors['balanceCalculation'] = 'Balance calculation is incorrect for debit transaction';
      }
    }
    
    // Validate completed date
    if (status == TransactionStatus.COMPLETED && completedAt == null) {
      errors['completedAt'] = 'Completed date is required for completed transactions';
    }
    
    if (completedAt != null && completedAt!.isBefore(createdAt)) {
      errors['completedAt'] = 'Completed date cannot be before created date';
    }
    
    return errors;
  }

  bool get isValid => validate().isEmpty;

  // Computed properties
  bool get isPending => status == TransactionStatus.PENDING;
  bool get isCompleted => status == TransactionStatus.COMPLETED;
  bool get isFailed => status == TransactionStatus.FAILED;
  
  bool get isCredit => type == TransactionType.CREDIT;
  bool get isDebit => type == TransactionType.DEBIT;

  String get typeDisplayText {
    switch (type) {
      case TransactionType.CREDIT:
        return 'Credit';
      case TransactionType.DEBIT:
        return 'Debit';
    }
  }

  String get statusDisplayText {
    switch (status) {
      case TransactionStatus.PENDING:
        return 'Pending';
      case TransactionStatus.COMPLETED:
        return 'Completed';
      case TransactionStatus.FAILED:
        return 'Failed';
    }
  }

  String get formattedAmount {
    final sign = isCredit ? '+' : '-';
    return '$sign₹${amount.toStringAsFixed(2)}';
  }

  // Factory methods for common transaction types
  factory WalletTransactionModel.recharge({
    required String id,
    required String userId,
    required double amount,
    required String upiTransactionId,
    required double balanceBefore,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return WalletTransactionModel(
      id: id,
      userId: userId,
      amount: amount,
      type: TransactionType.CREDIT,
      status: TransactionStatus.COMPLETED,
      description: 'Wallet recharge via UPI',
      createdAt: now,
      completedAt: now,
      upiTransactionId: upiTransactionId,
      balanceAfter: balanceBefore + amount,
      balanceBefore: balanceBefore,
    );
  }

  factory WalletTransactionModel.payment({
    required String id,
    required String userId,
    required double amount,
    required String paymentId,
    required double balanceBefore,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    return WalletTransactionModel(
      id: id,
      userId: userId,
      amount: amount,
      type: TransactionType.DEBIT,
      status: TransactionStatus.COMPLETED,
      description: 'Payment for TV subscription',
      createdAt: now,
      completedAt: now,
      referenceId: paymentId,
      balanceAfter: balanceBefore - amount,
      balanceBefore: balanceBefore,
    );
  }

  // Factory constructor from Firestore document
  factory WalletTransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletTransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      type: TransactionType.values.firstWhere(
        (type) => type.toString().split('.').last == data['type'],
        orElse: () => TransactionType.CREDIT,
      ),
      status: TransactionStatus.values.firstWhere(
        (status) => status.toString().split('.').last == data['status'],
        orElse: () => TransactionStatus.PENDING,
      ),
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      referenceId: data['referenceId'],
      upiTransactionId: data['upiTransactionId'],
      balanceAfter: (data['balanceAfter'] ?? 0.0).toDouble(),
      balanceBefore: (data['balanceBefore'] ?? 0.0).toDouble(),
    );
  }

  // Create from Supabase row
  factory WalletTransactionModel.fromSupabase(Map<String, dynamic> data) {
    return WalletTransactionModel(
      id: data['id']?.toString() ?? '',
      userId: data['user_firebase_uid'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      type: TransactionType.values.firstWhere(
        (type) => type.toString().split('.').last == data['type'],
        orElse: () => TransactionType.CREDIT,
      ),
      status: TransactionStatus.values.firstWhere(
        (status) => status.toString().split('.').last == data['status'],
        orElse: () => TransactionStatus.PENDING,
      ),
      description: data['description'] ?? '',
      createdAt: DateTime.parse(data['created_at']),
      completedAt: data['completed_at'] != null
          ? DateTime.parse(data['completed_at'])
          : null,
      referenceId: data['reference_id'],
      upiTransactionId: data['upi_transaction_id'],
      balanceAfter: (data['balance_after'] ?? 0.0).toDouble(),
      balanceBefore: (data['balance_before'] ?? 0.0).toDouble(),
    );
  }

  // Convert to Supabase row
  Map<String, dynamic> toSupabase() {
    return {
      'user_firebase_uid': userId,
      'amount': amount,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'reference_id': referenceId,
      'upi_transaction_id': upiTransactionId,
      'balance_after': balanceAfter,
      'balance_before': balanceBefore,
    };
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'referenceId': referenceId,
      'upiTransactionId': upiTransactionId,
      'balanceAfter': balanceAfter,
      'balanceBefore': balanceBefore,
    };
  }

  // Copy with method for immutable updates
  WalletTransactionModel copyWith({
    String? id,
    String? userId,
    double? amount,
    TransactionType? type,
    TransactionStatus? status,
    String? description,
    DateTime? createdAt,
    DateTime? completedAt,
    String? referenceId,
    String? upiTransactionId,
    double? balanceAfter,
    double? balanceBefore,
  }) {
    return WalletTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      status: status ?? this.status,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      referenceId: referenceId ?? this.referenceId,
      upiTransactionId: upiTransactionId ?? this.upiTransactionId,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      balanceBefore: balanceBefore ?? this.balanceBefore,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletTransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          amount == other.amount &&
          type == other.type &&
          status == other.status &&
          description == other.description &&
          createdAt == other.createdAt &&
          completedAt == other.completedAt &&
          referenceId == other.referenceId &&
          upiTransactionId == other.upiTransactionId &&
          balanceAfter == other.balanceAfter &&
          balanceBefore == other.balanceBefore;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      amount.hashCode ^
      type.hashCode ^
      status.hashCode ^
      description.hashCode ^
      createdAt.hashCode ^
      completedAt.hashCode ^
      referenceId.hashCode ^
      upiTransactionId.hashCode ^
      balanceAfter.hashCode ^
      balanceBefore.hashCode;

  @override
  String toString() {
    return 'WalletTransactionModel{id: $id, userId: $userId, amount: $amount, type: $type, status: $status}';
  }
}