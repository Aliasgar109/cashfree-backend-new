import '../models/payment_model.dart';

/// Service for managing bilingual notification templates
class NotificationTemplateService {
  /// Get notification title for payment status change
  static String getPaymentStatusTitle(PaymentStatus status, String language) {
    if (language == 'gu') {
      switch (status) {
        case PaymentStatus.APPROVED:
          return 'ચુકવણી મંજૂર થઈ';
        case PaymentStatus.REJECTED:
          return 'ચુકવણી નકારવામાં આવી';
        case PaymentStatus.PENDING:
          return 'ચુકવણી બાકી';
        case PaymentStatus.INCOMPLETE:
          return 'ચુકવણી અપૂર્ણ';
      }
    } else {
      switch (status) {
        case PaymentStatus.APPROVED:
          return 'Payment Approved';
        case PaymentStatus.REJECTED:
          return 'Payment Rejected';
        case PaymentStatus.PENDING:
          return 'Payment Pending';
        case PaymentStatus.INCOMPLETE:
          return 'Payment Incomplete';
      }
    }
  }

  /// Get notification message for payment status change
  static String getPaymentStatusMessage(
    PaymentStatus status,
    PaymentModel payment,
    String language,
    String? rejectionReason,
  ) {
    final amount = '₹${payment.totalAmount.toStringAsFixed(2)}';
    
    if (language == 'gu') {
      switch (status) {
        case PaymentStatus.APPROVED:
          return 'તમારી $amount ની ચુકવણી મંજૂર કરવામાં આવી છે. રસીદ WhatsApp દ્વારા મોકલવામાં આવી છે.';
        case PaymentStatus.REJECTED:
          final reason = rejectionReason != null ? ' કારણ: $rejectionReason' : '';
          return 'તમારી $amount ની ચુકવણી નકારવામાં આવી છે.$reason કૃપા કરીને ફરીથી પ્રયાસ કરો.';
        case PaymentStatus.PENDING:
          return 'તમારી $amount ની ચુકવણી સમીક્ષા હેઠળ છે.';
        case PaymentStatus.INCOMPLETE:
          return 'તમારી $amount ની ચુકવણી પૂર્ણ થઈ નથી. કૃપા કરીને ફરીથી પ્રયાસ કરો.';
      }
    } else {
      switch (status) {
        case PaymentStatus.APPROVED:
          return 'Your payment of $amount has been approved. Receipt has been sent via WhatsApp.';
        case PaymentStatus.REJECTED:
          final reason = rejectionReason != null ? ' Reason: $rejectionReason' : '';
          return 'Your payment of $amount has been rejected.$reason Please try again.';
        case PaymentStatus.PENDING:
          return 'Your payment of $amount is under review.';
        case PaymentStatus.INCOMPLETE:
          return 'Your payment of $amount was not completed. Please try again.';
      }
    }
  }

  /// Get reminder notification title
  static String getReminderTitle(String language) {
    return language == 'gu' 
        ? 'ચુકવણી રિમાઇન્ડર'
        : 'Payment Reminder';
  }

  /// Get reminder notification message
  static String getReminderMessage(double amount, int year, String language) {
    final amountStr = '₹${amount.toStringAsFixed(2)}';
    
    return language == 'gu'
        ? 'તમારી $year ની $amountStr ની સબ્સ્ક્રિપ્શન ફી બાકી છે. કૃપા કરીને તેને ચૂકવો.'
        : 'Your subscription fee of $amountStr for $year is due. Please make the payment.';
  }

  /// Get escalated reminder title
  static String getEscalatedReminderTitle(String language) {
    return language == 'gu' 
        ? 'તાત્કાલિક ચુકવણી આવશ્યક'
        : 'Urgent Payment Required';
  }

