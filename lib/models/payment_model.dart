import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethod { 
  UPI, 
  CASH, 
  WALLET, 
  COMBINED,
  CASHFREE_CARD,
  CASHFREE_UPI,
  CASHFREE_NETBANKING,
  CASHFREE_WALLET
}

enum PaymentStatus { PENDING, APPROVED, REJECTED, INCOMPLETE }

class PaymentModel {
  final String id;
  final String userId;
  final double amount;
  final double extraCharges;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? transactionId;
  final String? screenshotUrl;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String receiptNumber;
  final int year;
  final double? walletAmountUsed;
  final double? upiAmountPaid;
  final DateTime? servicePeriodStart;
  final DateTime? servicePeriodEnd;
  final double? lateFees;
  final double? wireCharges;
  final String? notes;
  final String? upiTransactionId;
  final DateTime? paidAt;
  final String? userFirebaseUid;
  
  // Cashfree-specific fields
  final String? cashfreeOrderId;
  final String? cashfreePaymentId;
  final String? cashfreeSessionId;
  final String? paymentGateway;
  final String? bankReference;
  final Map<String, dynamic>? gatewayResponse;

  PaymentModel({
    required this.id,
    required this.userId,
    required this.amount,
    this.extraCharges = 0.0,
    required this.method,
    this.status = PaymentStatus.PENDING,
    this.transactionId,
    this.screenshotUrl,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    required this.receiptNumber,
    required this.year,
    this.walletAmountUsed,
    this.upiAmountPaid,
    this.servicePeriodStart,
    this.servicePeriodEnd,
    this.lateFees,
    this.wireCharges,
    this.notes,
    this.upiTransactionId,
    this.paidAt,
    this.userFirebaseUid,
    this.cashfreeOrderId,
    this.cashfreePaymentId,
    this.cashfreeSessionId,
    this.paymentGateway,
    this.bankReference,
    this.gatewayResponse,
  });

  // Validation methods
  static String? validateAmount(double? amount) {
    if (amount == null || amount <= 0) {
      return 'Amount must be greater than 0';
    }
    if (amount > 100000) {
      return 'Amount cannot exceed ₹1,00,000';
    }
    return null;
  }

  static String? validateExtraCharges(double? extraCharges) {
    if (extraCharges == null) return null;
    if (extraCharges < 0) {
      return 'Extra charges cannot be negative';
    }
    if (extraCharges > 50000) {
      return 'Extra charges cannot exceed ₹50,000';
    }
    return null;
  }

  static String? validateTransactionId(String? transactionId, PaymentMethod method) {
    if (method == PaymentMethod.UPI || method == PaymentMethod.COMBINED) {
      if (transactionId == null || transactionId.trim().isEmpty) {
        return 'Transaction ID is required for UPI payments';
      }
      if (transactionId.trim().length < 8) {
        return 'Transaction ID must be at least 8 characters';
      }
      if (transactionId.trim().length > 50) {
        return 'Transaction ID must be less than 50 characters';
      }
      // Basic alphanumeric validation
      final transactionRegex = RegExp(r'^[a-zA-Z0-9]+$');
      if (!transactionRegex.hasMatch(transactionId.trim())) {
        return 'Transaction ID can only contain letters and numbers';
      }
    }
    return null;
  }

  static String? validateYear(int? year) {
    if (year == null) {
      return 'Year is required';
    }
    final currentYear = DateTime.now().year;
    if (year < 2020 || year > currentYear + 1) {
      return 'Invalid year selection';
    }
    return null;
  }

  static String? validateUserId(String? userId) {
    if (userId == null || userId.trim().isEmpty) {
      return 'User ID is required';
    }
    return null;
  }

  static String? validateReceiptNumber(String? receiptNumber) {
    if (receiptNumber == null || receiptNumber.trim().isEmpty) {
      return 'Receipt number is required';
    }
    // Receipt number format: RCP2024001
    final receiptRegex = RegExp(r'^RCP\d{4}\d{3,6}$');
    if (!receiptRegex.hasMatch(receiptNumber)) {
      return 'Invalid receipt number format';
    }
    return null;
  }

