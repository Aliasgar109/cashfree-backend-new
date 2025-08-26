/// Fallback service for Cashfree payment failures
/// 
/// This service provides fallback mechanisms when Cashfree payments fail,
/// including alternative payment methods and graceful degradation to
/// existing UPI intent system.

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/cashfree_error_model.dart';
import '../models/payment_model.dart';
import 'cashfree_error_handler.dart';

/// Fallback strategies for payment failures
enum CashfreeFallbackStrategy {
  /// No fallback, fail immediately
  none,
  
  /// Retry with same payment method
  retry,
  
  /// Switch to alternative Cashfree payment method
  alternativeMethod,
  
  /// Fallback to existing UPI intent system
  upiIntent,
  
  /// Fallback to wallet payment
  wallet,
  
  /// Fallback to combined wallet + UPI payment
  combined,
  
  /// Manual payment (cash/bank transfer)
  manual,
}

/// Fallback configuration for different error types
class CashfreeFallbackConfig {
  /// Primary fallback strategy
  final CashfreeFallbackStrategy primaryStrategy;
  
  /// Secondary fallback strategy if primary fails
  final CashfreeFallbackStrategy? secondaryStrategy;
  
  /// Whether to show user the fallback options
  final bool showUserOptions;
  
  /// Maximum number of fallback attempts
  final int maxAttempts;
  
  /// Delay between fallback attempts
  final Duration delay;
  
  /// Custom message to show user during fallback
  final String? userMessage;

  const CashfreeFallbackConfig({
    required this.primaryStrategy,
    this.secondaryStrategy,
    this.showUserOptions = true,
    this.maxAttempts = 2,
    this.delay = const Duration(seconds: 2),
    this.userMessage,
  });
}

/// Result of fallback operation
class CashfreeFallbackResult {
  /// Whether fallback was successful
  final bool success;
  
  /// The fallback strategy that was used
  final CashfreeFallbackStrategy? usedStrategy;
  
  /// The payment method that was used in fallback
  final PaymentMethod? fallbackMethod;
  
  /// Error if fallback failed
  final CashfreeError? error;
  
  /// Message for user about the fallback
  final String? message;
  
  /// Additional data from fallback operation
  final Map<String, dynamic>? data;

  const CashfreeFallbackResult({
    required this.success,
    this.usedStrategy,
    this.fallbackMethod,
    this.error,
    this.message,
    this.data,
  });

  /// Create successful fallback result
  factory CashfreeFallbackResult.success({
    required CashfreeFallbackStrategy strategy,
    required PaymentMethod method,
    String? message,
    Map<String, dynamic>? data,
  }) {
    return CashfreeFallbackResult(
      success: true,
      usedStrategy: strategy,
      fallbackMethod: method,
      message: message,
      data: data,
    );
  }

  /// Create failed fallback result
  factory CashfreeFallbackResult.failure({
    required CashfreeError error,
    CashfreeFallbackStrategy? attemptedStrategy,
    String? message,
  }) {
    return CashfreeFallbackResult(
      success: false,
      usedStrategy: attemptedStrategy,
      error: error,
      message: message,
    );
  }
}

/// Comprehensive fallback service for Cashfree payment failures
class CashfreeFallbackService {
  // Singleton pattern
  CashfreeFallbackService._();
  static final CashfreeFallbackService _instance = CashfreeFallbackService._();
  static CashfreeFallbackService get instance => _instance;

  // Dependencies
  final CashfreeErrorHandler _errorHandler = CashfreeErrorHandler.instance;

