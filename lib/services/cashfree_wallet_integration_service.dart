import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/payment_model.dart';
import '../models/wallet_transaction_model.dart';
import '../models/cashfree_error_model.dart' as error_model;
import 'wallet_service.dart';
import 'cashfree_payment_service.dart' as payment_service;
import 'cashfree_error_handler.dart';

/// Service for integrating Cashfree payments with the existing wallet system
///
/// This service handles combined payment flows where users can pay partially
/// from their wallet balance and the remaining amount through Cashfree payment gateway.
class CashfreeWalletIntegrationService {
  // Private constructor for singleton pattern
  CashfreeWalletIntegrationService._();

  // Singleton instance
  static final CashfreeWalletIntegrationService _instance = CashfreeWalletIntegrationService._();
  static CashfreeWalletIntegrationService get instance => _instance;

  // Dependencies
  final WalletService _walletService = WalletService();
  final payment_service.CashfreePaymentService _cashfreeService = payment_service.CashfreePaymentService.instance;
  final CashfreeErrorHandler _errorHandler = CashfreeErrorHandler.instance;

  /// Check wallet balance for a user
  ///
  /// Returns the current wallet balance that can be used for payments.
  Future<double> getWalletBalance(String userId) async {
    try {
      return await _walletService.getWalletBalance(userId);
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Error getting wallet balance: $e');
      }
      throw error_model.CashfreeServiceException(_errorHandler.handleException(
        e,
        context: 'Getting wallet balance',
        additionalDetails: {'userId': userId},
      ));
    }
  }

  /// Validate if user has sufficient wallet balance for a given amount
  ///
  /// Returns true if the wallet balance is sufficient, false otherwise.
  Future<bool> validateSufficientWalletBalance(String userId, double amount) async {
    try {
      return await _walletService.validateSufficientBalance(userId, amount);
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Error validating wallet balance: $e');
      }
      // Return false on error to prevent payment processing
      return false;
    }
  }

  /// Calculate payment breakdown for wallet + Cashfree combination
  ///
  /// This method calculates how much can be paid from wallet and how much
  /// needs to be paid through Cashfree based on the user's wallet balance.
  Future<CombinedPaymentCalculation> calculateCombinedPayment({
    required String userId,
    required double totalAmount,
    double extraCharges = 0.0,
  }) async {
    try {
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Calculating combined payment for user: $userId, amount: $totalAmount');
      }

      // Validate input parameters
      _validateCalculationParams(userId, totalAmount);

      final finalAmount = totalAmount + extraCharges;
      
      // Get current wallet balance
      final walletBalance = await getWalletBalance(userId);

      if (walletBalance >= finalAmount) {
        // Wallet can cover the full amount
        return CombinedPaymentCalculation(
          totalAmount: finalAmount,
          walletAmount: finalAmount,
          cashfreeAmount: 0.0,
          canPayFullyFromWallet: true,
          requiresCashfreePayment: false,
          walletBalance: walletBalance,
        );
      } else if (walletBalance > 0) {
        // Partial wallet payment + Cashfree payment
        final remainingAmount = finalAmount - walletBalance;
        return CombinedPaymentCalculation(
          totalAmount: finalAmount,
          walletAmount: walletBalance,
          cashfreeAmount: remainingAmount,
          canPayFullyFromWallet: false,
          requiresCashfreePayment: true,
          walletBalance: walletBalance,
        );
      } else {
        // No wallet balance, full Cashfree payment
        return CombinedPaymentCalculation(
          totalAmount: finalAmount,
          walletAmount: 0.0,
          cashfreeAmount: finalAmount,
          canPayFullyFromWallet: false,
          requiresCashfreePayment: true,
          walletBalance: 0.0,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Error calculating combined payment: $e');
      }
      
      final error = _errorHandler.handleException(
        e,
        context: 'Combined payment calculation',
        additionalDetails: {
          'userId': userId,
          'totalAmount': totalAmount,
          'extraCharges': extraCharges,
        },
      );
      
      throw error_model.CashfreeServiceException(error);
    }
  }

  /// Process combined payment (wallet + Cashfree)
  ///
  /// This method handles the complete combined payment flow:
  /// 1. Calculates payment breakdown
  /// 2. Deducts wallet amount if applicable
  /// 3. Processes Cashfree payment for remaining amount
  /// 4. Handles rollback if Cashfree payment fails
  Future<CombinedPaymentResult> processCombinedPayment({
    required String userId,
    required double totalAmount,
    required PaymentMethod cashfreeMethod,
    double extraCharges = 0.0,
    String? note,
    String? paymentId,
  }) async {
    WalletTransactionModel? walletTransaction;
    
    try {
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Processing combined payment for user: $userId');
      }

      // Validate input parameters
      _validateCombinedPaymentParams(userId, totalAmount, cashfreeMethod);

      // Generate payment ID if not provided
      final finalPaymentId = paymentId ?? _generatePaymentId(userId);

      // Calculate payment breakdown
      final calculation = await calculateCombinedPayment(
        userId: userId,
        totalAmount: totalAmount,
        extraCharges: extraCharges,
      );

      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Payment breakdown - '
            'Wallet: ${calculation.walletAmount}, Cashfree: ${calculation.cashfreeAmount}');
      }

      // Step 1: Process wallet payment if applicable
      if (calculation.walletAmount > 0) {
        walletTransaction = await _processWalletPayment(
          userId: userId,
          amount: calculation.walletAmount,
          paymentId: finalPaymentId,
          description: note ?? 'Combined payment - wallet portion',
        );

        if (kDebugMode) {
          print('CashfreeWalletIntegrationService: Wallet payment processed: ${walletTransaction.id}');
        }
      }

      // Step 2: Process Cashfree payment if required
      payment_service.CashfreePaymentResult? cashfreeResult;
      if (calculation.requiresCashfreePayment) {
        cashfreeResult = await _processCashfreePayment(
          userId: userId,
          amount: calculation.cashfreeAmount,
          method: cashfreeMethod,
          note: note ?? 'Combined payment - Cashfree portion',
        );

        // If Cashfree payment failed, rollback wallet transaction
        if (!cashfreeResult.success && walletTransaction != null) {
          await _rollbackWalletTransaction(walletTransaction, 'Cashfree payment failed');
          walletTransaction = null; // Mark as rolled back
        }
      }

      // Step 3: Create combined result
      final success = (walletTransaction != null || calculation.walletAmount == 0) &&
                     (cashfreeResult?.success ?? !calculation.requiresCashfreePayment);

      return CombinedPaymentResult(
        success: success,
        paymentId: finalPaymentId,
        totalAmount: calculation.totalAmount,
        walletAmount: calculation.walletAmount,
        cashfreeAmount: calculation.cashfreeAmount,
        walletTransactionId: walletTransaction?.id,
        cashfreeOrderId: cashfreeResult?.orderId,
        cashfreePaymentId: cashfreeResult?.paymentId,
        cashfreeTransactionId: cashfreeResult?.transactionId,
        message: success 
            ? _buildSuccessMessage(calculation, cashfreeResult)
            : _buildFailureMessage(calculation, cashfreeResult),
        error: success ? null : (cashfreeResult?.error ?? 'Combined payment failed'),
        errorType: success ? null : error_model.CashfreeErrorType.payment,
      );

    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Error in combined payment: $e');
      }

      // Rollback wallet transaction if it was created
      if (walletTransaction != null) {
        try {
          await _rollbackWalletTransaction(walletTransaction, 'Payment processing error');
        } catch (rollbackError) {
          if (kDebugMode) {
            print('CashfreeWalletIntegrationService: Error rolling back wallet transaction: $rollbackError');
          }
        }
      }

      final error = _errorHandler.handleException(
        e,
        context: 'Combined payment processing',
        additionalDetails: {
          'userId': userId,
          'totalAmount': totalAmount,
          'cashfreeMethod': cashfreeMethod.name,
        },
      );

      return CombinedPaymentResult(
        success: false,
        totalAmount: totalAmount + extraCharges,
        walletAmount: 0.0,
        cashfreeAmount: 0.0,
        error: error.userMessage,
        errorType: error.type,
      );
    }
  }

  /// Process wallet-only payment
  ///
  /// This method processes a payment entirely from the user's wallet balance.
  Future<CombinedPaymentResult> processWalletOnlyPayment({
    required String userId,
    required double totalAmount,
    double extraCharges = 0.0,
    String? note,
    String? paymentId,
  }) async {
    try {
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Processing wallet-only payment for user: $userId');
      }

      // Validate input parameters
      _validateWalletPaymentParams(userId, totalAmount);

      final finalAmount = totalAmount + extraCharges;
      final finalPaymentId = paymentId ?? _generatePaymentId(userId);

      // Check if wallet has sufficient balance
      final hasBalance = await validateSufficientWalletBalance(userId, finalAmount);
      if (!hasBalance) {
        final currentBalance = await getWalletBalance(userId);
        return CombinedPaymentResult(
          success: false,
          totalAmount: finalAmount,
          walletAmount: 0.0,
          cashfreeAmount: 0.0,
          error: 'Insufficient wallet balance. Required: ₹${finalAmount.toStringAsFixed(2)}, Available: ₹${currentBalance.toStringAsFixed(2)}',
          errorType: error_model.CashfreeErrorType.validation,
        );
      }

      // Process wallet payment
      final walletTransaction = await _processWalletPayment(
        userId: userId,
        amount: finalAmount,
        paymentId: finalPaymentId,
        description: note ?? 'Wallet payment for TV subscription',
      );

      return CombinedPaymentResult(
        success: true,
        paymentId: finalPaymentId,
        totalAmount: finalAmount,
        walletAmount: finalAmount,
        cashfreeAmount: 0.0,
        walletTransactionId: walletTransaction.id,
        message: 'Payment completed successfully from wallet balance',
      );

    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Error in wallet-only payment: $e');
      }

      final error = _errorHandler.handleException(
        e,
        context: 'Wallet-only payment processing',
        additionalDetails: {
          'userId': userId,
          'totalAmount': totalAmount,
        },
      );

      return CombinedPaymentResult(
        success: false,
        totalAmount: totalAmount + extraCharges,
        walletAmount: 0.0,
        cashfreeAmount: 0.0,
        error: error.userMessage,
        errorType: error.type,
      );
    }
  }

  /// Verify combined payment status
  ///
  /// This method verifies both wallet and Cashfree payment components
  /// to ensure the complete payment was processed successfully.
  Future<CombinedPaymentVerificationResult> verifyCombinedPayment({
    required String paymentId,
    String? walletTransactionId,
    String? cashfreeOrderId,
  }) async {
    try {
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Verifying combined payment: $paymentId');
      }

      // Verify wallet transaction if applicable
      WalletTransactionModel? walletTransaction;
      if (walletTransactionId != null) {
        walletTransaction = await _walletService.getTransactionById(walletTransactionId);
      }

      // Verify Cashfree payment if applicable
      payment_service.CashfreeVerificationResult? cashfreeVerification;
      if (cashfreeOrderId != null) {
        cashfreeVerification = await _cashfreeService.verifyPayment(cashfreeOrderId);
      }

      // Determine overall verification status
      final walletVerified = walletTransaction?.isCompleted ?? true;
      final cashfreeVerified = cashfreeVerification?.success ?? true;
      final overallSuccess = walletVerified && cashfreeVerified;

      return CombinedPaymentVerificationResult(
        success: overallSuccess,
        paymentId: paymentId,
        walletTransactionVerified: walletVerified,
        cashfreePaymentVerified: cashfreeVerified,
        walletTransaction: walletTransaction,
        cashfreeVerification: cashfreeVerification,
        message: overallSuccess 
            ? 'Combined payment verification successful'
            : 'Combined payment verification failed',
      );

    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Error verifying combined payment: $e');
      }

      return CombinedPaymentVerificationResult(
        success: false,
        paymentId: paymentId,
        walletTransactionVerified: false,
        cashfreePaymentVerified: false,
        error: 'Payment verification failed: $e',
      );
    }
  }

  /// Process wallet payment portion
  Future<WalletTransactionModel> _processWalletPayment({
    required String userId,
    required double amount,
    required String paymentId,
    required String description,
  }) async {
    return await _walletService.deductFromWallet(
      userId: userId,
      amount: amount,
      paymentId: paymentId,
      description: description,
    );
  }

  /// Process Cashfree payment portion
  Future<payment_service.CashfreePaymentResult> _processCashfreePayment({
    required String userId,
    required double amount,
    required PaymentMethod method,
    required String note,
  }) async {
    return await _cashfreeService.processPaymentWithErrorHandling(
      userId: userId,
      amount: amount,
      method: method,
      note: note,
      enableFallback: true,
    );
  }

  /// Rollback wallet transaction in case of Cashfree payment failure
  Future<void> _rollbackWalletTransaction(
    WalletTransactionModel walletTransaction,
    String reason,
  ) async {
    try {
      await _walletService.reverseTransaction(
        originalTransactionId: walletTransaction.id,
        reason: reason,
      );
      
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Wallet transaction rolled back: ${walletTransaction.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWalletIntegrationService: Failed to rollback wallet transaction: $e');
      }
      // Log error but don't throw - this is a cleanup operation
    }
  }

  /// Build success message for combined payment
  String _buildSuccessMessage(
    CombinedPaymentCalculation calculation,
    payment_service.CashfreePaymentResult? cashfreeResult,
  ) {
    if (calculation.canPayFullyFromWallet) {
      return 'Payment completed successfully from wallet balance (₹${calculation.walletAmount.toStringAsFixed(2)})';
    } else if (calculation.walletAmount > 0) {
      return 'Combined payment successful: Wallet (₹${calculation.walletAmount.toStringAsFixed(2)}) + Cashfree (₹${calculation.cashfreeAmount.toStringAsFixed(2)})';
    } else {
      return cashfreeResult?.message ?? 'Payment completed successfully via Cashfree';
    }
  }

  /// Build failure message for combined payment
  String _buildFailureMessage(
    CombinedPaymentCalculation calculation,
    payment_service.CashfreePaymentResult? cashfreeResult,
  ) {
    if (calculation.requiresCashfreePayment && cashfreeResult != null && !cashfreeResult.success) {
      return 'Cashfree payment failed: ${cashfreeResult.error}';
    }
    return 'Combined payment failed';
  }

  /// Generate unique payment ID
  String _generatePaymentId(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'PAY_${userId}_$timestamp';
  }

  /// Validate calculation parameters
  void _validateCalculationParams(String userId, double totalAmount) {
    if (userId.isEmpty) {
      throw error_model.CashfreeServiceException.basic(
        'User identification is required.',
        error_model.CashfreeErrorType.validation,
      );
    }

    if (totalAmount <= 0) {
      throw error_model.CashfreeServiceException.basic(
        'Please enter a valid payment amount.',
        error_model.CashfreeErrorType.validation,
      );
    }
  }

  /// Validate combined payment parameters
  void _validateCombinedPaymentParams(
    String userId,
    double totalAmount,
    PaymentMethod cashfreeMethod,
  ) {
    _validateCalculationParams(userId, totalAmount);

    // Validate that method is a Cashfree-supported method
    final cashfreeMethods = [
      PaymentMethod.CASHFREE_CARD,
      PaymentMethod.CASHFREE_UPI,
      PaymentMethod.CASHFREE_NETBANKING,
      PaymentMethod.CASHFREE_WALLET,
    ];

    if (!cashfreeMethods.contains(cashfreeMethod)) {
      throw error_model.CashfreeServiceException.basic(
        'Selected payment method is not supported.',
        error_model.CashfreeErrorType.validation,
      );
    }
  }

  /// Validate wallet payment parameters
  void _validateWalletPaymentParams(String userId, double totalAmount) {
    _validateCalculationParams(userId, totalAmount);
  }
}

