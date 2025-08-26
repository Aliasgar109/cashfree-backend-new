/// Comprehensive error handling service for Cashfree payment integration
/// 
/// This service provides centralized error handling, user-friendly message
/// generation, retry logic, and fallback mechanisms for payment failures.

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/cashfree_error_model.dart';
import '../models/payment_model.dart';

/// Comprehensive error handling service for Cashfree payments
class CashfreeErrorHandler {
  // Singleton pattern
  CashfreeErrorHandler._();
  static final CashfreeErrorHandler _instance = CashfreeErrorHandler._();
  static CashfreeErrorHandler get instance => _instance;

  /// Map of error codes to user-friendly messages
  static const Map<String, String> _errorMessages = {
    // Network errors
    'NETWORK_TIMEOUT': 'Connection timed out. Please check your internet connection and try again.',
    'NETWORK_UNAVAILABLE': 'No internet connection. Please check your network settings.',
    'NETWORK_DNS_ERROR': 'Unable to connect to payment service. Please try again later.',
    'NETWORK_SSL_ERROR': 'Secure connection failed. Please check your network settings.',
    
    // API errors
    'API_INVALID_REQUEST': 'Invalid request. Please check your payment details.',
    'API_UNAUTHORIZED': 'Authentication failed. Please try again.',
    'API_FORBIDDEN': 'Access denied. Please contact support.',
    'API_NOT_FOUND': 'Payment service not found. Please try again later.',
    'API_RATE_LIMITED': 'Too many requests. Please wait a moment and try again.',
    'API_SERVER_ERROR': 'Payment service is temporarily unavailable. Please try again later.',
    'API_BAD_GATEWAY': 'Payment gateway error. Please try again.',
    'API_SERVICE_UNAVAILABLE': 'Payment service is temporarily down. Please try again later.',
    'API_GATEWAY_TIMEOUT': 'Payment gateway timeout. Please try again.',
    
    // Payment errors
    'PAYMENT_DECLINED': 'Payment was declined. Please check your payment details or try a different payment method.',
    'PAYMENT_INSUFFICIENT_FUNDS': 'Insufficient funds. Please check your account balance.',
    'PAYMENT_INVALID_CARD': 'Invalid card details. Please check your card information.',
    'PAYMENT_EXPIRED_CARD': 'Card has expired. Please use a different card.',
    'PAYMENT_BLOCKED_CARD': 'Card is blocked. Please contact your bank or use a different card.',
    'PAYMENT_LIMIT_EXCEEDED': 'Payment limit exceeded. Please try with a smaller amount or contact your bank.',
    'PAYMENT_CANCELLED': 'Payment was cancelled. You can try again if needed.',
    'PAYMENT_FAILED': 'Payment failed. Please try again or use a different payment method.',
    'PAYMENT_PENDING': 'Payment is being processed. Please wait for confirmation.',
    'PAYMENT_TIMEOUT': 'Payment timed out. Please check your payment status or try again.',
    
    // Validation errors
    'VALIDATION_AMOUNT_INVALID': 'Please enter a valid payment amount.',
    'VALIDATION_AMOUNT_TOO_LOW': 'Payment amount is too low. Minimum amount is ₹1.',
    'VALIDATION_AMOUNT_TOO_HIGH': 'Payment amount is too high. Please contact support for large payments.',
    'VALIDATION_USER_ID_REQUIRED': 'User identification is required for payment.',
    'VALIDATION_ORDER_ID_REQUIRED': 'Order information is missing. Please try again.',
    'VALIDATION_PHONE_INVALID': 'Please enter a valid phone number.',
    'VALIDATION_EMAIL_INVALID': 'Please enter a valid email address.',
    'VALIDATION_PAYMENT_METHOD_INVALID': 'Selected payment method is not supported.',
    
    // System errors
    'SYSTEM_INITIALIZATION_FAILED': 'Payment system initialization failed. Please try again.',
    'SYSTEM_CONFIGURATION_ERROR': 'Payment system configuration error. Please contact support.',
    'SYSTEM_SDK_ERROR': 'Payment SDK error. Please try again or contact support.',
    'SYSTEM_UNKNOWN_ERROR': 'An unexpected error occurred. Please try again.',
    
    // Security errors
    'SECURITY_AUTHENTICATION_FAILED': 'Authentication failed. Please try again.',
    'SECURITY_AUTHORIZATION_FAILED': 'Authorization failed. Please contact support.',
    'SECURITY_SIGNATURE_INVALID': 'Security validation failed. Please try again.',
    'SECURITY_SESSION_EXPIRED': 'Session expired. Please start a new payment.',
    
    // Configuration errors
    'CONFIG_MISSING_KEYS': 'Payment configuration error. Please contact support.',
    'CONFIG_INVALID_ENVIRONMENT': 'Invalid payment environment. Please contact support.',
    'CONFIG_INVALID_CREDENTIALS': 'Invalid payment credentials. Please contact support.',
  };

