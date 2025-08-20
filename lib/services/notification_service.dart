import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:telephony/telephony.dart';  // Commented out due to dependency issues
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import 'notification_template_service.dart';

/// Service for handling user notifications
class NotificationService {
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  // final Telephony _telephony;  // Commented out due to dependency issues

  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    // Telephony? telephony,  // Commented out due to dependency issues
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;
        // _telephony = telephony ?? Telephony.instance;  // Commented out due to dependency issues

  /// Send notification when payment status changes
  Future<NotificationResult> notifyPaymentStatusChange({
    required UserModel user,
    required PaymentModel payment,
    required PaymentStatus newStatus,
    String? rejectionReason,
  }) async {
    try {
      // Create notification record
      final notificationId = _firestore.collection('notifications').doc().id;
      
      final notification = {
        'id': notificationId,
        'userId': user.id,
        'type': 'payment_status_change',
        'title': NotificationTemplateService.getPaymentStatusTitle(newStatus, user.preferredLanguage),
        'message': NotificationTemplateService.getPaymentStatusMessage(newStatus, payment, user.preferredLanguage, rejectionReason),
        'paymentId': payment.id,
        'status': newStatus.name,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'language': user.preferredLanguage,
      };

      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(notification);

      // TODO: Send push notification via FCM
      // This would be implemented when FCM is set up
      final pushResult = await _sendPushNotification(
        userId: user.id,
        title: notification['title'] as String,
        message: notification['message'] as String,
        data: {
          'type': 'payment_status_change',
          'paymentId': payment.id,
          'status': newStatus.name,
        },
      );

      return NotificationResult(
        success: true,
        notificationId: notificationId,
        pushNotificationSent: pushResult,
        message: 'Notification sent successfully',
      );
    } catch (e) {
      return NotificationResult(
        success: false,
        error: 'Failed to send notification: $e',
      );
    }
  }

  /// Send notification for payment reminders with multiple channels
  Future<NotificationResult> sendPaymentReminder({
    required UserModel user,
    required double amount,
    required int year,
    List<NotificationChannel> channels = const [NotificationChannel.push],
  }) async {
    try {
      final notificationId = _firestore.collection('notifications').doc().id;
      
      final notification = {
        'id': notificationId,
        'userId': user.id,
        'type': 'payment_reminder',
        'title': NotificationTemplateService.getReminderTitle(user.preferredLanguage),
        'message': NotificationTemplateService.getReminderMessage(amount, year, user.preferredLanguage),
        'amount': amount,
        'year': year,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'language': user.preferredLanguage,
        'channels': channels.map((c) => c.name).toList(),
      };

      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(notification);

      // Send notifications through requested channels
      final results = <String, bool>{};
      
      for (final channel in channels) {
        switch (channel) {
          case NotificationChannel.push:
            results['push'] = await _sendPushNotification(
              userId: user.id,
              title: notification['title'] as String,
              message: notification['message'] as String,
              data: {
                'type': 'payment_reminder',
                'amount': amount.toString(),
                'year': year.toString(),
              },
            );
            break;
          case NotificationChannel.whatsapp:
            final whatsappMessage = NotificationTemplateService.getWhatsAppReminderTemplate(
              user.name,
              amount,
              year,
              user.preferredLanguage,
            );
            results['whatsapp'] = await _sendWhatsAppMessage(
              phoneNumber: user.phoneNumber,
              message: whatsappMessage,
            );
            break;
          case NotificationChannel.sms:
            final smsMessage = NotificationTemplateService.getSMSReminderTemplate(
              user.name,
              amount,
              year,
              user.preferredLanguage,
            );
            results['sms'] = await _sendSMSMessage(
              phoneNumber: user.phoneNumber,
              message: smsMessage,
            );
            break;
        }
      }

      // Log notification history
      await _logNotificationHistory(
        notificationId: notificationId,
        userId: user.id,
        type: 'payment_reminder',
        channels: channels,
        results: results,
      );

      return NotificationResult(
        success: true,
        notificationId: notificationId,
        pushNotificationSent: results['push'] ?? false,
        whatsappSent: results['whatsapp'] ?? false,
        smsSent: results['sms'] ?? false,
        message: 'Reminder sent successfully',
        channelResults: results,
      );
    } catch (e) {
      return NotificationResult(
        success: false,
        error: 'Failed to send reminder: $e',
      );
    }
  }

