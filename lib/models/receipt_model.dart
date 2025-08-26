import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptModel {
  final String id;
  final String paymentId;
  final String receiptNumber;
  final String pdfUrl;
  final DateTime generatedAt;
  final String language;
  final String userId;
  final double amount;
  final double extraCharges;
  final String paymentMethod;
  final int year;
  
  // Cashfree-specific fields
  final String? cashfreeOrderId;
  final String? cashfreePaymentId;
  final String? cashfreeSessionId;
  final String? paymentGateway;
  final String? bankReference;
  final Map<String, dynamic>? gatewayResponse;

  ReceiptModel({
    required this.id,
    required this.paymentId,
    required this.receiptNumber,
    required this.pdfUrl,
    required this.generatedAt,
    required this.language,
    required this.userId,
    required this.amount,
    this.extraCharges = 0.0,
    required this.paymentMethod,
    required this.year,
    this.cashfreeOrderId,
    this.cashfreePaymentId,
    this.cashfreeSessionId,
    this.paymentGateway,
    this.bankReference,
    this.gatewayResponse,
  });

  // Validation methods
  static String? validatePaymentId(String? paymentId) {
    if (paymentId == null || paymentId.trim().isEmpty) {
      return 'Payment ID is required';
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

  static String? validatePdfUrl(String? pdfUrl) {
    if (pdfUrl == null || pdfUrl.trim().isEmpty) {
      return 'PDF URL is required';
    }
    // Basic URL validation
    final urlRegex = RegExp(r'^https?://');
    if (!urlRegex.hasMatch(pdfUrl)) {
      return 'Invalid PDF URL format';
    }
    return null;
  }

  static String? validateLanguage(String? language) {
    const supportedLanguages = ['en', 'gu'];
    if (language == null || !supportedLanguages.contains(language)) {
      return 'Invalid language selection';
    }
    return null;
  }

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

  static String? validatePaymentMethod(String? paymentMethod) {
    const validMethods = [
      'UPI', 
      'CASH', 
      'WALLET', 
      'COMBINED',
      'CASHFREE_CARD',
      'CASHFREE_UPI',
      'CASHFREE_NETBANKING',
      'CASHFREE_WALLET'
    ];
    if (paymentMethod == null || !validMethods.contains(paymentMethod)) {
      return 'Invalid payment method';
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

  // Validation for the entire receipt model
  Map<String, String> validate() {
    final errors = <String, String>{};
    
    final paymentIdError = validatePaymentId(paymentId);
    if (paymentIdError != null) errors['paymentId'] = paymentIdError;
    
    final receiptNumberError = validateReceiptNumber(receiptNumber);
    if (receiptNumberError != null) errors['receiptNumber'] = receiptNumberError;
    
    final pdfUrlError = validatePdfUrl(pdfUrl);
    if (pdfUrlError != null) errors['pdfUrl'] = pdfUrlError;
    
    final languageError = validateLanguage(language);
    if (languageError != null) errors['language'] = languageError;
    
    final userIdError = validateUserId(userId);
    if (userIdError != null) errors['userId'] = userIdError;
    
    final amountError = validateAmount(amount);
    if (amountError != null) errors['amount'] = amountError;
    
    final extraChargesError = validateExtraCharges(extraCharges);
    if (extraChargesError != null) errors['extraCharges'] = extraChargesError;
    
    final paymentMethodError = validatePaymentMethod(paymentMethod);
    if (paymentMethodError != null) errors['paymentMethod'] = paymentMethodError;
    
    final yearError = validateYear(year);
    if (yearError != null) errors['year'] = yearError;
    
    // Validate Cashfree-specific fields
    final cashfreeOrderIdError = validateCashfreeOrderId(cashfreeOrderId);
    if (cashfreeOrderIdError != null) errors['cashfreeOrderId'] = cashfreeOrderIdError;
    
    final cashfreePaymentIdError = validateCashfreePaymentId(cashfreePaymentId);
    if (cashfreePaymentIdError != null) errors['cashfreePaymentId'] = cashfreePaymentIdError;
    
    final paymentGatewayError = validatePaymentGateway(paymentGateway);
    if (paymentGatewayError != null) errors['paymentGateway'] = paymentGatewayError;
    
    return errors;
  }

  bool get isValid => validate().isEmpty;

  // Computed properties
  double get totalAmount => amount + extraCharges;
  
  String get formattedReceiptNumber => receiptNumber;
  
  String get languageDisplayName {
    switch (language) {
      case 'en':
        return 'English';
      case 'gu':
        return 'Gujarati';
      default:
        return 'Unknown';
    }
  }

  String get paymentMethodDisplayText {
    switch (paymentMethod) {
      case 'UPI':
        return 'UPI Payment';
      case 'CASH':
        return 'Cash Payment';
      case 'WALLET':
        return 'Wallet Payment';
      case 'COMBINED':
        return 'Wallet + UPI';
      case 'CASHFREE_CARD':
        return 'Card Payment (Cashfree)';
      case 'CASHFREE_UPI':
        return 'UPI Payment (Cashfree)';
      case 'CASHFREE_NETBANKING':
        return 'Net Banking (Cashfree)';
      case 'CASHFREE_WALLET':
        return 'Wallet Payment (Cashfree)';
      default:
        return paymentMethod;
    }
  }

  // Cashfree-specific computed properties
  bool get isCashfreePayment => paymentGateway?.toLowerCase() == 'cashfree' || 
      paymentMethod.startsWith('CASHFREE_');
  
  bool get hasCashfreeData => cashfreeOrderId != null || 
      cashfreePaymentId != null || 
      cashfreeSessionId != null;
  
  String? get primaryTransactionId => cashfreePaymentId ?? cashfreeOrderId;

  // Generate a unique receipt number
  static String generateReceiptNumber(int year, int sequenceNumber) {
    return 'RCP$year${sequenceNumber.toString().padLeft(3, '0')}';
  }

  // Extract year from receipt number
  int get receiptYear {
    final match = RegExp(r'RCP(\d{4})').firstMatch(receiptNumber);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return year;
  }

  // Extract sequence number from receipt number
  int get sequenceNumber {
    final match = RegExp(r'RCP\d{4}(\d+)').firstMatch(receiptNumber);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
    return 0;
  }

  // Factory constructor from Firestore document
  factory ReceiptModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReceiptModel(
      id: doc.id,
      paymentId: data['paymentId'] ?? '',
      receiptNumber: data['receiptNumber'] ?? '',
      pdfUrl: data['pdfUrl'] ?? '',
      generatedAt: (data['generatedAt'] as Timestamp).toDate(),
      language: data['language'] ?? 'en',
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      extraCharges: (data['extraCharges'] ?? 0.0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      cashfreeOrderId: data['cashfreeOrderId'],
      cashfreePaymentId: data['cashfreePaymentId'],
      cashfreeSessionId: data['cashfreeSessionId'],
      paymentGateway: data['paymentGateway'],
      bankReference: data['bankReference'],
      gatewayResponse: data['gatewayResponse'] != null 
          ? Map<String, dynamic>.from(data['gatewayResponse'])
          : null,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'paymentId': paymentId,
      'receiptNumber': receiptNumber,
      'pdfUrl': pdfUrl,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'language': language,
      'userId': userId,
      'amount': amount,
      'extraCharges': extraCharges,
      'paymentMethod': paymentMethod,
      'year': year,
      'cashfreeOrderId': cashfreeOrderId,
      'cashfreePaymentId': cashfreePaymentId,
      'cashfreeSessionId': cashfreeSessionId,
      'paymentGateway': paymentGateway,
      'bankReference': bankReference,
      'gatewayResponse': gatewayResponse,
    };
  }

  // Create from Supabase row
  factory ReceiptModel.fromSupabase(Map<String, dynamic> data) {
    return ReceiptModel(
      id: data['id']?.toString() ?? '',
      paymentId: data['payment_id'] ?? '',
      receiptNumber: data['receipt_number'] ?? '',
      pdfUrl: data['pdf_url'] ?? '',
      generatedAt: DateTime.parse(data['generated_at']),
      language: data['language'] ?? 'en',
      userId: data['user_firebase_uid'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      extraCharges: (data['extra_charges'] ?? 0.0).toDouble(),
      paymentMethod: data['payment_method'] ?? '',
      year: data['year'] ?? DateTime.now().year,
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

  // Convert to Supabase row
  Map<String, dynamic> toSupabase() {
    return {
      'payment_id': paymentId,
      'receipt_number': receiptNumber,
      'pdf_url': pdfUrl,
      'generated_at': generatedAt.toIso8601String(),
      'language': language,
      'user_firebase_uid': userId,
      'amount': amount,
      'extra_charges': extraCharges,
      'payment_method': paymentMethod,
      'year': year,
    };
  }

  // Copy with method for immutable updates
  ReceiptModel copyWith({
    String? id,
    String? paymentId,
    String? receiptNumber,
    String? pdfUrl,
    DateTime? generatedAt,
    String? language,
    String? userId,
    double? amount,
    double? extraCharges,
    String? paymentMethod,
    int? year,
  }) {
    return ReceiptModel(
      id: id ?? this.id,
      paymentId: paymentId ?? this.paymentId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      generatedAt: generatedAt ?? this.generatedAt,
      language: language ?? this.language,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      extraCharges: extraCharges ?? this.extraCharges,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      year: year ?? this.year,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceiptModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          paymentId == other.paymentId &&
          receiptNumber == other.receiptNumber &&
          pdfUrl == other.pdfUrl &&
          generatedAt == other.generatedAt &&
          language == other.language &&
          userId == other.userId &&
          amount == other.amount &&
          extraCharges == other.extraCharges &&
          paymentMethod == other.paymentMethod &&
          year == other.year;

  @override
  int get hashCode =>
      id.hashCode ^
      paymentId.hashCode ^
      receiptNumber.hashCode ^
      pdfUrl.hashCode ^
      generatedAt.hashCode ^
      language.hashCode ^
      userId.hashCode ^
      amount.hashCode ^
      extraCharges.hashCode ^
      paymentMethod.hashCode ^
      year.hashCode;

  @override
  String toString() {
    return 'ReceiptModel{id: $id, receiptNumber: $receiptNumber, paymentId: $paymentId, language: $language}';
  }
}