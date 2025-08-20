import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/localization_helper.dart';

/// Notification template generator with localization support
class NotificationTemplate {
  /// Generate payment reminder notification
  static Map<String, String> generatePaymentReminder({
    required UserModel user,
    required double amount,
    required String languageCode,
    required BuildContext context,
  }) {
    if (languageCode == 'gu') {
      return {
        'title': 'ચુકવણી રિમાઇન્ડર',
        'body': 'પ્રિય ${user.name}, તમારી વાર્ષિક ટીવી સબ્સ્ક્રિપ્શન ફી ${LocalizationHelper.formatCurrency(context, amount)} બાકી છે. કૃપા કરીને તાત્કાલિક ચૂકવણી કરો.',
      };
    } else {
      return {
        'title': 'Payment Reminder',
        'body': 'Dear ${user.name}, your yearly TV subscription fee of ${LocalizationHelper.formatCurrency(context, amount)} is due. Please make the payment at your earliest convenience.',
      };
    }
  }
  
  /// Generate payment approval notification
  static Map<String, String> generatePaymentApproval({
    required UserModel user,
    required PaymentModel payment,
    required String receiptNumber,
    required String languageCode,
    required BuildContext context,
  }) {
    if (languageCode == 'gu') {
      return {
        'title': 'ચુકવણી મંજૂર થઈ',
        'body': 'પ્રિય ${user.name}, તમારી ${LocalizationHelper.formatCurrency(context, payment.amount)} ની ચુકવણી મંજૂર થઈ ગઈ છે. રસીદ નં: $receiptNumber',
      };
    } else {
      return {
        'title': 'Payment Approved',
        'body': 'Dear ${user.name}, your payment of ${LocalizationHelper.formatCurrency(context, payment.amount)} has been approved. Receipt No: $receiptNumber',
      };
    }
  }
  
  /// Generate payment rejection notification
  static Map<String, String> generatePaymentRejection({
    required UserModel user,
    required PaymentModel payment,
    required String reason,
    required String languageCode,
    required BuildContext context,
  }) {
    if (languageCode == 'gu') {
      return {
        'title': 'ચુકવણી નકારવામાં આવી',
        'body': 'પ્રિય ${user.name}, તમારી ${LocalizationHelper.formatCurrency(context, payment.amount)} ની ચુકવણી નકારવામાં આવી છે. કારણ: $reason',
      };
    } else {
      return {
        'title': 'Payment Rejected',
        'body': 'Dear ${user.name}, your payment of ${LocalizationHelper.formatCurrency(context, payment.amount)} has been rejected. Reason: $reason',
      };
    }
  }
  
  /// Generate overdue payment notification
  static Map<String, String> generateOverdueNotification({
    required UserModel user,
    required double amount,
    required int daysPastDue,
    required String languageCode,
    required BuildContext context,
  }) {
    if (languageCode == 'gu') {
      return {
        'title': 'મુદત વીતી ગઈ - તાત્કાલિક ચુકવણી કરો',
        'body': 'પ્રિય ${user.name}, તમારી ${LocalizationHelper.formatCurrency(context, amount)} ની ચુકવણી $daysPastDue દિવસથી બાકી છે. મોડી ફી લાગુ થઈ શકે છે.',
      };
    } else {
      return {
        'title': 'Payment Overdue - Immediate Action Required',
        'body': 'Dear ${user.name}, your payment of ${LocalizationHelper.formatCurrency(context, amount)} is $daysPastDue days overdue. Late fees may apply.',
      };
    }
  }
  
  /// Generate welcome notification for new users
  static Map<String, String> generateWelcomeNotification({
    required UserModel user,
    required String languageCode,
    required BuildContext context,
  }) {
    if (languageCode == 'gu') {
      return {
        'title': 'સ્વાગત છે!',
        'body': 'પ્રિય ${user.name}, ટીવી સબ્સ્ક્રિપ્શન એપમાં તમારું સ્વાગત છે. હવે તમે સરળતાથી તમારી ચુકવણીઓ કરી શકો છો.',
      };
    } else {
      return {
        'title': 'Welcome!',
        'body': 'Dear ${user.name}, welcome to the TV Subscription app. You can now easily make your payments and manage your account.',
      };
    }
  }
  
  /// Generate receipt sharing message for WhatsApp
  static String generateReceiptSharingMessage({
    required UserModel user,
    required PaymentModel payment,
    required String receiptNumber,
    required String languageCode,
    required BuildContext context,
  }) {
    if (languageCode == 'gu') {
      return '''
🧾 *ટીવી સબ્સ્ક્રિપ્શન ચુકવણી રસીદ*

📋 રસીદ નં: $receiptNumber
👤 નામ: ${user.name}
💰 રકમ: ${LocalizationHelper.formatCurrency(context, payment.amount)}
📅 તારીખ: ${LocalizationHelper.formatDate(context, payment.createdAt)}
✅ સ્થિતિ: ${LocalizationHelper.getPaymentStatusText(context, payment.status.toString())}

આભાર! 🙏
      ''';
    } else {
      return '''
🧾 *TV Subscription Payment Receipt*

📋 Receipt No: $receiptNumber
👤 Name: ${user.name}
💰 Amount: ${LocalizationHelper.formatCurrency(context, payment.amount)}
📅 Date: ${LocalizationHelper.formatDate(context, payment.createdAt)}
✅ Status: ${LocalizationHelper.getPaymentStatusText(context, payment.status.toString())}

Thank you! 🙏
      ''';
    }
  }
  
  /// Generate SMS reminder message
  static String generateSMSReminder({
    required UserModel user,
    required double amount,
    required String languageCode,
    required BuildContext context,
  }) {
    if (languageCode == 'gu') {
      return 'પ્રિય ${user.name}, તમારી ટીવી સબ્સ્ક્રિપ્શન ફી ${LocalizationHelper.formatCurrency(context, amount)} બાકી છે. કૃપા કરીને એપ દ્વારા ચુકવણી કરો.';
    } else {
      return 'Dear ${user.name}, your TV subscription fee of ${LocalizationHelper.formatCurrency(context, amount)} is due. Please make payment through the app.';
    }
  }
  
  /// Generate collector notification for cash payment
  static Map<String, String> generateCashPaymentNotification({
    required UserModel user,
    required PaymentModel payment,
    required String collectorName,
    required String languageCode,
    required BuildContext context,
  }) {
    if (languageCode == 'gu') {
      return {
        'title': 'રોકડ ચુકવણી રેકોર્ડ થઈ',
        'body': '${user.name} દ્વારા ${LocalizationHelper.formatCurrency(context, payment.amount)} ની રોકડ ચુકવણી $collectorName દ્વારા રેકોર્ડ કરવામાં આવી છે.',
      };
    } else {
      return {
        'title': 'Cash Payment Recorded',
        'body': 'Cash payment of ${LocalizationHelper.formatCurrency(context, payment.amount)} by ${user.name} has been recorded by $collectorName.',
      };
    }
  }
}