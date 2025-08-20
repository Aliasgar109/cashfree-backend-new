import '../models/user_model.dart';
import '../models/wallet_transaction_model.dart';
import '../config/supabase_config.dart';
import 'supabase_service.dart';

/// Wallet service using Supabase for data operations
/// Firebase Auth is still used for authentication
class SupabaseWalletService extends SupabaseService {
  
  /// Get current wallet balance for a user
  Future<double> getWalletBalance(String firebaseUid) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for wallet balance lookup
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from(SupabaseConfig.usersTable)
          .select('wallet_balance')
          .eq('firebase_uid', firebaseUid)
          .maybeSingle();
      
      if (response == null) {
        throw Exception('User not found');
      }
      
      return (response['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    });
  }

  /// Add money to wallet (credits)
  Future<String> addMoneyToWallet({
    required String firebaseUid,
    required double amount,
    required String transactionId,
    required String paymentMethod,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }

    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for wallet operations
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient.rpc('add_wallet_funds', params: {
        'user_firebase_uid': firebaseUid,
        'amount': amount,
        'transaction_id': transactionId,
        'payment_method': paymentMethod,
        'description': description ?? 'Wallet top-up',
        'metadata': metadata,
      });

      return response as String;
    });
  }

  /// Deduct money from wallet (debits)
  Future<String> deductMoneyFromWallet({
    required String firebaseUid,
    required double amount,
    required String transactionId,
    required String purpose,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }

    return await executeWithErrorHandling(() async {
      // Check if user has sufficient balance
      final currentBalance = await getWalletBalance(firebaseUid);
      if (currentBalance < amount) {
        throw Exception('Insufficient wallet balance');
      }

      // Use admin client to bypass RLS for wallet operations
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient.rpc('deduct_wallet_funds', params: {
        'user_firebase_uid': firebaseUid,
        'amount': amount,
        'transaction_id': transactionId,
        'purpose': purpose,
        'description': description ?? 'Wallet payment',
        'metadata': metadata,
      });

      return response as String;
    });
  }

  /// Get wallet transaction history for a user
  Future<List<WalletTransactionModel>> getWalletTransactions({
    required String firebaseUid,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for transaction lookup
      final adminClient = SupabaseConfig.adminClient;
      var query = adminClient
          .from('wallet_transactions')
          .select()
          .eq('user_firebase_uid', firebaseUid)
          .order('created_at', ascending: false);

      // Note: Date filtering removed due to Supabase query limitations
      // TODO: Implement proper date filtering when needed

      if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      
      return (response as List)
          .map((item) => WalletTransactionModel.fromSupabase(item))
          .toList();
    });
  }

  /// Get transaction by ID
  Future<WalletTransactionModel?> getTransactionById(String transactionId) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for transaction lookup
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from('wallet_transactions')
          .select()
          .eq('transaction_id', transactionId)
          .maybeSingle();

      if (response == null) return null;

      return WalletTransactionModel.fromSupabase(response);
    });
  }

  /// Get wallet statistics for a user
  Future<WalletStatistics> getWalletStatistics(String firebaseUid) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for statistics
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient.rpc('get_wallet_statistics', params: {
        'user_firebase_uid': firebaseUid,
      });

      return WalletStatistics.fromMap(response);
    });
  }

  /// Get wallet summary (alias for getWalletStatistics)
  Future<WalletStatistics> getWalletSummary(String firebaseUid) async {
    return await getWalletStatistics(firebaseUid);
  }

  /// Recharge wallet (alias for addMoneyToWallet)
  Future<WalletTransactionModel> rechargeWallet({
    required String userId,
    required double amount,
    required String upiTransactionId,
  }) async {
    final transactionId = await addMoneyToWallet(
      firebaseUid: userId,
      amount: amount,
      transactionId: upiTransactionId,
      paymentMethod: 'UPI',
      description: 'Wallet recharge',
    );

    // Get the created transaction
    final transactions = await getWalletTransactions(firebaseUid: userId, limit: 1);
    if (transactions.isNotEmpty) {
      return transactions.first;
    }

    throw Exception('Failed to get created transaction');
  }

  /// Transfer money between wallets
  Future<Map<String, String>> transferMoney({
    required String fromFirebaseUid,
    required String toFirebaseUid,
    required double amount,
    required String transferId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }

    if (fromFirebaseUid == toFirebaseUid) {
      throw Exception('Cannot transfer to the same wallet');
    }

    return await executeWithErrorHandling(() async {
      // Check if sender has sufficient balance
      final senderBalance = await getWalletBalance(fromFirebaseUid);
      if (senderBalance < amount) {
        throw Exception('Insufficient wallet balance');
      }

      // Use admin client to bypass RLS for transfer operations
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient.rpc('transfer_wallet_funds', params: {
        'from_firebase_uid': fromFirebaseUid,
        'to_firebase_uid': toFirebaseUid,
        'amount': amount,
        'transfer_id': transferId,
        'description': description ?? 'Wallet transfer',
        'metadata': metadata,
      });

      return Map<String, String>.from(response);
    });
  }

  /// Check if a transaction exists
  Future<bool> transactionExists(String transactionId) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for transaction lookup
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from('wallet_transactions')
          .select('id')
          .eq('transaction_id', transactionId)
          .maybeSingle();

      return response != null;
    });
  }

  /// Get pending transactions for a user
  Future<List<WalletTransactionModel>> getPendingTransactions(String firebaseUid) async {
    return await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for transaction lookup
      final adminClient = SupabaseConfig.adminClient;
      final response = await adminClient
          .from('wallet_transactions')
          .select()
          .eq('user_firebase_uid', firebaseUid)
          .eq('status', 'PENDING')
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => WalletTransactionModel.fromSupabase(item))
          .toList();
    });
  }

  /// Update transaction status
  Future<void> updateTransactionStatus({
    required String transactionId,
    required String status,
    String? notes,
  }) async {
    await executeWithErrorHandling(() async {
      // Use admin client to bypass RLS for transaction updates
      final adminClient = SupabaseConfig.adminClient;
      await adminClient
          .from('wallet_transactions')
          .update({
            'status': status,
            'notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('transaction_id', transactionId);
    });
  }
}

/// Statistics model for wallet operations
class WalletStatistics {
  final double totalCredits;
  final double totalDebits;
  final double currentBalance;
  final int totalTransactions;
  final DateTime? lastTransactionDate;

  const WalletStatistics({
    required this.totalCredits,
    required this.totalDebits,
    required this.currentBalance,
    required this.totalTransactions,
    this.lastTransactionDate,
  });

  factory WalletStatistics.fromMap(Map<String, dynamic> map) {
    return WalletStatistics(
      totalCredits: (map['total_credits'] as num?)?.toDouble() ?? 0.0,
      totalDebits: (map['total_debits'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: (map['total_transactions'] as num?)?.toInt() ?? 0,
      lastTransactionDate: map['last_transaction_date'] != null
          ? DateTime.parse(map['last_transaction_date'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_credits': totalCredits,
      'total_debits': totalDebits,
      'current_balance': currentBalance,
      'total_transactions': totalTransactions,
      'last_transaction_date': lastTransactionDate?.toIso8601String(),
    };
  }

  // Additional getter for compatibility
  List<dynamic> get recentTransactions => [];
}

/// Wallet Summary model for compatibility
class WalletSummary {
  final double balance;
  final int totalTransactions;
  final DateTime? lastTransactionDate;

  const WalletSummary({
    required this.balance,
    required this.totalTransactions,
    this.lastTransactionDate,
  });

  factory WalletSummary.fromMap(Map<String, dynamic> map) {
    return WalletSummary(
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: (map['total_transactions'] as num?)?.toInt() ?? 0,
      lastTransactionDate: map['last_transaction_date'] != null
          ? DateTime.parse(map['last_transaction_date'])
          : null,
    );
  }

  // Additional getters for compatibility
  double get currentBalance => balance;
  List<dynamic> get recentTransactions => [];
}