  /// Map of HTTP status codes to error types
  static const Map<int, CashfreeErrorType> _httpStatusToErrorType = {
    400: CashfreeErrorType.validation,
    401: CashfreeErrorType.security,
    403: CashfreeErrorType.security,
    404: CashfreeErrorType.api,
    408: CashfreeErrorType.network,
    409: CashfreeErrorType.api,
    422: CashfreeErrorType.validation,
    429: CashfreeErrorType.api,
    500: CashfreeErrorType.api,
    502: CashfreeErrorType.api,
    503: CashfreeErrorType.api,
    504: CashfreeErrorType.network,
  };

  /// Handle and categorize exceptions into CashfreeError
  CashfreeError handleException(
    dynamic exception, {
    String? context,
    Map<String, dynamic>? additionalDetails,
  }) {
    if (kDebugMode) {
      print('CashfreeErrorHandler: Handling exception: $exception');
      if (context != null) {
        print('Context: $context');
      }
    }

    // Handle CashfreeServiceException
    if (exception is CashfreeServiceException) {
      return exception.error.copyWith(
        details: {
          ...?exception.error.details,
          ...?additionalDetails,
          if (context != null) 'context': context,
        },
      );
    }

    // Handle network exceptions
    if (exception is SocketException) {
      return _createNetworkError(
        'NETWORK_UNAVAILABLE',
        'No internet connection available',
        exception,
        additionalDetails,
        context,
      );
    }

    if (exception is TimeoutException) {
      return _createNetworkError(
        'NETWORK_TIMEOUT',
        'Connection timed out',
        exception,
        additionalDetails,
        context,
      );
    }

    if (exception is HttpException) {
      return _createApiError(
        'API_HTTP_ERROR',
        'HTTP error: ${exception.message}',
        exception,
        additionalDetails,
        context,
      );
    }

    // Handle HTTP client exceptions
    if (exception is http.ClientException) {
      return _createNetworkError(
        'NETWORK_CLIENT_ERROR',
        'Network client error: ${exception.message}',
        exception,
        additionalDetails,
        context,
      );
    }

    // Handle format exceptions (JSON parsing errors)
    if (exception is FormatException) {
      return _createApiError(
        'API_INVALID_RESPONSE',
        'Invalid response format: ${exception.message}',
        exception,
        additionalDetails,
        context,
      );
    }

    // Handle state errors
    if (exception is StateError) {
      return _createSystemError(
        'SYSTEM_STATE_ERROR',
        'System state error: ${exception.message}',
        exception,
        additionalDetails,
        context,
      );
    }

    // Handle argument errors
    if (exception is ArgumentError) {
      return _createValidationError(
        'VALIDATION_ARGUMENT_ERROR',
        'Invalid argument: ${exception.message}',
        exception,
        additionalDetails,
        context,
      );
    }

    // Handle generic exceptions
    return _createSystemError(
      'SYSTEM_UNKNOWN_ERROR',
      'Unknown error: ${exception.toString()}',
      exception,
      additionalDetails,
      context,
    );
  }

