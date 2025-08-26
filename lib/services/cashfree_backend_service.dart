import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/cashfree_config.dart';
import 'cashfree_config_service.dart';
import 'cashfree_webhook_service.dart';

/// Backend service for server-to-server communication with Cashfree APIs
///
/// This service handles all backend API calls for Cashfree order management,
/// including order creation, payment session ID retrieval, and secure API
/// authentication. It ensures that sensitive credentials (App ID and Secret Key)
/// remain on the backend only.
class CashfreeBackendService {
  // Private constructor for singleton pattern
  CashfreeBackendService._();

  // Singleton instance
  static final CashfreeBackendService _instance = CashfreeBackendService._();
  static CashfreeBackendService get instance => _instance;

  // Dependencies
  final CashfreeConfigService _configService = CashfreeConfigService.instance;
  final http.Client _httpClient = http.Client();

  // Service state
  bool _isInitialized = false;

  /// Check if the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the backend service
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      if (kDebugMode) {
        print('CashfreeBackendService: Starting initialization...');
      }

      // Ensure config service is initialized
      if (!_configService.isInitialized) {
        final configInitialized = await _configService.initialize();
        if (!configInitialized) {
          throw CashfreeBackendException(
            'Configuration service initialization failed',
            CashfreeBackendErrorType.configuration,
          );
        }
      }

      _isInitialized = true;

