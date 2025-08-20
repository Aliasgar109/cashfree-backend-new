import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/wallet_transaction_model.dart';

class WalletService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _transactionsCollection => _firestore.collection('wallet_transactions');

  /// Get current wallet balance for a user
  Future<double> getWalletBalance(String userId) async {
    try {
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      return (userData['walletBalance'] ?? 0.0).toDouble();
    } catch (e) {
      throw Exception('Failed to get wallet balance: $e');
    }
  }

  /// Update wallet balance for a user
  Future<void> _updateWalletBalance(String userId, double newBalance) async {
    try {
      await _usersCollection.doc(userId).update({
        'walletBalance': newBalance,
      });
    } catch (e) {
      throw Exception('Failed to update wallet balance: $e');
    }
  }

  /// Validate if user has sufficient balance for a transaction
  Future<bool> validateSufficientBalance(String userId, double amount) async {
    try {
      final currentBalance = await getWalletBalance(userId);
      return currentBalance >= amount;
    } catch (e) {
      throw Exception('Failed to validate balance: $e');
    }
  }

  /// Add funds to wallet (recharge functionality)
  Future<WalletTransactionModel> rechargeWallet({
    required String userId,
    required double amount,
    required String upiTransactionId,
  }) async {
    // Validate inputs
    final amountError = WalletTransactionModel.validateAmount(amount);
    if (amountError != null) {
      throw Exception(amountError);
    }

    final upiError = WalletTransactionModel.validateUpiTransactionId(upiTransactionId);
    if (upiError != null) {
      throw Exception(upiError);
    }

    try {
      // Get current balance
      final currentBalance = await getWalletBalance(userId);
      
      // Create transaction record
      final transactionId = _transactionsCollection.doc().id;
      final transaction = WalletTransactionModel.recharge(
        id: transactionId,
        userId: userId,
        amount: amount,
        upiTransactionId: upiTransactionId,
        balanceBefore: currentBalance,
      );

      // Validate transaction
      final validationErrors = transaction.validate();
      if (validationErrors.isNotEmpty) {
        throw Exception('Transaction validation failed: ${validationErrors.values.first}');
      }

      // Use Firestore transaction to ensure atomicity
      await _firestore.runTransaction((firestoreTransaction) async {
        // Add transaction record
        firestoreTransaction.set(
          _transactionsCollection.doc(transactionId),
          transaction.toFirestore(),
        );

        // Update user wallet balance
        firestoreTransaction.update(
          _usersCollection.doc(userId),
          {'walletBalance': transaction.balanceAfter},
        );
      });

      return transaction;
    } catch (e) {
      throw Exception('Failed to recharge wallet: $e');
    }
  }

  /// Deduct funds from wallet for payment
  Future<WalletTransactionModel> deductFromWallet({
    required String userId,
    required double amount,
    required String paymentId,
    String? description,
  }) async {
    // Validate inputs
    final amountError = WalletTransactionModel.validateAmount(amount);
    if (amountError != null) {
      throw Exception(amountError);
    }

    try {
      // Get current balance
      final currentBalance = await getWalletBalance(userId);
      
      // Check sufficient balance
      if (currentBalance < amount) {
        throw Exception('Insufficient wallet balance. Current balance: ₹${currentBalance.toStringAsFixed(2)}, Required: ₹${amount.toStringAsFixed(2)}');
      }

      // Create transaction record
      final transactionId = _transactionsCollection.doc().id;
      final transaction = WalletTransactionModel.payment(
        id: transactionId,
        userId: userId,
        amount: amount,
        paymentId: paymentId,
        balanceBefore: currentBalance,
      );

      // Override description if provided
      final finalTransaction = description != null 
          ? transaction.copyWith(description: description)
          : transaction;

      // Validate transaction
      final validationErrors = finalTransaction.validate();
      if (validationErrors.isNotEmpty) {
        throw Exception('Transaction validation failed: ${validationErrors.values.first}');
      }

      // Use Firestore transaction to ensure atomicity
      await _firestore.runTransaction((firestoreTransaction) async {
        // Add transaction record
        firestoreTransaction.set(
          _transactionsCollection.doc(transactionId),
          finalTransaction.toFirestore(),
        );

        // Update user wallet balance
        firestoreTransaction.update(
          _usersCollection.doc(userId),
          {'walletBalance': finalTransaction.balanceAfter},
        );
      });

      return finalTransaction;
    } catch (e) {
      throw Exception('Failed to deduct from wallet: $e');
    }
  }

  /// Get transaction history for a user
  Future<List<WalletTransactionModel>> getTransactionHistory({
    required String userId,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    TransactionStatus? status,
  }) async {
    try {
      Query query = _transactionsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      // Apply filters
      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.toString().split('.').last);
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status.toString().split('.').last);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final querySnapshot = await query.get();
      
      return querySnapshot.docs
          .map((doc) => WalletTransactionModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get transaction history: $e');
    }
  }

  /// Get transaction by ID
  Future<WalletTransactionModel?> getTransactionById(String transactionId) async {
    try {
      final doc = await _transactionsCollection.doc(transactionId).get();
      if (!doc.exists) {
        return null;
      }
      return WalletTransactionModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get transaction: $e');
    }
  }

  /// Get wallet summary for a user
  Future<WalletSummary> getWalletSummary(String userId) async {
    try {
      final currentBalance = await getWalletBalance(userId);
      
      // Get recent transactions (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentTransactions = await getTransactionHistory(
        userId: userId,
        startDate: thirtyDaysAgo,
      );

      // Calculate totals
      double totalCredits = 0;
      double totalDebits = 0;
      int totalTransactions = recentTransactions.length;

      for (final transaction in recentTransactions) {
        if (transaction.isCredit) {
          totalCredits += transaction.amount;
        } else {
          totalDebits += transaction.amount;
        }
      }

      return WalletSummary(
        currentBalance: currentBalance,
        totalCredits: totalCredits,
        totalDebits: totalDebits,
        totalTransactions: totalTransactions,
        recentTransactions: recentTransactions.take(5).toList(),
      );
    } catch (e) {
      throw Exception('Failed to get wallet summary: $e');
    }
  }

  /// Stream wallet balance changes
  Stream<double> watchWalletBalance(String userId) {
    return _usersCollection
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return 0.0;
          final data = doc.data() as Map<String, dynamic>;
          return (data['walletBalance'] ?? 0.0).toDouble();
        });
  }

  /// Stream transaction history
  Stream<List<WalletTransactionModel>> watchTransactionHistory({
    required String userId,
    int? limit,
  }) {
    Query query = _transactionsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => WalletTransactionModel.fromFirestore(doc))
            .toList());
  }

  /// Calculate remaining amount after using wallet balance
  Future<PaymentCalculation> calculatePaymentWithWallet({
    required String userId,
    required double totalAmount,
  }) async {
    try {
      final walletBalance = await getWalletBalance(userId);
      
      if (walletBalance >= totalAmount) {
        // Wallet can cover full amount
        return PaymentCalculation(
          totalAmount: totalAmount,
          walletAmount: totalAmount,
          remainingAmount: 0.0,
          canPayFully: true,
        );
      } else {
        // Partial wallet payment
        return PaymentCalculation(
          totalAmount: totalAmount,
          walletAmount: walletBalance,
          remainingAmount: totalAmount - walletBalance,
          canPayFully: false,
        );
      }
    } catch (e) {
      throw Exception('Failed to calculate payment: $e');
    }
  }

  /// Reverse a transaction (for refunds or corrections)
  Future<WalletTransactionModel> reverseTransaction({
    required String originalTransactionId,
    required String reason,
  }) async {
    try {
      // Get original transaction
      final originalTransaction = await getTransactionById(originalTransactionId);
      if (originalTransaction == null) {
        throw Exception('Original transaction not found');
      }

      if (originalTransaction.status != TransactionStatus.COMPLETED) {
        throw Exception('Can only reverse completed transactions');
      }

      // Get current balance
      final currentBalance = await getWalletBalance(originalTransaction.userId);

      // Create reverse transaction
      final reverseTransactionId = _transactionsCollection.doc().id;
      final reverseType = originalTransaction.type == TransactionType.CREDIT 
          ? TransactionType.DEBIT 
          : TransactionType.CREDIT;

      final reverseTransaction = WalletTransactionModel(
        id: reverseTransactionId,
        userId: originalTransaction.userId,
        amount: originalTransaction.amount,
        type: reverseType,
        status: TransactionStatus.COMPLETED,
        description: 'Reversal: $reason',
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
        referenceId: originalTransactionId,
        balanceBefore: currentBalance,
        balanceAfter: reverseType == TransactionType.CREDIT 
            ? currentBalance + originalTransaction.amount
            : currentBalance - originalTransaction.amount,
      );

      // Validate reverse transaction
      final validationErrors = reverseTransaction.validate();
      if (validationErrors.isNotEmpty) {
        throw Exception('Reverse transaction validation failed: ${validationErrors.values.first}');
      }

      // Use Firestore transaction to ensure atomicity
      await _firestore.runTransaction((firestoreTransaction) async {
        // Add reverse transaction record
        firestoreTransaction.set(
          _transactionsCollection.doc(reverseTransactionId),
          reverseTransaction.toFirestore(),
        );

        // Update user wallet balance
        firestoreTransaction.update(
          _usersCollection.doc(originalTransaction.userId),
          {'walletBalance': reverseTransaction.balanceAfter},
        );
      });

      return reverseTransaction;
    } catch (e) {
      throw Exception('Failed to reverse transaction: $e');
    }
  }
}

