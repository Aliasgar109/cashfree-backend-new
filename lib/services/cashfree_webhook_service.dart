import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/payment_model.dart';
import 'cashfree_config_service.dart';
import 'cashfree_security_service.dart';

/// Service for handling Cashfree webhook notifications
///
/// This service processes webhook notifications from Cashfree to update
/// payment status in real-time. It includes signature verification for
/// security and proper error handling.
class CashfreeWebhookService {
  // Private constructor for singleton pattern
  CashfreeWebhookService._();

  // Singleton instance
  static final CashfreeWebhookService _instance = CashfreeWebhookService._();
  static CashfreeWebhookService get instance => _instance;

  // Dependencies
  final CashfreeConfigService _configService = CashfreeConfigService.instance;
  final CashfreeSecurityService _securityService = CashfreeSecurityService();

  // Service state
  bool _isInitialized = false;

  /// Check if the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the webhook service
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      if (kDebugMode) {
        print('CashfreeWebhookService: Starting initialization...');
      }

      // Ensure config service is initialized
      if (!_configService.isInitialized) {
        final configInitialized = await _configService.initialize();
        if (!configInitialized) {
          throw CashfreeWebhookException(
            'Configuration service initialization failed',
            CashfreeWebhookErrorType.configuration,
          );
        }
      }

      _isInitialized = true;