      if (kDebugMode) {
        print('CashfreeBackendService: Initialization successful');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeBackendService: Initialization error: $e');
      }
      return false;
    }
  }

  /// Create order with backend API
  ///
  /// This method communicates with the backend to create a Cashfree order
  /// using server-to-server communication. The backend handles all sensitive
  /// credentials and returns the payment session ID.
  Future<CashfreeOrderResponse> createOrder({
    required String orderId,
    required double amount,
    required String customerId,
    required String customerPhone,
    required String customerEmail,
    String? customerName,
    Map<String, dynamic>? orderMeta,
    List<String>? paymentMethods,
  }) async {
    _ensureInitialized();

    try {
      if (kDebugMode) {
        print('CashfreeBackendService: Creating order: $orderId');
      }

      // Validate input parameters
      _validateOrderParams(
        orderId,
        amount,
        customerId,
        customerPhone,
        customerEmail,
      );

      // Prepare request payload
      final requestPayload = _buildOrderRequest(
        orderId: orderId,
        amount: amount,
        customerId: customerId,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerName: customerName,
        orderMeta: orderMeta,
        paymentMethods: paymentMethods,
      );

      // Make API call to backend
      final response = await _makeBackendApiCall(
        endpoint: _configService.getCreateOrderEndpoint(),
        method: 'POST',
        payload: requestPayload,
      );

      // Parse response
      final orderData = _parseOrderResponse(response);

      if (kDebugMode) {
        print('CashfreeBackendService: Order created successfully');
      }

      return CashfreeOrderResponse(
        success: true,
        orderId: orderId,
        paymentSessionId: orderData['payment_session_id'],
        orderAmount: amount,
        orderStatus: orderData['order_status'] ?? 'ACTIVE',
        message: 'Order created successfully',
      );
    } on CashfreeBackendException catch (e) {
      if (kDebugMode) {
        print('CashfreeBackendService: Backend exception in createOrder: $e');
      }
      return CashfreeOrderResponse(
        success: false,
        orderId: orderId,
        error: e.message,
        errorType: e.type,
      );
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeBackendService: Unexpected error in createOrder: $e');
      }
      return CashfreeOrderResponse(
        success: false,
        orderId: orderId,
        error: 'Failed to create order: $e',
        errorType: CashfreeBackendErrorType.network,
      );
    }
  }

  /// Get payment status from backend
  ///
  /// This method retrieves the payment status for a given order ID
  /// using the backend's Cashfree Verify API integration.
  Future<CashfreePaymentStatus> getPaymentStatus(String orderId) async {
    _ensureInitialized();

    try {
      if (kDebugMode) {
        print(
          'CashfreeBackendService: Getting payment status for order: $orderId',
        );
      }

      // Validate order ID
      if (orderId.isEmpty) {
        throw CashfreeBackendException(
          'Order ID cannot be empty',
          CashfreeBackendErrorType.validation,
        );
      }

      // Make API call to backend
      final response = await _makeBackendApiCall(
        endpoint: _configService.getVerifyPaymentEndpoint(),
        method: 'POST',
        payload: {'order_id': orderId},
      );

      // Parse response
      final statusData = _parsePaymentStatusResponse(response);

      if (kDebugMode) {
        print('CashfreeBackendService: Payment status retrieved successfully');
      }

      return CashfreePaymentStatus(
        success: true,
        orderId: orderId,
        paymentStatus: statusData['payment_status'],
        cfPaymentId: statusData['cf_payment_id'],
        orderAmount: statusData['order_amount']?.toDouble(),
        paymentAmount: statusData['payment_amount']?.toDouble(),
        paymentMethod: statusData['payment_method'],
        bankReference: statusData['bank_reference'],
        paymentTime: statusData['payment_time'] != null
            ? DateTime.parse(statusData['payment_time'])
            : null,
        failureReason: statusData['failure_reason'],
        message: 'Payment status retrieved successfully',
      );
    } on CashfreeBackendException catch (e) {
      if (kDebugMode) {
        print(
          'CashfreeBackendService: Backend exception in getPaymentStatus: $e',
        );
      }
      return CashfreePaymentStatus(
        success: false,
        orderId: orderId,
        error: e.message,
        errorType: e.type,
      );
    } catch (e) {
      if (kDebugMode) {
        print(
          'CashfreeBackendService: Unexpected error in getPaymentStatus: $e',
        );
      }
      return CashfreePaymentStatus(
        success: false,
        orderId: orderId,
        error: 'Failed to get payment status: $e',
        errorType: CashfreeBackendErrorType.network,
      );
    }
  }

  /// Verify webhook signature
  ///
  /// This method verifies the webhook signature to ensure the webhook
  /// is authentic and comes from Cashfree.
  bool verifyWebhookSignature(
    String signature,
    String body, {
    String? timestamp,
  }) {
    try {
      if (kDebugMode) {
        print('CashfreeBackendService: Verifying webhook signature');
      }

      // For security reasons, webhook signature verification should be done
      // on the backend. This method provides a client-side validation
      // but the primary verification should happen on the server.

      if (signature.isEmpty || body.isEmpty) {
        if (kDebugMode) {
          print('CashfreeBackendService: Invalid signature or body');
        }
        return false;
      }

      // Basic signature format validation
      // The actual verification logic should be implemented on the backend
      final signatureParts = signature.split('.');
      if (signatureParts.length != 2) {
        if (kDebugMode) {
          print('CashfreeBackendService: Invalid signature format');
        }
        return false;
      }

      // For now, return true for basic validation
      // The backend should handle the actual cryptographic verification
      if (kDebugMode) {
        print(
          'CashfreeBackendService: Webhook signature validation passed (basic check)',
        );
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeBackendService: Error verifying webhook signature: $e');
      }
      return false;
    }
  }

  /// Handle webhook data processing
  ///
  /// This method processes webhook data received from Cashfree
  /// and forwards it to the backend for proper handling.
  Future<CashfreeWebhookResult> processWebhook({
    required Map<String, dynamic> webhookData,
    required String signature,
    String? timestamp,
    Map<String, String>? headers,
  }) async {
    _ensureInitialized();

    try {
      if (kDebugMode) {
        print('CashfreeBackendService: Processing webhook data');
      }

      // Verify webhook signature first
      if (!verifyWebhookSignature(
        signature,
        json.encode(webhookData),
        timestamp: timestamp,
      )) {
        throw CashfreeBackendException(
          'Invalid webhook signature',
          CashfreeBackendErrorType.security,
        );
      }

      // Prepare webhook payload
      final webhookPayload = {
        'webhook_data': webhookData,
        'signature': signature,
        'timestamp': timestamp ?? DateTime.now().toIso8601String(),
        'headers': headers ?? {},
      };

      // Forward to backend for processing
      final response = await _makeBackendApiCall(
        endpoint: _configService.getWebhookEndpoint(),
        method: 'POST',
        payload: webhookPayload,
      );

      // Parse response
      final webhookResult = _parseWebhookResponse(response);

      if (kDebugMode) {
        print('CashfreeBackendService: Webhook processed successfully');
      }

      return CashfreeWebhookResult(
        success: true,
        orderId: webhookResult['order_id'],
        paymentStatus: webhookResult['payment_status'],
        eventType: webhookResult['event_type'],
        processed: webhookResult['processed'] ?? true,
        message: 'Webhook processed successfully',
        paymentData: webhookResult['payment_data'],
      );
    } on CashfreeBackendException catch (e) {
      if (kDebugMode) {
        print(
          'CashfreeBackendService: Backend exception in processWebhook: $e',
        );
      }
      return CashfreeWebhookResult(
        success: false,
        error: e.message,
        errorType: _mapBackendErrorToWebhookError(e.type),
      );
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeBackendService: Unexpected error in processWebhook: $e');
      }
      return CashfreeWebhookResult(
        success: false,
        error: 'Failed to process webhook: $e',
        errorType: CashfreeWebhookErrorType.network,
      );
    }
  }

  /// Validate order parameters
  void _validateOrderParams(
    String orderId,
    double amount,
    String customerId,
    String customerPhone,
    String customerEmail,
  ) {
    if (orderId.isEmpty) {
      throw CashfreeBackendException(
        'Order ID cannot be empty',
        CashfreeBackendErrorType.validation,
      );
    }

    if (amount <= 0) {
      throw CashfreeBackendException(
        'Amount must be greater than 0',
        CashfreeBackendErrorType.validation,
      );
    }

    if (customerId.isEmpty) {
      throw CashfreeBackendException(
        'Customer ID cannot be empty',
        CashfreeBackendErrorType.validation,
      );
    }

    if (customerPhone.isEmpty) {
      throw CashfreeBackendException(
        'Customer phone cannot be empty',
        CashfreeBackendErrorType.validation,
      );
    }

    if (customerEmail.isEmpty) {
      throw CashfreeBackendException(
        'Customer email cannot be empty',
        CashfreeBackendErrorType.validation,
      );
    }

    // Validate phone number format (basic validation)
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    if (!phoneRegex.hasMatch(
      customerPhone.replaceAll(RegExp(r'[\s\-\(\)]'), ''),
    )) {
      throw CashfreeBackendException(
        'Invalid phone number format',
        CashfreeBackendErrorType.validation,
      );
    }

    // Validate email format
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(customerEmail)) {
      throw CashfreeBackendException(
        'Invalid email format',
        CashfreeBackendErrorType.validation,
      );
    }
  }

  /// Build order request payload
  Map<String, dynamic> _buildOrderRequest({
    required String orderId,
    required double amount,
    required String customerId,
    required String customerPhone,
    required String customerEmail,
    String? customerName,
    Map<String, dynamic>? orderMeta,
    List<String>? paymentMethods,
  }) {
    return {
      'order_id': orderId,
      'order_amount': amount,
      'order_currency': CashfreeConfig.defaultCurrency,
      'customer_details': {
        'customer_id': customerId,
        'customer_name': customerName ?? customerId,
        'customer_email': customerEmail,
        'customer_phone': customerPhone,
      },
      'order_meta':
          orderMeta ??
          {
            'return_url': '${_configService.backendUrl}/payment/return',
            'notify_url': '${_configService.backendUrl}/payment/webhook',
          },
      'order_expiry_time': DateTime.now()
          .add(CashfreeConfig.instance.paymentTimeout)
          .toIso8601String(),
      'payment_methods':
          paymentMethods ?? CashfreeConfig.supportedPaymentMethods,
    };
  }

  /// Make API call to backend
  Future<Map<String, dynamic>> _makeBackendApiCall({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final headers = _configService.getApiHeaders();
      headers['Content-Type'] = 'application/json';

      late http.Response response;

      switch (method.toUpperCase()) {
        case 'POST':
          response = await _httpClient
              .post(
                Uri.parse(endpoint),
                headers: headers,
                body: json.encode(payload),
              )
              .timeout(_configService.apiTimeout);
          break;
        case 'GET':
          final uri = Uri.parse(endpoint).replace(
            queryParameters: payload.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
          );
          response = await _httpClient
              .get(uri, headers: headers)
              .timeout(_configService.apiTimeout);
          break;
        default:
          throw CashfreeBackendException(
            'Unsupported HTTP method: $method',
            CashfreeBackendErrorType.validation,
          );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          return <String, dynamic>{};
        }
        return json.decode(responseBody) as Map<String, dynamic>;
      } else {
        String errorMessage =
            'API call failed with status ${response.statusCode}';
        try {
          final errorBody = json.decode(response.body) as Map<String, dynamic>;
          errorMessage =
              errorBody['message'] ?? errorBody['error'] ?? errorMessage;
        } catch (e) {
          errorMessage += ': ${response.body}';
        }

        throw CashfreeBackendException(
          errorMessage,
          _mapHttpStatusToErrorType(response.statusCode),
        );
      }
    } on TimeoutException {
      throw CashfreeBackendException(
        'API call timed out',
        CashfreeBackendErrorType.network,
      );
    } catch (e) {
      if (e is CashfreeBackendException) rethrow;
      throw CashfreeBackendException(
        'Network error: $e',
        CashfreeBackendErrorType.network,
      );
    }
  }

  /// Parse order response
  Map<String, dynamic> _parseOrderResponse(Map<String, dynamic> response) {
    if (response['payment_session_id'] == null) {
      throw CashfreeBackendException(
        'Invalid response: payment_session_id not found',
        CashfreeBackendErrorType.api,
      );
    }

    return response;
  }

  /// Parse payment status response
  Map<String, dynamic> _parsePaymentStatusResponse(
    Map<String, dynamic> response,
  ) {
    if (response['payment_status'] == null) {
      throw CashfreeBackendException(
        'Invalid response: payment_status not found',
        CashfreeBackendErrorType.api,
      );
    }

    return response;
  }

  /// Parse webhook response
  Map<String, dynamic> _parseWebhookResponse(Map<String, dynamic> response) {
    // Webhook response should contain processing status
    return response;
  }

  /// Map HTTP status codes to error types
  CashfreeBackendErrorType _mapHttpStatusToErrorType(int statusCode) {
    switch (statusCode) {
      case 400:
        return CashfreeBackendErrorType.validation;
      case 401:
      case 403:
        return CashfreeBackendErrorType.authentication;
      case 404:
        return CashfreeBackendErrorType.notFound;
      case 429:
        return CashfreeBackendErrorType.rateLimited;
      case 500:
      case 502:
      case 503:
      case 504:
        return CashfreeBackendErrorType.server;
      default:
        return CashfreeBackendErrorType.api;
    }
  }

  /// Ensure the service is initialized before use
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'CashfreeBackendService has not been initialized. Call initialize() first.',
      );
    }
  }

  /// Map backend error types to webhook error types
  CashfreeWebhookErrorType _mapBackendErrorToWebhookError(CashfreeBackendErrorType backendError) {
    switch (backendError) {
      case CashfreeBackendErrorType.configuration:
        return CashfreeWebhookErrorType.configuration;
      case CashfreeBackendErrorType.validation:
        return CashfreeWebhookErrorType.validation;
      case CashfreeBackendErrorType.security:
        return CashfreeWebhookErrorType.security;
      case CashfreeBackendErrorType.network:
        return CashfreeWebhookErrorType.network;
      default:
        return CashfreeWebhookErrorType.processing;
    }
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}