  /// Get escalated reminder message
  static String getEscalatedReminderMessage(
    double amount, 
    int year, 
    int daysPastDue, 
    String language
  ) {
    final amountStr = '₹${amount.toStringAsFixed(2)}';
    
    return language == 'gu'
        ? 'તમારી $year ની $amountStr ની સબ્સ્ક્રિપ્શન ફી $daysPastDue દિવસથી બાકી છે. કૃપા કરીને તાત્કાલિક ચૂકવણી કરો અથવા સેવા બંધ થઈ શકે છે.'
        : 'Your subscription fee of $amountStr for $year is $daysPastDue days overdue. Please make immediate payment or service may be discontinued.';
  }

  /// Get WhatsApp message template for payment reminder
  static String getWhatsAppReminderTemplate(
    String userName,
    double amount,
    int year,
    String language,
  ) {
    final amountStr = '₹${amount.toStringAsFixed(2)}';
    
    if (language == 'gu') {
      return '''
નમસ્તે $userName,

તમારી $year ની TV સબ્સ્ક્રિપ્શન ફી $amountStr બાકી છે.

કૃપા કરીને આ મહિનામાં ચુકવણી કરો:
• ઓનલાઇન UPI દ્વારા
• અમારા કલેક્ટર પાસે રોકડ

કોઈ પ્રશ્ન હોય તો સંપર્ક કરો.

આભાર,
TV સબ્સ્ક્રિપ્શન ટીમ
''';
    } else {
      return '''
Hello $userName,

Your TV subscription fee of $amountStr for $year is due.

Please make payment this month:
• Online via UPI
• Cash with our collector

Contact us for any questions.

Thank you,
TV Subscription Team
''';
    }
  }

  /// Get SMS message template for payment reminder
  static String getSMSReminderTemplate(
    String userName,
    double amount,
    int year,
    String language,
  ) {
    final amountStr = '₹${amount.toStringAsFixed(2)}';
    
    if (language == 'gu') {
      return 'નમસ્તે $userName, તમારી $year ની TV ફી $amountStr બાકી છે. કૃપા કરીને ચૂકવો. આભાર, TV ટીમ';
    } else {
      return 'Hello $userName, your TV subscription fee of $amountStr for $year is due. Please make payment. Thank you, TV Team';
    }
  }

  /// Get escalated WhatsApp message template
  static String getWhatsAppEscalatedTemplate(
    String userName,
    double amount,
    int year,
    int daysPastDue,
    String language,
  ) {
    final amountStr = '₹${amount.toStringAsFixed(2)}';
    
    if (language == 'gu') {
      return '''
⚠️ તાત્કાલિક સૂચના ⚠️

$userName,

તમારી $year ની TV સબ્સ્ક્રિપ્શન ફી $amountStr હવે $daysPastDue દિવસથી બાકી છે.

તાત્કાલિક ચુકવણી કરો અથવા સેવા બંધ થઈ શકે છે.

આજે જ ચૂકવો:
• ઓનલાઇન UPI દ્વારા
• અમારા કલેક્ટર પાસે રોકડ

TV સબ્સ્ક્રિપ્શન ટીમ
''';
    } else {
      return '''
⚠️ URGENT NOTICE ⚠️

$userName,

Your TV subscription fee of $amountStr for $year is now $daysPastDue days overdue.

Make immediate payment or service may be discontinued.

Pay today:
• Online via UPI
• Cash with our collector

TV Subscription Team
''';
    }
  }

  /// Get escalated SMS message template
  static String getSMSEscalatedTemplate(
    String userName,
    double amount,
    int year,
    int daysPastDue,
    String language,
  ) {
    final amountStr = '₹${amount.toStringAsFixed(2)}';
    
    if (language == 'gu') {
      return 'તાત્કાલિક: $userName, તમારી $year ની TV ફી $amountStr હવે $daysPastDue દિવસથી બાકી છે. તાત્કાલિક ચૂકવો. TV ટીમ';
    } else {
      return 'URGENT: $userName, your TV fee of $amountStr for $year is $daysPastDue days overdue. Pay immediately. TV Team';
    }
  }
}