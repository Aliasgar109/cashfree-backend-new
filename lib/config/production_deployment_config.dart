import 'package:flutter/foundation.dart';
import 'dart:io';

/// Production deployment configuration for Cashfree Payment Gateway
/// 
/// This class handles production-specific configuration including:
/// - HTTPS enforcement
/// - Production key management
/// - Webhook URL configuration
/// - Security validations
/// - Monitoring and logging setup
class ProductionDeploymentConfig {
  // Private constructor for singleton pattern
  ProductionDeploymentConfig._();
  
  // Singleton instance
  static final ProductionDeploymentConfig _instance = ProductionDeploymentConfig._();
  static ProductionDeploymentConfig get instance => _instance;
  
  // Production environment detection
  static const bool _kIsProduction = bool.fromEnvironment('PRODUCTION', defaultValue: false);
  static const bool _kForceProduction = bool.fromEnvironment('FORCE_PRODUCTION', defaultValue: false);
  
  // Production URLs and endpoints
  static const String _productionCashfreeUrl = 'https://api.cashfree.com/pg';
  static const String _productionBackendUrl = 'https://your-production-backend.com/api/cashfree';
  static const String _productionWebhookUrl = 'https://your-production-backend.com/api/cashfree/webhook';
  
  // Security configuration
  static const List<String> _allowedHosts = [
    'api.cashfree.com',
    'your-production-backend.com',
  ];
  
  static const List<String> _requiredHeaders = [
    'Content-Type',
    'Authorization',
    'x-client-version',
    'x-api-version',
  ];
  
  // Certificate pinning configuration
  static const Map<String, List<String>> _certificatePins = {
    'api.cashfree.com': [
      // SHA-256 fingerprints of Cashfree's certificates
      'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // Replace with actual
      'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // Replace with actual
    ],
    'your-production-backend.com': [
      // SHA-256 fingerprints of your backend certificates
      'sha256/CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=', // Replace with actual
      'sha256/DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD=', // Replace with actual
    ],
  };
  
  // Monitoring configuration
  static const int _maxRetryAttempts = 3;
  static const Duration _requestTimeout = Duration(seconds: 30);
  static const Duration _connectionTimeout = Duration(seconds: 10);
  
  /// Check if running in production environment
  bool get isProduction => _kIsProduction || _kForceProduction;
  
  /// Get production Cashfree API URL
  String get productionCashfreeUrl => _productionCashfreeUrl;
  
  /// Get production backend URL
  String get productionBackendUrl => _productionBackendUrl;
  
  /// Get production webhook URL
  String get productionWebhookUrl => _productionWebhookUrl;
  
  /// Get allowed hosts for network requests
  List<String> get allowedHosts => List.unmodifiable(_allowedHosts);
  
  /// Get required headers for API requests
  List<String> get requiredHeaders => List.unmodifiable(_requiredHeaders);
  
  /// Get certificate pins for SSL pinning
  Map<String, List<String>> get certificatePins => Map.unmodifiable(_certificatePins);
  
  /// Get maximum retry attempts
  int get maxRetryAttempts => _maxRetryAttempts;
  
  /// Get request timeout duration
  Duration get requestTimeout => _requestTimeout;
  
  /// Get connection timeout duration
  Duration get connectionTimeout => _connectionTimeout;
  
