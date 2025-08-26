/// Example demonstrating comprehensive error handling in Cashfree payment integration
/// 
/// This example shows how to use the error handling system, including
/// error categorization, user-friendly messages, retry logic, and fallback mechanisms.

import 'dart:async';
import 'dart:io';

import '../models/cashfree_error_model.dart';
import '../models/payment_model.dart';
import '../services/cashfree_error_handler.dart';
import '../services/cashfree_fallback_service.dart';
import '../services/cashfree_payment_service.dart';

/// Example class demonstrating comprehensive error handling
class ErrorHandlingExample {
  final CashfreePaymentService _paymentService = CashfreePaymentService.instance;
  final CashfreeErrorHandler _errorHandler = CashfreeErrorHandler.instance;
  final CashfreeFallbackService _fallbackService = CashfreeFallbackService.instance;

  /// Example 1: Basic error handling with user-friendly messages
  Future<void> basicErrorHandlingExample() async {
    print('=== Basic Error Handling Example ===');
    
    try {
      // Simulate a network error
      throw const SocketException('No internet connection');
    } catch (e) {
      final error = _errorHandler.handleException(
        e,
        context: 'Payment processing',
        additionalDetails: {'userId': 'user123', 'amount': 100.0},
      );

      print('Error Code: ${error.code}');
      print('Technical Message: ${error.message}');
      print('User Message: ${error.userMessage}');
      print('Error Type: ${error.type.name}');
      print('Can Retry: ${error.canRetry}');
      print('Suggested Actions:');
      for (final action in error.suggestedActions) {
        print('  • $action');
      }
    }
  }

  /// Example 2: Retry logic with exponential backoff
  Future<void> retryLogicExample() async {
    print('\n=== Retry Logic Example ===');
    
    int attemptCount = 0;
    
    try {
      final result = await _errorHandler.executeWithRetry<String>(
        () async {
          attemptCount++;
          print('Attempt $attemptCount');
          
          if (attemptCount < 3) {
            throw TimeoutException('Connection timeout', const Duration(seconds: 30));
          }
          
          return 'Payment successful!';
        },
        maxRetries: 3,
        initialDelay: const Duration(milliseconds: 500),
        backoffMultiplier: 2.0,
        context: 'Payment retry example',
      );
      
      print('Final result: $result');
      print('Total attempts: $attemptCount');
    } catch (e) {
      print('All retry attempts failed: $e');
    }
  }

  /// Example 3: Payment processing with comprehensive error handling
  Future<void> paymentProcessingExample() async {
    print('\n=== Payment Processing with Error Handling Example ===');
    
    try {
      final result = await _paymentService.processPaymentWithErrorHandling(
        userId: 'user123',
        amount: 500.0,
        method: PaymentMethod.CASHFREE_CARD,
        enableFallback: true,
      );
      
      if (result.success) {
        print('Payment successful!');
        print('Payment ID: ${result.paymentId}');
        print('Order ID: ${result.orderId}');
        print('Method: ${result.paymentMethod}');
      } else {
        print('Payment failed: ${result.error}');
        print('Error type: ${result.errorType?.name}');
      }
    } catch (e) {
      print('Payment processing error: $e');
    }
  }

  /// Example 4: Fallback mechanism demonstration
  Future<void> fallbackMechanismExample() async {
    print('\n=== Fallback Mechanism Example ===');
    
    // Simulate a payment failure
    final paymentError = CashfreeError(
      code: 'PAYMENT_DECLINED',
      message: 'Payment was declined by the bank',
      userMessage: 'Payment was declined. Please try a different payment method.',
      type: CashfreeErrorType.payment,
    );

    // Get available fallback methods
    final fallbackMethods = _fallbackService.getAvailableFallbackMethods(
      error: paymentError,
      originalMethod: PaymentMethod.CASHFREE_CARD,
      amount: 500.0,
    );

    print('Original payment method failed: ${PaymentMethod.CASHFREE_CARD.name}');
    print('Available fallback methods:');
    for (final method in fallbackMethods) {
      print('  • ${method.name}');
    }

    // Execute fallback
    final fallbackResult = await _fallbackService.executeFallback(
      error: paymentError,
      userId: 'user123',
      amount: 500.0,
      originalMethod: PaymentMethod.CASHFREE_CARD,
    );

    if (fallbackResult.success) {
      print('Fallback successful!');
      print('Used strategy: ${fallbackResult.usedStrategy?.name}');
      print('Fallback method: ${fallbackResult.fallbackMethod?.name}');
      print('Message: ${fallbackResult.message}');
    } else {
      print('Fallback failed: ${fallbackResult.error?.userMessage}');
    }
  }

