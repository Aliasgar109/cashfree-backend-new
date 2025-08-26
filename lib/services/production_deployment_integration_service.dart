import 'package:flutter/foundation.dart';
import '../config/production_deployment_config.dart';
import '../services/production_security_service.dart';
import '../services/production_monitoring_service.dart';
import '../services/production_webhook_service.dart';
import '../services/production_key_management_service.dart';
import '../services/cashfree_config_service.dart';

/// Production deployment integration service for Cashfree Payment Gateway
/// 
/// This service orchestrates all production deployment components:
/// - Production environment configuration
/// - Security service initialization
/// - Monitoring service setup
/// - Webhook service configuration
/// - Key management initialization
/// - Health checks and validation
class ProductionDeploymentIntegrationService {
  // Private constructor for singleton pattern
  ProductionDeploymentIntegrationService._();
  
  // Singleton instance
  static final ProductionDeploymentIntegrationService _instance = ProductionDeploymentIntegrationService._();
  static ProductionDeploymentIntegrationService get instance => _instance;
  
  // Service instances
  final ProductionDeploymentConfig _config = ProductionDeploymentConfig.instance;
  final ProductionSecurityService _security = ProductionSecurityService.instance;
  final ProductionMonitoringService _monitoring = ProductionMonitoringService.instance;
  final ProductionWebhookService _webhook = ProductionWebhookService.instance;
  final ProductionKeyManagementService _keyManagement = ProductionKeyManagementService.instance;
  final CashfreeConfigService _cashfreeConfig = CashfreeConfigService.instance;
  
  // Integration state
  bool _isInitialized = false;
  bool _initializationFailed = false;
  String? _initializationError;
  DateTime? _initializationTime;
  Map<String, bool> _serviceStatus = {};
  
  /// Check if the integration service has been initialized
  bool get isInitialized => _isInitialized;
  
  /// Check if initialization failed
  bool get initializationFailed => _initializationFailed;
  
  /// Get initialization error message if any
  String? get initializationError => _initializationError;
  
  /// Get initialization timestamp
  DateTime? get initializationTime => _initializationTime;
  
  /// Initialize all production deployment services
  Future<ProductionDeploymentResult> initializeProductionDeployment() async {
    if (_isInitialized) {
      return ProductionDeploymentResult(
        success: true,
        message: 'Production deployment already initialized',
        initializationTime: _initializationTime,
        serviceStatus: Map.from(_serviceStatus),
      );
    }
    
    final startTime = DateTime.now();
    final errors = <String>[];
    final warnings = <String>[];
    
    try {
      if (kDebugMode) {
        print('ProductionDeploymentIntegrationService: Starting production deployment initialization...');
      }
      
      // Step 1: Initialize Cashfree configuration service
      if (kDebugMode) {
        print('ProductionDeploymentIntegrationService: Initializing Cashfree configuration...');
      }
      
      final cashfreeConfigResult = await _cashfreeConfig.initialize();
      _serviceStatus['cashfree_config'] = cashfreeConfigResult;
      
      if (!cashfreeConfigResult) {
        errors.add('Cashfree configuration initialization failed');
      }
      
      // Step 2: Initialize production configuration
      if (kDebugMode) {
        print('ProductionDeploymentIntegrationService: Validating production configuration...');
      }
      
      final configValidation = await _config.validateProductionEnvironment();
      _serviceStatus['production_config'] = configValidation.isValid;
      
      if (!configValidation.isValid) {
        errors.addAll(configValidation.errors);
        warnings.addAll(configValidation.warnings);
      }
      
      // Step 3: Initialize key management service
      if (kDebugMode) {
        print('ProductionDeploymentIntegrationService: Initializing key management...');
      }
      
      final keyManagementResult = await _keyManagement.initialize();
      _serviceStatus['key_management'] = keyManagementResult;
      
      if (!keyManagementResult) {
        errors.add('Key management service initialization failed');
      }
      
      // Step 4: Initialize security service
      if (kDebugMode) {
        print('ProductionDeploymentIntegrationService: Initializing security service...');
      }
      
      final securityResult = await _security.initialize();
      _serviceStatus['security'] = securityResult;
      
      if (!securityResult) {
        errors.add('Security service initialization failed');
      }
      
      // Step 5: Initialize monitoring service
      if (kDebugMode) {
        print('ProductionDeploymentIntegrationService: Initializing monitoring service...');
      }
      
      final monitoringResult = await _monitoring.initialize();
      _serviceStatus['monitoring'] = monitoringResult;
      
      if (!monitoringResult) {
        errors.add('Monitoring service initialization failed');
      }
      
      // Step 6: Initialize webhook service
      if (kDebugMode) {
        print('ProductionDeploymentIntegrationService: Initializing webhook service...');
      }
      
      final webhookResult = await _webhook.initialize();
      _serviceStatus['webhook'] = webhookResult;
      
      if (!webhookResult) {
        errors.add('Webhook service initialization failed');
      }
      
      // Step 7: Perform comprehensive health check
      if (kDebugMode) {
        print('ProductionDeploymentIntegrationService: Performing health check...');
      }
      
      final healthCheck = await _performComprehensiveHealthCheck();
      if (!healthCheck.isHealthy) {
        warnings.addAll(healthCheck.issues);
      }
      
      // Determine initialization result
      final success = errors.isEmpty;
      _isInitialized = success;
      _initializationFailed = !success;
      _initializationError = success ? null : errors.join('; ');
      _initializationTime = startTime;
      
      final duration = DateTime.now().difference(startTime);
      
      // Log initialization result
      if (_serviceStatus['monitoring'] == true) {
        _monitoring.logSecurityEvent(
          eventType: success ? 'production_deployment_initialized' : 'production_deployment_failed',
          level: success ? SecurityLevel.info : SecurityLevel.critical,
          description: success 
              ? 'Production deployment initialized successfully'
              : 'Production deployment initialization failed',
          details: {
            'duration_ms': duration.inMilliseconds,
            'service_status': _serviceStatus,
            'errors': errors,
            'warnings': warnings,
          },
        );
      }
      
      if (kDebugMode) {
        if (success) {
          print('ProductionDeploymentIntegrationService: Production deployment initialized successfully in ${duration.inMilliseconds}ms');
        } else {
          print('ProductionDeploymentIntegrationService: Production deployment initialization failed: ${errors.join(', ')}');
        }
      }
      
      return ProductionDeploymentResult(
        success: success,
        message: success 
            ? 'Production deployment initialized successfully'
            : 'Production deployment initialization failed',
        errors: errors,
        warnings: warnings,
        initializationTime: _initializationTime,
        duration: duration,
        serviceStatus: Map.from(_serviceStatus),
        healthCheck: healthCheck,
      );
      
    } catch (e) {
      _isInitialized = false;
      _initializationFailed = true;
      _initializationError = e.toString();
      _initializationTime = startTime;
      
      final duration = DateTime.now().difference(startTime);
      
      if (kDebugMode) {
        print('ProductionDeploymentIntegrationService: Production deployment initialization error: $e');
      }
      
      return ProductionDeploymentResult(
        success: false,
        message: 'Production deployment initialization error',
        errors: [e.toString()],
        initializationTime: _initializationTime,
        duration: duration,
        serviceStatus: Map.from(_serviceStatus),
      );
    }
  }
  