  /// Validate production environment configuration
  Future<ProductionValidationResult> validateProductionEnvironment() async {
    final errors = <String>[];
    final warnings = <String>[];
    
    try {
      // Check if running in production mode
      if (!isProduction) {
        errors.add('Not running in production environment');
      }
      
      // Validate HTTPS enforcement
      final httpsValidation = await _validateHttpsEnforcement();
      if (!httpsValidation.isValid) {
        errors.addAll(httpsValidation.errors);
        warnings.addAll(httpsValidation.warnings);
      }
      
      // Validate network security
      final networkValidation = await _validateNetworkSecurity();
      if (!networkValidation.isValid) {
        errors.addAll(networkValidation.errors);
        warnings.addAll(networkValidation.warnings);
      }
      
      // Validate webhook configuration
      final webhookValidation = await _validateWebhookConfiguration();
      if (!webhookValidation.isValid) {
        errors.addAll(webhookValidation.errors);
        warnings.addAll(webhookValidation.warnings);
      }
      
      // Validate security headers
      final securityValidation = await _validateSecurityHeaders();
      if (!securityValidation.isValid) {
        errors.addAll(securityValidation.errors);
        warnings.addAll(securityValidation.warnings);
      }
      
      return ProductionValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      errors.add('Validation error: $e');
      return ProductionValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
        timestamp: DateTime.now(),
      );
    }
  }
  
  /// Validate HTTPS enforcement for all API communications
  Future<ValidationResult> _validateHttpsEnforcement() async {
    final errors = <String>[];
    final warnings = <String>[];
    
    try {
      // Check Cashfree API URL
      final cashfreeUri = Uri.parse(_productionCashfreeUrl);
      if (cashfreeUri.scheme != 'https') {
        errors.add('Cashfree API URL must use HTTPS: $_productionCashfreeUrl');
      }
      
      // Check backend URL
      final backendUri = Uri.parse(_productionBackendUrl);
      if (backendUri.scheme != 'https') {
        errors.add('Backend API URL must use HTTPS: $_productionBackendUrl');
      }
      
      // Check webhook URL
      final webhookUri = Uri.parse(_productionWebhookUrl);
      if (webhookUri.scheme != 'https') {
        errors.add('Webhook URL must use HTTPS: $_productionWebhookUrl');
      }
      
      // Validate SSL/TLS configuration
      if (Platform.isAndroid || Platform.isIOS) {
        // Check if certificate pinning is configured
        if (_certificatePins.isEmpty) {
          warnings.add('Certificate pinning not configured for enhanced security');
        }
      }
      
    } catch (e) {
      errors.add('HTTPS validation error: $e');
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
  
  /// Validate network security configuration
  Future<ValidationResult> _validateNetworkSecurity() async {
    final errors = <String>[];
    final warnings = <String>[];
    
    try {
      // Check allowed hosts configuration
      if (_allowedHosts.isEmpty) {
        errors.add('No allowed hosts configured for network security');
      }
      
      // Validate each allowed host
      for (final host in _allowedHosts) {
        if (host.isEmpty || !_isValidHostname(host)) {
          errors.add('Invalid hostname in allowed hosts: $host');
        }
      }
      
      // Check certificate pinning configuration
      for (final entry in _certificatePins.entries) {
        final host = entry.key;
        final pins = entry.value;
        
        if (!_allowedHosts.contains(host)) {
          warnings.add('Certificate pins configured for host not in allowed list: $host');
        }
        
        if (pins.isEmpty) {
          errors.add('No certificate pins configured for host: $host');
        }
        
        for (final pin in pins) {
          if (!_isValidCertificatePin(pin)) {
            errors.add('Invalid certificate pin format for host $host: $pin');
          }
        }
      }
      
    } catch (e) {
      errors.add('Network security validation error: $e');
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
  
  /// Validate webhook configuration
  Future<ValidationResult> _validateWebhookConfiguration() async {
    final errors = <String>[];
    final warnings = <String>[];
    
    try {
      // Check webhook URL format
      final webhookUri = Uri.tryParse(_productionWebhookUrl);
      if (webhookUri == null) {
        errors.add('Invalid webhook URL format: $_productionWebhookUrl');
      } else {
        // Check webhook URL scheme
        if (webhookUri.scheme != 'https') {
          errors.add('Webhook URL must use HTTPS: $_productionWebhookUrl');
        }
        
        // Check webhook URL host
        if (!_allowedHosts.contains(webhookUri.host)) {
          warnings.add('Webhook host not in allowed hosts list: ${webhookUri.host}');
        }
      }
      
    } catch (e) {
      errors.add('Webhook validation error: $e');
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
  
  /// Validate security headers configuration
  Future<ValidationResult> _validateSecurityHeaders() async {
    final errors = <String>[];
    final warnings = <String>[];
    
    try {
      // Check required headers
      if (_requiredHeaders.isEmpty) {
        errors.add('No required headers configured');
      }
      
      // Validate specific security headers
      final securityHeaders = ['Authorization', 'x-client-version', 'x-api-version'];
      for (final header in securityHeaders) {
        if (!_requiredHeaders.contains(header)) {
          warnings.add('Security header not in required list: $header');
        }
      }
      
    } catch (e) {
      errors.add('Security headers validation error: $e');
    }
    
    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
  
  /// Check if hostname is valid
  bool _isValidHostname(String hostname) {
    if (hostname.isEmpty) return false;
    
    // Basic hostname validation
    final hostnameRegex = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$');
    return hostnameRegex.hasMatch(hostname);
  }
  
  /// Check if certificate pin is valid
  bool _isValidCertificatePin(String pin) {
    if (pin.isEmpty) return false;
    
    // Check SHA-256 pin format
    final sha256Regex = RegExp(r'^sha256\/[A-Za-z0-9+\/]{43}=$');
    return sha256Regex.hasMatch(pin);
  }
  
  /// Get production deployment summary
  Map<String, dynamic> getDeploymentSummary() {
    return {
      'isProduction': isProduction,
      'cashfreeUrl': productionCashfreeUrl,
      'backendUrl': productionBackendUrl,
      'webhookUrl': productionWebhookUrl,
      'allowedHosts': allowedHosts,
      'certificatePinningEnabled': certificatePins.isNotEmpty,
      'maxRetryAttempts': maxRetryAttempts,
      'requestTimeout': requestTimeout.inSeconds,
      'connectionTimeout': connectionTimeout.inSeconds,
      'requiredHeaders': requiredHeaders,
    };
  }
}

/// Result of production environment validation
class ProductionValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final DateTime timestamp;
  
  const ProductionValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.timestamp,
  });
  
  /// Check if validation passed with no errors
  bool get hasNoErrors => errors.isEmpty;
  
  /// Check if validation has warnings
  bool get hasWarnings => warnings.isNotEmpty;
  
  /// Get total issue count
  int get totalIssues => errors.length + warnings.length;
  
  /// Convert to map for logging/debugging
  Map<String, dynamic> toMap() {
    return {
      'isValid': isValid,
      'hasNoErrors': hasNoErrors,
      'hasWarnings': hasWarnings,
      'totalIssues': totalIssues,
      'errors': errors,
      'warnings': warnings,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Production Validation Result:');
    buffer.writeln('  Valid: $isValid');
    buffer.writeln('  Errors: ${errors.length}');
    buffer.writeln('  Warnings: ${warnings.length}');
    buffer.writeln('  Timestamp: $timestamp');
    
    if (errors.isNotEmpty) {
      buffer.writeln('  Error Details:');
      for (final error in errors) {
        buffer.writeln('    - $error');
      }
    }
    
    if (warnings.isNotEmpty) {
      buffer.writeln('  Warning Details:');
      for (final warning in warnings) {
        buffer.writeln('    - $warning');
      }
    }
    
    return buffer.toString();
  }
}

/// Generic validation result
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