/// Data class for combined payment calculation results
class CombinedPaymentCalculation {
  final double totalAmount;
  final double walletAmount;
  final double cashfreeAmount;
  final bool canPayFullyFromWallet;
  final bool requiresCashfreePayment;
  final double walletBalance;

  CombinedPaymentCalculation({
    required this.totalAmount,
    required this.walletAmount,
    required this.cashfreeAmount,
    required this.canPayFullyFromWallet,
    required this.requiresCashfreePayment,
    required this.walletBalance,
  });

  String get formattedTotalAmount => '₹${totalAmount.toStringAsFixed(2)}';
  String get formattedWalletAmount => '₹${walletAmount.toStringAsFixed(2)}';
  String get formattedCashfreeAmount => '₹${cashfreeAmount.toStringAsFixed(2)}';
  String get formattedWalletBalance => '₹${walletBalance.toStringAsFixed(2)}';

  @override
  String toString() {
    return 'CombinedPaymentCalculation{total: $formattedTotalAmount, wallet: $formattedWalletAmount, cashfree: $formattedCashfreeAmount}';
  }
}

/// Data class for combined payment results
class CombinedPaymentResult {
  final bool success;
  final String? paymentId;
  final double totalAmount;
  final double walletAmount;
  final double cashfreeAmount;
  final String? walletTransactionId;
  final String? cashfreeOrderId;
  final String? cashfreePaymentId;
  final String? cashfreeTransactionId;
  final String? message;
  final String? error;
  final error_model.CashfreeErrorType? errorType;