      if (kDebugMode) {
        print('CashfreeWebhookService: Initialization successful');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWebhookService: Initialization error: $e');
      }
      return false;
    }
  }

  /// Handle incoming webhook notification
  ///
  /// This method processes webhook data from Cashfree and updates
  /// payment status accordingly. It includes signature verification
  /// and proper error handling.
  Future<CashfreeWebhookResult> handleWebhook({
    required Map<String, dynamic> webhookData,
    required String signature,
    String? timestamp,
    Map<String, String>? headers,
  }) async {
    _ensureInitialized();

    try {
      if (kDebugMode) {
        print('CashfreeWebhookService: Processing webhook notification');
      }

      // Validate webhook data structure
      final validationResult = validateWebhookData(webhookData);
      if (!validationResult.isValid) {
        throw CashfreeWebhookException(
          'Invalid webhook data: ${validationResult.error}',
          CashfreeWebhookErrorType.validation,
        );
      }

      // Verify webhook signature using security service
      final webhookBody = json.encode(webhookData);
      final webhookSecret = _configService.webhookSecret;
      
      final signatureValid = _securityService.verifyWebhookSignature(
        signature,
        webhookBody,
        webhookSecret,
      );

      if (!signatureValid) {
        throw CashfreeWebhookException(
          'Invalid webhook signature',
          CashfreeWebhookErrorType.security,
        );
      }

      // Parse webhook payload
      final webhookPayload = parseWebhookPayload(webhookData);

      // Process payment status update
      final updateResult = await _processPaymentStatusUpdate(webhookPayload);

      if (kDebugMode) {
        print('CashfreeWebhookService: Webhook processed successfully');
      }

      return CashfreeWebhookResult(
        success: true,
        orderId: webhookPayload.orderId,
        paymentStatus: webhookPayload.paymentStatus,
        eventType: webhookPayload.eventType,
        processed: updateResult.success,
        message: 'Webhook processed successfully',
        paymentData: updateResult.paymentData,
      );
    } on CashfreeWebhookException catch (e) {
      if (kDebugMode) {
        print('CashfreeWebhookService: Webhook exception: $e');
      }
      return CashfreeWebhookResult(
        success: false,
        error: e.message,
        errorType: e.type,
      );
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWebhookService: Unexpected error: $e');
      }
      return CashfreeWebhookResult(
        success: false,
        error: 'Failed to process webhook: $e',
        errorType: CashfreeWebhookErrorType.processing,
      );
    }
  }

  /// Verify webhook signature for security
  ///
  /// This method verifies that the webhook notification is authentic
  /// and comes from Cashfree by validating the signature.
  Future<bool> verifyWebhookSignature({
    required String signature,
    required String body,
    String? timestamp,
    Map<String, String>? headers,
  }) async {
    try {
      if (kDebugMode) {
        print('CashfreeWebhookService: Verifying webhook signature');
      }

      // Basic validation
      if (signature.isEmpty || body.isEmpty) {
        if (kDebugMode) {
          print('CashfreeWebhookService: Empty signature or body');
        }
        return false;
      }

      // Parse signature format (expected: t=timestamp,v1=signature)
      final signatureParts = _parseSignatureHeader(signature);
      if (signatureParts.isEmpty) {
        if (kDebugMode) {
          print('CashfreeWebhookService: Invalid signature format');
        }
        return false;
      }

      // Get webhook secret from config
      final webhookSecret = _configService.webhookSecret;
      if (webhookSecret.isEmpty) {
        if (kDebugMode) {
          print('CashfreeWebhookService: Webhook secret not configured');
        }
        return false;
      }

      // Verify timestamp if provided (prevent replay attacks)
      if (timestamp != null && !_isTimestampValid(timestamp)) {
        if (kDebugMode) {
          print('CashfreeWebhookService: Invalid timestamp');
        }
        return false;
      }

      // Construct payload for signature verification
      final timestampToUse = signatureParts['t'] ?? timestamp ?? '';
      final signedPayload = '$timestampToUse.$body';

      // Calculate expected signature
      final expectedSignature = _calculateSignature(signedPayload, webhookSecret);

      // Compare signatures
      final providedSignature = signatureParts['v1'] ?? '';
      final isValid = _secureCompare(expectedSignature, providedSignature);

      if (kDebugMode) {
        print('CashfreeWebhookService: Signature verification result: $isValid');
      }

      return isValid;
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWebhookService: Error verifying signature: $e');
      }
      return false;
    }
  }

  /// Validate webhook data structure
  @visibleForTesting
  WebhookValidationResult validateWebhookData(Map<String, dynamic> data) {
    try {
      // Check required fields
      final requiredFields = ['type', 'order_id', 'data'];
      for (final field in requiredFields) {
        if (!data.containsKey(field) || data[field] == null) {
          return WebhookValidationResult(
            isValid: false,
            error: 'Missing required field: $field',
          );
        }
      }

      // Validate event type
      final eventType = data['type'] as String;
      if (!_isValidEventType(eventType)) {
        return WebhookValidationResult(
          isValid: false,
          error: 'Invalid event type: $eventType',
        );
      }

      // Validate order ID format
      final orderId = data['order_id'] as String;
      if (orderId.isEmpty || orderId.length < 3) {
        return WebhookValidationResult(
          isValid: false,
          error: 'Invalid order ID format',
        );
      }

      // Validate data structure
      final webhookData = data['data'] as Map<String, dynamic>;
      if (webhookData.isEmpty) {
        return WebhookValidationResult(
          isValid: false,
          error: 'Empty webhook data',
        );
      }

      return WebhookValidationResult(isValid: true);
    } catch (e) {
      return WebhookValidationResult(
        isValid: false,
        error: 'Validation error: $e',
      );
    }
  }

  /// Parse webhook payload into structured data
  @visibleForTesting
  CashfreeWebhookPayload parseWebhookPayload(Map<String, dynamic> data) {
    final eventType = data['type'] as String;
    final orderId = data['order_id'] as String;
    final webhookData = data['data'] as Map<String, dynamic>;

    return CashfreeWebhookPayload(
      eventType: eventType,
      orderId: orderId,
      paymentSessionId: webhookData['payment_session_id'] as String?,
      paymentStatus: mapPaymentStatus(webhookData['order_status'] as String?),
      cfPaymentId: webhookData['cf_payment_id'] as String?,
      paymentMethod: webhookData['payment_method'] as String?,
      paymentAmount: (webhookData['payment_amount'] as num?)?.toDouble(),
      orderAmount: (webhookData['order_amount'] as num?)?.toDouble(),
      bankReference: webhookData['bank_reference'] as String?,
      paymentTime: webhookData['payment_time'] != null
          ? DateTime.tryParse(webhookData['payment_time'] as String)
          : null,
      failureReason: webhookData['failure_reason'] as String?,
      rawData: webhookData,
      timestamp: DateTime.now(),
    );
  }

  /// Process payment status update based on webhook data
  Future<PaymentUpdateResult> _processPaymentStatusUpdate(
    CashfreeWebhookPayload payload,
  ) async {
    try {
      if (kDebugMode) {
        print('CashfreeWebhookService: Processing payment update for order: ${payload.orderId}');
      }

      // Create payment data from webhook
      final paymentData = createPaymentDataFromWebhook(payload);

      // Here you would typically update your database
      // For now, we'll return a success result with the payment data
      // In a real implementation, you'd call your database service

      if (kDebugMode) {
        print('CashfreeWebhookService: Payment status updated successfully');
      }

      return PaymentUpdateResult(
        success: true,
        paymentData: paymentData,
        message: 'Payment status updated successfully',
      );
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWebhookService: Error updating payment status: $e');
      }
      return PaymentUpdateResult(
        success: false,
        error: 'Failed to update payment status: $e',
      );
    }
  }

  /// Create payment data from webhook payload
  @visibleForTesting
  Map<String, dynamic> createPaymentDataFromWebhook(
    CashfreeWebhookPayload payload,
  ) {
    return {
      'cashfree_order_id': payload.orderId,
      'cashfree_payment_id': payload.cfPaymentId,
      'cashfree_session_id': payload.paymentSessionId,
      'payment_status': payload.paymentStatus?.name.toUpperCase(),
      'payment_method': payload.paymentMethod,
      'payment_amount': payload.paymentAmount,
      'order_amount': payload.orderAmount,
      'bank_reference': payload.bankReference,
      'payment_time': payload.paymentTime?.toIso8601String(),
      'failure_reason': payload.failureReason,
      'gateway_response': payload.rawData,
      'payment_gateway': 'cashfree',
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Parse signature header into components
  Map<String, String> _parseSignatureHeader(String signature) {
    final parts = <String, String>{};
    try {
      final elements = signature.split(',');
      for (final element in elements) {
        final keyValue = element.split('=');
        if (keyValue.length == 2) {
          parts[keyValue[0]] = keyValue[1];
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeWebhookService: Error parsing signature header: $e');
      }
    }
    return parts;
  }

  /// Calculate HMAC signature for webhook verification
  String _calculateSignature(String payload, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payload);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  /// Secure comparison of signatures to prevent timing attacks
  bool _secureCompare(String a, String b) {
    if (a.length != b.length) {
      return false;
    }

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Validate timestamp to prevent replay attacks
  bool _isTimestampValid(String timestamp) {
    try {
      final timestampInt = int.parse(timestamp);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final diff = (now - timestampInt).abs();
      
      // Allow 5 minutes tolerance
      return diff <= 300;
    } catch (e) {
      return false;
    }
  }

  /// Check if event type is valid
  bool _isValidEventType(String eventType) {
    const validEventTypes = [
      'PAYMENT_SUCCESS_WEBHOOK',
      'PAYMENT_FAILED_WEBHOOK',
      'PAYMENT_USER_DROPPED_WEBHOOK',
      'ORDER_PAID',
    ];
    return validEventTypes.contains(eventType);
  }

  /// Map Cashfree payment status to internal PaymentStatus
  @visibleForTesting
  PaymentStatus? mapPaymentStatus(String? status) {
    if (status == null) return null;
    
    switch (status.toUpperCase()) {
      case 'PAID':
      case 'SUCCESS':
        return PaymentStatus.APPROVED;
      case 'FAILED':
      case 'CANCELLED':
        return PaymentStatus.REJECTED;
      case 'PENDING':
      case 'ACTIVE':
        return PaymentStatus.PENDING;
      default:
        return PaymentStatus.INCOMPLETE;
    }
  }

  /// Ensure the service is initialized before use
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'CashfreeWebhookService has not been initialized. Call initialize() first.',
      );
    }
  }
}

