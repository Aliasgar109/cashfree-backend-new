import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import 'receipt_service.dart';

/// Service for handling WhatsApp integration and receipt sharing
class WhatsAppService {
  final ReceiptService _receiptService = ReceiptService();

  /// Error types for WhatsApp sharing
  static const String errorWhatsAppNotInstalled = 'WHATSAPP_NOT_INSTALLED';
  static const String errorSharingFailed = 'SHARING_FAILED';
  static const String errorReceiptNotFound = 'RECEIPT_NOT_FOUND';
  static const String errorNetworkError = 'NETWORK_ERROR';
  static const String errorPermissionDenied = 'PERMISSION_DENIED';

  /// Share receipt via WhatsApp with comprehensive error handling
  Future<WhatsAppShareResult> shareReceiptViaWhatsApp({
    required ReceiptModel receipt,
    required UserModel user,
    String? customMessage,
  }) async {
    try {
      // Check if WhatsApp is available
      if (!await isWhatsAppAvailable()) {
        return WhatsAppShareResult.failure(
          errorWhatsAppNotInstalled,
          'WhatsApp is not installed on this device',
        );
      }

      // Create localized message
      final message = customMessage ?? _createReceiptMessage(receipt, user);
      
      // Share receipt with message
      await _receiptService.shareReceipt(
        receipt.pdfUrl,
        receipt.receiptNumber,
        message: message,
      );

      return WhatsAppShareResult.success();
    } on SocketException {
      return WhatsAppShareResult.failure(
        errorNetworkError,
        'Network connection failed. Please check your internet connection.',
      );
    } catch (e) {
      return WhatsAppShareResult.failure(
        errorSharingFailed,
        'Failed to share receipt: ${e.toString()}',
      );
    }
  }

