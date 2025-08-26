import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';

import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';

import '../models/payment_model.dart';
import '../models/cashfree_error_model.dart';
import 'cashfree_config_service.dart';
import 'cashfree_backend_service.dart';
import 'cashfree_error_handler.dart';
import 'cashfree_fallback_service.dart';
import 'cashfree_security_service.dart';
import 'cashfree_webhook_service.dart';

/// Core Cashfree payment service for handling payment processing
///
/// This service provides the foundation for Cashfree payment integration,
/// including payment session creation, payment processing workflow,
/// and basic error handling.
///
/// For combined wallet + Cashfree payments, use CashfreeWalletIntegrationService
/// which provides comprehensive wallet integration with automatic balance checking,
/// transaction management, and rollback capabilities.
class CashfreePaymentService {
  // Private constructor for singleton pattern
  CashfreePaymentService._();

  // Singleton instance
  static final CashfreePaymentService _instance = CashfreePaymentService._();
  static CashfreePaymentService get instance => _instance;

  // Dependencies
  final CashfreeConfigService _configService = CashfreeConfigService.instance;
  final CashfreeErrorHandler _errorHandler = CashfreeErrorHandler.instance;
  final CashfreeFallbackService _fallbackService =
      CashfreeFallbackService.instance;
  final CashfreeSecurityService _securityService = CashfreeSecurityService();
  late Dio _httpClient;

  // Service state
  bool _isInitialized = false;
  bool _initializationFailed = false;
  String? _initializationError;

  // Payment state
  Completer<CashfreePaymentResult>? _paymentCompleter;

  /// Check if the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Check if initialization failed
  bool get initializationFailed => _initializationFailed;

  /// Get initialization error message if any
  String? get initializationError => _initializationError;

  /// Initialize the Cashfree payment service
  ///
  /// This method should be called during app initialization to ensure
  /// proper service setup and configuration validation.
  ///
  /// Returns true if initialization is successful, false otherwise.
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      if (kDebugMode) {
        print('CashfreePaymentService: Starting initialization...');
      }

      // Ensure config service is initialized
      if (!_configService.isInitialized) {
        final configInitialized = await _configService.initialize();
        if (!configInitialized) {
          throw CashfreeServiceException(
            CashfreeError(
              code: 'CONFIG_INIT_FAILED',
              message: 'Configuration service initialization failed',
              userMessage:
                  'Payment system configuration error. Please contact support.',
              type: CashfreeErrorType.configuration,
              severity: CashfreeErrorSeverity.critical,
            ),
          );
        }
      }

      // Initialize security service
      await _securityService.initialize();

      // Use secure HTTP client from security service
      _httpClient = _securityService.secureHttpClient;

      // Initialize Cashfree SDK
      await _initializeCashfreeSDK();

      _isInitialized = true;
      _initializationFailed = false;
      _initializationError = null;

      if (kDebugMode) {
        print('CashfreePaymentService: Initialization successful');
      }