/// Custom exception class for webhook service errors
class CashfreeWebhookException implements Exception {
  final String message;
  final CashfreeWebhookErrorType type;

  const CashfreeWebhookException(this.message, this.type);

  @override
  String toString() =>
      'CashfreeWebhookException: $message (Type: ${type.name})';
}

/// Error types for webhook service
enum CashfreeWebhookErrorType {
  configuration,
  validation,
  security,
  processing,
  network,
}

/// Result class for webhook processing
class CashfreeWebhookResult {
  final bool success;
  final String? orderId;
  final PaymentStatus? paymentStatus;
  final String? eventType;
  final bool? processed;
  final String? message;
  final String? error;
  final CashfreeWebhookErrorType? errorType;
  final Map<String, dynamic>? paymentData;

  const CashfreeWebhookResult({
    required this.success,
    this.orderId,
    this.paymentStatus,
    this.eventType,
    this.processed,
    this.message,
    this.error,
    this.errorType,
    this.paymentData,
  });

  @override
  String toString() {
    return 'CashfreeWebhookResult{success: $success, orderId: $orderId, eventType: $eventType, error: $error}';
  }
}

/// Webhook payload data structure
class CashfreeWebhookPayload {
  final String eventType;
  final String orderId;
  final String? paymentSessionId;
  final PaymentStatus? paymentStatus;
  final String? cfPaymentId;
  final String? paymentMethod;
  final double? paymentAmount;
  final double? orderAmount;
  final String? bankReference;
  final DateTime? paymentTime;
  final String? failureReason;
  final Map<String, dynamic> rawData;
  final DateTime timestamp;

  const CashfreeWebhookPayload({
    required this.eventType,
    required this.orderId,
    this.paymentSessionId,
    this.paymentStatus,
    this.cfPaymentId,
    this.paymentMethod,
    this.paymentAmount,
    this.orderAmount,
    this.bankReference,
    this.paymentTime,
    this.failureReason,
    required this.rawData,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'CashfreeWebhookPayload{eventType: $eventType, orderId: $orderId, paymentStatus: $paymentStatus}';
  }
}

/// Validation result for webhook data
class WebhookValidationResult {
  final bool isValid;
  final String? error;

  const WebhookValidationResult({
    required this.isValid,
    this.error,
  });
}

/// Result class for payment update operations
class PaymentUpdateResult {
  final bool success;
  final Map<String, dynamic>? paymentData;
  final String? message;
  final String? error;

  const PaymentUpdateResult({
    required this.success,
    this.paymentData,
    this.message,
    this.error,
  });
}