  /// Share receipt directly to a specific WhatsApp number
  Future<WhatsAppShareResult> shareReceiptToWhatsAppNumber({
    required ReceiptModel receipt,
    required UserModel user,
    required String phoneNumber,
    String? customMessage,
  }) async {
    try {
      // Check if WhatsApp is available
      if (!await isWhatsAppAvailable()) {
        return WhatsAppShareResult.failure(
          errorWhatsAppNotInstalled,
          'WhatsApp is not installed on this device',
        );
      }

      // Create localized message
      final message = customMessage ?? _createReceiptMessage(receipt, user);
      
      // Format phone number for WhatsApp
      final formattedPhone = _formatPhoneForWhatsApp(phoneNumber);
      
      // Create WhatsApp URL with message
      final whatsappUrl = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}';
      
      // Launch WhatsApp
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // After launching WhatsApp, also share the PDF file
        await _receiptService.shareReceipt(
          receipt.pdfUrl,
          receipt.receiptNumber,
          message: 'Receipt PDF attached',
        );

        return WhatsAppShareResult.success();
      } else {
        return WhatsAppShareResult.failure(
          errorWhatsAppNotInstalled,
          'WhatsApp is not installed or cannot be opened',
        );
      }
    } on SocketException {
      return WhatsAppShareResult.failure(
        errorNetworkError,
        'Network connection failed. Please check your internet connection.',
      );
    } catch (e) {
      return WhatsAppShareResult.failure(
        errorSharingFailed,
        'Failed to share receipt to WhatsApp: ${e.toString()}',
      );
    }
  }

  /// Create localized receipt message
  String _createReceiptMessage(ReceiptModel receipt, UserModel user) {
    if (user.preferredLanguage == 'gu') {
      return '''
🧾 ચુકવણી રસીદ

નામ: ${user.name}
રસીદ નંબર: ${receipt.receiptNumber}
રકમ: ₹${receipt.totalAmount.toStringAsFixed(2)}
વર્ષ: ${receipt.year}
તારીખ: ${_formatDateForMessage(receipt.generatedAt, 'gu')}

આભાર! તમારી ચુકવણી સફળતાપૂર્વક પ્રાપ્ત થઈ છે.

📎 રસીદ PDF જોડાયેલ છે.
      ''';
    } else {
      return '''
🧾 Payment Receipt

Name: ${user.name}
Receipt Number: ${receipt.receiptNumber}
Amount: ₹${receipt.totalAmount.toStringAsFixed(2)}
Year: ${receipt.year}
Date: ${_formatDateForMessage(receipt.generatedAt, 'en')}

Thank you! Your payment has been successfully received.

📎 Receipt PDF attached.
      ''';
    }
  }

  /// Create auto-share message after payment approval
  String _createAutoShareMessage(ReceiptModel receipt, UserModel user) {
    if (user.preferredLanguage == 'gu') {
      return '''
✅ ચુકવણી મંજૂર થઈ!

પ્રિય ${user.name},

તમારી ચુકવણી સફળતાપૂર્વક મંજૂર થઈ ગઈ છે.

રસીદ નંબર: ${receipt.receiptNumber}
રકમ: ₹${receipt.totalAmount.toStringAsFixed(2)}
વર્ષ: ${receipt.year}

આભાર!
📎 તમારી રસીદ જોડાયેલ છે.
      ''';
    } else {
      return '''
✅ Payment Approved!

Dear ${user.name},

Your payment has been successfully approved.

Receipt Number: ${receipt.receiptNumber}
Amount: ₹${receipt.totalAmount.toStringAsFixed(2)}
Year: ${receipt.year}

Thank you!
📎 Your receipt is attached.
      ''';
    }
  }

  /// Format phone number for WhatsApp (remove special characters and add country code)
  String _formatPhoneForWhatsApp(String phoneNumber) {
    // Remove all non-digit characters
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add country code if not present
    if (cleanPhone.startsWith('91') && cleanPhone.length == 12) {
      return cleanPhone;
    } else if (cleanPhone.length == 10) {
      return '91$cleanPhone';
    } else if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      return '91${cleanPhone.substring(1)}';
    }
    
    return cleanPhone;
  }

  /// Format date for message
  String _formatDateForMessage(DateTime date, String locale) {
    if (locale == 'gu') {
      return '${date.day}/${date.month}/${date.year}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Automatically share receipt after payment approval
  Future<WhatsAppShareResult> autoShareReceiptAfterApproval({
    required ReceiptModel receipt,
    required UserModel user,
  }) async {
    try {
      // Check if auto-sharing is enabled (could be a user preference)
      // For now, we'll always attempt auto-sharing
      
      final result = await shareReceiptViaWhatsApp(
        receipt: receipt,
        user: user,
        customMessage: _createAutoShareMessage(receipt, user),
      );

      return result;
    } catch (e) {
      return WhatsAppShareResult.failure(
        errorSharingFailed,
        'Auto-share failed: ${e.toString()}',
      );
    }
  }

  /// Download receipt to device for manual sharing
  Future<WhatsAppShareResult> downloadReceiptForManualSharing({
    required ReceiptModel receipt,
    required UserModel user,
  }) async {
    try {
      // Download receipt to device
      final filePath = await _receiptService.downloadReceiptToDevice(
        receipt.pdfUrl,
        receipt.receiptNumber,
      );

      // Create share message
      final message = _createReceiptMessage(receipt, user);

      // Share the downloaded file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: message,
        subject: 'Payment Receipt - ${receipt.receiptNumber}',
      );

      return WhatsAppShareResult.success();
    } on SocketException {
      return WhatsAppShareResult.failure(
        errorNetworkError,
        'Network connection failed. Please check your internet connection.',
      );
    } catch (e) {
      return WhatsAppShareResult.failure(
        errorSharingFailed,
        'Failed to download and share receipt: ${e.toString()}',
      );
    }
  }

  /// Send payment reminder via WhatsApp
  Future<WhatsAppShareResult> sendPaymentReminder({
    required UserModel user,
    required double dueAmount,
    required int year,
  }) async {
    try {
      // Check if WhatsApp is available
      if (!await isWhatsAppAvailable()) {
        return WhatsAppShareResult.failure(
          errorWhatsAppNotInstalled,
          'WhatsApp is not installed on this device',
        );
      }

      final message = _createReminderMessage(user, dueAmount, year);
      final formattedPhone = _formatPhoneForWhatsApp(user.phoneNumber);
      
      final whatsappUrl = 'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}';
      
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return WhatsAppShareResult.success();
      } else {
        return WhatsAppShareResult.failure(
          errorWhatsAppNotInstalled,
          'WhatsApp is not installed or cannot be opened',
        );
      }
    } on SocketException {
      return WhatsAppShareResult.failure(
        errorNetworkError,
        'Network connection failed. Please check your internet connection.',
      );
    } catch (e) {
      return WhatsAppShareResult.failure(
        errorSharingFailed,
        'Failed to send payment reminder: ${e.toString()}',
      );
    }
  }

  /// Create localized payment reminder message
  String _createReminderMessage(UserModel user, double dueAmount, int year) {
    if (user.preferredLanguage == 'gu') {
      return '''
📺 ટીવી સબ્સ્ક્રિપ્શન રિમાઇન્ડર

પ્રિય ${user.name},

તમારી ${year} વર્ષની ટીવી સબ્સ્ક્રિપ્શન ફી બાકી છે.

બાકી રકમ: ₹${dueAmount.toStringAsFixed(2)}

કૃપા કરીને તમારી સુવિધા મુજબ ચુકવણી કરો.

આભાર!
ટીવી સબ્સ્ક્રિપ્શન સેવા
      ''';
    } else {
      return '''
📺 TV Subscription Reminder

Dear ${user.name},

Your TV subscription fee for year ${year} is pending.

Due Amount: ₹${dueAmount.toStringAsFixed(2)}

Please make the payment at your convenience.

Thank you!
TV Subscription Service
      ''';
    }
  }

  /// Check if WhatsApp is available
  Future<bool> isWhatsAppAvailable() async {
    try {
      // Check for WhatsApp Business first, then regular WhatsApp
      final whatsappBusinessUri = Uri.parse('whatsapp://send');
      final whatsappUri = Uri.parse('https://wa.me/');
      
      // Try WhatsApp Business first
      if (await canLaunchUrl(whatsappBusinessUri)) {
        return true;
      }
      
      // Try regular WhatsApp
      return await canLaunchUrl(whatsappUri);
    } catch (e) {
      return false;
    }
  }

  /// Check WhatsApp installation status with detailed info
  Future<WhatsAppAvailability> checkWhatsAppAvailability() async {
    try {
      final whatsappBusinessUri = Uri.parse('whatsapp://send');
      final whatsappUri = Uri.parse('https://wa.me/');
      
      final hasWhatsAppBusiness = await canLaunchUrl(whatsappBusinessUri);
      final hasWhatsApp = await canLaunchUrl(whatsappUri);
      
      if (hasWhatsAppBusiness) {
        return WhatsAppAvailability.business();
      } else if (hasWhatsApp) {
        return WhatsAppAvailability.regular();
      } else {
        return WhatsAppAvailability.notInstalled();
      }
    } catch (e) {
      return WhatsAppAvailability.error(e.toString());
    }
  }

  /// Share multiple receipts
  Future<WhatsAppShareResult> shareMultipleReceipts({
    required List<ReceiptModel> receipts,
    required UserModel user,
    String? customMessage,
  }) async {
    try {
      if (receipts.isEmpty) {
        return WhatsAppShareResult.failure(
          errorReceiptNotFound,
          'No receipts to share',
        );
      }

      // Create message for multiple receipts
      final message = customMessage ?? _createMultipleReceiptsMessage(receipts, user);
      
      // Download all receipts and prepare for sharing
      final List<XFile> files = [];
      
      for (final receipt in receipts) {
        try {
          final filePath = await _receiptService.downloadReceiptToDevice(
            receipt.pdfUrl,
            receipt.receiptNumber,
          );
          files.add(XFile(filePath));
        } catch (e) {
          // Continue with other receipts if one fails
          continue;
        }
      }
      
      if (files.isEmpty) {
        return WhatsAppShareResult.failure(
          errorSharingFailed,
          'Failed to download any receipts for sharing',
        );
      }
      
      // Share all files
      await Share.shareXFiles(
        files,
        text: message,
        subject: 'Payment Receipts',
      );

      return WhatsAppShareResult.success();
    } on SocketException {
      return WhatsAppShareResult.failure(
        errorNetworkError,
        'Network connection failed. Please check your internet connection.',
      );
    } catch (e) {
      return WhatsAppShareResult.failure(
        errorSharingFailed,
        'Failed to share multiple receipts: ${e.toString()}',
      );
    }
  }

  /// Create message for multiple receipts
  String _createMultipleReceiptsMessage(List<ReceiptModel> receipts, UserModel user) {
    if (user.preferredLanguage == 'gu') {
      return '''
🧾 ચુકવણી રસીદો

નામ: ${user.name}
કુલ રસીદો: ${receipts.length}

રસીદ નંબરો:
${receipts.map((r) => '• ${r.receiptNumber} (₹${r.totalAmount.toStringAsFixed(2)})').join('\n')}

આભાર!
      ''';
    } else {
      return '''
🧾 Payment Receipts

Name: ${user.name}
Total Receipts: ${receipts.length}

Receipt Numbers:
${receipts.map((r) => '• ${r.receiptNumber} (₹${r.totalAmount.toStringAsFixed(2)})').join('\n')}

Thank you!
      ''';
    }
  }
}

