import 'package:flutter/foundation.dart';

/// Cashfree Payment Gateway configuration for TV Subscription Payment App
/// 
/// This service manages environment-specific configuration for Cashfree integration,
/// ensuring secure handling of credentials and proper environment detection.
/// 
/// Security Note: App ID and Secret Key are never exposed in the mobile app.
/// Only the backend server should have access to these sensitive credentials.
class CashfreeConfig {
  // Private constructor to prevent instantiation
  CashfreeConfig._();
  
  // Singleton instance
  static final CashfreeConfig _instance = CashfreeConfig._();
  static CashfreeConfig get instance => _instance;
  
  // Environment detection
  static const bool _kIsProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  static const bool _kIsSandbox = !_kIsProduction;
  
  // Cashfree API Base URLs
  static const String _sandboxBaseUrl = 'https://sandbox.cashfree.com/pg';
  static const String _productionBaseUrl = 'https://api.cashfree.com/pg';
  
  // Backend API endpoints for Cashfree operations (Supabase Edge Functions)
  static const String _sandboxBackendUrl = 'https://rsaylanpqnenfecsevoj.supabase.co/functions/v1';
  static const String _productionBackendUrl = 'https://rsaylanpqnenfecsevoj.supabase.co/functions/v1';
  
  // Webhook secrets for signature verification
  // TODO: Replace with actual webhook secrets from Cashfree dashboard
  static const String _sandboxWebhookSecret = 'your-sandbox-webhook-secret';
  static const String _productionWebhookSecret = 'your-production-webhook-secret';
  
  // Cashfree SDK Environment Constants
  static const String sandboxEnvironment = 'SANDBOX';
  static const String productionEnvironment = 'PRODUCTION';
  
  // Payment configuration
  static const String defaultCurrency = 'INR';
  static const int paymentTimeoutSeconds = 300; // 5 minutes
  static const int apiTimeoutSeconds = 30;
  
  // Supported payment methods
  static const List<String> supportedPaymentMethods = [
    'cc', // Credit Card
    'dc', // Debit Card
    'upi', // UPI
    'nb', // Net Banking
    'wallet', // Wallets
  ];
  
  // Webhook configuration
  static const String webhookVersion = '2022-09-01';
  
  /// Get current environment (sandbox or production)
  bool get isSandbox => _kIsSandbox;
  
  /// Get current environment (sandbox or production)
  bool get isProduction => _kIsProduction;
  
  /// Get Cashfree API base URL based on current environment
  String get baseUrl => isSandbox ? _sandboxBaseUrl : _productionBaseUrl;
  
  /// Get backend API URL for Cashfree operations based on current environment
  String get backendUrl => isSandbox ? _sandboxBackendUrl : _productionBackendUrl;
  
  /// Get Cashfree SDK environment string
  String get environment => isSandbox ? sandboxEnvironment : productionEnvironment;
  
  /// Get environment display name for debugging
  String get environmentName => isSandbox ? 'Sandbox' : 'Production';
  
  /// Check if debug mode is enabled (only in sandbox)
  bool get isDebugEnabled => isSandbox && kDebugMode;
  
  /// Get API timeout duration
  Duration get apiTimeout => Duration(seconds: apiTimeoutSeconds);
  
  /// Get payment timeout duration
  Duration get paymentTimeout => Duration(seconds: paymentTimeoutSeconds);
  
  /// Get order creation endpoint
  String get createOrderEndpoint => '$backendUrl/create-cashfree-order';
  
  /// Get payment verification endpoint
  String get verifyPaymentEndpoint => '$backendUrl/verify-cashfree-payment';
  
  /// Get webhook endpoint
  String get webhookEndpoint => '$backendUrl/cashfree-webhook';
  
  /// Get payment session endpoint
  String get paymentSessionEndpoint => '$backendUrl/create-cashfree-order';
  
  /// Get webhook secret for signature verification
  String get webhookSecret => isSandbox ? _sandboxWebhookSecret : _productionWebhookSecret;
  
  /// Validate configuration
  bool validateConfiguration() {
    try {
      // Check if base URLs are valid
      if (baseUrl.isEmpty || backendUrl.isEmpty) {
        if (kDebugMode) {
          print('CashfreeConfig: Invalid base URLs');
        }
        return false;
      }
      
      // Check if URLs are properly formatted
      final baseUri = Uri.tryParse(baseUrl);
      final backendUri = Uri.tryParse(backendUrl);
      
      if (baseUri == null || backendUri == null) {
        if (kDebugMode) {
          print('CashfreeConfig: Invalid URL format');
        }
        return false;
      }
      
      // Check if URLs use HTTPS (except for localhost in debug mode)
      if (!isDebugEnabled) {
        if (baseUri.scheme != 'https' || backendUri.scheme != 'https') {
          if (kDebugMode) {
            print('CashfreeConfig: URLs must use HTTPS in production');
          }
          return false;
        }
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeConfig: Configuration validation error: $e');
      }
      return false;
    }
  }
  
  /// Get configuration summary for debugging
  Map<String, dynamic> getConfigSummary() {
    return {
      'environment': environmentName,
      'isSandbox': isSandbox,
      'isProduction': isProduction,
      'baseUrl': baseUrl,
      'backendUrl': backendUrl,
      'sdkEnvironment': environment,
      'isDebugEnabled': isDebugEnabled,
      'apiTimeout': apiTimeoutSeconds,
      'paymentTimeout': paymentTimeoutSeconds,
      'supportedMethods': supportedPaymentMethods,
      'currency': defaultCurrency,
      'webhookVersion': webhookVersion,
      'isValid': validateConfiguration(),
    };
  }
  
  /// Initialize Cashfree configuration
  /// This method can be called during app initialization to validate configuration
  Future<bool> initialize() async {
    try {
      if (kDebugMode) {
        print('CashfreeConfig: Initializing Cashfree configuration...');
        print('CashfreeConfig: Environment: $environmentName');
        print('CashfreeConfig: Base URL: $baseUrl');
        print('CashfreeConfig: Backend URL: $backendUrl');
      }
      
      final isValid = validateConfiguration();
      
      if (kDebugMode) {
        if (isValid) {
          print('CashfreeConfig: Configuration initialized successfully');
        } else {
          print('CashfreeConfig: Configuration validation failed');
        }
      }
      
      return isValid;
    } catch (e) {
      if (kDebugMode) {
        print('CashfreeConfig: Initialization error: $e');
      }
      return false;
    }
  }
  
  /// Get headers for API requests
  Map<String, String> getApiHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-client-version': 'flutter-2.2.9+47',
      'x-api-version': webhookVersion,
    };
  }
  
  /// Get Cashfree SDK configuration map
  Map<String, dynamic> getSdkConfig() {
    return {
      'environment': environment,
      'timeout': paymentTimeoutSeconds,
      'enableLogging': isDebugEnabled,
    };
  }
}