  /// Get production deployment status
  ProductionDeploymentStatus getDeploymentStatus() {
    return ProductionDeploymentStatus(
      isInitialized: _isInitialized,
      initializationFailed: _initializationFailed,
      initializationError: _initializationError,
      initializationTime: _initializationTime,
      isProduction: _config.isProduction,
      serviceStatus: Map.from(_serviceStatus),
      configSummary: _config.getDeploymentSummary(),
      securityStatus: _security.getSecurityStatus(),
      monitoringStatus: _monitoring.getMonitoringSummary(),
      webhookStatus: _webhook.getWebhookStatus(),
      keyManagementStatus: _keyManagement.getKeyManagementStatus(),
    );
  }
  
  /// Perform comprehensive health check
  Future<HealthCheckResult> performHealthCheck() async {
    return await _performComprehensiveHealthCheck();
  }
  
  /// Validate production readiness
  Future<ProductionReadinessResult> validateProductionReadiness() async {
    final errors = <String>[];
    final warnings = <String>[];
    final checks = <String, bool>{};
    
    try {
      // Check if initialized
      if (!_isInitialized) {
        errors.add('Production deployment not initialized');
        return ProductionReadinessResult(
          isReady: false,
          errors: errors,
          warnings: warnings,
          checks: checks,
        );
      }
      
      // Check service status
      _serviceStatus.forEach((service, status) {
        checks[service] = status;
        if (!status) {
          errors.add('Service not ready: $service');
        }
      });
      
      // Check production environment
      checks['production_environment'] = _config.isProduction;
      if (!_config.isProduction) {
        warnings.add('Not running in production environment');
      }
      
      // Check HTTPS enforcement
      final httpsValidation = await _config.validateProductionEnvironment();
      checks['https_enforcement'] = httpsValidation.isValid;
      if (!httpsValidation.isValid) {
        errors.addAll(httpsValidation.errors);
      }
      
      // Check key validation
      final keyValidation = await _keyManagement.validateProductionKeys();
      checks['key_validation'] = keyValidation.success;
      if (!keyValidation.success) {
        errors.add('Key validation failed: ${keyValidation.error}');
      }
      
      // Check security validation
      checks['security_validation'] = _security.isSecurityValidationCurrent();
      if (!_security.isSecurityValidationCurrent()) {
        warnings.add('Security validation is not current');
      }
      
      return ProductionReadinessResult(
        isReady: errors.isEmpty,
        errors: errors,
        warnings: warnings,
        checks: checks,
      );
      
    } catch (e) {
      errors.add('Production readiness validation error: $e');
      return ProductionReadinessResult(
        isReady: false,
        errors: errors,
        warnings: warnings,
        checks: checks,
      );
    }
  }
  
