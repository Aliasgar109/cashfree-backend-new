import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/production_deployment_config.dart';
import '../models/payment_model.dart';

/// Production monitoring and logging service for Cashfree Payment Gateway
/// 
/// This service handles:
/// - Payment transaction monitoring
/// - Error tracking and alerting
/// - Performance metrics collection
/// - Security event logging
/// - Production deployment health checks
class ProductionMonitoringService {
  // Private constructor for singleton pattern
  ProductionMonitoringService._();
  
  // Singleton instance
  static final ProductionMonitoringService _instance = ProductionMonitoringService._();
  static ProductionMonitoringService get instance => _instance;
  
  // Configuration instance
  final ProductionDeploymentConfig _config = ProductionDeploymentConfig.instance;
  
  // Monitoring state
  bool _isMonitoringEnabled = false;
  DateTime? _monitoringStartTime;
  
  // Metrics collection
  final Map<String, int> _paymentMetrics = {};
  final Map<String, int> _errorMetrics = {};
  final List<PaymentEvent> _paymentEvents = [];
  final List<SecurityEvent> _securityEvents = [];
  final List<PerformanceMetric> _performanceMetrics = [];
  
  // Event stream controllers
  final StreamController<PaymentEvent> _paymentEventController = StreamController<PaymentEvent>.broadcast();
  final StreamController<SecurityEvent> _securityEventController = StreamController<SecurityEvent>.broadcast();
  final StreamController<PerformanceMetric> _performanceController = StreamController<PerformanceMetric>.broadcast();
  
  /// Stream of payment events
  Stream<PaymentEvent> get paymentEvents => _paymentEventController.stream;
  
  /// Stream of security events
  Stream<SecurityEvent> get securityEvents => _securityEventController.stream;
  
  /// Stream of performance metrics
  Stream<PerformanceMetric> get performanceMetrics => _performanceController.stream;
  
  /// Initialize production monitoring service
  Future<bool> initialize() async {
    try {
      if (!_config.isProduction) {
        if (kDebugMode) {
          print('ProductionMonitoringService: Not in production mode, monitoring disabled');
        }
        return true;
      }
      
      _isMonitoringEnabled = true;
      _monitoringStartTime = DateTime.now();
      
      // Initialize metrics
      _initializeMetrics();
      
      // Start periodic health checks
      _startHealthChecks();
      
      if (kDebugMode) {
        print('ProductionMonitoringService: Monitoring initialized successfully');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('ProductionMonitoringService: Monitoring initialization failed: $e');
      }
      return false;
    }
  }
  