  /// Default fallback configurations for different error types
  static const Map<CashfreeErrorType, CashfreeFallbackConfig> _defaultConfigs = {
    CashfreeErrorType.network: CashfreeFallbackConfig(
      primaryStrategy: CashfreeFallbackStrategy.retry,
      secondaryStrategy: CashfreeFallbackStrategy.upiIntent,
      maxAttempts: 3,
      delay: Duration(seconds: 5),
      userMessage: 'Network issue detected. Trying alternative payment method...',
    ),
    
    CashfreeErrorType.api: CashfreeFallbackConfig(
      primaryStrategy: CashfreeFallbackStrategy.retry,
      secondaryStrategy: CashfreeFallbackStrategy.upiIntent,
      maxAttempts: 2,
      delay: Duration(seconds: 3),
      userMessage: 'Payment service issue. Switching to alternative method...',
    ),
    
    CashfreeErrorType.payment: CashfreeFallbackConfig(
      primaryStrategy: CashfreeFallbackStrategy.alternativeMethod,
      secondaryStrategy: CashfreeFallbackStrategy.upiIntent,
      maxAttempts: 2,
      delay: Duration(seconds: 1),
      userMessage: 'Payment failed. Trying alternative payment method...',
    ),
    
    CashfreeErrorType.sdk: CashfreeFallbackConfig(
      primaryStrategy: CashfreeFallbackStrategy.upiIntent,
      secondaryStrategy: CashfreeFallbackStrategy.manual,
      maxAttempts: 1,
      delay: Duration(seconds: 1),
      userMessage: 'Payment system issue. Switching to UPI...',
    ),
    
    CashfreeErrorType.system: CashfreeFallbackConfig(
      primaryStrategy: CashfreeFallbackStrategy.upiIntent,
      secondaryStrategy: CashfreeFallbackStrategy.manual,
      maxAttempts: 1,
      delay: Duration(seconds: 1),
      userMessage: 'System error. Using alternative payment method...',
    ),
    
    CashfreeErrorType.configuration: CashfreeFallbackConfig(
      primaryStrategy: CashfreeFallbackStrategy.upiIntent,
      maxAttempts: 1,
      delay: Duration(seconds: 1),
      userMessage: 'Configuration issue. Using UPI payment...',
    ),
    
    CashfreeErrorType.security: CashfreeFallbackConfig(
      primaryStrategy: CashfreeFallbackStrategy.manual,
      maxAttempts: 1,
      delay: Duration(seconds: 1),
      userMessage: 'Security issue detected. Please use manual payment...',
    ),
    
    CashfreeErrorType.validation: CashfreeFallbackConfig(
      primaryStrategy: CashfreeFallbackStrategy.none,
      maxAttempts: 0,
      userMessage: 'Please check your payment details and try again.',
    ),
  };

  /// Execute fallback strategy for payment failure
  Future<CashfreeFallbackResult> executeFallback({
    required CashfreeError error,
    required String userId,
    required double amount,
    required PaymentMethod originalMethod,
    CashfreeFallbackConfig? customConfig,
    Map<String, dynamic>? additionalData,
  }) async {
    if (kDebugMode) {
      print('CashfreeFallbackService: Executing fallback for error: ${error.code}');
      print('Original method: ${originalMethod.name}');
    }

    final config = customConfig ?? _getDefaultConfig(error.type);
    
    if (config.primaryStrategy == CashfreeFallbackStrategy.none) {
      return CashfreeFallbackResult.failure(
        error: error,
        message: config.userMessage ?? 'Payment cannot be completed at this time.',
      );
    }

    // Try primary strategy
    final primaryResult = await _executeFallbackStrategy(
      strategy: config.primaryStrategy,
      error: error,
      userId: userId,
      amount: amount,
      originalMethod: originalMethod,
      config: config,
      additionalData: additionalData,
    );

    if (primaryResult.success) {
      return primaryResult;
    }

    // Try secondary strategy if available
    if (config.secondaryStrategy != null) {
      if (kDebugMode) {
        print('CashfreeFallbackService: Primary fallback failed, trying secondary strategy');
      }

      await Future.delayed(config.delay);

      final secondaryResult = await _executeFallbackStrategy(
        strategy: config.secondaryStrategy!,
        error: error,
        userId: userId,
        amount: amount,
        originalMethod: originalMethod,
        config: config,
        additionalData: additionalData,
      );

      if (secondaryResult.success) {
        return secondaryResult;
      }
    }

    // All fallback strategies failed
    return CashfreeFallbackResult.failure(
      error: CashfreeError(
        code: 'FALLBACK_EXHAUSTED',
        message: 'All fallback strategies failed',
        userMessage: 'Payment could not be completed. Please try again later or contact support.',
        type: CashfreeErrorType.system,
        severity: CashfreeErrorSeverity.high,
      ),
      message: 'All payment methods failed. Please try again later.',
    );
  }