  /// Reset initialization state (useful for testing)
  @visibleForTesting
  void resetInitialization() {
    _isInitialized = false;
    _initializationFailed = false;
    _initializationError = null;
    _initializationTime = null;
    _serviceStatus.clear();
  }
  
  /// Perform comprehensive health check
  Future<HealthCheckResult> _performComprehensiveHealthCheck() async {
    final issues = <String>[];
    final checks = <String, bool>{};
    
    try {
      // Check configuration health
      final configValidation = await _config.validateProductionEnvironment();
      checks['configuration'] = configValidation.isValid;
      if (!configValidation.isValid) {
        issues.addAll(configValidation.errors);
      }
      
      // Check security health
      checks['security'] = _security.isSecurityValidationCurrent();
      if (!_security.isSecurityValidationCurrent()) {
        issues.add('Security validation is outdated');
      }
      
      // Check key management health
      checks['key_management'] = _keyManagement.isKeyValidationCurrent();
      if (!_keyManagement.isKeyValidationCurrent()) {
        issues.add('Key validation is outdated');
      }
      
      // Check monitoring health
      checks['monitoring'] = _serviceStatus['monitoring'] ?? false;
      if (!(_serviceStatus['monitoring'] ?? false)) {
        issues.add('Monitoring service not initialized');
      }
      
      // Check webhook health
      checks['webhook'] = _webhook.getWebhookStatus()['is_configured'] as bool? ?? false;
      if (!(checks['webhook'] ?? false)) {
        issues.add('Webhook service not properly configured');
      }
      
      return HealthCheckResult(
        isHealthy: issues.isEmpty,
        issues: issues,
        checks: checks,
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      issues.add('Health check error: $e');
      return HealthCheckResult(
        isHealthy: false,
        issues: issues,
        checks: checks,
        timestamp: DateTime.now(),
      );
    }
  }
}

/// Production deployment result
class ProductionDeploymentResult {
  final bool success;
  final String message;
  final List<String>? errors;
  final List<String>? warnings;
  final DateTime? initializationTime;
  final Duration? duration;
  final Map<String, bool> serviceStatus;
  final HealthCheckResult? healthCheck;
  
  const ProductionDeploymentResult({
    required this.success,
    required this.message,
    this.errors,
    this.warnings,
    this.initializationTime,
    this.duration,
    required this.serviceStatus,
    this.healthCheck,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'message': message,
      'errors': errors,
      'warnings': warnings,
      'initializationTime': initializationTime?.toIso8601String(),
      'durationMs': duration?.inMilliseconds,
      'serviceStatus': serviceStatus,
      'healthCheck': healthCheck?.toMap(),
    };
  }
}

/// Production deployment status
class ProductionDeploymentStatus {
  final bool isInitialized;
  final bool initializationFailed;
  final String? initializationError;
  final DateTime? initializationTime;
  final bool isProduction;
  final Map<String, bool> serviceStatus;
  final Map<String, dynamic> configSummary;
  final Map<String, dynamic> securityStatus;
  final Map<String, dynamic> monitoringStatus;
  final Map<String, dynamic> webhookStatus;
  final Map<String, dynamic> keyManagementStatus;
  
  const ProductionDeploymentStatus({
    required this.isInitialized,
    required this.initializationFailed,
    this.initializationError,
    this.initializationTime,
    required this.isProduction,
    required this.serviceStatus,
    required this.configSummary,
    required this.securityStatus,
    required this.monitoringStatus,
    required this.webhookStatus,
    required this.keyManagementStatus,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'isInitialized': isInitialized,
      'initializationFailed': initializationFailed,
      'initializationError': initializationError,
      'initializationTime': initializationTime?.toIso8601String(),
      'isProduction': isProduction,
      'serviceStatus': serviceStatus,
      'configSummary': configSummary,
      'securityStatus': securityStatus,
      'monitoringStatus': monitoringStatus,
      'webhookStatus': webhookStatus,
      'keyManagementStatus': keyManagementStatus,
    };
  }
}

/// Production readiness result
class ProductionReadinessResult {
  final bool isReady;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, bool> checks;
  
  const ProductionReadinessResult({
    required this.isReady,
    required this.errors,
    required this.warnings,
    required this.checks,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'isReady': isReady,
      'errors': errors,
      'warnings': warnings,
      'checks': checks,
    };
  }
}

/// Health check result
class HealthCheckResult {
  final bool isHealthy;
  final List<String> issues;
  final Map<String, bool> checks;
  final DateTime timestamp;
  
  const HealthCheckResult({
    required this.isHealthy,
    required this.issues,
    required this.checks,
    required this.timestamp,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'isHealthy': isHealthy,
      'issues': issues,
      'checks': checks,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}