  /// Log payment event
  void logPaymentEvent({
    required String eventType,
    required String paymentId,
    required String orderId,
    required PaymentStatus status,
    double? amount,
    String? paymentMethod,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) {
    if (!_isMonitoringEnabled) return;
    
    try {
      final event = PaymentEvent(
        eventType: eventType,
        paymentId: paymentId,
        orderId: orderId,
        status: status,
        amount: amount,
        paymentMethod: paymentMethod,
        errorMessage: errorMessage,
        metadata: metadata ?? {},
        timestamp: DateTime.now(),
      );
      
      // Add to events list (keep last 1000 events)
      _paymentEvents.add(event);
      if (_paymentEvents.length > 1000) {
        _paymentEvents.removeAt(0);
      }
      
      // Update metrics
      _updatePaymentMetrics(event);
      
      // Emit event
      _paymentEventController.add(event);
      
      // Log to console in debug mode
      if (kDebugMode) {
        print('PaymentEvent: ${event.toJson()}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('ProductionMonitoringService: Failed to log payment event: $e');
      }
    }
  }
  
  /// Log security event
  void logSecurityEvent({
    required String eventType,
    required SecurityLevel level,
    required String description,
    String? userId,
    String? ipAddress,
    Map<String, dynamic>? details,
  }) {
    if (!_isMonitoringEnabled) return;
    
    try {
      final event = SecurityEvent(
        eventType: eventType,
        level: level,
        description: description,
        userId: userId,
        ipAddress: ipAddress,
        details: details ?? {},
        timestamp: DateTime.now(),
      );
      
      // Add to events list (keep last 500 security events)
      _securityEvents.add(event);
      if (_securityEvents.length > 500) {
        _securityEvents.removeAt(0);
      }
      
      // Emit event
      _securityEventController.add(event);
      
      // Log to console in debug mode
      if (kDebugMode) {
        print('SecurityEvent: ${event.toJson()}');
      }
      
      // Handle critical security events
      if (level == SecurityLevel.critical) {
        _handleCriticalSecurityEvent(event);
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('ProductionMonitoringService: Failed to log security event: $e');
      }
    }
  }
  
  /// Log performance metric
  void logPerformanceMetric({
    required String metricName,
    required double value,
    required String unit,
    Map<String, dynamic>? tags,
  }) {
    if (!_isMonitoringEnabled) return;
    
    try {
      final metric = PerformanceMetric(
        name: metricName,
        value: value,
        unit: unit,
        tags: tags ?? {},
        timestamp: DateTime.now(),
      );
      
      // Add to metrics list (keep last 1000 metrics)
      _performanceMetrics.add(metric);
      if (_performanceMetrics.length > 1000) {
        _performanceMetrics.removeAt(0);
      }
      
      // Emit metric
      _performanceController.add(metric);
      
      // Log to console in debug mode
      if (kDebugMode) {
        print('PerformanceMetric: ${metric.toJson()}');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('ProductionMonitoringService: Failed to log performance metric: $e');
      }
    }
  }
  
  /// Log API request performance
  void logApiPerformance({
    required String endpoint,
    required Duration duration,
    required int statusCode,
    String? method = 'POST',
  }) {
    logPerformanceMetric(
      metricName: 'api_request_duration',
      value: duration.inMilliseconds.toDouble(),
      unit: 'milliseconds',
      tags: {
        'endpoint': endpoint,
        'method': method,
        'status_code': statusCode,
      },
    );
  }
  
  /// Get payment success rate
  double getPaymentSuccessRate() {
    if (_paymentMetrics.isEmpty) return 0.0;
    
    final totalPayments = _paymentMetrics.values.fold(0, (sum, count) => sum + count);
    final successfulPayments = _paymentMetrics['payment_success'] ?? 0;
    
    if (totalPayments == 0) return 0.0;
    return (successfulPayments / totalPayments) * 100;
  }
  
  /// Get error rate
  double getErrorRate() {
    if (_errorMetrics.isEmpty) return 0.0;
    
    final totalErrors = _errorMetrics.values.fold(0, (sum, count) => sum + count);
    final totalEvents = _paymentEvents.length;
    
    if (totalEvents == 0) return 0.0;
    return (totalErrors / totalEvents) * 100;
  }
  
  /// Get monitoring summary
  Map<String, dynamic> getMonitoringSummary() {
    return {
      'isMonitoringEnabled': _isMonitoringEnabled,
      'monitoringStartTime': _monitoringStartTime?.toIso8601String(),
      'paymentMetrics': Map.from(_paymentMetrics),
      'errorMetrics': Map.from(_errorMetrics),
      'paymentEventsCount': _paymentEvents.length,
      'securityEventsCount': _securityEvents.length,
      'performanceMetricsCount': _performanceMetrics.length,
      'paymentSuccessRate': getPaymentSuccessRate(),
      'errorRate': getErrorRate(),
    };
  }
  
  /// Get recent payment events
  List<PaymentEvent> getRecentPaymentEvents({int limit = 50}) {
    final events = List<PaymentEvent>.from(_paymentEvents);
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events.take(limit).toList();
  }
  
  /// Get recent security events
  List<SecurityEvent> getRecentSecurityEvents({int limit = 20}) {
    final events = List<SecurityEvent>.from(_securityEvents);
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events.take(limit).toList();
  }
  
  /// Get recent performance metrics
  List<PerformanceMetric> getRecentPerformanceMetrics({int limit = 100}) {
    final metrics = List<PerformanceMetric>.from(_performanceMetrics);
    metrics.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return metrics.take(limit).toList();
  }
  
  /// Initialize metrics counters
  void _initializeMetrics() {
    _paymentMetrics.clear();
    _errorMetrics.clear();
    
    // Initialize payment metrics
    _paymentMetrics['payment_initiated'] = 0;
    _paymentMetrics['payment_success'] = 0;
    _paymentMetrics['payment_failed'] = 0;
    _paymentMetrics['payment_cancelled'] = 0;
    _paymentMetrics['payment_pending'] = 0;
    
    // Initialize error metrics
    _errorMetrics['network_error'] = 0;
    _errorMetrics['api_error'] = 0;
    _errorMetrics['validation_error'] = 0;
    _errorMetrics['security_error'] = 0;
    _errorMetrics['unknown_error'] = 0;
  }
  
  /// Update payment metrics based on event
  void _updatePaymentMetrics(PaymentEvent event) {
    switch (event.status) {
      case PaymentStatus.APPROVED:
        _paymentMetrics['payment_success'] = (_paymentMetrics['payment_success'] ?? 0) + 1;
        break;
      case PaymentStatus.REJECTED:
        _paymentMetrics['payment_failed'] = (_paymentMetrics['payment_failed'] ?? 0) + 1;
        break;
      case PaymentStatus.INCOMPLETE:
        _paymentMetrics['payment_cancelled'] = (_paymentMetrics['payment_cancelled'] ?? 0) + 1;
        break;
      case PaymentStatus.PENDING:
        _paymentMetrics['payment_pending'] = (_paymentMetrics['payment_pending'] ?? 0) + 1;
        break;
    }
    
    // Update error metrics if there's an error
    if (event.errorMessage != null && event.errorMessage!.isNotEmpty) {
      final errorType = _categorizeError(event.errorMessage!);
      _errorMetrics[errorType] = (_errorMetrics[errorType] ?? 0) + 1;
    }
  }
  
  /// Categorize error message
  String _categorizeError(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    
    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return 'network_error';
    } else if (lowerError.contains('api') || lowerError.contains('server')) {
      return 'api_error';
    } else if (lowerError.contains('validation') || lowerError.contains('invalid')) {
      return 'validation_error';
    } else if (lowerError.contains('security') || lowerError.contains('unauthorized')) {
      return 'security_error';
    } else {
      return 'unknown_error';
    }
  }
  
  /// Handle critical security events
  void _handleCriticalSecurityEvent(SecurityEvent event) {
    // In a real production app, this would:
    // 1. Send alerts to monitoring systems
    // 2. Log to security information and event management (SIEM) systems
    // 3. Potentially trigger automated responses
    
    if (kDebugMode) {
      print('CRITICAL SECURITY EVENT: ${event.description}');
    }
  }
  
  /// Start periodic health checks
  void _startHealthChecks() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (!_isMonitoringEnabled) {
        timer.cancel();
        return;
      }
      
      _performHealthCheck();
    });
  }
  
  /// Perform health check
  void _performHealthCheck() {
    try {
      final healthStatus = {
        'timestamp': DateTime.now().toIso8601String(),
        'monitoring_enabled': _isMonitoringEnabled,
        'events_count': _paymentEvents.length + _securityEvents.length,
        'metrics_count': _performanceMetrics.length,
        'success_rate': getPaymentSuccessRate(),
        'error_rate': getErrorRate(),
      };
      
      if (kDebugMode) {
        print('Health Check: $healthStatus');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('Health check failed: $e');
      }
    }
  }
  
  /// Dispose resources
  void dispose() {
    _isMonitoringEnabled = false;
    _paymentEventController.close();
    _securityEventController.close();
    _performanceController.close();
    _paymentEvents.clear();
    _securityEvents.clear();
    _performanceMetrics.clear();
    _paymentMetrics.clear();
    _errorMetrics.clear();
  }
}