  /// Handle HTTP response errors
  CashfreeError handleHttpError(
    int statusCode,
    String responseBody, {
    String? context,
    Map<String, dynamic>? additionalDetails,
  }) {
    if (kDebugMode) {
      print('CashfreeErrorHandler: Handling HTTP error: $statusCode');
      print('Response body: $responseBody');
    }

    final errorType = _httpStatusToErrorType[statusCode] ?? CashfreeErrorType.api;
    final errorCode = 'HTTP_$statusCode';
    
    String message;
    String userMessage;

    switch (statusCode) {
      case 400:
        message = 'Bad request: $responseBody';
        userMessage = 'Invalid request. Please check your payment details.';
        break;
      case 401:
        message = 'Unauthorized: $responseBody';
        userMessage = 'Authentication failed. Please try again.';
        break;
      case 403:
        message = 'Forbidden: $responseBody';
        userMessage = 'Access denied. Please contact support.';
        break;
      case 404:
        message = 'Not found: $responseBody';
        userMessage = 'Payment service not found. Please try again later.';
        break;
      case 408:
        message = 'Request timeout: $responseBody';
        userMessage = 'Request timed out. Please try again.';
        break;
      case 409:
        message = 'Conflict: $responseBody';
        userMessage = 'Payment conflict. Please try again.';
        break;
      case 422:
        message = 'Unprocessable entity: $responseBody';
        userMessage = 'Invalid payment data. Please check your information.';
        break;
      case 429:
        message = 'Too many requests: $responseBody';
        userMessage = 'Too many requests. Please wait a moment and try again.';
        break;
      case 500:
        message = 'Internal server error: $responseBody';
        userMessage = 'Payment service error. Please try again later.';
        break;
      case 502:
        message = 'Bad gateway: $responseBody';
        userMessage = 'Payment gateway error. Please try again.';
        break;
      case 503:
        message = 'Service unavailable: $responseBody';
        userMessage = 'Payment service is temporarily unavailable. Please try again later.';
        break;
      case 504:
        message = 'Gateway timeout: $responseBody';
        userMessage = 'Payment gateway timeout. Please try again.';
        break;
      default:
        message = 'HTTP error $statusCode: $responseBody';
        userMessage = 'Payment service error. Please try again later.';
    }

    return CashfreeError(
      code: errorCode,
      message: message,
      userMessage: userMessage,
      type: errorType,
      severity: _getErrorSeverity(errorType),
      retryStrategy: _getRetryStrategy(errorType, statusCode),
      httpStatusCode: statusCode,
      details: {
        'statusCode': statusCode,
        'responseBody': responseBody,
        ...?additionalDetails,
        if (context != null) 'context': context,
      },
    );
  }

  /// Handle Cashfree SDK specific errors
  CashfreeError handleSdkError(
    String sdkErrorMessage, {
    String? errorCode,
    String? context,
    Map<String, dynamic>? additionalDetails,
  }) {
    if (kDebugMode) {
      print('CashfreeErrorHandler: Handling SDK error: $sdkErrorMessage');
    }

    final code = errorCode ?? 'SDK_ERROR';
    final userMessage = _getSdkUserMessage(sdkErrorMessage);

    return CashfreeError(
      code: code,
      message: 'Cashfree SDK error: $sdkErrorMessage',
      userMessage: userMessage,
      type: CashfreeErrorType.sdk,
      severity: CashfreeErrorSeverity.high,
      retryStrategy: CashfreeRetryStrategy.linear,
      details: {
        'sdkError': sdkErrorMessage,
        ...?additionalDetails,
        if (context != null) 'context': context,
      },
    );
  }

  /// Handle payment-specific errors
  CashfreeError handlePaymentError(
    String paymentStatus,
    String? failureReason, {
    String? context,
    Map<String, dynamic>? additionalDetails,
  }) {
    if (kDebugMode) {
      print('CashfreeErrorHandler: Handling payment error: $paymentStatus');
      print('Failure reason: $failureReason');
    }

    final code = 'PAYMENT_${paymentStatus.toUpperCase()}';
    final message = 'Payment $paymentStatus: ${failureReason ?? 'Unknown reason'}';
    final userMessage = _getPaymentUserMessage(paymentStatus, failureReason);

    return CashfreeError(
      code: code,
      message: message,
      userMessage: userMessage,
      type: CashfreeErrorType.payment,
      severity: _getPaymentErrorSeverity(paymentStatus),
      retryStrategy: _getPaymentRetryStrategy(paymentStatus),
      details: {
        'paymentStatus': paymentStatus,
        'failureReason': failureReason,
        ...?additionalDetails,
        if (context != null) 'context': context,
      },
    );
  }

