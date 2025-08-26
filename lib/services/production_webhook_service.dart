import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../config/production_deployment_config.dart';
import '../services/production_monitoring_service.dart';
import '../models/payment_model.dart';

/// Production webhook service for Cashfree Payment Gateway
///
/// This service handles:
/// - Production webhook URL configuration
/// - Webhook signature verification
/// - Secure webhook payload processing
/// - Webhook retry and error handling
/// - Production webhook monitoring
class ProductionWebhookService {
  // Private constructor for singleton pattern
  ProductionWebhookService._();

  // Singleton instance
  static final ProductionWebhookService _instance =
      ProductionWebhookService._();
  static ProductionWebhookService get instance => _instance;

  // Configuration and monitoring instances
  final ProductionDeploymentConfig _config =
      ProductionDeploymentConfig.instance;
  final ProductionMonitoringService _monitoring =
      ProductionMonitoringService.instance;

  // Webhook configuration
  static const String _webhookVersion = '2022-09-01';
  static const int _maxWebhookRetries = 3;
  static const Duration _webhookTimeout = Duration(seconds: 30);

  // Webhook state
  bool _isWebhookConfigured = false;
  String? _webhookSecret;
  DateTime? _lastWebhookReceived;

  /// Initialize production webhook service
  Future<bool> initialize() async {
    try {
      if (!_config.isProduction) {
        if (kDebugMode) {
          print(
            'ProductionWebhookService: Not in production mode, using sandbox webhook configuration',
          );
        }
        return true;
      }

      // Validate webhook configuration
      final validationResult = await _validateWebhookConfiguration();
      if (!validationResult.isValid) {
        if (kDebugMode) {
          print(
            'ProductionWebhookService: Webhook configuration validation failed',
          );
          for (final error in validationResult.errors) {
            print('  Error: $error');
          }
        }
        return false;
      }

      // Set webhook secret (in production, this would come from secure storage)
      _webhookSecret = _getWebhookSecret();
      _isWebhookConfigured = true;

      if (kDebugMode) {
        print(
          'ProductionWebhookService: Webhook service initialized successfully',
        );
        print(
          'ProductionWebhookService: Webhook URL: ${_config.productionWebhookUrl}',
        );
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('ProductionWebhookService: Webhook initialization failed: $e');
      }
      return false;
    }
  }

  /// Process incoming webhook payload
  Future<WebhookProcessingResult> processWebhook({
    required Map<String, dynamic> payload,
    required String signature,
    required Map<String, String> headers,
  }) async {
    try {
      // Log webhook received event
      _monitoring.logSecurityEvent(
        eventType: 'webhook_received',
        level: SecurityLevel.info,
        description: 'Webhook payload received',
        details: {
          'payload_size': jsonEncode(payload).length,
          'has_signature': signature.isNotEmpty,
          'headers_count': headers.length,
        },
      );

      // Validate webhook signature
      final signatureValidation = await _validateWebhookSignature(
        payload,
        signature,
      );
      if (!signatureValidation.isValid) {
        _monitoring.logSecurityEvent(
          eventType: 'webhook_signature_invalid',
          level: SecurityLevel.error,
          description: 'Invalid webhook signature',
          details: {
            'signature': signature,
            'validation_errors': signatureValidation.errors,
          },
        );

        return WebhookProcessingResult(
          success: false,
          error: 'Invalid webhook signature',
          details: signatureValidation.errors,
        );
      }

      // Validate webhook payload structure
      final payloadValidation = _validateWebhookPayload(payload);
      if (!payloadValidation.isValid) {
        _monitoring.logSecurityEvent(
          eventType: 'webhook_payload_invalid',
          level: SecurityLevel.warning,
          description: 'Invalid webhook payload structure',
          details: {'validation_errors': payloadValidation.errors},
        );

        return WebhookProcessingResult(
          success: false,
          error: 'Invalid webhook payload',
          details: payloadValidation.errors,
        );
      }

      // Process webhook data
      final processingResult = await _processWebhookData(payload);

      // Update last webhook received timestamp
      _lastWebhookReceived = DateTime.now();

      // Log successful webhook processing
      _monitoring.logPaymentEvent(
        eventType: 'webhook_processed',
        paymentId: payload['cf_payment_id']?.toString() ?? 'unknown',
        orderId: payload['order_id']?.toString() ?? 'unknown',
        status: _parsePaymentStatus(payload['order_status']?.toString()),
        metadata: {
          'webhook_type': payload['type']?.toString(),
          'processing_time': processingResult.processingTime?.inMilliseconds,
        },
      );

      return processingResult;
    } catch (e) {
      _monitoring.logSecurityEvent(
        eventType: 'webhook_processing_error',
        level: SecurityLevel.error,
        description: 'Webhook processing failed',
        details: {'error': e.toString(), 'payload_keys': payload.keys.toList()},
      );

      return WebhookProcessingResult(
        success: false,
        error: 'Webhook processing failed: $e',
        details: [e.toString()],
      );
    }
  }