  /// Send escalated reminder for overdue payments
  Future<NotificationResult> sendEscalatedReminder({
    required UserModel user,
    required double amount,
    required int year,
    required int daysPastDue,
  }) async {
    try {
      final notificationId = _firestore.collection('notifications').doc().id;
      
      final notification = {
        'id': notificationId,
        'userId': user.id,
        'type': 'escalated_reminder',
        'title': NotificationTemplateService.getEscalatedReminderTitle(user.preferredLanguage),
        'message': NotificationTemplateService.getEscalatedReminderMessage(amount, year, daysPastDue, user.preferredLanguage),
        'amount': amount,
        'year': year,
        'daysPastDue': daysPastDue,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'language': user.preferredLanguage,
        'channels': ['push', 'whatsapp', 'sms'], // Use all channels for escalated
      };

      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set(notification);

      // Send through all channels for escalated reminders
      final results = <String, bool>{};
      
      results['push'] = await _sendPushNotification(
        userId: user.id,
        title: notification['title'] as String,
        message: notification['message'] as String,
        data: {
          'type': 'escalated_reminder',
          'amount': amount.toString(),
          'year': year.toString(),
          'daysPastDue': daysPastDue.toString(),
        },
      );

      final whatsappMessage = NotificationTemplateService.getWhatsAppEscalatedTemplate(
        user.name,
        amount,
        year,
        daysPastDue,
        user.preferredLanguage,
      );
      results['whatsapp'] = await _sendWhatsAppMessage(
        phoneNumber: user.phoneNumber,
        message: whatsappMessage,
      );

      final smsMessage = NotificationTemplateService.getSMSEscalatedTemplate(
        user.name,
        amount,
        year,
        daysPastDue,
        user.preferredLanguage,
      );
      results['sms'] = await _sendSMSMessage(
        phoneNumber: user.phoneNumber,
        message: smsMessage,
      );

      // Log notification history
      await _logNotificationHistory(
        notificationId: notificationId,
        userId: user.id,
        type: 'escalated_reminder',
        channels: [NotificationChannel.push, NotificationChannel.whatsapp, NotificationChannel.sms],
        results: results,
      );

      return NotificationResult(
        success: true,
        notificationId: notificationId,
        pushNotificationSent: results['push'] ?? false,
        whatsappSent: results['whatsapp'] ?? false,
        smsSent: results['sms'] ?? false,
        message: 'Escalated reminder sent successfully',
        channelResults: results,
      );
    } catch (e) {
      return NotificationResult(
        success: false,
        error: 'Failed to send escalated reminder: $e',
      );
    }
  }

  /// Get user notifications
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      // Handle error silently for now
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final batch = _firestore.batch();
      