  /// Get available fallback options for user selection
  List<PaymentMethod> getAvailableFallbackMethods({
    required CashfreeError error,
    required PaymentMethod originalMethod,
    required double amount,
  }) {
    final availableMethods = <PaymentMethod>[];
    
    // Based on error type and original method, suggest alternatives
    switch (error.type) {
      case CashfreeErrorType.network:
      case CashfreeErrorType.api:
      case CashfreeErrorType.sdk:
      case CashfreeErrorType.system:
        // For system issues, suggest non-Cashfree methods
        availableMethods.addAll([
          PaymentMethod.UPI,
          PaymentMethod.WALLET,
          PaymentMethod.COMBINED,
        ]);
        break;
        
      case CashfreeErrorType.payment:
        // For payment issues, suggest alternative Cashfree methods first
        if (originalMethod != PaymentMethod.CASHFREE_UPI) {
          availableMethods.add(PaymentMethod.CASHFREE_UPI);
        }
        if (originalMethod != PaymentMethod.CASHFREE_CARD) {
          availableMethods.add(PaymentMethod.CASHFREE_CARD);
        }
        if (originalMethod != PaymentMethod.CASHFREE_NETBANKING) {
          availableMethods.add(PaymentMethod.CASHFREE_NETBANKING);
        }
        
        // Then suggest non-Cashfree methods
        availableMethods.addAll([
          PaymentMethod.UPI,
          PaymentMethod.WALLET,
          PaymentMethod.COMBINED,
        ]);
        break;
        
      case CashfreeErrorType.configuration:
      case CashfreeErrorType.security:
        // For config/security issues, only suggest non-Cashfree methods
        availableMethods.addAll([
          PaymentMethod.UPI,
          PaymentMethod.WALLET,
          PaymentMethod.COMBINED,
          PaymentMethod.CASH,
        ]);
        break;
        
      case CashfreeErrorType.validation:
      case CashfreeErrorType.unknown:
        // For validation issues, suggest all methods
        availableMethods.addAll([
          PaymentMethod.CASHFREE_UPI,
          PaymentMethod.CASHFREE_CARD,
          PaymentMethod.CASHFREE_NETBANKING,
          PaymentMethod.UPI,
          PaymentMethod.WALLET,
          PaymentMethod.COMBINED,
        ]);
        break;
    }

    // Remove the original method from suggestions
    availableMethods.remove(originalMethod);
    
    // Filter based on amount constraints
    return availableMethods.where((method) => _isMethodAvailableForAmount(method, amount)).toList();
  }

  /// Get user-friendly fallback message
  String getFallbackMessage({
    required CashfreeError error,
    required CashfreeFallbackStrategy strategy,
    PaymentMethod? fallbackMethod,
  }) {
    final config = _getDefaultConfig(error.type);
    
    if (config.userMessage != null) {
      return config.userMessage!;
    }

    switch (strategy) {
      case CashfreeFallbackStrategy.retry:
        return 'Retrying payment. Please wait...';
      case CashfreeFallbackStrategy.alternativeMethod:
        return 'Trying alternative payment method...';
      case CashfreeFallbackStrategy.upiIntent:
        return 'Switching to UPI payment...';
      case CashfreeFallbackStrategy.wallet:
        return 'Using wallet payment...';
      case CashfreeFallbackStrategy.combined:
        return 'Using combined wallet + UPI payment...';
      case CashfreeFallbackStrategy.manual:
        return 'Please use manual payment method.';
      case CashfreeFallbackStrategy.none:
        return 'Payment could not be completed.';
    }
  }

