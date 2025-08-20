import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_constants.dart';

/// Production-ready UPI Intent Service with standards-compliant implementation
class UPIIntentService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // UPI Configuration Constants
  static const String _merchantCategoryCode = '5712'; // Furniture store MCC
  static const String _currency = 'INR';
  static const int _maxTransactionRefLength = 35;
  static const int _maxTransactionIdLength = 35;

  /// Launch UPI app with payment details for wallet recharge
  Future<UPIResult> launchUPIForRecharge({
    required double amount,
    required String userId,
    String? note,
  }) async {
    try {
      final transactionRef = _generateSafeTransactionRef('WALLET', userId);
      final transactionId = _generateSafeTransactionId('WALLET', userId);
      
      final upiUrl = _buildStandardsCompliantUPIUrl(
        amount: amount,
        note: note ?? 'Wallet Recharge',
        transactionRef: transactionRef,
        transactionId: transactionId,
      );

      return await _launchUPIIntent(upiUrl);
    } catch (e) {
      return UPIResult(success: false, error: 'Failed to launch UPI app: $e');
    }
  }

  /// Launch UPI app with payment details for subscription payment
  Future<UPIResult> launchUPIForPayment({
    required double amount,
    required String userId,
    required String paymentId,
    String? note,
  }) async {
    try {
      final transactionRef = _generateSafeTransactionRef('PAY', paymentId);
      final transactionId = _generateSafeTransactionId('PAY', paymentId);
      
      final upiUrl = _buildStandardsCompliantUPIUrl(
        amount: amount,
        note: note ?? 'TV Subscription Payment',
        transactionRef: transactionRef,
        transactionId: transactionId,
      );

      return await _launchUPIIntent(upiUrl);
    } catch (e) {
      return UPIResult(success: false, error: 'Failed to launch UPI app: $e');
    }
  }

  /// Build standards-compliant UPI URL with all mandatory parameters
  String _buildStandardsCompliantUPIUrl({
    required double amount,
    required String note,
    required String transactionRef,
    required String transactionId,
  }) {
    // Validate inputs
    if (amount <= 0) {
      throw ArgumentError('Amount must be greater than 0');
    }
    if (transactionRef.length > _maxTransactionRefLength) {
      throw ArgumentError('Transaction reference exceeds $_maxTransactionRefLength characters');
    }
    if (transactionId.length > _maxTransactionIdLength) {
      throw ArgumentError('Transaction ID exceeds $_maxTransactionIdLength characters');
    }

    // Build query parameters using Uri.queryParameters for proper encoding
    final queryParameters = <String, String>{
      'pa': AppConstants.tvChannelUpiId, // Payee VPA (mandatory)
      'pn': AppConstants.tvChannelName, // Payee name (mandatory)
      'mc': _merchantCategoryCode, // Merchant Category Code (mandatory)
      'tid': transactionId, // Transaction ID (mandatory)
      'tr': transactionRef, // Transaction reference (mandatory)
      'tn': note, // Transaction note (mandatory)
      'am': amount.toStringAsFixed(2), // Amount (mandatory)
      'cu': _currency, // Currency (mandatory)
    };

    // Build URI with proper encoding
    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: queryParameters,
    );

    return uri.toString();
  }

  /// Generate safe transaction reference (≤ 35 characters)
  String _generateSafeTransactionRef(String prefix, String id) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final baseRef = '${prefix}_${id}_$timestamp';
    
    // Truncate to fit within 35 character limit
    if (baseRef.length <= _maxTransactionRefLength) {
      return baseRef;
    }
    
    // Calculate how much we can keep from each part
    final remainingLength = _maxTransactionRefLength - prefix.length - 2; // 2 for underscores
    final idLength = (remainingLength * 0.4).round(); // 40% for ID
    final timestampLength = remainingLength - idLength;
    
    final truncatedId = id.length > idLength ? id.substring(0, idLength) : id;
    final truncatedTimestamp = timestamp.length > timestampLength 
        ? timestamp.substring(timestamp.length - timestampLength) 
        : timestamp;
    
    return '${prefix}_${truncatedId}_$truncatedTimestamp';
  }

  /// Generate safe transaction ID (≤ 35 characters)
  String _generateSafeTransactionId(String prefix, String id) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final baseId = '${prefix}${id}${timestamp}';
    
    // Truncate to fit within 35 character limit
    if (baseId.length <= _maxTransactionIdLength) {
      return baseId;
    }
    
    // Keep prefix and truncate the rest
    final remainingLength = _maxTransactionIdLength - prefix.length;
    final idLength = (remainingLength * 0.6).round(); // 60% for ID
    final timestampLength = remainingLength - idLength;
    
    final truncatedId = id.length > idLength ? id.substring(0, idLength) : id;
    final truncatedTimestamp = timestamp.length > timestampLength 
        ? timestamp.substring(timestamp.length - timestampLength) 
        : timestamp;
    
    return '$prefix${truncatedId}$truncatedTimestamp';
  }

  /// Launch UPI intent with proper fallback strategy
  Future<UPIResult> _launchUPIIntent(String upiUrl) async {
    try {
      if (Platform.isAndroid) {
        return await _launchAndroidUPIIntent(upiUrl);
      } else {
        return UPIResult(
          success: false,
          error: 'UPI payments are only supported on Android devices',
        );
      }
    } catch (e) {
      return UPIResult(
        success: false,
        error: 'Failed to launch UPI intent: $e',
      );
    }
  }

  /// Launch UPI intent on Android with proper fallback strategy
  Future<UPIResult> _launchAndroidUPIIntent(String upiUrl) async {
    try {
      final uri = Uri.parse(upiUrl);

      // Method 1: Try LaunchMode.externalApplication (shows app chooser)
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          return UPIResult(
            success: true,
            message: 'UPI app chooser opened. Please select your preferred UPI app and complete the payment.',
          );
        }
      } catch (launchError) {
        print('External application launch failed: $launchError');
      }

      // Method 2: Try LaunchMode.platformDefault
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );

        if (launched) {
          return UPIResult(
            success: true,
            message: 'UPI app launched successfully. Please complete the payment and return to the app.',
          );
        }
      } catch (fallbackError) {
        print('Platform default launch failed: $fallbackError');
      }

      // Method 3: Try intent:// fallback for better compatibility
      try {
        final intentUrl = 'intent://${uri.host}${uri.path}?${uri.query}#Intent;scheme=upi;action=android.intent.action.VIEW;package=;S.browser_fallback_url=${Uri.encodeComponent(upiUrl)};end';
        
        final launched = await launchUrl(
          Uri.parse(intentUrl),
          mode: LaunchMode.externalApplication,
        );

        if (launched) {
          return UPIResult(
            success: true,
            message: 'UPI app launched via intent. Please complete the payment and return to the app.',
          );
        }
      } catch (intentError) {
        print('Intent fallback launch failed: $intentError');
      }

      // If all methods fail, provide manual instructions
      final manualInstructions = _getManualPaymentInstructions(uri);
      
      return UPIResult(
        success: false,
        error: 'Unable to launch UPI app automatically.\n\n$manualInstructions',
      );
    } catch (e) {
      return UPIResult(success: false, error: 'Android UPI intent failed: $e');
    }
  }

  /// Get manual payment instructions with all necessary details
  String _getManualPaymentInstructions(Uri uri) {
    final amount = uri.queryParameters['am'] ?? '0';
    final note = uri.queryParameters['tn'] ?? 'TV Subscription Payment';
    final transactionRef = uri.queryParameters['tr'] ?? '';
    
    return '''
📱 Manual Payment Instructions:

1. Open your UPI app (Paytm/PhonePe/GPay/BHIM/Amazon Pay)
2. Tap on "Pay" or "Send Money"
3. Enter UPI ID: ${AppConstants.tvChannelUpiId}
4. Enter Amount: ₹$amount
5. Add Note: $note
6. Complete the payment

💡 Payment Details:
• UPI ID: ${AppConstants.tvChannelUpiId}
• Merchant: ${AppConstants.tvChannelName}
• Amount: ₹$amount
• Note: $note
• Reference: $transactionRef

⚠️ Important: After payment, please return to the app and upload a screenshot for verification.
''';
  }

  /// Upload payment screenshot to Firebase Storage
  Future<ScreenshotUploadResult> uploadPaymentScreenshot({
    required String paymentId,
    required String userId,
  }) async {
    try {
      // Pick image from gallery or camera
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) {
        return ScreenshotUploadResult(
          success: false,
          error: 'No image selected',
        );
      }

      // Validate image file
      final file = File(image.path);
      final fileSize = await file.length();

      // Check file size (max 5MB)
      if (fileSize > 5 * 1024 * 1024) {
        return ScreenshotUploadResult(
          success: false,
          error: 'Image size too large. Please select an image smaller than 5MB.',
        );
      }

      // Upload to Firebase Storage
      final fileName = 'payment_screenshots/${userId}/${paymentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return ScreenshotUploadResult(
        success: true,
        downloadUrl: downloadUrl,
        fileName: fileName,
      );
    } catch (e) {
      return ScreenshotUploadResult(
        success: false,
        error: 'Failed to upload screenshot: $e',
      );
    }
  }

  /// Take screenshot using camera
  Future<ScreenshotUploadResult> takePaymentScreenshot({
    required String paymentId,
    required String userId,
  }) async {
    try {
      // Pick image from camera
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) {
        return ScreenshotUploadResult(success: false, error: 'No photo taken');
      }

      // Validate and upload
      final file = File(image.path);
      final fileSize = await file.length();

      if (fileSize > 5 * 1024 * 1024) {
        return ScreenshotUploadResult(
          success: false,
          error: 'Photo size too large. Please try again.',
        );
      }

      // Upload to Firebase Storage
      final fileName = 'payment_screenshots/${userId}/${paymentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return ScreenshotUploadResult(
        success: true,
        downloadUrl: downloadUrl,
        fileName: fileName,
      );
    } catch (e) {
      return ScreenshotUploadResult(
        success: false,
        error: 'Failed to take screenshot: $e',
      );
    }
  }

  /// Update payment with screenshot and transaction ID
  Future<UPIPaymentUpdateResult> updatePaymentWithDetails({
    required String paymentId,
    String? transactionId,
    String? screenshotUrl,
  }) async {
    try {
      if (transactionId == null && screenshotUrl == null) {
        return UPIPaymentUpdateResult(
          success: false,
          error: 'Either transaction ID or screenshot is required',
        );
      }

      // Validate transaction ID if provided
      if (transactionId != null && !_isValidUPITransactionId(transactionId)) {
        return UPIPaymentUpdateResult(
          success: false,
          error: 'Invalid transaction ID format. Please enter a valid UPI transaction ID.',
        );
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'PENDING', // Always set to PENDING for UPI payments
      };

      if (transactionId != null) {
        updateData['transactionId'] = transactionId.trim();
      }

      if (screenshotUrl != null) {
        updateData['screenshotUrl'] = screenshotUrl;
      }

      await _firestore.collection('payments').doc(paymentId).update(updateData);

      return UPIPaymentUpdateResult(
        success: true,
        message: 'Payment details updated successfully. Your payment is now pending approval.',
      );
    } catch (e) {
      return UPIPaymentUpdateResult(
        success: false,
        error: 'Failed to update payment details: $e',
      );
    }
  }

  /// Track payment status changes
  Stream<PaymentStatus> trackPaymentStatus(String paymentId) {
    return _firestore.collection('payments').doc(paymentId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return PaymentStatus(status: 'NOT_FOUND', message: 'Payment not found');
      }

      final data = snapshot.data()!;
      final status = data['status'] as String? ?? 'UNKNOWN';
      final approvedAt = data['approvedAt'] as Timestamp?;
      final rejectedAt = data['rejectedAt'] as Timestamp?;
      final approvedBy = data['approvedBy'] as String?;
      final rejectionReason = data['rejectionReason'] as String?;

      String message;
      switch (status) {
        case 'PENDING':
          message = 'Payment is pending approval by admin';
          break;
        case 'APPROVED':
          message = 'Payment approved successfully';
          break;
        case 'REJECTED':
          message = rejectionReason ?? 'Payment was rejected';
          break;
        default:
          message = 'Payment status: $status';
      }

      return PaymentStatus(
        status: status,
        message: message,
        approvedAt: approvedAt?.toDate(),
        rejectedAt: rejectedAt?.toDate(),
        approvedBy: approvedBy,
        rejectionReason: rejectionReason,
      );
    });
  }

  /// Get list of available UPI apps
  Future<List<UPIApp>> getAvailableUPIApps() async {
    try {
      if (!Platform.isAndroid) {
        return [];
      }

      // List of common UPI apps with their package names
      final upiApps = [
        UPIApp(packageName: 'net.one97.paytm', appName: 'Paytm', iconUrl: ''),
        UPIApp(packageName: 'com.phonepe.app', appName: 'PhonePe', iconUrl: ''),
        UPIApp(
          packageName: 'com.google.android.apps.nbu.paisa.user',
          appName: 'Google Pay',
          iconUrl: '',
        ),
        UPIApp(packageName: 'in.org.npci.upiapp', appName: 'BHIM', iconUrl: ''),
        UPIApp(packageName: 'com.amazonpay', appName: 'Amazon Pay', iconUrl: ''),
        UPIApp(packageName: 'com.mobikwik_new', appName: 'MobiKwik', iconUrl: ''),
        UPIApp(packageName: 'com.freecharge.android', appName: 'FreeCharge', iconUrl: ''),
        UPIApp(packageName: 'com.airtel.money', appName: 'Airtel Money', iconUrl: ''),
      ];

      return upiApps;
    } catch (e) {
      return [];
    }
  }

  /// Validate UPI transaction ID format
  static bool _isValidUPITransactionId(String? transactionId) {
    if (transactionId == null || transactionId.trim().isEmpty) {
      return false;
    }

    final cleanId = transactionId.trim();
    if (cleanId.length < 8 || cleanId.length > 50) {
      return false;
    }

    // Check for valid characters (alphanumeric)
    final upiIdRegex = RegExp(r'^[A-Za-z0-9]+$');
    return upiIdRegex.hasMatch(cleanId);
  }

  /// Format amount for UPI display
  static String formatAmountForUPI(double amount) {
    return amount.toStringAsFixed(2);
  }

  /// Generate UPI QR code data for manual payment
  static String generateUPIQRData({
    required String upiId,
    required double amount,
    required String note,
    required String transactionRef,
  }) {
    final queryParameters = <String, String>{
      'pa': upiId,
      'pn': AppConstants.tvChannelName,
      'mc': '5712', // Merchant Category Code
      'tid': _generateSafeTransactionIdForQR('QR', transactionRef),
      'tr': transactionRef,
      'tn': note,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
    };

    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: queryParameters,
    );

    return uri.toString();
  }

  /// Generate safe transaction ID for QR codes
  static String _generateSafeTransactionIdForQR(String prefix, String id) {
    const maxLength = 35;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final baseId = '${prefix}${id}${timestamp}';
    
    if (baseId.length <= maxLength) {
      return baseId;
    }
    
    final remainingLength = maxLength - prefix.length;
    final idLength = (remainingLength * 0.6).round();
    final timestampLength = remainingLength - idLength;
    
    final truncatedId = id.length > idLength ? id.substring(0, idLength) : id;
    final truncatedTimestamp = timestamp.length > timestampLength 
        ? timestamp.substring(timestamp.length - timestampLength) 
        : timestamp;
    
    return '$prefix${truncatedId}$truncatedTimestamp';
  }
}