/// Payment event for monitoring
class PaymentEvent {
  final String eventType;
  final String paymentId;
  final String orderId;
  final PaymentStatus status;
  final double? amount;
  final String? paymentMethod;
  final String? errorMessage;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  
  const PaymentEvent({
    required this.eventType,
    required this.paymentId,
    required this.orderId,
    required this.status,
    this.amount,
    this.paymentMethod,
    this.errorMessage,
    required this.metadata,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'paymentId': paymentId,
      'orderId': orderId,
      'status': status.toString(),
      'amount': amount,
      'paymentMethod': paymentMethod,
      'errorMessage': errorMessage,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Security event for monitoring
class SecurityEvent {
  final String eventType;
  final SecurityLevel level;
  final String description;
  final String? userId;
  final String? ipAddress;
  final Map<String, dynamic> details;
  final DateTime timestamp;
  
  const SecurityEvent({
    required this.eventType,
    required this.level,
    required this.description,
    this.userId,
    this.ipAddress,
    required this.details,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'eventType': eventType,
      'level': level.toString(),
      'description': description,
      'userId': userId,
      'ipAddress': ipAddress,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Performance metric for monitoring
class PerformanceMetric {
  final String name;
  final double value;
  final String unit;
  final Map<String, dynamic> tags;
  final DateTime timestamp;
  
  const PerformanceMetric({
    required this.name,
    required this.value,
    required this.unit,
    required this.tags,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'unit': unit,
      'tags': tags,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Security level enumeration
enum SecurityLevel {
  info,
  warning,
  error,
  critical,
}