  /// Check if Cashfree service is available
  Future<bool> isCashfreeAvailable() async {
    try {
      // This would typically check service health endpoint
      // For now, we'll simulate a basic availability check
      await Future.delayed(const Duration(milliseconds: 500));
      return true; // Assume available for now
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeFallbackService: Cashfree availability check failed: $e');
      }
      return false;
    }
  }

  /// Check if fallback to UPI intent is available
  bool isUpiIntentAvailable() {
    // Check if device supports UPI intents
    // This would typically check for UPI apps installed
    return true; // Assume available for now
  }

  /// Check if wallet payment is available
  Future<bool> isWalletAvailable(String userId) async {
    try {
      // This would check wallet service availability and user balance
      await Future.delayed(const Duration(milliseconds: 300));
      return true; // Assume available for now
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeFallbackService: Wallet availability check failed: $e');
      }
      return false;
    }
  }

  /// Execute specific fallback strategy
  Future<CashfreeFallbackResult> _executeFallbackStrategy({
    required CashfreeFallbackStrategy strategy,
    required CashfreeError error,
    required String userId,
    required double amount,
    required PaymentMethod originalMethod,
    required CashfreeFallbackConfig config,
    Map<String, dynamic>? additionalData,
  }) async {
    if (kDebugMode) {
      print('CashfreeFallbackService: Executing strategy: ${strategy.name}');
    }

    try {
      switch (strategy) {
        case CashfreeFallbackStrategy.none:
          return CashfreeFallbackResult.failure(
            error: error,
            attemptedStrategy: strategy,
            message: 'No fallback available',
          );

        case CashfreeFallbackStrategy.retry:
          return await _executeRetryStrategy(
            error: error,
            userId: userId,
            amount: amount,
            originalMethod: originalMethod,
            config: config,
          );

        case CashfreeFallbackStrategy.alternativeMethod:
          return await _executeAlternativeMethodStrategy(
            error: error,
            userId: userId,
            amount: amount,
            originalMethod: originalMethod,
            config: config,
          );

        case CashfreeFallbackStrategy.upiIntent:
          return await _executeUpiIntentStrategy(
            error: error,
            userId: userId,
            amount: amount,
            config: config,
          );

        case CashfreeFallbackStrategy.wallet:
          return await _executeWalletStrategy(
            error: error,
            userId: userId,
            amount: amount,
            config: config,
          );

        case CashfreeFallbackStrategy.combined:
          return await _executeCombinedStrategy(
            error: error,
            userId: userId,
            amount: amount,
            config: config,
          );

        case CashfreeFallbackStrategy.manual:
          return _executeManualStrategy(
            error: error,
            userId: userId,
            amount: amount,
            config: config,
          );
      }
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeFallbackService: Strategy execution failed: $e');
      }

      return CashfreeFallbackResult.failure(
        error: _errorHandler.handleException(
          e,
          context: 'Fallback strategy execution',
          additionalDetails: {
            'strategy': strategy.name,
            'originalError': error.code,
          },
        ),
        attemptedStrategy: strategy,
        message: 'Fallback strategy failed',
      );
    }
  }

  /// Execute retry strategy
  Future<CashfreeFallbackResult> _executeRetryStrategy({
    required CashfreeError error,
    required String userId,
    required double amount,
    required PaymentMethod originalMethod,
    required CashfreeFallbackConfig config,
  }) async {
    // For retry strategy, we would typically retry the original payment
    // This is a placeholder implementation
    await Future.delayed(config.delay);
    
    // Simulate retry success/failure
    final retrySuccess = error.canRetry && error.type == CashfreeErrorType.network;
    
    if (retrySuccess) {
      return CashfreeFallbackResult.success(
        strategy: CashfreeFallbackStrategy.retry,
        method: originalMethod,
        message: 'Payment retry successful',
      );
    } else {
      return CashfreeFallbackResult.failure(
        error: error,
        attemptedStrategy: CashfreeFallbackStrategy.retry,
        message: 'Payment retry failed',
      );
    }
  }

  /// Execute alternative method strategy
  Future<CashfreeFallbackResult> _executeAlternativeMethodStrategy({
    required CashfreeError error,
    required String userId,
    required double amount,
    required PaymentMethod originalMethod,
    required CashfreeFallbackConfig config,
  }) async {
    // Find alternative Cashfree payment method
    final alternativeMethod = _getAlternativeCashfreeMethod(originalMethod);
    
    if (alternativeMethod == null) {
      return CashfreeFallbackResult.failure(
        error: CashfreeError(
          code: 'NO_ALTERNATIVE_METHOD',
          message: 'No alternative Cashfree method available',
          userMessage: 'No alternative payment method available',
          type: CashfreeErrorType.system,
        ),
        attemptedStrategy: CashfreeFallbackStrategy.alternativeMethod,
      );
    }

    // This would typically initiate payment with alternative method
    // For now, we'll simulate success
    return CashfreeFallbackResult.success(
      strategy: CashfreeFallbackStrategy.alternativeMethod,
      method: alternativeMethod,
      message: 'Switched to ${alternativeMethod.name}',
    );
  }

  /// Execute UPI intent strategy
  Future<CashfreeFallbackResult> _executeUpiIntentStrategy({
    required CashfreeError error,
    required String userId,
    required double amount,
    required CashfreeFallbackConfig config,
  }) async {
    if (!isUpiIntentAvailable()) {
      return CashfreeFallbackResult.failure(
        error: CashfreeError(
          code: 'UPI_INTENT_UNAVAILABLE',
          message: 'UPI intent not available',
          userMessage: 'UPI payment not available on this device',
          type: CashfreeErrorType.system,
        ),
        attemptedStrategy: CashfreeFallbackStrategy.upiIntent,
      );
    }

    // This would typically launch UPI intent
    // For now, we'll simulate success
    return CashfreeFallbackResult.success(
      strategy: CashfreeFallbackStrategy.upiIntent,
      method: PaymentMethod.UPI,
      message: 'Switched to UPI payment',
    );
  }

  /// Execute wallet strategy
  Future<CashfreeFallbackResult> _executeWalletStrategy({
    required CashfreeError error,
    required String userId,
    required double amount,
    required CashfreeFallbackConfig config,
  }) async {
    final walletAvailable = await isWalletAvailable(userId);
    
    if (!walletAvailable) {
      return CashfreeFallbackResult.failure(
        error: CashfreeError(
          code: 'WALLET_UNAVAILABLE',
          message: 'Wallet payment not available',
          userMessage: 'Wallet payment not available',
          type: CashfreeErrorType.system,
        ),
        attemptedStrategy: CashfreeFallbackStrategy.wallet,
      );
    }

    // This would typically process wallet payment
    // For now, we'll simulate success
    return CashfreeFallbackResult.success(
      strategy: CashfreeFallbackStrategy.wallet,
      method: PaymentMethod.WALLET,
      message: 'Using wallet payment',
    );
  }

  /// Execute combined strategy
  Future<CashfreeFallbackResult> _executeCombinedStrategy({
    required CashfreeError error,
    required String userId,
    required double amount,
    required CashfreeFallbackConfig config,
  }) async {
    final walletAvailable = await isWalletAvailable(userId);
    final upiAvailable = isUpiIntentAvailable();
    
    if (!walletAvailable || !upiAvailable) {
      return CashfreeFallbackResult.failure(
        error: CashfreeError(
          code: 'COMBINED_UNAVAILABLE',
          message: 'Combined payment not available',
          userMessage: 'Combined payment not available',
          type: CashfreeErrorType.system,
        ),
        attemptedStrategy: CashfreeFallbackStrategy.combined,
      );
    }

    // This would typically process combined payment
    // For now, we'll simulate success
    return CashfreeFallbackResult.success(
      strategy: CashfreeFallbackStrategy.combined,
      method: PaymentMethod.COMBINED,
      message: 'Using combined wallet + UPI payment',
    );
  }

  /// Execute manual strategy
  CashfreeFallbackResult _executeManualStrategy({
    required CashfreeError error,
    required String userId,
    required double amount,
    required CashfreeFallbackConfig config,
  }) {
    return CashfreeFallbackResult.success(
      strategy: CashfreeFallbackStrategy.manual,
      method: PaymentMethod.CASH,
      message: 'Please use manual payment method (cash or bank transfer)',
      data: {
        'requiresManualProcessing': true,
        'amount': amount,
        'userId': userId,
      },
    );
  }

  /// Get default configuration for error type
  CashfreeFallbackConfig _getDefaultConfig(CashfreeErrorType errorType) {
    return _defaultConfigs[errorType] ?? const CashfreeFallbackConfig(
      primaryStrategy: CashfreeFallbackStrategy.upiIntent,
      maxAttempts: 1,
    );
  }

  /// Get alternative Cashfree payment method
  PaymentMethod? _getAlternativeCashfreeMethod(PaymentMethod originalMethod) {
    switch (originalMethod) {
      case PaymentMethod.CASHFREE_CARD:
        return PaymentMethod.CASHFREE_UPI;
      case PaymentMethod.CASHFREE_UPI:
        return PaymentMethod.CASHFREE_NETBANKING;
      case PaymentMethod.CASHFREE_NETBANKING:
        return PaymentMethod.CASHFREE_CARD;
      case PaymentMethod.CASHFREE_WALLET:
        return PaymentMethod.CASHFREE_UPI;
      default:
        return null;
    }
  }

  /// Check if payment method is available for amount
  bool _isMethodAvailableForAmount(PaymentMethod method, double amount) {
    // Basic amount constraints for different payment methods
    switch (method) {
      case PaymentMethod.UPI:
        return amount <= 100000; // UPI limit
      case PaymentMethod.WALLET:
        return amount <= 10000; // Typical wallet limit
      case PaymentMethod.COMBINED:
        return amount <= 110000; // Combined limit
      case PaymentMethod.CASH:
        return amount <= 50000; // Cash handling limit
      default:
        return true; // No specific limits for Cashfree methods
    }
  }
}