/// UPI Result class to handle UPI transaction results
class UPIResult {
  final bool success;
  final String? transactionId;
  final String? message;
  final String? error;

  UPIResult({
    required this.success,
    this.transactionId,
    this.message,
    this.error,
  });

  @override
  String toString() {
    return 'UPIResult{success: $success, transactionId: $transactionId, message: $message, error: $error}';
  }
}

/// UPI App information class
class UPIApp {
  final String packageName;
  final String appName;
  final String iconUrl;

  UPIApp({
    required this.packageName,
    required this.appName,
    required this.iconUrl,
  });

  @override
  String toString() {
    return 'UPIApp{packageName: $packageName, appName: $appName}';
  }
}

/// Screenshot upload result class
class ScreenshotUploadResult {
  final bool success;
  final String? downloadUrl;
  final String? fileName;
  final String? error;

  ScreenshotUploadResult({
    required this.success,
    this.downloadUrl,
    this.fileName,
    this.error,
  });

  @override
  String toString() {
    return 'ScreenshotUploadResult{success: $success, downloadUrl: $downloadUrl, error: $error}';
  }
}

/// UPI payment update result class
class UPIPaymentUpdateResult {
  final bool success;
  final String? message;
  final String? error;

  UPIPaymentUpdateResult({required this.success, this.message, this.error});

  @override
  String toString() {
    return 'UPIPaymentUpdateResult{success: $success, message: $message, error: $error}';
  }
}

/// Payment status tracking class
class PaymentStatus {
  final String status;
  final String message;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? approvedBy;
  final String? rejectionReason;

  PaymentStatus({
    required this.status,
    required this.message,
    this.approvedAt,
    this.rejectedAt,
    this.approvedBy,
    this.rejectionReason,
  });

  @override
  String toString() {
    return 'PaymentStatus{status: $status, message: $message}';
  }
}
