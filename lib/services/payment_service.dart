import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_model.dart';
import '../models/receipt_model.dart';
import '../models/settings_model.dart';
import 'upi_intent_service.dart' as upi;

import 'wallet_service.dart';
import 'receipt_service.dart';
import 'whatsapp_service.dart';
import 'user_service.dart';
import 'notification_service.dart';
import 'settings_service.dart';

/// Service for handling payment processing and management
class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final upi.UPIIntentService _upiService = upi.UPIIntentService();
  final WalletService _walletService = WalletService();
  final ReceiptService _receiptService = ReceiptService();
  final WhatsAppService _whatsAppService = WhatsAppService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();
  final SettingsService _settingsService = SettingsService();

  /// Create a new payment record
  Future<PaymentResult> createPayment({
    required String userId,
    required double amount,
    required PaymentMethod method,
    double extraCharges = 0.0,
    String? note,
  }) async {
    try {
      final paymentId = _firestore.collection('payments').doc().id;

      final payment = PaymentModel(
        id: paymentId,
        userId: userId,
        amount: amount,
        extraCharges: extraCharges,
        method: method,
        status: PaymentStatus.PENDING,
        createdAt: DateTime.now(),
        receiptNumber: _generateReceiptNumber(),
        year: DateTime.now().year,
      );

      await _firestore
          .collection('payments')
          .doc(paymentId)
          .set(payment.toFirestore());

      return PaymentResult(
        success: true,
        paymentId: paymentId,
        payment: payment,
        message: 'Payment created successfully',
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        error: 'Failed to create payment: $e',
      );
    }
  }

  /// Process UPI payment
  Future<UPIPaymentResult> processUPIPayment({
    required String userId,
    required double amount,
    double extraCharges = 0.0,
    String? note,
  }) async {
    try {
      // Create payment record
      final paymentResult = await createPayment(
        userId: userId,
        amount: amount + extraCharges,
        method: PaymentMethod.UPI,
        extraCharges: extraCharges,
        note: note,
      );

      if (!paymentResult.success || paymentResult.paymentId == null) {
        return UPIPaymentResult(
          success: false,
          error: paymentResult.error ?? 'Failed to create payment',
        );
      }

      // Launch UPI intent
      final upiResult = await _upiService.launchUPIForPayment(
        amount: amount + extraCharges,
        userId: userId,
        paymentId: paymentResult.paymentId!,
        note: note,
      );

      return UPIPaymentResult(
        success: upiResult.success,
        paymentId: paymentResult.paymentId,
        upiResult: upiResult,
        error: upiResult.error,
      );
    } catch (e) {
      return UPIPaymentResult(
        success: false,
        error: 'UPI payment processing failed: $e',
      );
    }
  }

  /// Process wallet payment
  Future<WalletPaymentResult> processWalletPayment({
    required String userId,
    required double amount,
    double extraCharges = 0.0,
    String? note,
  }) async {
    try {
      final totalAmount = amount + extraCharges;

      // Check wallet balance
      final balance = await _walletService.getWalletBalance(userId);
      if (balance < totalAmount) {
        return WalletPaymentResult(
          success: false,
          error:
              'Insufficient wallet balance. Current balance: ₹${balance.toStringAsFixed(2)}',
          currentBalance: balance,
          requiredAmount: totalAmount,
        );
      }

      // Create payment record
      final paymentResult = await createPayment(
        userId: userId,
        amount: totalAmount,
        method: PaymentMethod.WALLET,
        extraCharges: extraCharges,
        note: note,
      );

      if (!paymentResult.success || paymentResult.paymentId == null) {
        return WalletPaymentResult(
          success: false,
          error: paymentResult.error ?? 'Failed to create payment',
        );
      }

      // Deduct from wallet
      final walletTransaction = await _walletService.deductFromWallet(
        userId: userId,
        amount: totalAmount,
        description: 'TV Subscription Payment',
        paymentId: paymentResult.paymentId!,
      );

      // Update payment status to approved (wallet payments are auto-approved)
      await _firestore
          .collection('payments')
          .doc(paymentResult.paymentId!)
          .update({
        'status': PaymentStatus.APPROVED.name,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': 'SYSTEM_WALLET',
        'transactionId': walletTransaction.id,
      });

      return WalletPaymentResult(
        success: true,
        paymentId: paymentResult.paymentId!,
        transactionId: walletTransaction.id,
        newBalance: walletTransaction.balanceAfter,
        message: 'Payment completed successfully using wallet',
      );
    } catch (e) {
      return WalletPaymentResult(
        success: false,
        error: 'Wallet payment processing failed: $e',
      );
    }
  }

  /// Process combined payment (wallet + UPI)
  Future<CombinedPaymentResult> processCombinedPayment({
    required String userId,
    required double amount,
    double extraCharges = 0.0,
    String? note,
  }) async {
    try {
      final totalAmount = amount + extraCharges;

      // Get wallet balance
      final walletBalance = await _walletService.getWalletBalance(userId);

      if (walletBalance <= 0) {
        return CombinedPaymentResult(
          success: false,
          error: 'No wallet balance available for combined payment',
        );
      }

      final walletAmount = walletBalance > totalAmount
          ? totalAmount
          : walletBalance;
      final upiAmount = totalAmount - walletAmount;

      // Create payment record
      final paymentResult = await createPayment(
        userId: userId,
        amount: totalAmount,
        method: PaymentMethod.COMBINED,
        extraCharges: extraCharges,
        note: note,
      );

      if (!paymentResult.success || paymentResult.paymentId == null) {
        return CombinedPaymentResult(
          success: false,
          error: paymentResult.error ?? 'Failed to create payment',
        );
      }

      // Deduct wallet amount
      final walletTransaction = await _walletService.deductFromWallet(
        userId: userId,
        amount: walletAmount,
        description: 'TV Subscription Payment (Partial)',
        paymentId: paymentResult.paymentId!,
      );

      // Update payment with wallet transaction
      await _firestore
          .collection('payments')
          .doc(paymentResult.paymentId!)
          .update({
        'walletAmount': walletAmount,
        'walletTransactionId': walletTransaction.id,
        'remainingAmount': upiAmount,
      });

      // Launch UPI for remaining amount
      final upiResult = await _upiService.launchUPIForPayment(
        amount: upiAmount,
        userId: userId,
        paymentId: paymentResult.paymentId!,
        note: '$note (Remaining amount after wallet)',
      );

      return CombinedPaymentResult(
        success: true,
        paymentId: paymentResult.paymentId!,
        walletAmount: walletAmount,
        upiAmount: upiAmount,
        walletTransactionId: walletTransaction.id,
        newWalletBalance: walletTransaction.balanceAfter,
        upiResult: upiResult,
        message:
            'Wallet amount deducted. Complete UPI payment for remaining amount.',
      );
    } catch (e) {
      return CombinedPaymentResult(
        success: false,
        error: 'Combined payment processing failed: $e',
      );
    }
  }

  /// Get payment by ID
  Future<PaymentModel?> getPayment(String paymentId) async {
    try {
      final doc = await _firestore.collection('payments').doc(paymentId).get();
      if (doc.exists) {
        return PaymentModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user payments
  Stream<List<PaymentModel>> getUserPayments(String userId) {
    return _firestore
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Generate unique receipt number
  String _generateReceiptNumber() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final timestamp = now.millisecondsSinceEpoch.toString().substring(8);
    return 'RCP$year$month$timestamp';
  }

  /// Update payment status (for admin approval/rejection)
  Future<PaymentUpdateResult> updatePaymentStatus({
    required String paymentId,
    required PaymentStatus newStatus,
    required String adminId,
    String? rejectionReason,
  }) async {
    try {
      final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
      
      if (!paymentDoc.exists) {
        return PaymentUpdateResult(
          success: false,
          error: 'Payment not found',
        );
      }

      final payment = PaymentModel.fromFirestore(paymentDoc);
      
      // Validate status transition
      if (payment.status != PaymentStatus.PENDING) {
        return PaymentUpdateResult(
          success: false,
          error: 'Payment is not in pending status',
        );
      }

      final updateData = <String, dynamic>{
        'status': newStatus.name,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminId,
      };

      if (newStatus == PaymentStatus.REJECTED && rejectionReason != null) {
        updateData['rejectionReason'] = rejectionReason;
      }

      await _firestore.collection('payments').doc(paymentId).update(updateData);

      // Get updated payment
      final updatedPaymentDoc = await _firestore.collection('payments').doc(paymentId).get();
      final updatedPayment = PaymentModel.fromFirestore(updatedPaymentDoc);

      // If approved, generate receipt and auto-share via WhatsApp
      if (newStatus == PaymentStatus.APPROVED) {
        await _handlePaymentApproval(updatedPayment);
      }

      // Send notification to user about status change
      await _sendStatusChangeNotification(updatedPayment, newStatus, rejectionReason);

      return PaymentUpdateResult(
        success: true,
        paymentId: paymentId,
        newStatus: newStatus,
        message: newStatus == PaymentStatus.APPROVED 
            ? 'Payment approved successfully'
            : 'Payment rejected successfully',
      );
    } catch (e) {
      return PaymentUpdateResult(
        success: false,
        error: 'Failed to update payment status: $e',
      );
    }
  }

  /// Handle payment approval - generate receipt and auto-share via WhatsApp
  Future<void> _handlePaymentApproval(PaymentModel payment) async {
    try {
      // Get user details
      final user = await _userService.getUserById(payment.userId);
      if (user == null) {
        throw Exception('User not found for payment ${payment.id}');
      }

      // Generate receipt
      final receipt = await _receiptService.generateReceipt(
        payment: payment,
        user: user,
      );

      // Auto-share receipt via WhatsApp
      final shareResult = await _whatsAppService.autoShareReceiptAfterApproval(
        receipt: receipt,
        user: user,
      );

      // Log the sharing result (in a real app, you might want to store this)
      if (!shareResult.isSuccess) {
        // Handle sharing failure gracefully - maybe log it or notify admin
        // In production, use proper logging instead of print
        // Logger.warning('WhatsApp auto-share failed: ${shareResult.errorMessage}');
        // Could implement fallback notification methods here
      }
    } catch (e) {
      // Handle receipt generation or sharing errors gracefully
      // Don't fail the payment approval if receipt/sharing fails
      // In production, use proper logging instead of print
      // Logger.error('Error in payment approval handling: $e');
    }
  }

  /// Manually share receipt via WhatsApp (for user-initiated sharing)
  Future<WhatsAppShareResult> shareReceiptManually({
    required String paymentId,
    required String userId,
  }) async {
    try {
      // Get payment details
      final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
      if (!paymentDoc.exists) {
        return WhatsAppShareResult.failure(
          WhatsAppService.errorReceiptNotFound,
          'Payment not found',
        );
      }

      final payment = PaymentModel.fromFirestore(paymentDoc);
      
      // Verify payment belongs to user and is approved
      if (payment.userId != userId) {
        return WhatsAppShareResult.failure(
          WhatsAppService.errorPermissionDenied,
          'Payment does not belong to this user',
        );
      }

      if (payment.status != PaymentStatus.APPROVED) {
        return WhatsAppShareResult.failure(
          WhatsAppService.errorReceiptNotFound,
          'Receipt is only available for approved payments',
        );
      }

      // Get user details
      final user = await _userService.getUserById(userId);
      if (user == null) {
        return WhatsAppShareResult.failure(
          WhatsAppService.errorReceiptNotFound,
          'User not found',
        );
      }

      // Get receipt
      final receipt = await _receiptService.getReceiptByPaymentId(paymentId);
      if (receipt == null) {
        return WhatsAppShareResult.failure(
          WhatsAppService.errorReceiptNotFound,
          'Receipt not found for this payment',
        );
      }

      // Share receipt via WhatsApp
      return await _whatsAppService.downloadReceiptForManualSharing(
        receipt: receipt,
        user: user,
      );
    } catch (e) {
      return WhatsAppShareResult.failure(
        WhatsAppService.errorSharingFailed,
        'Failed to share receipt: ${e.toString()}',
      );
    }
  }

  /// Share multiple receipts for a user
  Future<WhatsAppShareResult> shareMultipleReceipts({
    required String userId,
    required List<String> paymentIds,
  }) async {
    try {
      // Get user details
      final user = await _userService.getUserById(userId);
      if (user == null) {
        return WhatsAppShareResult.failure(
          WhatsAppService.errorReceiptNotFound,
          'User not found',
        );
      }

      // Get all receipts for the specified payments
      final receipts = <ReceiptModel>[];
      
      for (final paymentId in paymentIds) {
        final receipt = await _receiptService.getReceiptByPaymentId(paymentId);
        if (receipt != null) {
          // Verify payment belongs to user
          final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
          if (paymentDoc.exists) {
            final payment = PaymentModel.fromFirestore(paymentDoc);
            if (payment.userId == userId && payment.status == PaymentStatus.APPROVED) {
              receipts.add(receipt);
            }
          }
        }
      }

      if (receipts.isEmpty) {
        return WhatsAppShareResult.failure(
          WhatsAppService.errorReceiptNotFound,
          'No valid receipts found for sharing',
        );
      }

      // Share multiple receipts
      return await _whatsAppService.shareMultipleReceipts(
        receipts: receipts,
        user: user,
      );
    } catch (e) {
      return WhatsAppShareResult.failure(
        WhatsAppService.errorSharingFailed,
        'Failed to share receipts: ${e.toString()}',
      );
    }
  }

  /// Get pending payments for admin review
  Stream<List<PaymentModel>> getPendingPayments() {
    return _firestore
        .collection('payments')
        .where('status', isEqualTo: PaymentStatus.PENDING.name)
        .orderBy('createdAt', descending: false) // Oldest first for FIFO processing
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get payments by status
  Stream<List<PaymentModel>> getPaymentsByStatus(PaymentStatus status) {
    return _firestore
        .collection('payments')
        .where('status', isEqualTo: status.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => PaymentModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Calculate yearly fee with dynamic charges and late fees using SettingsService
  Future<FeeCalculation> calculateYearlyFee({
    required String userId,
    double? customAmount,
    double extraCharges = 0.0,
    double? wireLength, // For per-meter wire charges
  }) async {
    try {
      // Use SettingsService for fee calculation
      final feeBreakdown = await _settingsService.calculateFeeBreakdown(
        userId: userId,
        customBaseAmount: customAmount,
        extraCharges: extraCharges,
        wireLength: wireLength,
      );

      // Check if user has already paid for current year
      final currentYear = DateTime.now().year;
      final currentYearPayment = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('year', isEqualTo: currentYear)
          .where('status', isEqualTo: PaymentStatus.APPROVED.name)
          .limit(1)
          .get();

      final hasCurrentYearPayment = currentYearPayment.docs.isNotEmpty;

      return FeeCalculation(
        baseAmount: feeBreakdown.baseAmount,
        extraCharges: feeBreakdown.extraCharges,
        wireCharges: feeBreakdown.wireCharges,
        lateFees: feeBreakdown.lateFees,
        totalAmount: feeBreakdown.totalAmount,
        hasLateFees: feeBreakdown.hasLateFees,
        hasCurrentYearPayment: hasCurrentYearPayment,
        lateFeesPercentage: feeBreakdown.lateFeesPercentage,
        wireLength: feeBreakdown.wireLength,
        wireChargePerMeter: feeBreakdown.wireChargePerMeter,
      );
    } catch (e) {
      return FeeCalculation(
        baseAmount: customAmount ?? 1000.0,
        extraCharges: extraCharges,
        wireCharges: 0.0,
        lateFees: 0.0,
        totalAmount: (customAmount ?? 1000.0) + extraCharges,
        hasLateFees: false,
        hasCurrentYearPayment: false,
        lateFeesPercentage: 10.0,
        wireLength: wireLength,
        wireChargePerMeter: 5.0,
      );
    }
  }

  /// Send notification to user about payment status change
  Future<void> _sendStatusChangeNotification(
    PaymentModel payment,
    PaymentStatus newStatus,
    String? rejectionReason,
  ) async {
    try {
      final user = await _userService.getUserById(payment.userId);
      if (user != null) {
        await _notificationService.notifyPaymentStatusChange(
          user: user,
          payment: payment,
          newStatus: newStatus,
          rejectionReason: rejectionReason,
        );
      }
    } catch (e) {
      // Handle notification errors gracefully - don't fail the payment update
      // In production, use proper logging instead of print
      // Logger.warning('Failed to send status change notification: $e');
    }
  }

  /// Calculate late fees for a specific payment using SettingsService
  Future<double> calculateLateFees({
    required String userId,
    required int paymentYear,
  }) async {
    try {
      final currentYear = DateTime.now().year;
      
      if (paymentYear >= currentYear) {
        return 0.0; // No late fees for current or future years
      }

      // Get the original payment amount for that year
      final paymentQuery = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('year', isEqualTo: paymentYear)
          .limit(1)
          .get();

      if (paymentQuery.docs.isEmpty) {
        return 0.0; // No payment record found
      }

      final payment = PaymentModel.fromFirestore(paymentQuery.docs.first);
      final yearsDifference = currentYear - paymentYear;
      
      // Use SettingsService for late fees calculation
      return await _settingsService.calculateLateFees(
        originalAmount: payment.totalAmount,
        yearsOverdue: yearsDifference,
      );
    } catch (e) {
      return 0.0;
    }
  }

  /// Get payment statistics for admin dashboard
  Future<PaymentStatistics> getPaymentStatistics() async {
    try {
      final currentYear = DateTime.now().year;
      
      // Get all payments for current year
      final currentYearQuery = await _firestore
          .collection('payments')
          .where('year', isEqualTo: currentYear)
          .get();

      int totalPayments = currentYearQuery.docs.length;
      int approvedPayments = 0;
      int pendingPayments = 0;
      int rejectedPayments = 0;
      double totalRevenue = 0.0;
      double pendingAmount = 0.0;

      for (final doc in currentYearQuery.docs) {
        final payment = PaymentModel.fromFirestore(doc);
        
        switch (payment.status) {
          case PaymentStatus.APPROVED:
            approvedPayments++;
            totalRevenue += payment.totalAmount;
            break;
          case PaymentStatus.PENDING:
            pendingPayments++;
            pendingAmount += payment.totalAmount;
            break;
          case PaymentStatus.REJECTED:
            rejectedPayments++;
            break;
          case PaymentStatus.INCOMPLETE:
            // Skip incomplete payments in statistics
            break;
        }
      }

      // Get overdue payments (previous years, not approved)
      final overdueQuery = await _firestore
          .collection('payments')
          .where('year', isLessThan: currentYear)
          .where('status', whereIn: [PaymentStatus.PENDING.name, PaymentStatus.REJECTED.name])
          .get();

      final overduePayments = overdueQuery.docs.length;

      return PaymentStatistics(
        totalPayments: totalPayments,
        approvedPayments: approvedPayments,
        pendingPayments: pendingPayments,
        rejectedPayments: rejectedPayments,
        overduePayments: overduePayments,
        totalRevenue: totalRevenue,
        pendingAmount: pendingAmount,
        currentYear: currentYear,
      );
    } catch (e) {
      return PaymentStatistics(
        totalPayments: 0,
        approvedPayments: 0,
        pendingPayments: 0,
        rejectedPayments: 0,
        overduePayments: 0,
        totalRevenue: 0.0,
        pendingAmount: 0.0,
        currentYear: DateTime.now().year,
      );
    }
  }

  /// Get all payments for a specific user
  Future<List<PaymentModel>> getPaymentsByUserId(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PaymentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get payments for user: $e');
    }
  }
}

/// Payment processing result
class PaymentResult {
  final bool success;
  final String? paymentId;
  final PaymentModel? payment;
  final String? message;
  final String? error;

  PaymentResult({
    required this.success,
    this.paymentId,
    this.payment,
    this.message,
    this.error,
  });
}

/// UPI payment result
class UPIPaymentResult {
  final bool success;
  final String? paymentId;
  final upi.UPIResult? upiResult;
  final String? error;

  UPIPaymentResult({
    required this.success,
    this.paymentId,
    this.upiResult,
    this.error,
  });
}

/// Wallet payment result
class WalletPaymentResult {
  final bool success;
  final String? paymentId;
  final String? transactionId;
  final double? newBalance;
  final double? currentBalance;
  final double? requiredAmount;
  final String? message;
  final String? error;

  WalletPaymentResult({
    required this.success,
    this.paymentId,
    this.transactionId,
    this.newBalance,
    this.currentBalance,
    this.requiredAmount,
    this.message,
    this.error,
  });
}

/// Combined payment result
class CombinedPaymentResult {
  final bool success;
  final String? paymentId;
  final double? walletAmount;
  final double? upiAmount;
  final String? walletTransactionId;
  final double? newWalletBalance;
  final upi.UPIResult? upiResult;
  final String? message;
  final String? error;

  CombinedPaymentResult({
    required this.success,
    this.paymentId,
    this.walletAmount,
    this.upiAmount,
    this.walletTransactionId,
    this.newWalletBalance,
    this.upiResult,
    this.message,
    this.error,
  });
}

/// Fee calculation result
class FeeCalculation {
  final double baseAmount;
  final double extraCharges;
  final double wireCharges;
  final double lateFees;
  final double totalAmount;
  final bool hasLateFees;
  final bool hasCurrentYearPayment;
  final double lateFeesPercentage;
  final double? wireLength;
  final double wireChargePerMeter;

  FeeCalculation({
    required this.baseAmount,
    required this.extraCharges,
    required this.wireCharges,
    required this.lateFees,
    required this.totalAmount,
    required this.hasLateFees,
    required this.hasCurrentYearPayment,
    required this.lateFeesPercentage,
    this.wireLength,
    required this.wireChargePerMeter,
  });

  @override
  String toString() {
    return 'FeeCalculation{baseAmount: $baseAmount, extraCharges: $extraCharges, wireCharges: $wireCharges, lateFees: $lateFees, totalAmount: $totalAmount}';
  }
}

/// Payment update result
class PaymentUpdateResult {
  final bool success;
  final String? paymentId;
  final PaymentStatus? newStatus;
  final String? message;
  final String? error;

  PaymentUpdateResult({
    required this.success,
    this.paymentId,
    this.newStatus,
    this.message,
    this.error,
  });
}

/// Payment statistics for admin dashboard
class PaymentStatistics {
  final int totalPayments;
  final int approvedPayments;
  final int pendingPayments;
  final int rejectedPayments;
  final int overduePayments;
  final double totalRevenue;
  final double pendingAmount;
  final int currentYear;

  PaymentStatistics({
    required this.totalPayments,
    required this.approvedPayments,
    required this.pendingPayments,
    required this.rejectedPayments,
    required this.overduePayments,
    required this.totalRevenue,
    required this.pendingAmount,
    required this.currentYear,
  });

  double get approvalRate => totalPayments > 0 ? (approvedPayments / totalPayments) * 100 : 0.0;
  double get pendingRate => totalPayments > 0 ? (pendingPayments / totalPayments) * 100 : 0.0;
  
  @override
  String toString() {
    return 'PaymentStatistics{total: $totalPayments, approved: $approvedPayments, pending: $pendingPayments, revenue: $totalRevenue}';
  }
}
