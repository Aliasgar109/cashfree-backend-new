import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

import 'sanitization_service.dart';

/// Service for audit logging and security monitoring
class AuditService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Private constructor to prevent instantiation
  AuditService._();

  /// Logs user authentication events
  static Future<void> logAuthEvent(String action, {Map<String, dynamic>? details}) async {
    try {
      await _logEvent(
        action: action,
        resource: 'authentication',
        details: details,
      );
    } catch (e) {
      developer.log('Failed to log auth event: $e', name: 'AuditService');
    }
  }

  /// Logs payment-related events
  static Future<void> logPaymentEvent(String action, String paymentId, {Map<String, dynamic>? details}) async {
    try {
      await _logEvent(
        action: action,
        resource: 'payment:$paymentId',
        details: details,
      );
    } catch (e) {
      developer.log('Failed to log payment event: $e', name: 'AuditService');
    }
  }

  /// Logs user management events
  static Future<void> logUserManagementEvent(String action, String targetUserId, {Map<String, dynamic>? details}) async {
    try {
      await _logEvent(
        action: action,
        resource: 'user:$targetUserId',
        details: details,
      );
    } catch (e) {
      developer.log('Failed to log user management event: $e', name: 'AuditService');
    }
  }

  /// Logs file upload events
  static Future<void> logFileUploadEvent(String action, String fileName, {Map<String, dynamic>? details}) async {
    try {
      await _logEvent(
        action: action,
        resource: 'file:$fileName',
        details: details,
      );
    } catch (e) {
      developer.log('Failed to log file upload event: $e', name: 'AuditService');
    }
  }

  /// Logs security-related events
  static Future<void> logSecurityEvent(String action, String resource, {Map<String, dynamic>? details}) async {
    try {
      await _logEvent(
        action: action,
        resource: 'security:$resource',
        details: details,
        priority: 'HIGH',
      );
    } catch (e) {
      developer.log('Failed to log security event: $e', name: 'AuditService');
    }
  }

  /// Logs admin actions
  static Future<void> logAdminAction(String action, String resource, {Map<String, dynamic>? details}) async {
    try {
      await _logEvent(
        action: action,
        resource: 'admin:$resource',
        details: details,
        priority: 'MEDIUM',
      );
    } catch (e) {
      developer.log('Failed to log admin action: $e', name: 'AuditService');
    }
  }

  /// Logs data access events
  static Future<void> logDataAccess(String action, String resource, {Map<String, dynamic>? details}) async {
    try {
      await _logEvent(
        action: action,
        resource: 'data:$resource',
        details: details,
      );
    } catch (e) {
      developer.log('Failed to log data access event: $e', name: 'AuditService');
    }
  }

  /// Logs system configuration changes
  static Future<void> logConfigChange(String action, String configKey, {Map<String, dynamic>? details}) async {
    try {
      await _logEvent(
        action: action,
        resource: 'config:$configKey',
        details: details,
        priority: 'HIGH',
      );
    } catch (e) {
      developer.log('Failed to log config change: $e', name: 'AuditService');
    }
  }

  /// Logs failed operations for security monitoring
  static Future<void> logFailedOperation(String operation, String reason, {Map<String, dynamic>? details}) async {
    try {
      Map<String, dynamic> failureDetails = {
        'reason': SanitizationService.sanitizeLogData(reason),
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      if (details != null) {
        failureDetails.addAll(details);
      }

      await _logEvent(
        action: 'FAILED_$operation',
        resource: 'system',
        details: failureDetails,
        priority: 'HIGH',
      );
    } catch (e) {
      developer.log('Failed to log failed operation: $e', name: 'AuditService');
    }
  }

  /// Private method to log events to Firestore
  static Future<void> _logEvent({
    required String action,
    required String resource,
    Map<String, dynamic>? details,
    String priority = 'LOW',
  }) async {
    try {
      final user = _auth.currentUser;
      final userId = user?.uid ?? 'anonymous';

      // Sanitize all input data
      final sanitizedAction = SanitizationService.sanitizeLogData(action);
      final sanitizedResource = SanitizationService.sanitizeLogData(resource);

      Map<String, dynamic> logData = {
        'userId': userId,
        'action': sanitizedAction,
        'resource': sanitizedResource,
        'timestamp': FieldValue.serverTimestamp(),
        'priority': priority,
        'userAgent': 'Flutter Mobile App',
        'ipAddress': 'mobile_device', // Mobile apps don't have traditional IP addresses
      };

      // Add sanitized details if provided
      if (details != null) {
        Map<String, dynamic> sanitizedDetails = {};
        details.forEach((key, value) {
          if (value is String) {
            sanitizedDetails[key] = SanitizationService.sanitizeLogData(value);
          } else {
            sanitizedDetails[key] = value;
          }
        });
        logData['details'] = sanitizedDetails;
      }

      // Store in Firestore
      await _firestore.collection('audit_logs').add(logData);

      // Also log to console for development
      developer.log(
        'Audit: $sanitizedAction on $sanitizedResource by $userId',
        name: 'AuditService',
      );
    } catch (e) {
      // Fallback to console logging if Firestore fails
      developer.log(
        'Audit logging failed: $e. Original event: $action on $resource',
        name: 'AuditService',
      );
    }
  }

  /// Retrieves audit logs for admin review (with pagination)
  static Future<List<Map<String, dynamic>>> getAuditLogs({
    String? userId,
    String? action,
    String? resource,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query = _firestore.collection('audit_logs');

      // Apply filters
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      if (action != null) {
        query = query.where('action', isEqualTo: action);
      }
      if (resource != null) {
        query = query.where('resource', isEqualTo: resource);
      }
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      // Order by timestamp (most recent first)
      query = query.orderBy('timestamp', descending: true);

      // Apply pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final querySnapshot = await query.get();
      
      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      developer.log('Failed to retrieve audit logs: $e', name: 'AuditService');
      return [];
    }
  }

  /// Gets audit log statistics for dashboard
  static Future<Map<String, dynamic>> getAuditStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('audit_logs');

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final querySnapshot = await query.get();
      
      Map<String, int> actionCounts = {};
      Map<String, int> priorityCounts = {};
      Map<String, int> userCounts = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Count actions
        String action = data['action'] ?? 'unknown';
        actionCounts[action] = (actionCounts[action] ?? 0) + 1;
        
        // Count priorities
        String priority = data['priority'] ?? 'LOW';
        priorityCounts[priority] = (priorityCounts[priority] ?? 0) + 1;
        
        // Count users
        String userId = data['userId'] ?? 'anonymous';
        userCounts[userId] = (userCounts[userId] ?? 0) + 1;
      }

      return {
        'totalEvents': querySnapshot.docs.length,
        'actionCounts': actionCounts,
        'priorityCounts': priorityCounts,
        'userCounts': userCounts,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      developer.log('Failed to get audit statistics: $e', name: 'AuditService');
      return {
        'totalEvents': 0,
        'actionCounts': {},
        'priorityCounts': {},
        'userCounts': {},
        'error': e.toString(),
      };
    }
  }

  /// Cleans up old audit logs (for maintenance)
  static Future<void> cleanupOldLogs({int daysToKeep = 365}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      
      final query = _firestore
          .collection('audit_logs')
          .where('timestamp', isLessThan: cutoffDate)
          .limit(500); // Process in batches

      final querySnapshot = await query.get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        
        for (var doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
        
        await batch.commit();
        
        developer.log(
          'Cleaned up ${querySnapshot.docs.length} old audit logs',
          name: 'AuditService',
        );
      }
    } catch (e) {
      developer.log('Failed to cleanup old audit logs: $e', name: 'AuditService');
    }
  }
}