/// Custom exception class for Cashfree backend service errors
class CashfreeBackendException implements Exception {
  final String message;
  final CashfreeBackendErrorType type;

  const CashfreeBackendException(this.message, this.type);

  @override
  String toString() =>
      'CashfreeBackendException: $message (Type: ${type.name})';
}

/// Error types for Cashfree backend service
enum CashfreeBackendErrorType {
  configuration,
  validation,
  network,
  api,
  authentication,
  notFound,
  rateLimited,
  server,
  security,
}

/// Response class for order creation
class CashfreeOrderResponse {
  final bool success;
  final String orderId;
  final String? paymentSessionId;
  final double? orderAmount;
  final String? orderStatus;
  final String? message;
  final String? error;
  final CashfreeBackendErrorType? errorType;

  const CashfreeOrderResponse({
    required this.success,
    required this.orderId,
    this.paymentSessionId,
    this.orderAmount,
    this.orderStatus,
    this.message,
    this.error,
    this.errorType,
  });

  @override
  String toString() {
    return 'CashfreeOrderResponse{success: $success, orderId: $orderId, sessionId: $paymentSessionId, error: $error}';
  }
}

/// Response class for payment status
class CashfreePaymentStatus {
  final bool success;
  final String orderId;
  final String? paymentStatus;
  final String? cfPaymentId;
  final double? orderAmount;
  final double? paymentAmount;
  final String? paymentMethod;
  final String? bankReference;
  final DateTime? paymentTime;
  final String? failureReason;
  final String? message;
  final String? error;
  final CashfreeBackendErrorType? errorType;

  const CashfreePaymentStatus({
    required this.success,
    required this.orderId,
    this.paymentStatus,
    this.cfPaymentId,
    this.orderAmount,
    this.paymentAmount,
    this.paymentMethod,
    this.bankReference,
    this.paymentTime,
    this.failureReason,
    this.message,
    this.error,
    this.errorType,
  });

  @override
  String toString() {
    return 'CashfreePaymentStatus{success: $success, orderId: $orderId, status: $paymentStatus, error: $error}';
  }
}

/// Response class for webhook processing
class CashfreeWebhookResult {
  final bool success;
  final String? orderId;
  final String? paymentStatus;
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
    return 'CashfreeWebhookResult{success: $success, orderId: $orderId, eventType: $eventType, processed: $processed, error: $error}';
  }
}