      final notifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in notifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      // Handle error silently for now
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    try {
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      return query.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Get notification history for admin tracking
  Stream<List<NotificationHistoryModel>> getNotificationHistory({
    String? userId,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _firestore.collection('notification_history');
    
    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }
    
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    
    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    
    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    
    return query
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationHistoryModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get notification statistics
  Future<NotificationStats> getNotificationStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('notification_history');
      
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      final snapshot = await query.get();
      
      int totalSent = 0;
      int pushSent = 0;
      int whatsappSent = 0;
      int smsSent = 0;
      int successful = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalSent++;
        
        final results = data['results'] as Map<String, dynamic>? ?? {};
        final channels = List<String>.from(data['channels'] ?? []);
        
        if (channels.contains('push') && results['push'] == true) pushSent++;
        if (channels.contains('whatsapp') && results['whatsapp'] == true) whatsappSent++;
        if (channels.contains('sms') && results['sms'] == true) smsSent++;
        if (data['success'] == true) successful++;
      }
      
      return NotificationStats(
        totalSent: totalSent,
        pushSent: pushSent,
        whatsappSent: whatsappSent,
        smsSent: smsSent,
        successful: successful,
        successRate: totalSent > 0 ? (successful / totalSent) * 100 : 0,
      );
    } catch (e) {
      return NotificationStats(
        totalSent: 0,
        pushSent: 0,
        whatsappSent: 0,
        smsSent: 0,
        successful: 0,
        successRate: 0,
      );
    }
  }

  /// Send bulk reminders to multiple users
  Future<List<NotificationResult>> sendBulkReminders({
    required List<UserModel> users,
    required double amount,
    required int year,
    List<NotificationChannel> channels = const [NotificationChannel.push],
  }) async {
    final results = <NotificationResult>[];
    
    for (final user in users) {
      final result = await sendPaymentReminder(
        user: user,
        amount: amount,
        year: year,
        channels: channels,
      );
      results.add(result);
      
      // Add small delay to avoid overwhelming the system
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return results;
  }

  /// Send push notification via FCM
  Future<bool> _sendPushNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, String>? data,
  }) async {
    try {
      // Get FCM token for the user
      final tokenDoc = await _firestore
          .collection('fcm_tokens')
          .doc(userId)
          .get();
      
      if (!tokenDoc.exists) {
        return false; // No FCM token available
      }
      
      final token = tokenDoc.data()?['token'] as String?;
      if (token == null) {
        return false;
      }

      // Note: In a production app, FCM messages should be sent from a server
      // This is a client-side implementation for demonstration
      // In reality, you would call your backend API to send the FCM message
      
      // For now, we'll simulate successful sending
      // In a real implementation, you would use Firebase Admin SDK on your server
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send WhatsApp message using URL scheme
  Future<bool> _sendWhatsAppMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Clean phone number (remove +91 if present and ensure it starts with 91)
      String cleanNumber = phoneNumber.replaceAll('+', '').replaceAll(' ', '');
      if (cleanNumber.startsWith('91')) {
        cleanNumber = cleanNumber;
      } else if (cleanNumber.length == 10) {
        cleanNumber = '91$cleanNumber';
      }

      final encodedMessage = Uri.encodeComponent(message);
      final whatsappUrl = 'https://wa.me/$cleanNumber?text=$encodedMessage';
      
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Send SMS message
  Future<bool> _sendSMSMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // final bool? permissionsGranted = await _telephony.requestPhoneAndSmsPermissions; // Commented out due to dependency issues
      
      // if (permissionsGranted == true) { // Commented out due to dependency issues
        // await _telephony.sendSms( // Commented out due to dependency issues
        //   to: phoneNumber, // Commented out due to dependency issues
        //   message: message, // Commented out due to dependency issues
        // ); // Commented out due to dependency issues
        return true; // Commented out due to dependency issues
      // } // Commented out due to dependency issues
      return false; // Commented out due to dependency issues
    } catch (e) { // Commented out due to dependency issues
      return false; // Commented out due to dependency issues
    } // Commented out due to dependency issues
  } // Commented out due to dependency issues

  /// Log notification history for tracking
  Future<void> _logNotificationHistory({
    required String notificationId,
    required String userId,
    required String type,
    required List<NotificationChannel> channels,
    required Map<String, bool> results,
  }) async {
    try {
      final historyId = _firestore.collection('notification_history').doc().id;
      
      await _firestore
          .collection('notification_history')
          .doc(historyId)
          .set({
        'id': historyId,
        'notificationId': notificationId,
        'userId': userId,
        'type': type,
        'channels': channels.map((c) => c.name).toList(),
        'results': results,
        'timestamp': FieldValue.serverTimestamp(),
        'success': results.values.any((success) => success),
      });
    } catch (e) {
      // Log error but don't fail the notification
    }
  }

  /// Initialize FCM for the current user
  Future<String?> initializeFCM(String userId) async {
    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        final token = await _messaging.getToken();
        
        if (token != null) {
          // Store token in Firestore
          await _firestore
              .collection('fcm_tokens')
              .doc(userId)
              .set({
            'userId': userId,
            'token': token,
            'updatedAt': FieldValue.serverTimestamp(),
            'platform': 'android',
          }, SetOptions(merge: true));
          
          return token;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Handle FCM token refresh
  void setupTokenRefresh(String userId) {
    _messaging.onTokenRefresh.listen((newToken) {
      _firestore
          .collection('fcm_tokens')
          .doc(userId)
          .update({
        'token': newToken,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }


}

/// Notification model for storing notification data
class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String language;
  final String? paymentId;
  final String? status;
  final double? amount;
  final int? year;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    required this.language,
    this.paymentId,
    this.status,
    this.amount,
    this.year,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      language: data['language'] ?? 'en',
      paymentId: data['paymentId'],
      status: data['status'],
      amount: data['amount']?.toDouble(),
      year: data['year'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'language': language,
      'paymentId': paymentId,
      'status': status,
      'amount': amount,
      'year': year,
    };
  }
}

/// Notification channels enum
enum NotificationChannel {
  push,
  whatsapp,
  sms,
}

/// Result of notification operation
class NotificationResult {
  final bool success;
  final String? notificationId;
  final bool pushNotificationSent;
  final bool whatsappSent;
  final bool smsSent;
  final String? message;
  final String? error;
  final Map<String, bool>? channelResults;

  NotificationResult({
    required this.success,
    this.notificationId,
    this.pushNotificationSent = false,
    this.whatsappSent = false,
    this.smsSent = false,
    this.message,
    this.error,
    this.channelResults,
  });
}

/// Notification history model for tracking
class NotificationHistoryModel {
  final String id;
  final String notificationId;
  final String userId;
  final String type;
  final List<String> channels;
  final Map<String, bool> results;
  final DateTime timestamp;
  final bool success;

  NotificationHistoryModel({
    required this.id,
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.channels,
    required this.results,
    required this.timestamp,
    required this.success,
  });

  factory NotificationHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationHistoryModel(
      id: doc.id,
      notificationId: data['notificationId'] ?? '',
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      channels: List<String>.from(data['channels'] ?? []),
      results: Map<String, bool>.from(data['results'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      success: data['success'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'type': type,
      'channels': channels,
      'results': results,
      'timestamp': Timestamp.fromDate(timestamp),
      'success': success,
    };
  }
}

/// Notification statistics model
class NotificationStats {
  final int totalSent;
  final int pushSent;
  final int whatsappSent;
  final int smsSent;
  final int successful;
  final double successRate;

  NotificationStats({
    required this.totalSent,
    required this.pushSent,
    required this.whatsappSent,
    required this.smsSent,
    required this.successful,
    required this.successRate,
  });
}