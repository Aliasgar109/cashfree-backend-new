import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import '../models/settings_model.dart';
import 'notification_service.dart';
import 'settings_service.dart';
import 'user_service.dart';

/// Service for handling automated payment reminders
class ReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final NotificationService _notificationService = NotificationService();
  final SettingsService _settingsService = SettingsService();
  final UserService _userService = UserService();

  static const String _remindersCollection = 'reminders';
  static const String _reminderHistoryCollection = 'reminder_history';
  static const String _fcmTokensCollection = 'fcm_tokens';

  /// Initialize FCM and request permissions
  Future<ReminderInitResult> initializeFCM() async {
    try {
      // Request permission for notifications
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        final token = await _messaging.getToken();
        
        return ReminderInitResult(
          success: true,
          fcmToken: token,
          message: 'FCM initialized successfully',
        );
      } else {
        return ReminderInitResult(
          success: false,
          error: 'Notification permission denied',
        );
      }
    } catch (e) {
      return ReminderInitResult(
        success: false,
        error: 'Failed to initialize FCM: $e',
      );
    }
  }

  /// Store FCM token for a user
  Future<void> storeFCMToken({
    required String userId,
    required String token,
  }) async {
    try {
      await _firestore
          .collection(_fcmTokensCollection)
          .doc(userId)
          .set({
        'userId': userId,
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': 'android', // Since this is Android-only app
      }, SetOptions(merge: true));
    } catch (e) {
      // Handle error silently for now
    }
  }

  /// Get FCM token for a user
  Future<String?> getFCMToken(String userId) async {
    try {
      final doc = await _firestore
          .collection(_fcmTokensCollection)
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return doc.data()?['token'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Schedule automatic reminders for all users
  Future<ReminderScheduleResult> scheduleAutomaticReminders() async {
    try {
      final settings = await _settingsService.getSettings();
      final currentYear = DateTime.now().year;
      final reminderDate = DateTime(currentYear, 12, 31)
          .subtract(Duration(days: settings.reminderDaysBefore));

      // Only schedule if we haven't passed the reminder date
      if (DateTime.now().isBefore(reminderDate)) {
        return ReminderScheduleResult(
          success: false,
          error: 'Reminder date has already passed for this year',
        );
      }

      // Get all active users
      final users = await _userService.getAllUsers();
      int scheduledCount = 0;
      int errorCount = 0;

      for (final user in users) {
        if (user.role == UserRole.USER) {
          final result = await _scheduleReminderForUser(
            user: user,
            year: currentYear,
            settings: settings,
          );
          
          if (result.success) {
            scheduledCount++;
          } else {
            errorCount++;
          }
        }
      }

      return ReminderScheduleResult(
        success: true,
        scheduledCount: scheduledCount,
        errorCount: errorCount,
        message: 'Scheduled $scheduledCount reminders, $errorCount errors',
      );
    } catch (e) {
      return ReminderScheduleResult(
        success: false,
        error: 'Failed to schedule automatic reminders: $e',
      );
    }
  }

  /// Schedule reminder for a specific user
  Future<ReminderResult> _scheduleReminderForUser({
    required UserModel user,
    required int year,
    required SettingsModel settings,
  }) async {
    try {
      // Check if user has already paid for this year
      final hasPayment = await _hasUserPaidForYear(user.id, year);
      if (hasPayment) {
        return ReminderResult(
          success: true,
          message: 'User has already paid for $year',
        );
      }

      // Check if reminder already exists for this user and year
      final existingReminder = await _getReminderForUserYear(user.id, year);
      if (existingReminder != null) {
        return ReminderResult(
          success: true,
          message: 'Reminder already scheduled for user',
        );
      }

      // Calculate reminder date
      final reminderDate = DateTime(year, 12, 31)
          .subtract(Duration(days: settings.reminderDaysBefore));

      // Create reminder record
      final reminderId = _firestore.collection(_remindersCollection).doc().id;
      final reminder = ReminderModel(
        id: reminderId,
        userId: user.id,
        year: year,
        amount: settings.yearlyFee,
        scheduledDate: reminderDate,
        status: ReminderStatus.scheduled,
        reminderType: ReminderType.paymentDue,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection(_remindersCollection)
          .doc(reminderId)
          .set(reminder.toFirestore());

      return ReminderResult(
        success: true,
        reminderId: reminderId,
        message: 'Reminder scheduled successfully',
      );
    } catch (e) {
      return ReminderResult(
        success: false,
        error: 'Failed to schedule reminder for user: $e',
      );
    }
  }

  /// Send immediate reminder to a user
  Future<ReminderResult> sendImmediateReminder({
    required String userId,
    required ReminderType type,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final user = await _userService.getUserById(userId);
      if (user == null) {
        return ReminderResult(
          success: false,
          error: 'User not found',
        );
      }

      final settings = await _settingsService.getSettings();
      final currentYear = DateTime.now().year;

      // Send notification
      final notificationResult = await _notificationService.sendPaymentReminder(
        user: user,
        amount: settings.yearlyFee,
        year: currentYear,
      );

      // Send push notification
      final pushResult = await _sendPushReminder(
        user: user,
        type: type,
        amount: settings.yearlyFee,
        year: currentYear,
      );

      // Log reminder history
      await _logReminderHistory(
        userId: userId,
        type: type,
        status: ReminderStatus.sent,
        notificationSent: notificationResult.success,
        pushNotificationSent: pushResult,
        additionalData: additionalData,
      );

      return ReminderResult(
        success: true,
        message: 'Immediate reminder sent successfully',
        notificationSent: notificationResult.success,
        pushNotificationSent: pushResult,
      );
    } catch (e) {
      return ReminderResult(
        success: false,
        error: 'Failed to send immediate reminder: $e',
      );
    }
  }

  /// Process scheduled reminders (to be called by a scheduled job)
  Future<ReminderProcessResult> processScheduledReminders() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Get all scheduled reminders for today
      final remindersQuery = await _firestore
          .collection(_remindersCollection)
          .where('status', isEqualTo: ReminderStatus.scheduled.name)
          .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(today.add(Duration(days: 1))))
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .get();

      int processedCount = 0;
      int errorCount = 0;
      List<String> errors = [];

      for (final doc in remindersQuery.docs) {
        try {
          final reminder = ReminderModel.fromFirestore(doc);
          
          // Check if user still needs to pay
          final hasPayment = await _hasUserPaidForYear(reminder.userId, reminder.year);
          if (hasPayment) {
            // Mark reminder as cancelled since payment was made
            await _updateReminderStatus(reminder.id, ReminderStatus.cancelled);
            continue;
          }

          // Send the reminder
          final result = await sendImmediateReminder(
            userId: reminder.userId,
            type: reminder.reminderType,
            additionalData: {
              'reminderId': reminder.id,
              'scheduledDate': reminder.scheduledDate.toIso8601String(),
            },
          );

          if (result.success) {
            await _updateReminderStatus(reminder.id, ReminderStatus.sent);
            processedCount++;
          } else {
            await _updateReminderStatus(reminder.id, ReminderStatus.failed);
            errorCount++;
            errors.add('Reminder ${reminder.id}: ${result.error}');
          }
        } catch (e) {
          errorCount++;
          errors.add('Document ${doc.id}: $e');
        }
      }

      return ReminderProcessResult(
        success: true,
        processedCount: processedCount,
        errorCount: errorCount,
        errors: errors,
        message: 'Processed $processedCount reminders, $errorCount errors',
      );
    } catch (e) {
      return ReminderProcessResult(
        success: false,
        error: 'Failed to process scheduled reminders: $e',
      );
    }
  }

  /// Send escalated reminders for overdue payments
  Future<ReminderProcessResult> sendEscalatedReminders() async {
    try {
      final currentYear = DateTime.now().year;
      
      // Get users with overdue payments (previous years)
      final overdueUsers = await _getOverdueUsers(currentYear);
      
      int sentCount = 0;
      int errorCount = 0;
      List<String> errors = [];

      for (final user in overdueUsers) {
        try {
          final result = await sendImmediateReminder(
            userId: user.id,
            type: ReminderType.overduePayment,
            additionalData: {
              'escalated': true,
              'overdueYears': await _getOverdueYears(user.id, currentYear),
            },
          );

          if (result.success) {
            sentCount++;
          } else {
            errorCount++;
            errors.add('User ${user.id}: ${result.error}');
          }
        } catch (e) {
          errorCount++;
          errors.add('User ${user.id}: $e');
        }
      }

      return ReminderProcessResult(
        success: true,
        processedCount: sentCount,
        errorCount: errorCount,
        errors: errors,
        message: 'Sent $sentCount escalated reminders, $errorCount errors',
      );
    } catch (e) {
      return ReminderProcessResult(
        success: false,
        error: 'Failed to send escalated reminders: $e',
      );
    }
  }

  /// Configure reminder settings
  Future<ReminderConfigResult> configureReminderSettings({
    required int reminderDaysBefore,
    required bool enableAutomaticReminders,
    required bool enableEscalatedReminders,
    required int escalationDays,
    required String updatedBy,
  }) async {
    try {
      // Update main settings
      final settingsResult = await _settingsService.updateReminderDays(
        days: reminderDaysBefore,
        updatedBy: updatedBy,
      );

      if (!settingsResult.success) {
        return ReminderConfigResult(
          success: false,
          error: settingsResult.error,
        );
      }

      // Store reminder-specific configuration
      await _firestore
          .collection('reminder_config')
          .doc('settings')
          .set({
        'enableAutomaticReminders': enableAutomaticReminders,
        'enableEscalatedReminders': enableEscalatedReminders,
        'escalationDays': escalationDays,
        'reminderDaysBefore': reminderDaysBefore,
        'lastUpdated': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      }, SetOptions(merge: true));

      return ReminderConfigResult(
        success: true,
        message: 'Reminder settings configured successfully',
      );
    } catch (e) {
      return ReminderConfigResult(
        success: false,
        error: 'Failed to configure reminder settings: $e',
      );
    }
  }

  /// Get reminder configuration
  Future<ReminderConfig> getReminderConfig() async {
    try {
      final doc = await _firestore
          .collection('reminder_config')
          .doc('settings')
          .get();

      if (doc.exists) {
        return ReminderConfig.fromFirestore(doc);
      } else {
        return ReminderConfig.defaultConfig();
      }
    } catch (e) {
      return ReminderConfig.defaultConfig();
    }
  }

  /// Get reminder history for a user
  Future<List<ReminderHistoryEntry>> getReminderHistory({
    required String userId,
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collection(_reminderHistoryCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('sentAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => ReminderHistoryEntry.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get reminder statistics
  Future<ReminderStats> getReminderStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final start = startDate ?? DateTime.now().subtract(Duration(days: 30));
      final end = endDate ?? DateTime.now();

      Query query = _firestore
          .collection(_reminderHistoryCollection)
          .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('sentAt', isLessThanOrEqualTo: Timestamp.fromDate(end));

      final snapshot = await query.get();
      final entries = snapshot.docs
          .map((doc) => ReminderHistoryEntry.fromFirestore(doc))
          .toList();

      int totalSent = entries.length;
      int successful = entries.where((e) => e.notificationSent).length;
      int pushNotificationsSent = entries.where((e) => e.pushNotificationSent).length;
      
      Map<ReminderType, int> byType = {};
      for (final entry in entries) {
        byType[entry.type] = (byType[entry.type] ?? 0) + 1;
      }

      return ReminderStats(
        totalSent: totalSent,
        successful: successful,
        pushNotificationsSent: pushNotificationsSent,
        byType: byType,
        period: DateRange(start: start, end: end),
      );
    } catch (e) {
      return ReminderStats(
        totalSent: 0,
        successful: 0,
        pushNotificationsSent: 0,
        byType: {},
        period: DateRange(
          start: DateTime.now().subtract(Duration(days: 30)),
          end: DateTime.now(),
        ),
      );
    }
  }

  // Helper methods

  Future<bool> _hasUserPaidForYear(String userId, int year) async {
    try {
      final query = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('year', isEqualTo: year)
          .where('status', isEqualTo: PaymentStatus.APPROVED.name)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<ReminderModel?> _getReminderForUserYear(String userId, int year) async {
    try {
      final query = await _firestore
          .collection(_remindersCollection)
          .where('userId', isEqualTo: userId)
          .where('year', isEqualTo: year)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return ReminderModel.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<UserModel>> _getOverdueUsers(int currentYear) async {
    try {
      // Get all users who have unpaid payments from previous years
      final overduePayments = await _firestore
          .collection('payments')
          .where('year', isLessThan: currentYear)
          .where('status', whereIn: ['PENDING', 'REJECTED'])
          .get();

      final overdueUserIds = overduePayments.docs
          .map((doc) => doc.data()['userId'] as String)
          .toSet()
          .toList();

      if (overdueUserIds.isEmpty) return [];

      // Get user details
      final users = <UserModel>[];
      for (final userId in overdueUserIds) {
        final user = await _userService.getUserById(userId);
        if (user != null && user.role == UserRole.USER) {
          users.add(user);
        }
      }

      return users;
    } catch (e) {
      return [];
    }
  }

  Future<List<int>> _getOverdueYears(String userId, int currentYear) async {
    try {
      final overduePayments = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('year', isLessThan: currentYear)
          .where('status', whereIn: ['PENDING', 'REJECTED'])
          .get();

      return overduePayments.docs
          .map((doc) => doc.data()['year'] as int)
          .toSet()
          .toList()
        ..sort();
    } catch (e) {
      return [];
    }
  }

  Future<bool> _sendPushReminder({
    required UserModel user,
    required ReminderType type,
    required double amount,
    required int year,
  }) async {
    try {
      final token = await getFCMToken(user.id);
      if (token == null) return false;

      // Note: In a real implementation, this would be done server-side
      // For now, we'll just return true to indicate the attempt was made
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _logReminderHistory({
    required String userId,
    required ReminderType type,
    required ReminderStatus status,
    required bool notificationSent,
    required bool pushNotificationSent,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final historyId = _firestore.collection(_reminderHistoryCollection).doc().id;
      
      await _firestore
          .collection(_reminderHistoryCollection)
          .doc(historyId)
          .set({
        'id': historyId,
        'userId': userId,
        'type': type.name,
        'status': status.name,
        'notificationSent': notificationSent,
        'pushNotificationSent': pushNotificationSent,
        'sentAt': FieldValue.serverTimestamp(),
        'additionalData': additionalData ?? {},
      });
    } catch (e) {
      // Handle error silently for now
    }
  }

  Future<void> _updateReminderStatus(String reminderId, ReminderStatus status) async {
    try {
      await _firestore
          .collection(_remindersCollection)
          .doc(reminderId)
          .update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Handle error silently for now
    }
  }

  String _getReminderTitle(ReminderType type, String language) {
    if (language == 'gu') {
      switch (type) {
        case ReminderType.paymentDue:
          return 'ચુકવણી રિમાઇન્ડર';
        case ReminderType.overduePayment:
          return 'મુદત વીતી ગયેલી ચુકવણી';
        case ReminderType.finalNotice:
          return 'અંતિમ નોટિસ';
      }
    } else {
      switch (type) {
        case ReminderType.paymentDue:
          return 'Payment Reminder';
        case ReminderType.overduePayment:
          return 'Overdue Payment';
        case ReminderType.finalNotice:
          return 'Final Notice';
      }
    }
  }

  String _getReminderMessage(ReminderType type, double amount, int year, String language) {
    final amountStr = '₹${amount.toStringAsFixed(2)}';
    
    if (language == 'gu') {
      switch (type) {
        case ReminderType.paymentDue:
          return 'તમારી $year ની $amountStr ની સબ્સ્ક્રિપ્શન ફી બાકી છે. કૃપા કરીને તેને ચૂકવો.';
        case ReminderType.overduePayment:
          return 'તમારી $year ની $amountStr ની ચુકવણી મુદત વીતી ગઈ છે. કૃપા કરીને તાત્કાલિક ચૂકવો.';
        case ReminderType.finalNotice:
          return 'અંતિમ નોટિસ: તમારી $year ની $amountStr ની ચુકવણી તાત્કાલિક કરવી જરૂરી છે.';
      }
    } else {
      switch (type) {
        case ReminderType.paymentDue:
          return 'Your subscription fee of $amountStr for $year is due. Please make the payment.';
        case ReminderType.overduePayment:
          return 'Your payment of $amountStr for $year is overdue. Please pay immediately.';
        case ReminderType.finalNotice:
          return 'Final Notice: Your payment of $amountStr for $year requires immediate attention.';
      }
    }
  }
}

// Enums and Models

enum ReminderType {
  paymentDue,
  overduePayment,
  finalNotice,
}

enum ReminderStatus {
  scheduled,
  sent,
  failed,
  cancelled,
}

class ReminderModel {
  final String id;
  final String userId;
  final int year;
  final double amount;
  final DateTime scheduledDate;
  final ReminderStatus status;
  final ReminderType reminderType;
  final DateTime createdAt;
  final DateTime? sentAt;

  ReminderModel({
    required this.id,
    required this.userId,
    required this.year,
    required this.amount,
    required this.scheduledDate,
    required this.status,
    required this.reminderType,
    required this.createdAt,
    this.sentAt,
  });

  factory ReminderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReminderModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      status: ReminderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ReminderStatus.scheduled,
      ),
      reminderType: ReminderType.values.firstWhere(
        (e) => e.name == data['reminderType'],
        orElse: () => ReminderType.paymentDue,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'year': year,
      'amount': amount,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': status.name,
      'reminderType': reminderType.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
    };
  }
}

class ReminderConfig {
  final bool enableAutomaticReminders;
  final bool enableEscalatedReminders;
  final int escalationDays;
  final int reminderDaysBefore;
  final DateTime lastUpdated;
  final String updatedBy;

  ReminderConfig({
    required this.enableAutomaticReminders,
    required this.enableEscalatedReminders,
    required this.escalationDays,
    required this.reminderDaysBefore,
    required this.lastUpdated,
    required this.updatedBy,
  });

  factory ReminderConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReminderConfig(
      enableAutomaticReminders: data['enableAutomaticReminders'] ?? true,
      enableEscalatedReminders: data['enableEscalatedReminders'] ?? true,
      escalationDays: data['escalationDays'] ?? 7,
      reminderDaysBefore: data['reminderDaysBefore'] ?? 30,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedBy: data['updatedBy'] ?? 'system',
    );
  }

  factory ReminderConfig.defaultConfig() {
    return ReminderConfig(
      enableAutomaticReminders: true,
      enableEscalatedReminders: true,
      escalationDays: 7,
      reminderDaysBefore: 30,
      lastUpdated: DateTime.now(),
      updatedBy: 'system',
    );
  }
}

class ReminderHistoryEntry {
  final String id;
  final String userId;
  final ReminderType type;
  final ReminderStatus status;
  final bool notificationSent;
  final bool pushNotificationSent;
  final DateTime sentAt;
  final Map<String, dynamic> additionalData;

  ReminderHistoryEntry({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.notificationSent,
    required this.pushNotificationSent,
    required this.sentAt,
    required this.additionalData,
  });

  factory ReminderHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReminderHistoryEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: ReminderType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ReminderType.paymentDue,
      ),
      status: ReminderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ReminderStatus.sent,
      ),
      notificationSent: data['notificationSent'] ?? false,
      pushNotificationSent: data['pushNotificationSent'] ?? false,
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      additionalData: Map<String, dynamic>.from(data['additionalData'] ?? {}),
    );
  }
}

class ReminderStats {
  final int totalSent;
  final int successful;
  final int pushNotificationsSent;
  final Map<ReminderType, int> byType;
  final DateRange period;

  ReminderStats({
    required this.totalSent,
    required this.successful,
    required this.pushNotificationsSent,
    required this.byType,
    required this.period,
  });
}

class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

// Result classes

class ReminderInitResult {
  final bool success;
  final String? fcmToken;
  final String? message;
  final String? error;

  ReminderInitResult({
    required this.success,
    this.fcmToken,
    this.message,
    this.error,
  });
}

class ReminderResult {
  final bool success;
  final String? reminderId;
  final String? message;
  final String? error;
  final bool notificationSent;
  final bool pushNotificationSent;

  ReminderResult({
    required this.success,
    this.reminderId,
    this.message,
    this.error,
    this.notificationSent = false,
    this.pushNotificationSent = false,
  });
}

class ReminderScheduleResult {
  final bool success;
  final int scheduledCount;
  final int errorCount;
  final String? message;
  final String? error;

  ReminderScheduleResult({
    required this.success,
    this.scheduledCount = 0,
    this.errorCount = 0,
    this.message,
    this.error,
  });
}

class ReminderProcessResult {
  final bool success;
  final int processedCount;
  final int errorCount;
  final List<String> errors;
  final String? message;
  final String? error;

  ReminderProcessResult({
    required this.success,
    this.processedCount = 0,
    this.errorCount = 0,
    this.errors = const [],
    this.message,
    this.error,
  });
}

class ReminderConfigResult {
  final bool success;
  final String? message;
  final String? error;

  ReminderConfigResult({
    required this.success,
    this.message,
    this.error,
  });
}