  /// Example 5: HTTP error handling
  Future<void> httpErrorHandlingExample() async {
    print('\n=== HTTP Error Handling Example ===');
    
    // Simulate different HTTP errors
    final httpErrors = [
      (400, 'Bad Request: Invalid payment data'),
      (401, 'Unauthorized: Authentication failed'),
      (429, 'Too Many Requests: Rate limit exceeded'),
      (500, 'Internal Server Error: Payment service error'),
      (504, 'Gateway Timeout: Payment gateway timeout'),
    ];

    for (final (statusCode, responseBody) in httpErrors) {
      final error = _errorHandler.handleHttpError(
        statusCode,
        responseBody,
        context: 'API call example',
      );

      print('\nHTTP $statusCode Error:');
      print('  User Message: ${error.userMessage}');
      print('  Can Retry: ${error.canRetry}');
      print('  Retry Strategy: ${error.retryStrategy.name}');
      print('  Severity: ${error.severity.name}');
    }
  }

  /// Example 6: SDK error handling
  Future<void> sdkErrorHandlingExample() async {
    print('\n=== SDK Error Handling Example ===');
    
    final sdkErrors = [
      'Network connection failed',
      'Payment timeout occurred',
      'Payment was cancelled by user',
      'Payment declined by bank',
      'Unknown SDK error',
    ];

    for (final sdkErrorMessage in sdkErrors) {
      final error = _errorHandler.handleSdkError(
        sdkErrorMessage,
        context: 'SDK operation',
      );

      print('\nSDK Error: $sdkErrorMessage');
      print('  User Message: ${error.userMessage}');
      print('  Error Type: ${error.type.name}');
      print('  Severity: ${error.severity.name}');
    }
  }

  /// Example 7: Custom error creation and handling
  Future<void> customErrorExample() async {
    print('\n=== Custom Error Example ===');
    
    // Create a custom error
    final customError = CashfreeError(
      code: 'CUSTOM_BUSINESS_ERROR',
      message: 'Business rule validation failed',
      userMessage: 'Payment amount exceeds daily limit',
      description: 'User has exceeded their daily payment limit of ₹10,000',
      type: CashfreeErrorType.validation,
      severity: CashfreeErrorSeverity.high,
      details: {
        'dailyLimit': 10000,
        'currentAmount': 15000,
        'userId': 'user123',
      },
      suggestedActions: [
        'Try with a smaller amount',
        'Contact support to increase your limit',
        'Try again tomorrow',
      ],
    );

    print('Custom Error Details:');
    print('  Code: ${customError.code}');
    print('  User Message: ${customError.userMessage}');
    print('  Description: ${customError.description}');
    print('  Severity: ${customError.severity.name}');
    print('  Can Retry: ${customError.canRetry}');
    print('  Details: ${customError.details}');
    print('  Suggested Actions:');
    for (final action in customError.suggestedActions) {
      print('    • $action');
    }

    // Convert to JSON for logging
    final errorJson = customError.toJson();
    print('  JSON: $errorJson');
  }

  /// Example 8: Error result wrapper usage
  Future<void> errorResultWrapperExample() async {
    print('\n=== Error Result Wrapper Example ===');
    
    // Simulate a service method that returns CashfreeResult
    CashfreeResult<String> simulatePaymentOperation(bool shouldSucceed) {
      if (shouldSucceed) {
        return CashfreeResult.success('Payment completed successfully');
      } else {
        final error = CashfreeError(
          code: 'PAYMENT_FAILED',
          message: 'Payment processing failed',
          userMessage: 'Payment could not be processed. Please try again.',
          type: CashfreeErrorType.payment,
        );
        return CashfreeResult.failure(error);
      }
    }

    // Success case
    final successResult = simulatePaymentOperation(true);
    if (successResult.isSuccess) {
      print('Success: ${successResult.dataOrThrow}');
    }

    // Failure case
    final failureResult = simulatePaymentOperation(false);
    if (failureResult.isFailure) {
      print('Failure: ${failureResult.error?.userMessage}');
    }

    // Chain operations
    final chainedResult = successResult
        .map((data) => 'Processed: $data')
        .flatMap((data) => CashfreeResult.success('Final: $data'));

    if (chainedResult.isSuccess) {
      print('Chained result: ${chainedResult.dataOrThrow}');
    }
  }

  /// Run all examples
  Future<void> runAllExamples() async {
    print('🚀 Cashfree Error Handling Examples\n');
    
    await basicErrorHandlingExample();
    await retryLogicExample();
    await paymentProcessingExample();
    await fallbackMechanismExample();
    await httpErrorHandlingExample();
    await sdkErrorHandlingExample();
    await customErrorExample();
    await errorResultWrapperExample();
    
    print('\n✅ All examples completed!');
  }
}

/// Main function to run the examples
Future<void> main() async {
  final example = ErrorHandlingExample();
  await example.runAllExamples();
}