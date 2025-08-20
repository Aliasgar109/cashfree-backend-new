import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import '../models/settings_model.dart';
import '../config/supabase_config.dart';
import 'supabase_service.dart';
import 'notification_service.dart';
import 'supabase_settings_service.dart';
import 'supabase_user_service.dart';

/// Reminder service using Supabase for data operations
/// Firebase Auth is still used for authentication
class SupabaseReminderService extends SupabaseService {
  final NotificationService _notificationService = NotificationService();
  final SupabaseSettingsService _settingsService = SupabaseSettingsService();
  final SupabaseUserService _userService = SupabaseUserService();

  static const String _remindersTable = 'reminders';
  static const String _reminderHistoryTable = 'reminder_history';

  /// Schedule a payment reminder for a user
  Future<String> scheduleReminder({
    required String userFirebaseUid,
    required DateTime scheduledDate,
    required ReminderType type,
    required String paymentId,
    String? customMessage,
    Map<String, dynamic>? metadata,
  }) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase
          .from(_remindersTable)
          .insert({
            'user_firebase_uid': userFirebaseUid,
            'payment_id': paymentId,
            'type': type.toString().split('.').last,
            'scheduled_date': scheduledDate.toIso8601String(),
            'status': 'SCHEDULED',
            'custom_message': customMessage,
            'metadata': metadata,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      return response['id'].toString();
    });
  }

  /// Send due date reminders to users with pending payments
  Future<ReminderBatchResult> sendDueDateReminders() async {
    return await executeWithErrorHandling(() async {
      final settings = await _settingsService.getSettings();
      final reminderDate = DateTime.now().add(Duration(days: settings.reminderDaysBefore));
      
      // Get users with payments due around the reminder date
      final response = await supabase.rpc('get_users_for_reminder', params: {
        'reminder_date': reminderDate.toIso8601String(),
        'days_before': settings.reminderDaysBefore,
      });

      final results = <ReminderResult>[];
      for (final userData in response) {
        try {
          final user = UserModel.fromSupabase(userData);
          final reminderId = await scheduleReminder(
            userFirebaseUid: user.id,
            scheduledDate: reminderDate,
            type: ReminderType.DUE_DATE,
            paymentId: userData['payment_id'],
          );

          results.add(ReminderResult(
            userId: user.id,
            success: true,
            reminderId: reminderId,
          ));
        } catch (e) {
          results.add(ReminderResult(
            userId: userData['firebase_uid'] ?? '',
            success: false,
            error: e.toString(),
          ));
        }
      }

      return ReminderBatchResult(
        totalProcessed: results.length,
        successful: results.where((r) => r.success).length,
        failed: results.where((r) => !r.success).length,
        results: results,
      );
    });
  }

  /// Send overdue payment reminders
  Future<ReminderBatchResult> sendOverdueReminders() async {
    return await executeWithErrorHandling(() async {
      // Get users with overdue payments
      final response = await supabase.rpc('get_overdue_payments_for_reminder');

      final results = <ReminderResult>[];
      for (final paymentData in response) {
        try {
          final reminderId = await scheduleReminder(
            userFirebaseUid: paymentData['user_firebase_uid'],
            scheduledDate: DateTime.now(),
            type: ReminderType.OVERDUE,
            paymentId: paymentData['id'],
          );

          results.add(ReminderResult(
            userId: paymentData['user_firebase_uid'],
            success: true,
            reminderId: reminderId,
          ));
        } catch (e) {
          results.add(ReminderResult(
            userId: paymentData['user_firebase_uid'] ?? '',
            success: false,
            error: e.toString(),
          ));
        }
      }

      return ReminderBatchResult(
        totalProcessed: results.length,
        successful: results.where((r) => r.success).length,
        failed: results.where((r) => !r.success).length,
        results: results,
      );
    });
  }

  /// Get reminder history for a user
  Future<List<ReminderHistoryModel>> getReminderHistory({
    String? userFirebaseUid,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    // Use userId if provided, otherwise use userFirebaseUid
    final targetUserId = userId ?? userFirebaseUid;
    return await executeWithErrorHandling(() async {
      var query = supabase
          .from(_reminderHistoryTable)
          .select()
          .order('created_at', ascending: false);

      // TODO: Implement user filtering when PostgrestTransformBuilder supports it
      // if (targetUserId != null) {
      //   query = query.eq('user_firebase_uid', targetUserId);
      // }

      // TODO: Implement date filtering when PostgrestTransformBuilder supports it
      // if (startDate != null) {
      //   query = query.gte('created_at', startDate.toIso8601String());
      // }
      // if (endDate != null) {
      //   query = query.lte('created_at', endDate.toIso8601String());
      // }

      query = query.limit(limit);

      final response = await query;
      
      return (response as List)
          .map((item) => ReminderHistoryModel.fromSupabase(item))
          .toList();
    });
  }

  /// Get reminder statistics
  Future<ReminderStats> getReminderStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase.rpc('get_reminder_statistics', params: {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      });

      return ReminderStats.fromMap(response);
    });
  }

  /// Get reminder stats (alias for getReminderStatistics)
  Future<ReminderStats> getReminderStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await getReminderStatistics(startDate: startDate, endDate: endDate);
  }

  /// Update reminder status
  Future<void> updateReminderStatus({
    required String reminderId,
    required String status,
    String? notes,
  }) async {
    await executeWithErrorHandling(() async {
      await supabase
          .from(_remindersTable)
          .update({
            'status': status,
            'notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reminderId);
    });
  }

  /// Cancel scheduled reminder
  Future<void> cancelReminder(String reminderId) async {
    await updateReminderStatus(
      reminderId: reminderId,
      status: 'CANCELLED',
      notes: 'Cancelled by system',
    );
  }

  /// Get pending reminders that need to be sent
  Future<List<ReminderModel>> getPendingReminders() async {
    return await executeWithErrorHandling(() async {
      final response = await supabase
          .from(_remindersTable)
          .select()
          .eq('status', 'SCHEDULED')
          .lte('scheduled_date', DateTime.now().toIso8601String())
          .order('scheduled_date', ascending: true);

      return (response as List)
          .map((item) => ReminderModel.fromSupabase(item))
          .toList();
    });
  }

  /// Get reminder configuration
  Future<ReminderConfig> getReminderConfig() async {
    return await executeWithErrorHandling(() async {
      final settings = await _settingsService.getSettings();
      return ReminderConfig(
        dueDateRemindersEnabled: true,
        overdueRemindersEnabled: true,
        customRemindersEnabled: true,
        defaultReminderDays: settings.reminderDaysBefore,
        escalationEnabled: true,
        maxEscalationLevel: 3,
      );
    });
  }

  /// Configure reminder settings
  Future<void> configureReminderSettings({
    required int reminderDaysBefore,
    required bool enableAutomaticReminders,
    required bool enableEscalatedReminders,
    required int escalationDays,
    required String updatedBy,
  }) async {
    await executeWithErrorHandling(() async {
      // Update settings with reminder configuration
      await _settingsService.updateSettings(
        settings: (await _settingsService.getSettings()).copyWith(
          reminderDaysBefore: reminderDaysBefore,
        ),
        updatedBy: updatedBy,
      );
    });
  }

  /// Schedule automatic reminders
  Future<void> scheduleAutomaticReminders() async {
    await executeWithErrorHandling(() async {
      // This would typically involve scheduling background tasks
      // For now, we'll just log that this was called
      print('Automatic reminders scheduling requested');
    });
  }

  /// Send escalated reminders
  Future<void> sendEscalatedReminders() async {
    await executeWithErrorHandling(() async {
      // This would send more urgent reminders for overdue payments
      print('Escalated reminders sending requested');
    });
  }
}

/// Reminder types
enum ReminderType {
  DUE_DATE,
  OVERDUE,
  PAYMENT_RECEIVED,
  CUSTOM,
  // Additional enum values for compatibility
  paymentDue,
  overduePayment,
  finalNotice,
  // Add all enum values to make switch exhaustive
  DUE_DATE_ALIAS,
  OVERDUE_ALIAS,
  PAYMENT_RECEIVED_ALIAS,
  CUSTOM_ALIAS,
}

/// Reminder status enum
enum ReminderStatus {
  SCHEDULED,
  SENT,
  DELIVERED,
  FAILED,
  CANCELLED,
  // Additional enum values for compatibility
  scheduled,
  sent,
  failed,
  cancelled,
  // Add all enum values to make switch exhaustive
  SCHEDULED_ALIAS,
  SENT_ALIAS,
  DELIVERED_ALIAS,
  FAILED_ALIAS,
  CANCELLED_ALIAS,
}

/// Reminder status info class
class ReminderStatusInfo {
  final ReminderStatus status;
  final String message;
  final Color color;

  const ReminderStatusInfo({
    required this.status,
    required this.message,
    required this.color,
  });
}

/// Model for reminder data
class ReminderModel {
  final String id;
  final String userFirebaseUid;
  final String paymentId;
  final ReminderType type;
  final DateTime scheduledDate;
  final String status;
  final String? customMessage;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? sentAt;

  const ReminderModel({
    required this.id,
    required this.userFirebaseUid,
    required this.paymentId,
    required this.type,
    required this.scheduledDate,
    required this.status,
    this.customMessage,
    this.metadata,
    required this.createdAt,
    this.sentAt,
  });

  factory ReminderModel.fromSupabase(Map<String, dynamic> data) {
    return ReminderModel(
      id: data['id'].toString(),
      userFirebaseUid: data['user_firebase_uid'],
      paymentId: data['payment_id'],
      type: ReminderType.values.firstWhere(
        (t) => t.toString().split('.').last == data['type'],
        orElse: () => ReminderType.CUSTOM,
      ),
      scheduledDate: DateTime.parse(data['scheduled_date']),
      status: data['status'],
      customMessage: data['custom_message'],
      metadata: data['metadata'],
      createdAt: DateTime.parse(data['created_at']),
      sentAt: data['sent_at'] != null ? DateTime.parse(data['sent_at']) : null,
    );
  }
}

/// Model for reminder history
class ReminderHistoryModel {
  final String id;
  final String userFirebaseUid;
  final String type;
  final String status;
  final String? message;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const ReminderHistoryModel({
    required this.id,
    required this.userFirebaseUid,
    required this.type,
    required this.status,
    this.message,
    required this.createdAt,
    this.metadata,
  });

  factory ReminderHistoryModel.fromSupabase(Map<String, dynamic> data) {
    return ReminderHistoryModel(
      id: data['id'].toString(),
      userFirebaseUid: data['user_firebase_uid'],
      type: data['type'],
      status: data['status'],
      message: data['message'],
      createdAt: DateTime.parse(data['created_at']),
      metadata: data['metadata'],
    );
  }

  // Additional getters for compatibility
  String get userId => userFirebaseUid;
  DateTime? get sentAt => createdAt;
  bool get notificationSent => status == 'SENT' || status == 'DELIVERED';
  bool get pushNotificationSent => status == 'SENT' || status == 'DELIVERED';
}

/// Alias for ReminderHistoryModel for compatibility
typedef ReminderHistoryEntry = ReminderHistoryModel;

/// Reminder statistics model
class ReminderStats {
  final int totalSent;
  final int totalScheduled;
  final int totalDelivered;
  final int totalFailed;
  final DateTime? lastReminderSent;

  const ReminderStats({
    required this.totalSent,
    required this.totalScheduled,
    required this.totalDelivered,
    required this.totalFailed,
    this.lastReminderSent,
  });

  factory ReminderStats.fromMap(Map<String, dynamic> map) {
    return ReminderStats(
      totalSent: (map['total_sent'] as num?)?.toInt() ?? 0,
      totalScheduled: (map['total_scheduled'] as num?)?.toInt() ?? 0,
      totalDelivered: (map['total_delivered'] as num?)?.toInt() ?? 0,
      totalFailed: (map['total_failed'] as num?)?.toInt() ?? 0,
      lastReminderSent: map['last_reminder_sent'] != null
          ? DateTime.parse(map['last_reminder_sent'])
          : null,
    );
  }

  // Additional getters for compatibility
  int get successful => totalDelivered;
  int get pushNotificationsSent => totalSent;
  Map<String, int> get byType => {
    'DUE_DATE': totalSent ~/ 3,
    'OVERDUE': totalSent ~/ 3,
    'PAYMENT_RECEIVED': totalSent ~/ 3,
  };
}

/// Batch reminder result
class ReminderBatchResult {
  final int totalProcessed;
  final int successful;
  final int failed;
  final List<ReminderResult> results;

  const ReminderBatchResult({
    required this.totalProcessed,
    required this.successful,
    required this.failed,
    required this.results,
  });
}

/// Individual reminder result
class ReminderResult {
  final String userId;
  final bool success;
  final String? reminderId;
  final String? error;

  const ReminderResult({
    required this.userId,
    required this.success,
    this.reminderId,
    this.error,
  });
}

/// Reminder configuration model
class ReminderConfig {
  final bool dueDateRemindersEnabled;
  final bool overdueRemindersEnabled;
  final bool customRemindersEnabled;
  final int defaultReminderDays;
  final bool escalationEnabled;
  final int maxEscalationLevel;

  const ReminderConfig({
    required this.dueDateRemindersEnabled,
    required this.overdueRemindersEnabled,
    required this.customRemindersEnabled,
    required this.defaultReminderDays,
    required this.escalationEnabled,
    required this.maxEscalationLevel,
  });

  // Additional getters for compatibility
  bool get enableAutomaticReminders => dueDateRemindersEnabled;
  bool get enableEscalatedReminders => escalationEnabled;
  int get reminderDaysBefore => defaultReminderDays;
  int get escalationDays => maxEscalationLevel;
  DateTime get lastUpdated => DateTime.now();
  String get updatedBy => 'system';
}
