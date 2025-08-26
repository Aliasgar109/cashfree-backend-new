import 'package:flutter/foundation.dart';
import '../config/cashfree_config.dart';

/// Service class for managing Cashfree configuration and environment settings
/// 
/// This service provides a high-level interface for accessing Cashfree configuration
/// and handles environment-specific settings, validation, and initialization.
class CashfreeConfigService {
  // Private constructor for singleton pattern
  CashfreeConfigService._();
  
  // Singleton instance
  static final CashfreeConfigService _instance = CashfreeConfigService._();
  static CashfreeConfigService get instance => _instance;
  
  // Configuration instance
  final CashfreeConfig _config = CashfreeConfig.instance;
  
  // Initialization state
  bool _isInitialized = false;
  bool _initializationFailed = false;
  String? _initializationError;
  
  /// Check if the service has been initialized
  bool get isInitialized => _isInitialized;
  
  /// Check if initialization failed
  bool get initializationFailed => _initializationFailed;
  
  /// Get initialization error message if any
  String? get initializationError => _initializationError;
  
  /// Get current environment (sandbox/production)
  bool get isSandbox => _config.isSandbox;
  
  /// Get current environment (sandbox/production)
  bool get isProduction => _config.isProduction;
  
  /// Get environment name for display
  String get environmentName => _config.environmentName;
  
  /// Get Cashfree API base URL
  String get baseUrl => _config.baseUrl;
  
  /// Get backend API URL
  String get backendUrl => _config.backendUrl;
  
  /// Get Cashfree SDK environment string
  String get sdkEnvironment => _config.environment;
  
  /// Get API timeout duration
  Duration get apiTimeout => _config.apiTimeout;
  
  /// Get payment timeout duration
  Duration get paymentTimeout => _config.paymentTimeout;
  
  /// Get supported payment methods
  List<String> get supportedPaymentMethods => List.unmodifiable(CashfreeConfig.supportedPaymentMethods);
  
  /// Get default currency
  String get defaultCurrency => CashfreeConfig.defaultCurrency;
  
  /// Get webhook secret for signature verification
  String get webhookSecret => _config.webhookSecret;
  
  /// Initialize the Cashfree configuration service
  /// 
  /// This method should be called during app initialization to ensure
  /// proper configuration and environment setup.
  /// 
  /// Returns true if initialization is successful, false otherwise.
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }
    
    try {
      if (kDebugMode) {
        print('CashfreeConfigService: Starting initialization...');
      }
      
      // Initialize the configuration
      final success = await _config.initialize();
      
      if (success) {
        _isInitialized = true;
        _initializationFailed = false;
        _initializationError = null;
        
        if (kDebugMode) {
          print('CashfreeConfigService: Initialization successful');
          _logConfigurationSummary();
        }
      } else {
        _initializationFailed = true;
        _initializationError = 'Configuration validation failed';
        
        if (kDebugMode) {
          print('CashfreeConfigService: Initialization failed - Configuration validation failed');
        }
      }
      
      return success;
    } catch (e) {
      _initializationFailed = true;
      _initializationError = e.toString();
      
      if (kDebugMode) {
        print('CashfreeConfigService: Initialization error: $e');
      }
      
      return false;
    }
  }
  
  /// Validate current configuration
  /// 
  /// Returns true if configuration is valid, false otherwise.
  bool validateConfiguration() {
    return _config.validateConfiguration();
  }
  
  /// Get API endpoint for creating orders
  String getCreateOrderEndpoint() {
    _ensureInitialized();
    return _config.createOrderEndpoint;
  }
  
  /// Get API endpoint for payment verification
  String getVerifyPaymentEndpoint() {
    _ensureInitialized();
    return _config.verifyPaymentEndpoint;
  }
  
  /// Get webhook endpoint
  String getWebhookEndpoint() {
    _ensureInitialized();
    return _config.webhookEndpoint;
  }
  
  /// Get payment session endpoint
  String getPaymentSessionEndpoint() {
    _ensureInitialized();
    return _config.paymentSessionEndpoint;
  }
  
  /// Get API headers for HTTP requests
  Map<String, String> getApiHeaders() {
    _ensureInitialized();
    return _config.getApiHeaders();
  }
  
  /// Get Cashfree SDK configuration
  Map<String, dynamic> getSdkConfiguration() {
    _ensureInitialized();
    return _config.getSdkConfig();
  }
  
  /// Get complete configuration summary
  /// 
  /// Useful for debugging and logging purposes.
  Map<String, dynamic> getConfigurationSummary() {
    return _config.getConfigSummary();
  }
  
  /// Check if debug mode is enabled
  bool get isDebugEnabled => _config.isDebugEnabled;
  
  /// Reset initialization state (useful for testing)
  @visibleForTesting
  void resetInitialization() {
    _isInitialized = false;
    _initializationFailed = false;
    _initializationError = null;
  }
  
  /// Ensure the service is initialized before use
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'CashfreeConfigService has not been initialized. Call initialize() first.'
      );
    }
    
    if (_initializationFailed) {
      throw StateError(
        'CashfreeConfigService initialization failed: $_initializationError'
      );
    }
  }
  
  /// Log configuration summary for debugging
  void _logConfigurationSummary() {
    if (!kDebugMode) return;
    
    final summary = getConfigurationSummary();
    print('CashfreeConfigService: Configuration Summary:');
    summary.forEach((key, value) {
      print('  $key: $value');
    });
  }
  
  /// Get environment-specific configuration for external services
  /// 
  /// This method can be used by other services that need to know
  /// about the current Cashfree environment.
  Map<String, dynamic> getEnvironmentConfig() {
    _ensureInitialized();
    
    return {
      'environment': environmentName,
      'isSandbox': isSandbox,
      'isProduction': isProduction,
      'baseUrl': baseUrl,
      'backendUrl': backendUrl,
      'sdkEnvironment': sdkEnvironment,
      'currency': defaultCurrency,
      'apiTimeout': apiTimeout.inSeconds,
      'paymentTimeout': paymentTimeout.inSeconds,
    };
  }
  
  /// Check if a payment method is supported
  bool isPaymentMethodSupported(String paymentMethod) {
    return supportedPaymentMethods.contains(paymentMethod.toLowerCase());
  }
  
  /// Get formatted timeout string for display
  String getTimeoutDisplayString() {
    final minutes = paymentTimeout.inMinutes;
    final seconds = paymentTimeout.inSeconds % 60;
    
    if (minutes > 0) {
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }
}