  // Cashfree-specific validation methods
  static String? validateCashfreeOrderId(String? orderId) {
    if (orderId == null || orderId.trim().isEmpty) {
      return null; // Optional field
    }
    if (orderId.trim().length < 3) {
      return 'Cashfree order ID must be at least 3 characters';
    }
    if (orderId.trim().length > 50) {
      return 'Cashfree order ID must be less than 50 characters';
    }
    // Allow alphanumeric characters, hyphens, and underscores
    final orderIdRegex = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!orderIdRegex.hasMatch(orderId.trim())) {
      return 'Cashfree order ID can only contain letters, numbers, hyphens, and underscores';
    }
    return null;
  }

  static String? validateCashfreePaymentId(String? paymentId) {
    if (paymentId == null || paymentId.trim().isEmpty) {
      return null; // Optional field
    }
    if (paymentId.trim().length < 10) {
      return 'Cashfree payment ID must be at least 10 characters';
    }
    if (paymentId.trim().length > 100) {
      return 'Cashfree payment ID must be less than 100 characters';
    }
    return null;
  }

  static String? validateCashfreeSessionId(String? sessionId) {
    if (sessionId == null || sessionId.trim().isEmpty) {
      return null; // Optional field
    }
    if (sessionId.trim().length < 10) {
      return 'Cashfree session ID must be at least 10 characters';
    }
    if (sessionId.trim().length > 200) {
      return 'Cashfree session ID must be less than 200 characters';
    }
    return null;
  }

  static String? validatePaymentGateway(String? gateway) {
    if (gateway == null || gateway.trim().isEmpty) {
      return null; // Optional field
    }
    final validGateways = ['cashfree', 'razorpay', 'payu', 'stripe'];
    if (!validGateways.contains(gateway.toLowerCase())) {
      return 'Invalid payment gateway';
    }
    return null;
  }

  static String? validateBankReference(String? bankReference) {
    if (bankReference == null || bankReference.trim().isEmpty) {
      return null; // Optional field
    }
    if (bankReference.trim().length < 5) {
      return 'Bank reference must be at least 5 characters';
    }
    if (bankReference.trim().length > 100) {
      return 'Bank reference must be less than 100 characters';
    }
    return null;
  }

  static String? validateGatewayResponse(Map<String, dynamic>? gatewayResponse) {
    if (gatewayResponse == null || gatewayResponse.isEmpty) {
      return null; // Optional field
    }
    // Basic validation - ensure it's a valid map structure
    try {
      // Check if the map can be serialized (basic validation)
      gatewayResponse.toString();
      return null;
    } catch (e) {
      return 'Invalid gateway response format';
    }
  }

  // Validation for Cashfree payment methods
  static String? validateCashfreePaymentMethod(PaymentMethod method, String? cashfreeOrderId, String? cashfreeSessionId) {
    final cashfreeMethods = [
      PaymentMethod.CASHFREE_CARD,
      PaymentMethod.CASHFREE_UPI,
      PaymentMethod.CASHFREE_NETBANKING,
      PaymentMethod.CASHFREE_WALLET
    ];
    
    if (cashfreeMethods.contains(method)) {
      if (cashfreeOrderId == null || cashfreeOrderId.trim().isEmpty) {
        return 'Cashfree order ID is required for Cashfree payment methods';
      }
      if (cashfreeSessionId == null || cashfreeSessionId.trim().isEmpty) {
        return 'Cashfree session ID is required for Cashfree payment methods';
      }
    }
    return null;
  }

  // Validation for the entire payment model
  Map<String, String> validate() {
    final errors = <String, String>{};
    
    final userIdError = validateUserId(userId);
    if (userIdError != null) errors['userId'] = userIdError;
    
    final amountError = validateAmount(amount);
    if (amountError != null) errors['amount'] = amountError;
    
    final extraChargesError = validateExtraCharges(extraCharges);
    if (extraChargesError != null) errors['extraCharges'] = extraChargesError;
    
    final transactionIdError = validateTransactionId(transactionId, method);
    if (transactionIdError != null) errors['transactionId'] = transactionIdError;
    
    final yearError = validateYear(year);
    if (yearError != null) errors['year'] = yearError;
    
    final receiptError = validateReceiptNumber(receiptNumber);
    if (receiptError != null) errors['receiptNumber'] = receiptError;
    
    // Validate Cashfree-specific fields
    final cashfreeOrderIdError = validateCashfreeOrderId(cashfreeOrderId);
    if (cashfreeOrderIdError != null) errors['cashfreeOrderId'] = cashfreeOrderIdError;
    
    final cashfreePaymentIdError = validateCashfreePaymentId(cashfreePaymentId);
    if (cashfreePaymentIdError != null) errors['cashfreePaymentId'] = cashfreePaymentIdError;
    
    final cashfreeSessionIdError = validateCashfreeSessionId(cashfreeSessionId);
    if (cashfreeSessionIdError != null) errors['cashfreeSessionId'] = cashfreeSessionIdError;
    
    final paymentGatewayError = validatePaymentGateway(paymentGateway);
    if (paymentGatewayError != null) errors['paymentGateway'] = paymentGatewayError;
    
    final bankReferenceError = validateBankReference(bankReference);
    if (bankReferenceError != null) errors['bankReference'] = bankReferenceError;
    
    final gatewayResponseError = validateGatewayResponse(gatewayResponse);
    if (gatewayResponseError != null) errors['gatewayResponse'] = gatewayResponseError;
    
    final cashfreeMethodError = validateCashfreePaymentMethod(method, cashfreeOrderId, cashfreeSessionId);
    if (cashfreeMethodError != null) errors['cashfreeMethod'] = cashfreeMethodError;
    
    // Validate combined payment amounts
    if (method == PaymentMethod.COMBINED) {
      if (walletAmountUsed == null || upiAmountPaid == null) {
        errors['combinedPayment'] = 'Wallet and UPI amounts are required for combined payments';
      } else {
        final totalPaid = walletAmountUsed! + upiAmountPaid!;
        final totalRequired = amount + extraCharges;
        if ((totalPaid - totalRequired).abs() > 0.01) { // Allow for floating point precision
          errors['combinedPayment'] = 'Total payment amount does not match required amount';
        }
      }
    }
    
    // Validate wallet amount
    if (walletAmountUsed != null && walletAmountUsed! < 0) {
      errors['walletAmountUsed'] = 'Wallet amount cannot be negative';
    }
    
    // Validate UPI amount
    if (upiAmountPaid != null && upiAmountPaid! < 0) {
      errors['upiAmountPaid'] = 'UPI amount cannot be negative';
    }
    
    return errors;
  }

  bool get isValid => validate().isEmpty;

  // Computed properties
  double get totalAmount => amount + extraCharges;
  
  bool get isPending => status == PaymentStatus.PENDING;
  bool get isApproved => status == PaymentStatus.APPROVED;
  bool get isRejected => status == PaymentStatus.REJECTED;
  
  bool get requiresApproval => method == PaymentMethod.UPI || method == PaymentMethod.COMBINED;
  
  // Cashfree-specific computed properties
  bool get isCashfreePayment => [
    PaymentMethod.CASHFREE_CARD,
    PaymentMethod.CASHFREE_UPI,
    PaymentMethod.CASHFREE_NETBANKING,
    PaymentMethod.CASHFREE_WALLET
  ].contains(method);
  
  bool get hasCashfreeData => cashfreeOrderId != null || cashfreePaymentId != null || cashfreeSessionId != null;
  
  bool get isCompleteCashfreePayment => isCashfreePayment && 
      cashfreeOrderId != null && 
      cashfreePaymentId != null && 
      cashfreeSessionId != null;
  
  String get statusDisplayText {
    switch (status) {
      case PaymentStatus.PENDING:
        return 'Pending Approval';
      case PaymentStatus.APPROVED:
        return 'Approved';
      case PaymentStatus.REJECTED:
        return 'Rejected';
      case PaymentStatus.INCOMPLETE:
        return 'Incomplete';
    }
  }

  String get methodDisplayText {
    switch (method) {
      case PaymentMethod.UPI:
        return 'UPI Payment';
      case PaymentMethod.CASH:
        return 'Cash Payment';
      case PaymentMethod.WALLET:
        return 'Wallet Payment';
      case PaymentMethod.COMBINED:
        return 'Wallet + UPI';
      case PaymentMethod.CASHFREE_CARD:
        return 'Card Payment (Cashfree)';
      case PaymentMethod.CASHFREE_UPI:
        return 'UPI Payment (Cashfree)';
      case PaymentMethod.CASHFREE_NETBANKING:
        return 'Net Banking (Cashfree)';
      case PaymentMethod.CASHFREE_WALLET:
        return 'Wallet Payment (Cashfree)';
    }
  }

  String get paymentMethod => method.name;

  // Factory constructor from Firestore document
  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      extraCharges: (data['extraCharges'] ?? 0.0).toDouble(),
      method: PaymentMethod.values.firstWhere(
        (method) => method.toString().split('.').last == data['method'],
        orElse: () => PaymentMethod.UPI,
      ),
      status: PaymentStatus.values.firstWhere(
        (status) => status.toString().split('.').last == data['status'],
        orElse: () => PaymentStatus.PENDING,
      ),
      transactionId: data['transactionId'],
      screenshotUrl: data['screenshotUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'],
      receiptNumber: data['receiptNumber'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      walletAmountUsed: data['walletAmountUsed']?.toDouble(),
      upiAmountPaid: data['upiAmountPaid']?.toDouble(),
    );
  }

  // Factory constructor from Supabase response
  factory PaymentModel.fromSupabase(Map<String, dynamic> data) {
    return PaymentModel(
      id: data['id'] ?? '',
      userId: data['user_id'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      extraCharges: (data['extra_charges'] ?? 0.0).toDouble(),
      method: PaymentMethod.values.firstWhere(
        (method) => method.name.toUpperCase() == (data['payment_method'] ?? 'UPI').toString().toUpperCase(),
        orElse: () => PaymentMethod.UPI,
      ),
      status: PaymentStatus.values.firstWhere(
        (status) => status.name.toUpperCase() == (data['status'] ?? 'PENDING').toString().toUpperCase(),
        orElse: () => PaymentStatus.PENDING,
      ),
      transactionId: data['transaction_id'],
      screenshotUrl: data['screenshot_url'],
      createdAt: DateTime.parse(data['created_at'] ?? DateTime.now().toIso8601String()),
      approvedAt: data['approved_at'] != null
          ? DateTime.parse(data['approved_at'])
          : null,
      approvedBy: data['approved_by'],
      receiptNumber: data['receipt_number'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      walletAmountUsed: data['wallet_amount_used']?.toDouble(),
      upiAmountPaid: data['upi_amount_paid']?.toDouble(),
      servicePeriodStart: data['service_period_start'] != null 
          ? DateTime.parse(data['service_period_start'])
          : null,
      servicePeriodEnd: data['service_period_end'] != null 
          ? DateTime.parse(data['service_period_end'])
          : null,
      lateFees: data['late_fees']?.toDouble(),
      wireCharges: data['wire_charges']?.toDouble(),
      notes: data['notes'],
      upiTransactionId: data['upi_transaction_id'],
      paidAt: data['paid_at'] != null 
          ? DateTime.parse(data['paid_at'])
          : null,
      userFirebaseUid: data['user_firebase_uid'],
      cashfreeOrderId: data['cashfree_order_id'],
      cashfreePaymentId: data['cashfree_payment_id'],
      cashfreeSessionId: data['cashfree_session_id'],
      paymentGateway: data['payment_gateway'],
      bankReference: data['bank_reference'],
      gatewayResponse: data['gateway_response'] != null 
          ? Map<String, dynamic>.from(data['gateway_response'])
          : null,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'amount': amount,
      'extraCharges': extraCharges,
      'method': method.toString().split('.').last,
      'status': status.toString().split('.').last,
      'transactionId': transactionId,
      'screenshotUrl': screenshotUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'receiptNumber': receiptNumber,
      'year': year,
      'walletAmountUsed': walletAmountUsed,
      'upiAmountPaid': upiAmountPaid,
    };
  }

  // Convert to Supabase format
  Map<String, dynamic> toSupabase() {
    final data = <String, dynamic>{
      'user_id': userId,
      'amount': amount,
      'extra_charges': extraCharges,
      'payment_method': method.name.toUpperCase(),
      'status': status.name.toUpperCase(),
      'transaction_id': transactionId,
      'screenshot_url': screenshotUrl,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
      'receipt_number': receiptNumber,
      'year': year,
      'wallet_amount_used': walletAmountUsed,
      'upi_amount_paid': upiAmountPaid,
      'service_period_start': servicePeriodStart?.toIso8601String(),
      'service_period_end': servicePeriodEnd?.toIso8601String(),
      'late_fees': lateFees,
      'wire_charges': wireCharges,
      'notes': notes,
      'upi_transaction_id': upiTransactionId,
      'paid_at': paidAt?.toIso8601String(),
      'user_firebase_uid': userFirebaseUid,
      'cashfree_order_id': cashfreeOrderId,
      'cashfree_payment_id': cashfreePaymentId,
      'cashfree_session_id': cashfreeSessionId,
      'payment_gateway': paymentGateway,
      'bank_reference': bankReference,
      'gateway_response': gatewayResponse,
    };

    // Only include id if it's not empty (for updates)
    if (id.isNotEmpty) {
      data['id'] = id;
    }

    return data;
  }

  // Copy with method for immutable updates
  PaymentModel copyWith({
    String? id,
    String? userId,
    double? amount,
    double? extraCharges,
    PaymentMethod? method,
    PaymentStatus? status,
    String? transactionId,
    String? screenshotUrl,
    DateTime? createdAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? receiptNumber,
    int? year,
    double? walletAmountUsed,
    double? upiAmountPaid,
    DateTime? servicePeriodStart,
    DateTime? servicePeriodEnd,
    double? lateFees,
    double? wireCharges,
    String? notes,
    String? upiTransactionId,
    DateTime? paidAt,
    String? userFirebaseUid,
    String? cashfreeOrderId,
    String? cashfreePaymentId,
    String? cashfreeSessionId,
    String? paymentGateway,
    String? bankReference,
    Map<String, dynamic>? gatewayResponse,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      extraCharges: extraCharges ?? this.extraCharges,
      method: method ?? this.method,
      status: status ?? this.status,
      transactionId: transactionId ?? this.transactionId,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      year: year ?? this.year,
      walletAmountUsed: walletAmountUsed ?? this.walletAmountUsed,
      upiAmountPaid: upiAmountPaid ?? this.upiAmountPaid,
      servicePeriodStart: servicePeriodStart ?? this.servicePeriodStart,
      servicePeriodEnd: servicePeriodEnd ?? this.servicePeriodEnd,
      lateFees: lateFees ?? this.lateFees,
      wireCharges: wireCharges ?? this.wireCharges,
      notes: notes ?? this.notes,
      upiTransactionId: upiTransactionId ?? this.upiTransactionId,
      paidAt: paidAt ?? this.paidAt,
      userFirebaseUid: userFirebaseUid ?? this.userFirebaseUid,
      cashfreeOrderId: cashfreeOrderId ?? this.cashfreeOrderId,
      cashfreePaymentId: cashfreePaymentId ?? this.cashfreePaymentId,
      cashfreeSessionId: cashfreeSessionId ?? this.cashfreeSessionId,
      paymentGateway: paymentGateway ?? this.paymentGateway,
      bankReference: bankReference ?? this.bankReference,
      gatewayResponse: gatewayResponse ?? this.gatewayResponse,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          amount == other.amount &&
          extraCharges == other.extraCharges &&
          method == other.method &&
          status == other.status &&
          transactionId == other.transactionId &&
          screenshotUrl == other.screenshotUrl &&
          createdAt == other.createdAt &&
          approvedAt == other.approvedAt &&
          approvedBy == other.approvedBy &&
          receiptNumber == other.receiptNumber &&
          year == other.year &&
          walletAmountUsed == other.walletAmountUsed &&
          upiAmountPaid == other.upiAmountPaid &&
          servicePeriodStart == other.servicePeriodStart &&
          servicePeriodEnd == other.servicePeriodEnd &&
          lateFees == other.lateFees &&
          wireCharges == other.wireCharges &&
          notes == other.notes &&
          upiTransactionId == other.upiTransactionId &&
          paidAt == other.paidAt &&
          userFirebaseUid == other.userFirebaseUid &&
          cashfreeOrderId == other.cashfreeOrderId &&
          cashfreePaymentId == other.cashfreePaymentId &&
          cashfreeSessionId == other.cashfreeSessionId &&
          paymentGateway == other.paymentGateway &&
          bankReference == other.bankReference;

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      amount.hashCode ^
      extraCharges.hashCode ^
      method.hashCode ^
      status.hashCode ^
      transactionId.hashCode ^
      screenshotUrl.hashCode ^
      createdAt.hashCode ^
      approvedAt.hashCode ^
      approvedBy.hashCode ^
      receiptNumber.hashCode ^
      year.hashCode ^
      walletAmountUsed.hashCode ^
      upiAmountPaid.hashCode ^
      servicePeriodStart.hashCode ^
      servicePeriodEnd.hashCode ^
      lateFees.hashCode ^
      wireCharges.hashCode ^
      notes.hashCode ^
      upiTransactionId.hashCode ^
      paidAt.hashCode ^
      userFirebaseUid.hashCode ^
      cashfreeOrderId.hashCode ^
      cashfreePaymentId.hashCode ^
      cashfreeSessionId.hashCode ^
      paymentGateway.hashCode ^
      bankReference.hashCode;

  @override
  String toString() {
    return 'PaymentModel{id: $id, userId: $userId, amount: $amount, method: $method, status: $status}';
  }
}