  /// Get webhook configuration for Cashfree dashboard
  Map<String, dynamic> getWebhookConfiguration() {
    return {
      'webhook_url': _config.productionWebhookUrl,
      'webhook_version': _webhookVersion,
      'webhook_secret_configured': _webhookSecret != null,
      'supported_events': [
        'PAYMENT_SUCCESS_WEBHOOK',
        'PAYMENT_FAILED_WEBHOOK',
        'PAYMENT_USER_DROPPED_WEBHOOK',
      ],
      'retry_configuration': {
        'max_retries': _maxWebhookRetries,
        'timeout_seconds': _webhookTimeout.inSeconds,
      },
    };
  }

  /// Get webhook status
  Map<String, dynamic> getWebhookStatus() {
    return {
      'is_configured': _isWebhookConfigured,
      'webhook_url': _config.productionWebhookUrl,
      'last_webhook_received': _lastWebhookReceived?.toIso8601String(),
      'webhook_secret_set': _webhookSecret != null,
      'is_production': _config.isProduction,
    };
  }

  /// Validate webhook configuration
  Future<ValidationResult> _validateWebhookConfiguration() async {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      // Check webhook URL
      final webhookUrl = _config.productionWebhookUrl;
      if (webhookUrl.isEmpty) {
        errors.add('Webhook URL not configured');
      } else {
        final uri = Uri.tryParse(webhookUrl);
        if (uri == null) {
          errors.add('Invalid webhook URL format: $webhookUrl');
        } else {
          // Check HTTPS requirement
          if (uri.scheme != 'https') {
            errors.add('Webhook URL must use HTTPS: $webhookUrl');
          }

          // Check if host is in allowed list
          if (!_config.allowedHosts.contains(uri.host)) {
            warnings.add('Webhook host not in allowed hosts list: ${uri.host}');
          }
        }
      }

      // Check webhook secret availability
      final secret = _getWebhookSecret();
      if (secret == null || secret.isEmpty) {
        errors.add('Webhook secret not configured');
      }
    } catch (e) {
      errors.add('Webhook configuration validation error: $e');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Validate webhook signature
  Future<ValidationResult> _validateWebhookSignature(
    Map<String, dynamic> payload,
    String signature,
  ) async {
    final errors = <String>[];

    try {
      if (_webhookSecret == null || _webhookSecret!.isEmpty) {
        errors.add('Webhook secret not configured');
        return ValidationResult(isValid: false, errors: errors, warnings: []);
      }

      if (signature.isEmpty) {
        errors.add('Webhook signature is empty');
        return ValidationResult(isValid: false, errors: errors, warnings: []);
      }

      // Create payload string for signature verification
      final payloadString = _createSignaturePayload(payload);

      // Calculate expected signature
      final expectedSignature = _calculateWebhookSignature(
        payloadString,
        _webhookSecret!,
      );

      // Compare signatures
      if (!_compareSignatures(signature, expectedSignature)) {
        errors.add('Webhook signature mismatch');
        return ValidationResult(isValid: false, errors: errors, warnings: []);
      }
    } catch (e) {
      errors.add('Signature validation error: $e');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: [],
    );
  }

  /// Validate webhook payload structure
  ValidationResult _validateWebhookPayload(Map<String, dynamic> payload) {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      // Check required fields
      final requiredFields = ['type', 'order_id', 'order_status'];
      for (final field in requiredFields) {
        if (!payload.containsKey(field) || payload[field] == null) {
          errors.add('Missing required field: $field');
        }
      }

      // Validate webhook type
      if (payload.containsKey('type')) {
        final type = payload['type']?.toString();
        final validTypes = [
          'PAYMENT_SUCCESS_WEBHOOK',
          'PAYMENT_FAILED_WEBHOOK',
          'PAYMENT_USER_DROPPED_WEBHOOK',
        ];

        if (type == null || !validTypes.contains(type)) {
          warnings.add('Unknown webhook type: $type');
        }
      }

      // Validate order status
      if (payload.containsKey('order_status')) {
        final status = payload['order_status']?.toString();
        final validStatuses = ['PAID', 'ACTIVE', 'EXPIRED', 'CANCELLED'];

        if (status == null || !validStatuses.contains(status)) {
          warnings.add('Unknown order status: $status');
        }
      }
    } catch (e) {
      errors.add('Payload validation error: $e');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Process webhook data
  Future<WebhookProcessingResult> _processWebhookData(
    Map<String, dynamic> payload,
  ) async {
    final startTime = DateTime.now();

    try {
      // Extract webhook information
      final webhookType = payload['type']?.toString() ?? 'unknown';
      final orderId = payload['order_id']?.toString() ?? 'unknown';
      final orderStatus = payload['order_status']?.toString() ?? 'unknown';
      final paymentId = payload['cf_payment_id']?.toString();

      // Process based on webhook type
      switch (webhookType) {
        case 'PAYMENT_SUCCESS_WEBHOOK':
          await _handlePaymentSuccessWebhook(payload);
          break;
        case 'PAYMENT_FAILED_WEBHOOK':
          await _handlePaymentFailedWebhook(payload);
          break;
        case 'PAYMENT_USER_DROPPED_WEBHOOK':
          await _handlePaymentDroppedWebhook(payload);
          break;
        default:
          if (kDebugMode) {
            print(
              'ProductionWebhookService: Unknown webhook type: $webhookType',
            );
          }
      }

      final processingTime = DateTime.now().difference(startTime);

      return WebhookProcessingResult(
        success: true,
        orderId: orderId,
        paymentId: paymentId,
        webhookType: webhookType,
        orderStatus: orderStatus,
        processingTime: processingTime,
      );
    } catch (e) {
      final processingTime = DateTime.now().difference(startTime);

      return WebhookProcessingResult(
        success: false,
        error: 'Webhook data processing failed: $e',
        processingTime: processingTime,
      );
    }
  }

  /// Handle payment success webhook
  Future<void> _handlePaymentSuccessWebhook(
    Map<String, dynamic> payload,
  ) async {
    // In a real implementation, this would:
    // 1. Update payment status in database
    // 2. Send confirmation to user
    // 3. Update subscription status
    // 4. Generate receipt

    if (kDebugMode) {
      print('ProductionWebhookService: Processing payment success webhook');
    }
  }

  /// Handle payment failed webhook
  Future<void> _handlePaymentFailedWebhook(Map<String, dynamic> payload) async {
    // In a real implementation, this would:
    // 1. Update payment status in database
    // 2. Send failure notification to user
    // 3. Log failure reason
    // 4. Trigger retry logic if applicable

    if (kDebugMode) {
      print('ProductionWebhookService: Processing payment failed webhook');
    }
  }

  /// Handle payment dropped webhook
  Future<void> _handlePaymentDroppedWebhook(
    Map<String, dynamic> payload,
  ) async {
    // In a real implementation, this would:
    // 1. Update payment status in database
    // 2. Log user drop-off
    // 3. Trigger re-engagement flow

    if (kDebugMode) {
      print('ProductionWebhookService: Processing payment dropped webhook');
    }
  }

  /// Get webhook secret (in production, this would come from secure storage)
  String? _getWebhookSecret() {
    // In a real production app, this would be retrieved from:
    // 1. Secure environment variables
    // 2. Key management service (AWS KMS, Azure Key Vault, etc.)
    // 3. Encrypted configuration files

    return _config.isProduction
        ? 'your-production-webhook-secret'
        : 'your-sandbox-webhook-secret';
  }

  /// Create signature payload string
  String _createSignaturePayload(Map<String, dynamic> payload) {
    // Sort keys and create signature string
    final sortedKeys = payload.keys.toList()..sort();
    final signatureData = <String>[];

    for (final key in sortedKeys) {
      final value = payload[key];
      if (value != null) {
        signatureData.add('$key=$value');
      }
    }

    return signatureData.join('&');
  }

  /// Calculate webhook signature
  String _calculateWebhookSignature(String payload, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }

  /// Compare signatures securely
  bool _compareSignatures(String signature1, String signature2) {
    if (signature1.length != signature2.length) {
      return false;
    }

    int result = 0;
    for (int i = 0; i < signature1.length; i++) {
      result |= signature1.codeUnitAt(i) ^ signature2.codeUnitAt(i);
    }

    return result == 0;
  }

  /// Parse payment status from webhook
  PaymentStatus _parsePaymentStatus(String? status) {
    switch (status?.toUpperCase()) {
      case 'PAID':
        return PaymentStatus.APPROVED;
      case 'EXPIRED':
      case 'CANCELLED':
        return PaymentStatus.INCOMPLETE;
      case 'ACTIVE':
        return PaymentStatus.PENDING;
      default:
        return PaymentStatus.REJECTED;
    }
  }
}

/// Webhook processing result
class WebhookProcessingResult {
  final bool success;
  final String? error;
  final List<String>? details;
  final String? orderId;
  final String? paymentId;
  final String? webhookType;
  final String? orderStatus;
  final Duration? processingTime;

  const WebhookProcessingResult({
    required this.success,
    this.error,
    this.details,
    this.orderId,
    this.paymentId,
    this.webhookType,
    this.orderStatus,
    this.processingTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'error': error,
      'details': details,
      'orderId': orderId,
      'paymentId': paymentId,
      'webhookType': webhookType,
      'orderStatus': orderStatus,
      'processingTimeMs': processingTime?.inMilliseconds,
    };
  }
}

/// Validation result for webhook operations
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });
}