/// Wallet summary data class
class WalletSummary {
  final double currentBalance;
  final double totalCredits;
  final double totalDebits;
  final int totalTransactions;
  final List<WalletTransactionModel> recentTransactions;

  WalletSummary({
    required this.currentBalance,
    required this.totalCredits,
    required this.totalDebits,
    required this.totalTransactions,
    required this.recentTransactions,
  });

  double get netAmount => totalCredits - totalDebits;
  
  String get formattedCurrentBalance => '₹${currentBalance.toStringAsFixed(2)}';
  String get formattedTotalCredits => '₹${totalCredits.toStringAsFixed(2)}';
  String get formattedTotalDebits => '₹${totalDebits.toStringAsFixed(2)}';
  String get formattedNetAmount => '₹${netAmount.toStringAsFixed(2)}';
}

/// Payment calculation data class
class PaymentCalculation {
  final double totalAmount;
  final double walletAmount;
  final double remainingAmount;
  final bool canPayFully;

  PaymentCalculation({
    required this.totalAmount,
    required this.walletAmount,
    required this.remainingAmount,
    required this.canPayFully,
  });

  String get formattedTotalAmount => '₹${totalAmount.toStringAsFixed(2)}';
  String get formattedWalletAmount => '₹${walletAmount.toStringAsFixed(2)}';
  String get formattedRemainingAmount => '₹${remainingAmount.toStringAsFixed(2)}';
}