      return true;
    } catch (e) {
      _initializationFailed = true;
      _initializationError = e.toString();

      if (kDebugMode) {
        print('CashfreePaymentService: Initialization error: $e');
      }

      return false;
    }
  }

  /// Initialize Cashfree SDK with proper configuration
  Future<void> _initializeCashfreeSDK() async {
    try {
      // Set SDK environment
      final environment = _configService.isSandbox
          ? CFEnvironment.SANDBOX
          : CFEnvironment.PRODUCTION;

      // Initialize payment gateway service with callbacks
      CFPaymentGatewayService().setCallback(
        _handlePaymentCallback,
        _handlePaymentError,
      );

      if (kDebugMode) {
        print(
          'CashfreePaymentService: SDK initialized with environment: ${environment.name}',
        );
      }
    } catch (e) {
      throw CashfreeServiceException(
        _errorHandler.handleException(
          e,
          context: 'SDK initialization',
          additionalDetails: {
            'environment': _configService.isSandbox ? 'sandbox' : 'production',
          },
        ),
      );
    }
  }

  /// Create payment session with backend
  ///
  /// This method communicates with the backend to create a Cashfree order
  /// and returns the payment session ID required for SDK payment processing.
  Future<CashfreePaymentSessionResult> createPaymentSession({
    required String userId,
    required double amount,
    required String orderId,
    Map<String, dynamic>? customerDetails,
    Map<String, dynamic>? orderMeta,
  }) async {
    _ensureInitialized();

    try {
      if (kDebugMode) {
        print(
          'CashfreePaymentService: Creating payment session for order: $orderId',
        );
      }

      // Validate input parameters
      _validatePaymentSessionParams(userId, amount, orderId);

      // Validate session data with security service
      final sessionData = {
        'orderId': orderId,
        'amount': amount,
        'customerId': userId,
        'sessionId': _securityService.generateSecureSessionToken(
          orderId,
          userId,
        ),
      };

      if (!_securityService.validatePaymentSession(sessionData)) {
        throw CashfreeServiceException(
          CashfreeError(
            code: 'INVALID_SESSION_DATA',
            message: 'Payment session data validation failed',
            userMessage: 'Invalid payment information. Please try again.',
            type: CashfreeErrorType.validation,
            severity: CashfreeErrorSeverity.high,
          ),
        );
      }

      // Prepare request payload
      final requestPayload = _buildPaymentSessionRequest(
        userId: userId,
        amount: amount,
        orderId: orderId,
        customerDetails: customerDetails,
        orderMeta: orderMeta,
      );

      // Make API call to backend
      final response = await _makeBackendApiCall(
        endpoint: _configService.getPaymentSessionEndpoint(),
        payload: requestPayload,
      );

      // Parse response
      final sessionResponse = _parsePaymentSessionResponse(response);

      if (kDebugMode) {
        print('CashfreePaymentService: Payment session created successfully');
      }

      return CashfreePaymentSessionResult(
        success: true,
        sessionId: sessionResponse['payment_session_id'] as String?,
        orderId: orderId,
        amount: amount,
        message: 'Payment session created successfully',
      );
    } on CashfreeServiceException catch (e) {
      if (kDebugMode) {
        print(
          'CashfreePaymentService: Service exception in createPaymentSession: $e',
        );
      }
      return CashfreePaymentSessionResult(
        success: false,
        error: e.message,
        errorType: e.type,
      );
    } catch (e) {
      if (kDebugMode) {
        print(
          'CashfreePaymentService: Unexpected error in createPaymentSession: $e',
        );
      }
      return CashfreePaymentSessionResult(
        success: false,
        error: 'Failed to create payment session: $e',
        errorType: CashfreeErrorType.network,
      );
    }
  }

  /// Process payment using Cashfree SDK with comprehensive error handling
  ///
  /// This method initiates the payment flow using the Cashfree SDK
  /// with comprehensive error handling, retry logic, and fallback mechanisms.
  Future<CashfreePaymentResult> processPaymentWithErrorHandling({
    required String userId,
    required double amount,
    required PaymentMethod method,
    double extraCharges = 0.0,
    String? note,
    String? sessionId,
    bool enableFallback = true,
  }) async {
    return await _errorHandler.executeWithRetry(
      () => _processPaymentInternal(
        userId: userId,
        amount: amount,
        method: method,
        extraCharges: extraCharges,
        note: note,
        sessionId: sessionId,
        enableFallback: enableFallback,
      ),
      context: 'Payment processing',
      maxRetries: 2,
      shouldRetry: (error) => _shouldRetryPayment(error, method),
    );
  }

  /// Process combined payment with wallet integration
  ///
  /// This method handles combined payments where part of the amount
  /// is paid from wallet and remaining through Cashfree.
  ///
  /// Note: This method is deprecated. Use CashfreeWalletIntegrationService.processCombinedPayment() instead.
  @Deprecated(
    'Use CashfreeWalletIntegrationService.processCombinedPayment() for better wallet integration',
  )
  Future<CashfreePaymentResult> processCombinedPayment({
    required String userId,
    required double totalAmount,
    required double walletAmount,
    required double cashfreeAmount,
    required PaymentMethod method,
    double extraCharges = 0.0,
    String? note,
    String? sessionId,
  }) async {
    _ensureInitialized();

    try {
      if (kDebugMode) {
        print(
          'CashfreePaymentService: Processing combined payment - '
          'Total: $totalAmount, Wallet: $walletAmount, Cashfree: $cashfreeAmount',
        );
        print(
          'Note: This method is deprecated. Consider using CashfreeWalletIntegrationService instead.',
        );
      }

      // Validate combined payment parameters
      _validateCombinedPaymentParams(
        userId,
        totalAmount,
        walletAmount,
        cashfreeAmount,
        method,
      );

      // Process only the Cashfree portion
      final cashfreeResult = await processPaymentWithErrorHandling(
        userId: userId,
        amount: cashfreeAmount,
        method: method,
        extraCharges: 0.0, // Extra charges already included in amounts
        note: note ?? 'Combined payment - Cashfree portion',
        sessionId: sessionId,
        enableFallback: true,
      );

      // Update result to reflect combined payment
      if (cashfreeResult.success) {
        return cashfreeResult.copyWith(
          amount: totalAmount, // Show total amount in result
          message:
              'Combined payment successful: Wallet (₹${walletAmount.toStringAsFixed(2)}) + Cashfree (₹${cashfreeAmount.toStringAsFixed(2)})',
        );
      }

      return cashfreeResult;
    } catch (e) {
      if (kDebugMode) {
        print('CashfreePaymentService: Error in combined payment: $e');
      }

      final error = _errorHandler.handleException(
        e,
        context: 'Combined payment processing',
        additionalDetails: {
          'userId': userId,
          'totalAmount': totalAmount,
          'walletAmount': walletAmount,
          'cashfreeAmount': cashfreeAmount,
          'method': method.name,
        },
      );

      return CashfreePaymentResult(
        success: false,
        error: error.userMessage,
        errorType: error.type,
      );
    }
  }

  /// Internal payment processing method
  Future<CashfreePaymentResult> _processPaymentInternal({
    required String userId,
    required double amount,
    required PaymentMethod method,
    double extraCharges = 0.0,
    String? note,
    String? sessionId,
    bool enableFallback = true,
  }) async {
    try {
      final result = await processPayment(
        userId: userId,
        amount: amount,
        method: method,
        extraCharges: extraCharges,
        note: note,
        sessionId: sessionId,
      );

      // If payment failed and fallback is enabled, try fallback
      if (!result.success && enableFallback && result.errorType != null) {
        final fallbackResult = await _executeFallbackPayment(
          error: CashfreeError(
            code: result.errorType!.name.toUpperCase(),
            message: result.error ?? 'Payment failed',
            userMessage: result.error ?? 'Payment failed',
            type: result.errorType!,
          ),
          userId: userId,
          amount: amount + extraCharges,
          originalMethod: method,
        );

        if (fallbackResult.success) {
          return CashfreePaymentResult(
            success: true,
            paymentId: result.paymentId,
            orderId: result.orderId,
            transactionId: result.transactionId,
            amount: amount + extraCharges,
            paymentMethod: fallbackResult.fallbackMethod?.name,
            message:
                fallbackResult.message ??
                'Payment completed using fallback method',
          );
        }
      }

      return result;
    } catch (e) {
      final error = _errorHandler.handleException(
        e,
        context: 'Payment processing',
        additionalDetails: {
          'userId': userId,
          'amount': amount,
          'method': method.name,
        },
      );

      // Try fallback if enabled and error is suitable for fallback
      if (enableFallback && _shouldAttemptFallback(error)) {
        final fallbackResult = await _executeFallbackPayment(
          error: error,
          userId: userId,
          amount: amount + extraCharges,
          originalMethod: method,
        );

        if (fallbackResult.success) {
          return CashfreePaymentResult(
            success: true,
            amount: amount + extraCharges,
            paymentMethod: fallbackResult.fallbackMethod?.name,
            message:
                fallbackResult.message ??
                'Payment completed using fallback method',
          );
        }
      }

      return CashfreePaymentResult(
        success: false,
        error: error.userMessage,
        errorType: error.type,
      );
    }
  }

  /// Process payment using Cashfree SDK
  ///
  /// This method initiates the payment flow using the Cashfree SDK
  /// with the provided payment session ID.
  Future<CashfreePaymentResult> processPayment({
    required String userId,
    required double amount,
    required PaymentMethod method,
    double extraCharges = 0.0,
    String? note,
    String? sessionId,
  }) async {
    _ensureInitialized();

    try {
      if (kDebugMode) {
        print('CashfreePaymentService: Processing payment for user: $userId');
      }

      // Validate input parameters
      _validatePaymentParams(userId, amount, method);

      // Sanitize payment data for security
      final sanitizedData = _securityService.sanitizePaymentData({
        'userId': userId,
        'amount': amount,
        'method': method.toString(),
        'extraCharges': extraCharges,
        'note': note,
      });

      final totalAmount = amount + extraCharges;
      final orderId = _generateOrderId(userId);

      // Create payment session if not provided
      String paymentSessionId;
      if (sessionId != null) {
        paymentSessionId = sessionId;
      } else {
        final sessionResult = await createPaymentSession(
          userId: userId,
          amount: totalAmount,
          orderId: orderId,
        );

        if (!sessionResult.success || sessionResult.sessionId == null) {
          return CashfreePaymentResult(
            success: false,
            error: sessionResult.error ?? 'Failed to create payment session',
            errorType: sessionResult.errorType ?? CashfreeErrorType.api,
          );
        }

        paymentSessionId = sessionResult.sessionId!;
      }

      // Create CFSession for SDK
      final cfSession = _createCFSession(paymentSessionId, orderId);

      // Create payment component with session
      final paymentComponent = _createPaymentComponent(method, cfSession);

      // Start payment processing
      final paymentResult = await _executePayment(paymentComponent);

      if (kDebugMode) {
        print('CashfreePaymentService: Payment processing completed');
      }

      return paymentResult;
    } on CashfreeServiceException catch (e) {
      if (kDebugMode) {
        print(
          'CashfreePaymentService: Service exception in processPayment: $e',
        );
      }
      return CashfreePaymentResult(
        success: false,
        error: e.message,
        errorType: e.type,
      );
    } catch (e) {
      if (kDebugMode) {
        print('CashfreePaymentService: Unexpected error in processPayment: $e');
      }
      return CashfreePaymentResult(
        success: false,
        error: 'Payment processing failed: $e',
        errorType: CashfreeErrorType.system,
      );
    }
  }

  /// Verify payment status with Cashfree API
  ///
  /// This method verifies the payment status using Cashfree's verification API
  /// to ensure payment authenticity and get final status.
  Future<CashfreeVerificationResult> verifyPayment(String orderId) async {
    return await verifyPaymentWithRetry(orderId, maxRetries: 3);
  }

  /// Verify payment status with retry logic
  ///
  /// This method implements automatic retry logic for payment verification
  /// to handle transient network errors and API failures.
  Future<CashfreeVerificationResult> verifyPaymentWithRetry(
    String orderId, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    _ensureInitialized();

    if (kDebugMode) {
      print(
        'CashfreePaymentService: Starting payment verification with retry for order: $orderId',
      );
    }

    // Validate order ID
    if (orderId.isEmpty) {
      return CashfreeVerificationResult(
        success: false,
        orderId: orderId,
        error: 'Order ID cannot be empty',
        errorType: CashfreeErrorType.validation,
      );
    }

    int attemptCount = 0;
    CashfreeVerificationResult? lastResult;

    while (attemptCount < maxRetries) {
      attemptCount++;

      try {
        if (kDebugMode) {
          print(
            'CashfreePaymentService: Verification attempt $attemptCount/$maxRetries for order: $orderId',
          );
        }

        // Use backend service for verification
        final backendResult = await CashfreeBackendService.instance
            .getPaymentStatus(orderId);

        if (backendResult.success) {
          // Process successful verification result
          final verificationResult = _processVerificationResult(
            backendResult,
            orderId,
          );

          if (kDebugMode) {
            print(
              'CashfreePaymentService: Payment verification completed successfully on attempt $attemptCount',
            );
          }

          return verificationResult;
        } else {
          // Handle backend service error
          lastResult = CashfreeVerificationResult(
            success: false,
            orderId: orderId,
            error: backendResult.error ?? 'Backend verification failed',
            errorType: _mapBackendErrorType(backendResult.errorType),
            attemptCount: attemptCount,
          );

          // Check if we should retry based on error type
          if (!_shouldRetryVerification(backendResult.errorType) ||
              attemptCount >= maxRetries) {
            break;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print(
            'CashfreePaymentService: Verification attempt $attemptCount failed: $e',
          );
        }

        lastResult = CashfreeVerificationResult(
          success: false,
          orderId: orderId,
          error: 'Payment verification failed: $e',
          errorType: CashfreeErrorType.network,
          attemptCount: attemptCount,
        );

        // Don't retry on validation errors
        if (e is CashfreeServiceException &&
            e.type == CashfreeErrorType.validation) {
          break;
        }
      }

      // Wait before retry (except on last attempt)
      if (attemptCount < maxRetries) {
        if (kDebugMode) {
          print(
            'CashfreePaymentService: Waiting ${retryDelay.inSeconds}s before retry...',
          );
        }
        await Future.delayed(retryDelay);

        // Exponential backoff: double the delay for next retry
        retryDelay = Duration(
          milliseconds: (retryDelay.inMilliseconds * 1.5).round(),
        );
      }
    }

    if (kDebugMode) {
      print(
        'CashfreePaymentService: Payment verification failed after $maxRetries attempts',
      );
    }

    return lastResult ??
        CashfreeVerificationResult(
          success: false,
          orderId: orderId,
          error: 'Payment verification failed after $maxRetries attempts',
          errorType: CashfreeErrorType.network,
          attemptCount: attemptCount,
        );
  }

  /// Automatically verify payment after completion
  ///
  /// This method is called automatically after payment completion
  /// to verify the payment status and update the payment record.
  Future<CashfreeVerificationResult> autoVerifyPayment(
    String orderId, {
    Duration initialDelay = const Duration(seconds: 5),
  }) async {
    if (kDebugMode) {
      print(
        'CashfreePaymentService: Starting automatic payment verification for order: $orderId',
      );
    }

    // Wait for initial delay to allow payment processing to complete
    await Future.delayed(initialDelay);

    // Perform verification with retry logic
    final verificationResult = await verifyPaymentWithRetry(
      orderId,
      maxRetries: 5, // More retries for auto-verification
      retryDelay: const Duration(seconds: 3),
    );

    if (kDebugMode) {
      print(
        'CashfreePaymentService: Automatic verification completed: ${verificationResult.success}',
      );
    }

    return verificationResult;
  }

  /// Process verification result from backend service
  CashfreeVerificationResult _processVerificationResult(
    CashfreePaymentStatus backendResult,
    String orderId,
  ) {
    return CashfreeVerificationResult(
      success: true,
      orderId: orderId,
      paymentStatus: backendResult.paymentStatus,
      transactionId: backendResult.cfPaymentId,
      amount: backendResult.paymentAmount ?? backendResult.orderAmount,
      paymentMethod: backendResult.paymentMethod,
      bankReference: backendResult.bankReference,
      paymentTime: backendResult.paymentTime,
      failureReason: backendResult.failureReason,
      message: 'Payment verification completed successfully',
      attemptCount: 1,
    );
  }

  /// Map backend error types to service error types
  CashfreeErrorType _mapBackendErrorType(
    CashfreeBackendErrorType? backendErrorType,
  ) {
    if (backendErrorType == null) return CashfreeErrorType.system;

    switch (backendErrorType) {
      case CashfreeBackendErrorType.configuration:
        return CashfreeErrorType.configuration;
      case CashfreeBackendErrorType.validation:
        return CashfreeErrorType.validation;
      case CashfreeBackendErrorType.network:
        return CashfreeErrorType.network;
      case CashfreeBackendErrorType.api:
        return CashfreeErrorType.api;
      case CashfreeBackendErrorType.authentication:
        return CashfreeErrorType.api;
      case CashfreeBackendErrorType.notFound:
        return CashfreeErrorType.api;
      case CashfreeBackendErrorType.rateLimited:
        return CashfreeErrorType.api;
      case CashfreeBackendErrorType.server:
        return CashfreeErrorType.api;
      case CashfreeBackendErrorType.security:
        return CashfreeErrorType.system;
    }
  }

  /// Map webhook error types to service error types
  CashfreeErrorType _mapWebhookErrorType(
    CashfreeWebhookErrorType? webhookErrorType,
  ) {
    if (webhookErrorType == null) return CashfreeErrorType.system;

    switch (webhookErrorType) {
      case CashfreeWebhookErrorType.configuration:
        return CashfreeErrorType.configuration;
      case CashfreeWebhookErrorType.validation:
        return CashfreeErrorType.validation;
      case CashfreeWebhookErrorType.security:
        return CashfreeErrorType.security;
      case CashfreeWebhookErrorType.processing:
        return CashfreeErrorType.system;
      case CashfreeWebhookErrorType.network:
        return CashfreeErrorType.network;
    }
  }

  /// Determine if verification should be retried based on error type
  bool _shouldRetryVerification(CashfreeBackendErrorType? errorType) {
    if (errorType == null) return true;

    switch (errorType) {
      case CashfreeBackendErrorType.network:
      case CashfreeBackendErrorType.server:
      case CashfreeBackendErrorType.rateLimited:
        return true; // Retry these errors
      case CashfreeBackendErrorType.configuration:
      case CashfreeBackendErrorType.validation:
      case CashfreeBackendErrorType.authentication:
      case CashfreeBackendErrorType.notFound:
      case CashfreeBackendErrorType.security:
        return false; // Don't retry these errors
      case CashfreeBackendErrorType.api:
        return true; // Retry API errors (might be transient)
    }
  }

  /// Handle payment callback from Cashfree SDK
  void _handlePaymentCallback(String result) {
    if (kDebugMode) {
      print('CashfreePaymentService: Payment callback received: $result');
    }

    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      try {
        // Parse the JSON result from Cashfree SDK
        final Map<String, dynamic> resultData = json.decode(result);

        // Extract payment information
        final orderId = resultData['orderId'] as String?;
        final paymentSessionId = resultData['paymentSessionId'] as String?;
        final txStatus = resultData['txStatus'] as String?;
        final txMsg = resultData['txMsg'] as String?;
        final referenceId = resultData['referenceId'] as String?;
        final txTime = resultData['txTime'] as String?;

        // Determine if payment was successful
        final isSuccess = txStatus?.toUpperCase() == 'SUCCESS';

        if (kDebugMode) {
          print(
            'CashfreePaymentService: Parsed payment result - Status: $txStatus, Message: $txMsg',
          );
        }

        _paymentCompleter!.complete(
          CashfreePaymentResult(
            success: isSuccess,
            orderId: orderId,
            paymentId: paymentSessionId,
            transactionId: referenceId,
            message: isSuccess
                ? 'Payment completed successfully'
                : txMsg ?? 'Payment failed',
            error: isSuccess ? null : txMsg,
            errorType: isSuccess ? null : CashfreeErrorType.payment,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          print('CashfreePaymentService: Error parsing payment callback: $e');
        }

        // Fallback parsing for non-JSON responses
        final isSuccess =
            result.toLowerCase().contains('success') ||
            result.toLowerCase().contains('paid');

        _paymentCompleter!.complete(
          CashfreePaymentResult(
            success: isSuccess,
            message: isSuccess
                ? 'Payment completed successfully'
                : 'Payment failed',
            error: isSuccess ? null : 'Payment callback parsing failed: $e',
            errorType: isSuccess ? null : CashfreeErrorType.sdk,
          ),
        );
      }
    }
  }

  /// Handle payment error from Cashfree SDK
  void _handlePaymentError(CFErrorResponse errorResponse, String orderId) {
    if (kDebugMode) {
      print(
        'CashfreePaymentService: Payment error received for order: $orderId',
      );
      print('Error: ${errorResponse.getMessage()}');
    }

    if (_paymentCompleter != null && !_paymentCompleter!.isCompleted) {
      final sdkError = _errorHandler.handleSdkError(
        errorResponse.getMessage() ?? 'Payment failed',
        context: 'SDK payment callback',
        additionalDetails: {'orderId': orderId},
      );

      _paymentCompleter!.complete(
        CashfreePaymentResult(
          success: false,
          orderId: orderId,
          error: sdkError.userMessage,
          errorType: sdkError.type,
        ),
      );
    }
  }

  /// Validate payment session parameters
  void _validatePaymentSessionParams(
    String userId,
    double amount,
    String orderId,
  ) {
    if (userId.isEmpty) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'VALIDATION_USER_ID_REQUIRED',
          message: 'User ID cannot be empty',
          userMessage: 'User identification is required for payment.',
          type: CashfreeErrorType.validation,
          severity: CashfreeErrorSeverity.high,
          suggestedActions: [
            'Please ensure you are logged in',
            'Contact support if the problem persists',
          ],
        ),
      );
    }

    if (amount <= 0) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'VALIDATION_AMOUNT_INVALID',
          message: 'Amount must be greater than 0',
          userMessage: 'Please enter a valid payment amount.',
          type: CashfreeErrorType.validation,
          severity: CashfreeErrorSeverity.medium,
          suggestedActions: [
            'Enter an amount greater than ₹0',
            'Check the payment details',
          ],
        ),
      );
    }

    if (orderId.isEmpty) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'VALIDATION_ORDER_ID_REQUIRED',
          message: 'Order ID cannot be empty',
          userMessage: 'Order information is missing. Please try again.',
          type: CashfreeErrorType.validation,
          severity: CashfreeErrorSeverity.high,
          suggestedActions: [
            'Try creating a new payment',
            'Contact support if the problem persists',
          ],
        ),
      );
    }
  }

  /// Validate payment parameters
  void _validatePaymentParams(
    String userId,
    double amount,
    PaymentMethod method,
  ) {
    if (userId.isEmpty) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'VALIDATION_USER_ID_REQUIRED',
          message: 'User ID cannot be empty',
          userMessage: 'User identification is required for payment.',
          type: CashfreeErrorType.validation,
          severity: CashfreeErrorSeverity.high,
          suggestedActions: [
            'Please ensure you are logged in',
            'Contact support if the problem persists',
          ],
        ),
      );
    }

    if (amount <= 0) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'VALIDATION_AMOUNT_INVALID',
          message: 'Amount must be greater than 0',
          userMessage: 'Please enter a valid payment amount.',
          type: CashfreeErrorType.validation,
          severity: CashfreeErrorSeverity.medium,
          suggestedActions: [
            'Enter an amount greater than ₹0',
            'Check the payment details',
          ],
        ),
      );
    }

    // Validate that method is a Cashfree-supported method
    final cashfreeMethods = [
      PaymentMethod.CASHFREE_CARD,
      PaymentMethod.CASHFREE_UPI,
      PaymentMethod.CASHFREE_NETBANKING,
      PaymentMethod.CASHFREE_WALLET,
    ];

    if (!cashfreeMethods.contains(method)) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'VALIDATION_PAYMENT_METHOD_INVALID',
          message: 'Payment method $method is not supported by Cashfree',
          userMessage: 'Selected payment method is not supported.',
          type: CashfreeErrorType.validation,
          severity: CashfreeErrorSeverity.medium,
          suggestedActions: [
            'Choose a supported payment method (Card, UPI, Net Banking, or Wallet)',
            'Contact support if you need help selecting a payment method',
          ],
        ),
      );
    }
  }

  /// Validate combined payment parameters
  void _validateCombinedPaymentParams(
    String userId,
    double totalAmount,
    double walletAmount,
    double cashfreeAmount,
    PaymentMethod method,
  ) {
    // Basic validation
    _validatePaymentParams(userId, cashfreeAmount, method);

    if (totalAmount <= 0) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'VALIDATION_TOTAL_AMOUNT_INVALID',
          message: 'Total amount must be greater than 0',
          userMessage: 'Please enter a valid total payment amount.',
          type: CashfreeErrorType.validation,
          severity: CashfreeErrorSeverity.medium,
        ),
      );
    }

    if (walletAmount < 0) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'VALIDATION_WALLET_AMOUNT_INVALID',
          message: 'Wallet amount cannot be negative',
          userMessage: 'Wallet amount must be zero or positive.',
          type: CashfreeErrorType.validation,
          severity: CashfreeErrorSeverity.medium,
        ),
      );
    }

    if (cashfreeAmount < 0) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'VALIDATION_CASHFREE_AMOUNT_INVALID',
          message: 'Cashfree amount cannot be negative',
          userMessage: 'Cashfree payment amount must be zero or positive.',
          type: CashfreeErrorType.validation,
          severity: CashfreeErrorSeverity.medium,
        ),
      );
    }

    // Validate amount breakdown
    final calculatedTotal = walletAmount + cashfreeAmount;
    if ((calculatedTotal - totalAmount).abs() > 0.01) {
      // Allow for floating point precision
      throw CashfreeServiceException(
        CashfreeError(
          code: 'VALIDATION_AMOUNT_MISMATCH',
          message:
              'Wallet amount + Cashfree amount does not equal total amount',
          userMessage: 'Payment amount breakdown is incorrect.',
          type: CashfreeErrorType.validation,
          severity: CashfreeErrorSeverity.high,
          suggestedActions: [
            'Please recalculate the payment amounts',
            'Contact support if the problem persists',
          ],
        ),
      );
    }

    // Ensure at least one payment method has a positive amount
    if (walletAmount <= 0 && cashfreeAmount <= 0) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'VALIDATION_NO_PAYMENT_AMOUNT',
          message:
              'Either wallet amount or Cashfree amount must be greater than 0',
          userMessage:
              'At least one payment method must have a positive amount.',
          type: CashfreeErrorType.validation,
          severity: CashfreeErrorSeverity.high,
        ),
      );
    }
  }

  /// Build payment session request payload
  Map<String, dynamic> _buildPaymentSessionRequest({
    required String userId,
    required double amount,
    required String orderId,
    Map<String, dynamic>? customerDetails,
    Map<String, dynamic>? orderMeta,
  }) {
    return {
      'order_id': orderId,
      'order_amount': amount,
      'order_currency': _configService.defaultCurrency,
      'customer_details':
          customerDetails ??
          {
            'customer_id': userId,
            'customer_phone': '', // Will be populated from user data
            'customer_email': '', // Will be populated from user data
          },
      'order_meta':
          orderMeta ??
          {
            'return_url': '${_configService.backendUrl}/payment/return',
            'notify_url': '${_configService.backendUrl}/payment/webhook',
          },
    };
  }

  /// Make API call to backend
  Future<Map<String, dynamic>> _makeBackendApiCall({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final headers = _configService.getApiHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await _httpClient.post(
        endpoint,
        data: payload,
        options: Options(
          headers: headers,
          sendTimeout: _configService.apiTimeout,
          receiveTimeout: _configService.apiTimeout,
        ),
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw CashfreeServiceException(
          _errorHandler.handleHttpError(
            response.statusCode ?? 0,
            response.data?.toString() ?? '',
            context: 'Backend API call',
            additionalDetails: {'endpoint': endpoint},
          ),
        );
      }
    } on TimeoutException catch (e) {
      throw CashfreeServiceException(
        _errorHandler.handleException(
          e,
          context: 'Backend API call timeout',
          additionalDetails: {'endpoint': endpoint},
        ),
      );
    } catch (e) {
      if (e is CashfreeServiceException) rethrow;
      throw CashfreeServiceException(
        _errorHandler.handleException(
          e,
          context: 'Backend API call',
          additionalDetails: {'endpoint': endpoint},
        ),
      );
    }
  }

  /// Parse payment session response
  Map<String, dynamic> _parsePaymentSessionResponse(
    Map<String, dynamic> response,
  ) {
    if (response['payment_session_id'] == null) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'API_INVALID_RESPONSE',
          message: 'Invalid response: payment_session_id not found',
          userMessage:
              'Invalid response from payment service. Please try again.',
          type: CashfreeErrorType.api,
          severity: CashfreeErrorSeverity.high,
          retryStrategy: CashfreeRetryStrategy.linear,
          suggestedActions: [
            'Try again in a few moments',
            'Contact support if the problem persists',
          ],
          details: {'response': response},
        ),
      );
    }

    return response;
  }

  /// Parse verification response
  Map<String, dynamic> _parseVerificationResponse(
    Map<String, dynamic> response,
  ) {
    if (response['payment_status'] == null) {
      throw CashfreeServiceException(
        CashfreeError(
          code: 'API_INVALID_VERIFICATION_RESPONSE',
          message: 'Invalid verification response: payment_status not found',
          userMessage: 'Invalid response from payment verification service. Please try again.',
          type: CashfreeErrorType.api,
          severity: CashfreeErrorSeverity.high,
        ),
      );
    }

    return response;
  }

  /// Create CFSession for SDK with in-app payment configuration
  CFSession _createCFSession(String sessionId, String orderId) {
    final environment = _configService.isSandbox
        ? CFEnvironment.SANDBOX
        : CFEnvironment.PRODUCTION;

    if (kDebugMode) {
      print(
        'CashfreePaymentService: Creating CFSession for order: $orderId, session: $sessionId',
      );
    }

    return CFSessionBuilder()
        .setEnvironment(environment)
        .setPaymentSessionId(sessionId)
        .setOrderId(orderId)
        .build();
  }

  /// Initialize payment session for in-app processing
  ///
  /// This method creates and configures a payment session specifically
  /// for in-app WebView payment processing, ensuring the payment interface
  /// opens within the app rather than external browsers.
  Future<CFSession> initializeInAppPaymentSession({
    required String userId,
    required double amount,
    required String orderId,
    Map<String, dynamic>? customerDetails,
    Map<String, dynamic>? orderMeta,
  }) async {
    _ensureInitialized();

    try {
      if (kDebugMode) {
        print(
          'CashfreePaymentService: Initializing in-app payment session for order: $orderId',
        );
      }

      // Create payment session with backend
      final sessionResult = await createPaymentSession(
        userId: userId,
        amount: amount,
        orderId: orderId,
        customerDetails: customerDetails,
        orderMeta: orderMeta,
      );

      if (!sessionResult.success || sessionResult.sessionId == null) {
        throw CashfreeServiceException(
          CashfreeError(
            code: 'SESSION_CREATION_FAILED',
            message: sessionResult.error ?? 'Failed to create payment session',
            userMessage: sessionResult.error ?? 'Failed to create payment session',
            type: sessionResult.errorType ?? CashfreeErrorType.api,
          ),
        );
      }

      // Create CFSession for in-app payment
      final cfSession = _createCFSession(sessionResult.sessionId!, orderId);

      if (kDebugMode) {
        print(
          'CashfreePaymentService: In-app payment session initialized successfully',
        );
      }

      return cfSession;
    } catch (e) {
      if (kDebugMode) {
        print(
          'CashfreePaymentService: Error initializing in-app payment session: $e',
        );
      }

      if (e is CashfreeServiceException) {
        rethrow;
      }

      throw CashfreeServiceException(
        CashfreeError(
          code: 'IN_APP_SESSION_INIT_FAILED',
          message: 'Failed to initialize in-app payment session: $e',
          userMessage: 'Failed to initialize payment session. Please try again.',
          type: CashfreeErrorType.system,
        ),
      );
    }
  }

  /// Create payment component based on method
  Map<String, dynamic> _createPaymentComponent(
    PaymentMethod method,
    CFSession session,
  ) {
    if (kDebugMode) {
      print(
        'CashfreePaymentService: Creating payment component for method: ${method.name}',
      );
    }

    // Return payment component configuration with actual CFSession
    return {
      'method': method.name,
      'cfSession': session,
      'orderId': session.getOrderId(),
      'environment': session.getEnvironment().toString(),
    };
  }

  /// Execute payment using Cashfree SDK
  Future<CashfreePaymentResult> _executePayment(
    Map<String, dynamic> componentConfig,
  ) async {
    try {
      if (kDebugMode) {
        print('CashfreePaymentService: Starting payment execution');
        print('Component config: $componentConfig');
      }

      // Extract session from component config
      final session = componentConfig['cfSession'] as CFSession;

      // Create CFWebCheckoutPayment for in-app payment
      final webCheckoutPayment = CFWebCheckoutPaymentBuilder()
          .setSession(session)
          .setTheme(_createPaymentTheme())
          .build();

      // Create a completer for the payment result
      _paymentCompleter = Completer<CashfreePaymentResult>();

      // Start payment using Cashfree SDK
      await CFPaymentGatewayService().doPayment(webCheckoutPayment);

      if (kDebugMode) {
        print(
          'CashfreePaymentService: Payment initiated, waiting for result...',
        );
      }

      // Wait for payment completion with timeout
      final result = await _paymentCompleter!.future.timeout(
        const Duration(minutes: 10), // 10 minute timeout for payment
        onTimeout: () {
          return CashfreePaymentResult(
            success: false,
            error: 'Payment timeout - please try again',
            errorType: CashfreeErrorType.system,
          );
        },
      );

      if (kDebugMode) {
        print(
          'CashfreePaymentService: Payment execution completed: ${result.success}',
        );
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('CashfreePaymentService: Payment execution error: $e');
      }

      return CashfreePaymentResult(
        success: false,
        error: 'Payment execution failed: $e',
        errorType: CashfreeErrorType.sdk,
      );
    } finally {
      _paymentCompleter = null;
    }
  }

  /// Generate unique order ID
  String _generateOrderId(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'CF_${userId}_$timestamp';
  }

  /// Execute fallback payment when primary payment fails
  Future<CashfreeFallbackResult> _executeFallbackPayment({
    required CashfreeError error,
    required String userId,
    required double amount,
    required PaymentMethod originalMethod,
  }) async {
    if (kDebugMode) {
      print(
        'CashfreePaymentService: Executing fallback for error: ${error.code}',
      );
    }

    try {
      return await _fallbackService.executeFallback(
        error: error,
        userId: userId,
        amount: amount,
        originalMethod: originalMethod,
      );
    } catch (e) {
      if (kDebugMode) {
        print('CashfreePaymentService: Fallback execution failed: $e');
      }

      return CashfreeFallbackResult.failure(
        error: _errorHandler.handleException(e, context: 'Fallback execution'),
      );
    }
  }

  /// Check if payment should be retried based on error
  bool _shouldRetryPayment(dynamic error, PaymentMethod method) {
    if (error is CashfreeServiceException) {
      // Don't retry validation errors
      if (error.type == CashfreeErrorType.validation) {
        return false;
      }

      // Don't retry security errors
      if (error.type == CashfreeErrorType.security) {
        return false;
      }

      // Retry network and API errors
      return error.error.canRetry;
    }

    // Default retry logic for other errors
    return true;
  }

  /// Check if fallback should be attempted for the error
  bool _shouldAttemptFallback(CashfreeError error) {
    switch (error.type) {
      case CashfreeErrorType.network:
      case CashfreeErrorType.api:
      case CashfreeErrorType.payment:
      case CashfreeErrorType.sdk:
      case CashfreeErrorType.system:
      case CashfreeErrorType.configuration:
        return true;
      case CashfreeErrorType.validation:
      case CashfreeErrorType.security:
      case CashfreeErrorType.unknown:
        return false;
    }
  }

  /// Get available fallback payment methods for user
  Future<List<PaymentMethod>> getAvailableFallbackMethods({
    required CashfreeError error,
    required PaymentMethod originalMethod,
    required double amount,
  }) async {
    return _fallbackService.getAvailableFallbackMethods(
      error: error,
      originalMethod: originalMethod,
      amount: amount,
    );
  }

  /// Get user-friendly error message with suggested actions
  String getUserFriendlyErrorMessage(CashfreeError error) {
    final message = error.userMessage;
    final actions = error.suggestedActions;

    if (actions.isNotEmpty) {
      return '$message\n\nSuggested actions:\n${actions.map((action) => '• $action').join('\n')}';
    }

    return message;
  }

  /// Ensure the service is initialized before use
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'CashfreePaymentService has not been initialized. Call initialize() first.',
      );
    }

    if (_initializationFailed) {
      throw StateError(
        'CashfreePaymentService initialization failed: $_initializationError',
      );
    }
  }

  /// Process in-app payment using Cashfree SDK WebView
  ///
  /// This method handles the complete in-app payment flow, ensuring
  /// the payment interface opens within the app using WebView rather
  /// than redirecting to external browsers.
  Future<CashfreePaymentResult> processInAppPayment({
    required String userId,
    required double amount,
    required PaymentMethod method,
    double extraCharges = 0.0,
    String? note,
    Map<String, dynamic>? customerDetails,
    Map<String, dynamic>? orderMeta,
  }) async {
    _ensureInitialized();

    try {
      if (kDebugMode) {
        print(
          'CashfreePaymentService: Starting in-app payment processing for user: $userId',
        );
      }

      // Validate input parameters
      _validatePaymentParams(userId, amount, method);

      final totalAmount = amount + extraCharges;
      final orderId = _generateOrderId(userId);

      // Initialize in-app payment session
      final cfSession = await initializeInAppPaymentSession(
        userId: userId,
        amount: totalAmount,
        orderId: orderId,
        customerDetails: customerDetails,
        orderMeta: orderMeta,
      );

      // Create payment completer for result handling
      _paymentCompleter = Completer<CashfreePaymentResult>();

      if (kDebugMode) {
        print('CashfreePaymentService: Launching in-app payment interface');
      }

      // Create CFWebCheckoutPayment for in-app payment
      final webCheckoutPayment = CFWebCheckoutPaymentBuilder()
          .setSession(cfSession)
          .setTheme(_createPaymentTheme())
          .build();

      // Launch in-app payment using Cashfree SDK
      // The doPayment method will open the payment interface within the app
      await CFPaymentGatewayService().doPayment(webCheckoutPayment);

      // Wait for payment completion
      final result = await _paymentCompleter!.future.timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          return CashfreePaymentResult(
            success: false,
            orderId: orderId,
            error: 'Payment timeout - please try again',
            errorType: CashfreeErrorType.system,
          );
        },
      );

      if (kDebugMode) {
        print(
          'CashfreePaymentService: In-app payment processing completed: ${result.success}',
        );
      }

      // Perform automatic verification if payment was successful
      CashfreeVerificationResult? verificationResult;
      if (result.success) {
        if (kDebugMode) {
          print(
            'CashfreePaymentService: Starting automatic verification for successful payment',
          );
        }

        try {
          verificationResult = await autoVerifyPayment(orderId);
        } catch (e) {
          if (kDebugMode) {
            print('CashfreePaymentService: Auto-verification failed: $e');
          }
          // Don't fail the payment if verification fails - it can be retried later
        }
      }

      // Add additional context to the result
      return CashfreePaymentResult(
        success: result.success,
        paymentId: result.paymentId,
        orderId: result.orderId ?? orderId,
        transactionId: result.transactionId,
        amount: totalAmount,
        paymentMethod: method.name,
        message: result.message,
        error: result.error,
        errorType: result.errorType,
        verificationResult: verificationResult,
      );
    } catch (e) {
      if (kDebugMode) {
        print('CashfreePaymentService: Error in in-app payment processing: $e');
      }

      if (e is CashfreeServiceException) {
        return CashfreePaymentResult(
          success: false,
          error: e.message,
          errorType: e.type,
        );
      }

      return CashfreePaymentResult(
        success: false,
        error: 'In-app payment processing failed: $e',
        errorType: CashfreeErrorType.system,
      );
    } finally {
      _paymentCompleter = null;
    }
  }

  /// Create payment theme for in-app WebView
  ///
  /// This method creates a customized theme for the Cashfree payment WebView
  /// to ensure a consistent in-app experience.
  CFTheme _createPaymentTheme() {
    return CFThemeBuilder()
        .setNavigationBarBackgroundColorColor('#1976D2') // Primary blue color
        .setNavigationBarTextColor('#FFFFFF') // White text
        .setButtonBackgroundColor('#1976D2') // Primary blue for buttons
        .setButtonTextColor('#FFFFFF') // White button text
        .setPrimaryTextColor('#212121') // Dark text for readability
        .setSecondaryTextColor('#757575') // Gray secondary text
        .setBackgroundColor('#FFFFFF') // White background
        .build();
  }

  /// Handle webhook verification update
  ///
  /// This method processes webhook notifications to update payment status
  /// and provides an additional verification mechanism.
  Future<CashfreeVerificationResult> handleWebhookVerification({
    required Map<String, dynamic> webhookData,
    required String signature,
    String? timestamp,
  }) async {
    _ensureInitialized();

    try {
      if (kDebugMode) {
        print('CashfreePaymentService: Processing webhook verification');
      }

      // Process webhook through backend service
      final webhookResult = await CashfreeBackendService.instance
          .processWebhook(
            webhookData: webhookData,
            signature: signature,
            timestamp: timestamp,
          );

      if (!webhookResult.success) {
        return CashfreeVerificationResult(
          success: false,
          orderId: webhookResult.orderId ?? 'unknown',
          error: webhookResult.error ?? 'Webhook processing failed',
          errorType: _mapWebhookErrorType(webhookResult.errorType),
        );
      }

      // Extract order ID from webhook data
      final orderId =
          webhookResult.orderId ?? webhookData['order_id'] ?? 'unknown';

      // Perform additional verification using API
      final verificationResult = await verifyPaymentWithRetry(
        orderId,
        maxRetries: 2, // Fewer retries for webhook verification
      );

      if (kDebugMode) {
        print(
          'CashfreePaymentService: Webhook verification completed: ${verificationResult.success}',
        );
      }

      return verificationResult;
    } catch (e) {
      if (kDebugMode) {
        print('CashfreePaymentService: Error in webhook verification: $e');
      }

      return CashfreeVerificationResult(
        success: false,
        orderId: webhookData['order_id'] ?? 'unknown',
        error: 'Webhook verification failed: $e',
        errorType: CashfreeErrorType.system,
      );
    }
  }

  /// Batch verify multiple payments
  ///
  /// This method allows verification of multiple payments in batch
  /// for efficiency and better error handling.
  Future<List<CashfreeVerificationResult>> batchVerifyPayments(
    List<String> orderIds, {
    int maxConcurrentRequests = 3,
  }) async {
    _ensureInitialized();

    if (kDebugMode) {
      print(
        'CashfreePaymentService: Starting batch verification for ${orderIds.length} orders',
      );
    }

    final results = <CashfreeVerificationResult>[];

    // Process orders in batches to avoid overwhelming the API
    for (int i = 0; i < orderIds.length; i += maxConcurrentRequests) {
      final batch = orderIds.skip(i).take(maxConcurrentRequests).toList();

      // Create futures for concurrent verification
      final futures = batch
          .map(
            (orderId) => verifyPaymentWithRetry(
              orderId,
              maxRetries: 2, // Fewer retries for batch operations
            ),
          )
          .toList();

      // Wait for batch completion
      final batchResults = await Future.wait(futures);
      results.addAll(batchResults);

      // Small delay between batches to be respectful to the API
      if (i + maxConcurrentRequests < orderIds.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (kDebugMode) {
      final successCount = results.where((r) => r.success).length;
      print(
        'CashfreePaymentService: Batch verification completed: $successCount/${results.length} successful',
      );
    }

    return results;
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}

// CashfreeErrorType is imported from cashfree_error_model.dart

/// Result class for payment session creation
class CashfreePaymentSessionResult {
  final bool success;
  final String? sessionId;
  final String? orderId;
  final double? amount;
  final String? message;
  final String? error;
  final CashfreeErrorType? errorType;

  const CashfreePaymentSessionResult({
    required this.success,
    this.sessionId,
    this.orderId,
    this.amount,
    this.message,
    this.error,
    this.errorType,
  });

  @override
  String toString() {
    return 'CashfreePaymentSessionResult{success: $success, sessionId: $sessionId, error: $error}';
  }
}

/// Result class for payment verification
class CashfreeVerificationResult {
  final bool success;
  final String orderId;
  final String? paymentStatus;
  final String? transactionId;
  final double? amount;
  final String? paymentMethod;
  final String? bankReference;
  final DateTime? paymentTime;
  final String? failureReason;
  final String? message;
  final String? error;
  final CashfreeErrorType? errorType;
  final int? attemptCount;

  const CashfreeVerificationResult({
    required this.success,
    required this.orderId,
    this.paymentStatus,
    this.transactionId,
    this.amount,
    this.paymentMethod,
    this.bankReference,
    this.paymentTime,
    this.failureReason,
    this.message,
    this.error,
    this.errorType,
    this.attemptCount,
  });

  /// Check if payment was successful based on status
  bool get isPaymentSuccessful {
    return success &&
        paymentStatus != null &&
        (paymentStatus!.toUpperCase() == 'SUCCESS' ||
            paymentStatus!.toUpperCase() == 'PAID');
  }

  /// Check if payment failed
  bool get isPaymentFailed {
    return success &&
        paymentStatus != null &&
        (paymentStatus!.toUpperCase() == 'FAILED' ||
            paymentStatus!.toUpperCase() == 'CANCELLED');
  }

  /// Check if payment is still pending
  bool get isPaymentPending {
    return success &&
        paymentStatus != null &&
        paymentStatus!.toUpperCase() == 'PENDING';
  }

  @override
  String toString() {
    return 'CashfreeVerificationResult{success: $success, orderId: $orderId, status: $paymentStatus, error: $error}';
  }
}

/// Result class for payment processing
class CashfreePaymentResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? transactionId;
  final double? amount;
  final String? paymentMethod;
  final String? message;
  final String? error;
  final CashfreeErrorType? errorType;
  final CashfreeVerificationResult? verificationResult;

  const CashfreePaymentResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.transactionId,
    this.amount,
    this.paymentMethod,
    this.message,
    this.error,
    this.errorType,
    this.verificationResult,
  });

  /// Check if payment was verified successfully
  bool get isVerified => verificationResult?.success == true;

  /// Check if payment was successful and verified
  bool get isSuccessfulAndVerified =>
      success &&
      isVerified &&
      (verificationResult?.isPaymentSuccessful == true);

  /// Create a copy with modified fields
  CashfreePaymentResult copyWith({
    bool? success,
    String? paymentId,
    String? orderId,
    String? transactionId,
    double? amount,
    String? paymentMethod,
    String? message,
    String? error,
    CashfreeErrorType? errorType,
    CashfreeVerificationResult? verificationResult,
  }) {
    return CashfreePaymentResult(
      success: success ?? this.success,
      paymentId: paymentId ?? this.paymentId,
      orderId: orderId ?? this.orderId,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      message: message ?? this.message,
      error: error ?? this.error,
      errorType: errorType ?? this.errorType,
      verificationResult: verificationResult ?? this.verificationResult,
    );
  }

  @override
  String toString() {
    return 'CashfreePaymentResult{success: $success, orderId: $orderId, verified: $isVerified, error: $error}';
  }
}