  /// Execute operation with retry logic
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int? maxRetries,
    Duration? initialDelay,
    double? backoffMultiplier,
    Duration? maxDelay,
    bool Function(dynamic error)? shouldRetry,
    String? context,
  }) async {
    final retries = maxRetries ?? 3;
    final delay = initialDelay ?? const Duration(seconds: 1);
    final multiplier = backoffMultiplier ?? 2.0;
    final maxDelayDuration = maxDelay ?? const Duration(seconds: 30);

    int attemptCount = 0;
    Duration currentDelay = delay;

    while (attemptCount <= retries) {
      try {
        if (kDebugMode && attemptCount > 0) {
          print('CashfreeErrorHandler: Retry attempt $attemptCount/$retries');
        }

        final result = await operation();
        
        if (kDebugMode && attemptCount > 0) {
          print('CashfreeErrorHandler: Operation succeeded on attempt ${attemptCount + 1}');
        }
        
        return result;
      } catch (error) {
        attemptCount++;

        if (kDebugMode) {
          print('CashfreeErrorHandler: Attempt $attemptCount failed: $error');
        }

        // Check if we should retry this error
        final canRetry = shouldRetry?.call(error) ?? _shouldRetryError(error);
        
        if (attemptCount > retries || !canRetry) {
          if (kDebugMode) {
            print('CashfreeErrorHandler: Max retries reached or error not retryable');
          }
          
          // Convert to CashfreeError if needed
          if (error is CashfreeServiceException) {
            throw error;
          } else {
            throw CashfreeServiceException(handleException(
              error,
              context: context,
              additionalDetails: {'attemptCount': attemptCount},
            ));
          }
        }

        // Wait before retry (except on last attempt)
        if (attemptCount <= retries) {
          if (kDebugMode) {
            print('CashfreeErrorHandler: Waiting ${currentDelay.inMilliseconds}ms before retry');
          }
          
          await Future.delayed(currentDelay);
          
          // Exponential backoff
          currentDelay = Duration(
            milliseconds: min(
              (currentDelay.inMilliseconds * multiplier).round(),
              maxDelayDuration.inMilliseconds,
            ),
          );
        }
      }
    }

    // This should never be reached, but just in case
    throw CashfreeServiceException(CashfreeError(
      code: 'RETRY_EXHAUSTED',
      message: 'All retry attempts exhausted',
      userMessage: 'Operation failed after multiple attempts. Please try again later.',
      type: CashfreeErrorType.system,
    ));
  }

  /// Get user-friendly error message for error code
  String getUserMessage(String errorCode) {
    return _errorMessages[errorCode] ?? 'An unexpected error occurred. Please try again.';
  }

  /// Check if error should be retried
  bool _shouldRetryError(dynamic error) {
    if (error is CashfreeServiceException) {
      return error.error.canRetry;
    }

    // Retry network errors
    if (error is SocketException || 
        error is TimeoutException || 
        error is http.ClientException) {
      return true;
    }

    // Don't retry validation or security errors
    if (error is ArgumentError || error is FormatException) {
      return false;
    }

    // Default to retry for unknown errors
    return true;
  }

  /// Create network error
  CashfreeError _createNetworkError(
    String code,
    String message,
    dynamic exception,
    Map<String, dynamic>? additionalDetails,
    String? context,
  ) {
    return CashfreeError(
      code: code,
      message: message,
      userMessage: getUserMessage(code),
      type: CashfreeErrorType.network,
      severity: CashfreeErrorSeverity.medium,
      retryStrategy: CashfreeRetryStrategy.exponential,
      originalException: exception,
      details: {
        ...?additionalDetails,
        if (context != null) 'context': context,
      },
    );
  }

  /// Create API error
  CashfreeError _createApiError(
    String code,
    String message,
    dynamic exception,
    Map<String, dynamic>? additionalDetails,
    String? context,
  ) {
    return CashfreeError(
      code: code,
      message: message,
      userMessage: _getApiUserMessage(code, message),
      type: CashfreeErrorType.api,
      severity: CashfreeErrorSeverity.medium,
      retryStrategy: CashfreeRetryStrategy.linear,
      originalException: exception,
      details: {
        ...?additionalDetails,
        if (context != null) 'context': context,
      },
    );
  }

  /// Get user message for API errors
  String _getApiUserMessage(String code, String message) {
    final predefinedMessage = getUserMessage(code);
    if (predefinedMessage != 'An unexpected error occurred. Please try again.') {
      return predefinedMessage;
    }
    
    // For API errors, provide a generic but appropriate message
    return 'Service temporarily unavailable. Please try again later.';
  }

  /// Create system error
  CashfreeError _createSystemError(
    String code,
    String message,
    dynamic exception,
    Map<String, dynamic>? additionalDetails,
    String? context,
  ) {
    return CashfreeError(
      code: code,
      message: message,
      userMessage: getUserMessage(code),
      type: CashfreeErrorType.system,
      severity: CashfreeErrorSeverity.high,
      retryStrategy: CashfreeRetryStrategy.none,
      originalException: exception,
      details: {
        ...?additionalDetails,
        if (context != null) 'context': context,
      },
    );
  }

  /// Create validation error
  CashfreeError _createValidationError(
    String code,
    String message,
    dynamic exception,
    Map<String, dynamic>? additionalDetails,
    String? context,
  ) {
    return CashfreeError(
      code: code,
      message: message,
      userMessage: getUserMessage(code),
      type: CashfreeErrorType.validation,
      severity: CashfreeErrorSeverity.medium,
      retryStrategy: CashfreeRetryStrategy.none,
      originalException: exception,
      details: {
        ...?additionalDetails,
        if (context != null) 'context': context,
      },
    );
  }

  /// Get error severity based on type
  CashfreeErrorSeverity _getErrorSeverity(CashfreeErrorType type) {
    switch (type) {
      case CashfreeErrorType.network:
      case CashfreeErrorType.api:
        return CashfreeErrorSeverity.medium;
      case CashfreeErrorType.payment:
        return CashfreeErrorSeverity.high;
      case CashfreeErrorType.validation:
        return CashfreeErrorSeverity.medium;
      case CashfreeErrorType.system:
      case CashfreeErrorType.configuration:
      case CashfreeErrorType.security:
        return CashfreeErrorSeverity.high;
      case CashfreeErrorType.sdk:
        return CashfreeErrorSeverity.high;
      case CashfreeErrorType.unknown:
        return CashfreeErrorSeverity.medium;
    }
  }

  /// Get retry strategy based on error type and HTTP status
  CashfreeRetryStrategy _getRetryStrategy(CashfreeErrorType type, int? statusCode) {
    switch (type) {
      case CashfreeErrorType.network:
        return CashfreeRetryStrategy.exponential;
      case CashfreeErrorType.api:
        if (statusCode == 429) return CashfreeRetryStrategy.exponential;
        if (statusCode != null && statusCode >= 500) return CashfreeRetryStrategy.linear;
        return CashfreeRetryStrategy.none;
      case CashfreeErrorType.payment:
      case CashfreeErrorType.validation:
      case CashfreeErrorType.security:
      case CashfreeErrorType.configuration:
        return CashfreeRetryStrategy.none;
      case CashfreeErrorType.system:
      case CashfreeErrorType.sdk:
        return CashfreeRetryStrategy.linear;
      case CashfreeErrorType.unknown:
        return CashfreeRetryStrategy.linear;
    }
  }

  /// Get user message for SDK errors
  String _getSdkUserMessage(String sdkError) {
    final lowerError = sdkError.toLowerCase();
    
    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return 'Network connection error. Please check your internet connection and try again.';
    }
    
    if (lowerError.contains('timeout')) {
      return 'Payment timed out. Please try again.';
    }
    
    if (lowerError.contains('cancelled') || lowerError.contains('canceled')) {
      return 'Payment was cancelled. You can try again if needed.';
    }
    
    if (lowerError.contains('declined') || lowerError.contains('failed')) {
      return 'Payment failed. Please check your payment details and try again.';
    }
    
    return 'Payment processing error. Please try again or contact support.';
  }

  /// Get user message for payment errors
  String _getPaymentUserMessage(String status, String? reason) {
    final lowerStatus = status.toLowerCase();
    final lowerReason = reason?.toLowerCase() ?? '';
    
    switch (lowerStatus) {
      case 'failed':
        if (lowerReason.contains('insufficient')) {
          return 'Insufficient funds. Please check your account balance.';
        }
        if (lowerReason.contains('declined')) {
          return 'Payment was declined. Please check your payment details or try a different payment method.';
        }
        if (lowerReason.contains('expired')) {
          return 'Card has expired. Please use a different card.';
        }
        if (lowerReason.contains('blocked')) {
          return 'Card is blocked. Please contact your bank or use a different card.';
        }
        return 'Payment failed. Please try again or use a different payment method.';
      
      case 'cancelled':
      case 'canceled':
        return 'Payment was cancelled. You can try again if needed.';
      
      case 'timeout':
        return 'Payment timed out. Please check your payment status or try again.';
      
      case 'pending':
        return 'Payment is being processed. Please wait for confirmation.';
      
      default:
        return 'Payment could not be completed. Please try again.';
    }
  }

  /// Get error severity for payment errors
  CashfreeErrorSeverity _getPaymentErrorSeverity(String status) {
    switch (status.toLowerCase()) {
      case 'failed':
      case 'declined':
        return CashfreeErrorSeverity.high;
      case 'cancelled':
      case 'canceled':
        return CashfreeErrorSeverity.medium;
      case 'timeout':
        return CashfreeErrorSeverity.medium;
      case 'pending':
        return CashfreeErrorSeverity.low;
      default:
        return CashfreeErrorSeverity.medium;
    }
  }

  /// Get retry strategy for payment errors
  CashfreeRetryStrategy _getPaymentRetryStrategy(String status) {
    switch (status.toLowerCase()) {
      case 'timeout':
        return CashfreeRetryStrategy.linear;
      case 'failed':
      case 'declined':
      case 'cancelled':
      case 'canceled':
      case 'pending':
        return CashfreeRetryStrategy.none;
      default:
        return CashfreeRetryStrategy.none;
    }
  }
}