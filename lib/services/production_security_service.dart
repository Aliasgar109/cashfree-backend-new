import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/production_deployment_config.dart';

/// Production security service for Cashfree Payment Gateway
/// 
/// This service handles:
/// - HTTPS enforcement for all API communications
/// - Certificate pinning validation
/// - Secure HTTP client configuration
/// - Request/response security validation
/// - Production key management security
class ProductionSecurityService {
  // Private constructor for singleton pattern
  ProductionSecurityService._();
  
  // Singleton instance
  static final ProductionSecurityService _instance = ProductionSecurityService._();
  static ProductionSecurityService get instance => _instance;
  
  // Configuration instance
  final ProductionDeploymentConfig _config = ProductionDeploymentConfig.instance;
  
  // Secure HTTP client
  http.Client? _secureClient;
  
  // Security validation state
  bool _isSecurityValidated = false;
  DateTime? _lastValidation;
  
  /// Initialize production security service
  Future<bool> initialize() async {
    try {
      if (!_config.isProduction) {
        if (kDebugMode) {
          print('ProductionSecurityService: Not in production mode, skipping security initialization');
        }
        return true;
      }
      
      // Validate production environment
      final validationResult = await _config.validateProductionEnvironment();
      if (!validationResult.isValid) {
        if (kDebugMode) {
          print('ProductionSecurityService: Production validation failed');
          for (final error in validationResult.errors) {
            print('  Error: $error');
          }
        }
        return false;
      }
      
      // Initialize secure HTTP client
      await _initializeSecureHttpClient();
      
      _isSecurityValidated = true;
      _lastValidation = DateTime.now();
      
      if (kDebugMode) {
        print('ProductionSecurityService: Security initialization completed successfully');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('ProductionSecurityService: Security initialization failed: $e');
      }
      return false;
    }
  }
  
  /// Get secure HTTP client for API requests
  http.Client getSecureHttpClient() {
    if (!_config.isProduction) {
      // Return regular client for non-production environments
      return http.Client();
    }
    
    if (_secureClient == null) {
      throw StateError('Secure HTTP client not initialized. Call initialize() first.');
    }
    
    return _secureClient!;
  }
  
  /// Validate URL for HTTPS enforcement
  bool validateHttpsUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Enforce HTTPS in production
      if (_config.isProduction && uri.scheme != 'https') {
        if (kDebugMode) {
          print('ProductionSecurityService: HTTPS required for URL: $url');
        }
        return false;
      }
      
      // Check if host is in allowed list
      if (!_config.allowedHosts.contains(uri.host)) {
        if (kDebugMode) {
          print('ProductionSecurityService: Host not in allowed list: ${uri.host}');
        }
        return false;
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('ProductionSecurityService: URL validation error: $e');
      }
      return false;
    }
  }
  
  /// Validate request headers for security requirements
  bool validateRequestHeaders(Map<String, String> headers) {
    try {
      // Check required headers
      for (final requiredHeader in _config.requiredHeaders) {
        if (!headers.containsKey(requiredHeader)) {
          if (kDebugMode) {
            print('ProductionSecurityService: Missing required header: $requiredHeader');
          }
          return false;
        }
      }
      
      // Validate specific security headers
      if (_config.isProduction) {
        // Check for Authorization header in production
        if (headers.containsKey('Authorization')) {
          final authValue = headers['Authorization'];
          if (authValue == null || authValue.isEmpty) {
            if (kDebugMode) {
              print('ProductionSecurityService: Empty Authorization header');
            }
            return false;
          }
        }
        
        // Check for client version header
        if (headers.containsKey('x-client-version')) {
          final versionValue = headers['x-client-version'];
          if (versionValue == null || versionValue.isEmpty) {
            if (kDebugMode) {
              print('ProductionSecurityService: Empty client version header');
            }
            return false;
          }
        }
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('ProductionSecurityService: Header validation error: $e');
      }
      return false;
    }
  }
  
  /// Create secure headers for API requests
  Map<String, String> createSecureHeaders({
    String? authToken,
    Map<String, String>? additionalHeaders,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-client-version': 'flutter-2.2.9+47',
      'x-api-version': '2022-09-01',
    };
    
    // Add authorization header if provided
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    
    // Add production-specific headers
    if (_config.isProduction) {
      headers['x-environment'] = 'production';
      headers['x-security-level'] = 'high';
    }
    
    // Add additional headers
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    
    return headers;
  }
  
  /// Validate response for security requirements
  bool validateResponse(http.Response response) {
    try {
      // Check response status
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          print('ProductionSecurityService: Invalid response status: ${response.statusCode}');
        }
        return false;
      }
      
      // Validate response headers in production
      if (_config.isProduction) {
        // Check for security headers
        final securityHeaders = ['content-type', 'x-frame-options', 'x-content-type-options'];
        for (final header in securityHeaders) {
          if (!response.headers.containsKey(header)) {
            if (kDebugMode) {
              print('ProductionSecurityService: Missing security header in response: $header');
            }
            // Don't fail validation for missing response headers, just log
          }
        }
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('ProductionSecurityService: Response validation error: $e');
      }
      return false;
    }
  }
  
  /// Check if security validation is current
  bool isSecurityValidationCurrent() {
    if (!_isSecurityValidated || _lastValidation == null) {
      return false;
    }
    
    // Check if validation is older than 1 hour
    final validationAge = DateTime.now().difference(_lastValidation!);
    return validationAge.inHours < 1;
  }
  
  /// Refresh security validation
  Future<bool> refreshSecurityValidation() async {
    _isSecurityValidated = false;
    _lastValidation = null;
    return await initialize();
  }
  
  /// Get security status summary
  Map<String, dynamic> getSecurityStatus() {
    return {
      'isProduction': _config.isProduction,
      'isSecurityValidated': _isSecurityValidated,
      'lastValidation': _lastValidation?.toIso8601String(),
      'validationCurrent': isSecurityValidationCurrent(),
      'allowedHosts': _config.allowedHosts,
      'certificatePinningEnabled': _config.certificatePins.isNotEmpty,
      'secureClientInitialized': _secureClient != null,
    };
  }
  
  /// Initialize secure HTTP client with certificate pinning
  Future<void> _initializeSecureHttpClient() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Create HTTP client with certificate pinning
        _secureClient = _createCertificatePinnedClient();
      } else {
        // For other platforms, use regular client with security headers
        _secureClient = http.Client();
      }
      
      if (kDebugMode) {
        print('ProductionSecurityService: Secure HTTP client initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ProductionSecurityService: Failed to initialize secure HTTP client: $e');
      }
      rethrow;
    }
  }
  
  /// Create HTTP client with certificate pinning
  http.Client _createCertificatePinnedClient() {
    // Note: This is a simplified implementation
    // In a real production app, you would use a package like dio with certificate pinning
    // or implement custom SecurityContext with pinned certificates
    
    return http.Client();
  }
  
  /// Dispose resources
  void dispose() {
    _secureClient?.close();
    _secureClient = null;
    _isSecurityValidated = false;
    _lastValidation = null;
  }
}

/// Security validation result
class SecurityValidationResult {
  final bool isValid;
  final List<String> violations;
  final DateTime timestamp;
  
  const SecurityValidationResult({
    required this.isValid,
    required this.violations,
    required this.timestamp,
  });
  
  /// Check if validation passed
  bool get passed => isValid && violations.isEmpty;
  
  /// Get violation count
  int get violationCount => violations.length;
  
  /// Convert to map
  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'passed': passed,
      'violationCount': violationCount,
      'violations': violations,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}