/// Result class for WhatsApp sharing operations
class WhatsAppShareResult {
  final bool isSuccess;
  final String? errorCode;
  final String? errorMessage;

  const WhatsAppShareResult._({
    required this.isSuccess,
    this.errorCode,
    this.errorMessage,
  });

  /// Create a successful result
  factory WhatsAppShareResult.success() {
    return const WhatsAppShareResult._(isSuccess: true);
  }

  /// Create a failure result
  factory WhatsAppShareResult.failure(String errorCode, String errorMessage) {
    return WhatsAppShareResult._(
      isSuccess: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  /// Get user-friendly error message
  String get userFriendlyMessage {
    if (isSuccess) return 'Shared successfully';
    
    switch (errorCode) {
      case WhatsAppService.errorWhatsAppNotInstalled:
        return 'WhatsApp is not installed on this device. Please install WhatsApp to share receipts.';
      case WhatsAppService.errorNetworkError:
        return 'Network connection failed. Please check your internet connection and try again.';
      case WhatsAppService.errorReceiptNotFound:
        return 'Receipt not found or could not be accessed.';
      case WhatsAppService.errorPermissionDenied:
        return 'Permission denied. Please allow file access to share receipts.';
      case WhatsAppService.errorSharingFailed:
      default:
        return errorMessage ?? 'Failed to share receipt. Please try again.';
    }
  }
}

/// WhatsApp availability status
class WhatsAppAvailability {
  final WhatsAppType type;
  final bool isAvailable;
  final String? errorMessage;

  const WhatsAppAvailability._({
    required this.type,
    required this.isAvailable,
    this.errorMessage,
  });

  /// WhatsApp Business is available
  factory WhatsAppAvailability.business() {
    return const WhatsAppAvailability._(
      type: WhatsAppType.business,
      isAvailable: true,
    );
  }

  /// Regular WhatsApp is available
  factory WhatsAppAvailability.regular() {
    return const WhatsAppAvailability._(
      type: WhatsAppType.regular,
      isAvailable: true,
    );
  }

  /// WhatsApp is not installed
  factory WhatsAppAvailability.notInstalled() {
    return const WhatsAppAvailability._(
      type: WhatsAppType.none,
      isAvailable: false,
    );
  }

  /// Error checking WhatsApp availability
  factory WhatsAppAvailability.error(String errorMessage) {
    return WhatsAppAvailability._(
      type: WhatsAppType.none,
      isAvailable: false,
      errorMessage: errorMessage,
    );
  }

  /// Get display name for WhatsApp type
  String get displayName {
    switch (type) {
      case WhatsAppType.business:
        return 'WhatsApp Business';
      case WhatsAppType.regular:
        return 'WhatsApp';
      case WhatsAppType.none:
        return 'Not Available';
    }
  }
}

/// Types of WhatsApp installations
enum WhatsAppType {
  business,
  regular,
  none,
}