  CombinedPaymentResult({
    required this.success,
    this.paymentId,
    required this.totalAmount,
    required this.walletAmount,
    required this.cashfreeAmount,
    this.walletTransactionId,
    this.cashfreeOrderId,
    this.cashfreePaymentId,
    this.cashfreeTransactionId,
    this.message,
    this.error,
    this.errorType,
  });

  String get formattedTotalAmount => '₹${totalAmount.toStringAsFixed(2)}';
  String get formattedWalletAmount => '₹${walletAmount.toStringAsFixed(2)}';
  String get formattedCashfreeAmount => '₹${cashfreeAmount.toStringAsFixed(2)}';

  @override
  String toString() {
    return 'CombinedPaymentResult{success: $success, total: $formattedTotalAmount, message: $message}';
  }
}

/// Data class for combined payment verification results
class CombinedPaymentVerificationResult {
  final bool success;
  final String paymentId;
  final bool walletTransactionVerified;
  final bool cashfreePaymentVerified;
  final WalletTransactionModel? walletTransaction;
  final payment_service.CashfreeVerificationResult? cashfreeVerification;
  final String? message;
  final String? error;

  CombinedPaymentVerificationResult({
    required this.success,
    required this.paymentId,
    required this.walletTransactionVerified,
    required this.cashfreePaymentVerified,
    this.walletTransaction,
    this.cashfreeVerification,
    this.message,
    this.error,
  });

  @override
  String toString() {
    return 'CombinedPaymentVerificationResult{success: $success, paymentId: $paymentId}';
  }
}