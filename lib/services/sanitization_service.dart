import '../utils/input_validator.dart';

/// Service for sanitizing and validating user inputs across the application
class SanitizationService {
  // Private constructor to prevent instantiation
  SanitizationService._();

  /// Sanitizes user model data before saving to database
  static Map<String, dynamic> sanitizeUserData(Map<String, dynamic> userData) {
    Map<String, dynamic> sanitized = {};

    // Sanitize name
    if (userData['name'] != null) {
      sanitized['name'] = InputValidator.sanitizeTextForStorage(userData['name'].toString());
    }

    // Sanitize phone number
    if (userData['phoneNumber'] != null) {
      String phone = userData['phoneNumber'].toString().replaceAll(RegExp(r'[^\d+]'), '');
      sanitized['phoneNumber'] = phone;
    }

    // Sanitize address
    if (userData['address'] != null) {
      sanitized['address'] = InputValidator.sanitizeTextForStorage(userData['address'].toString());
    }

    // Sanitize area
    if (userData['area'] != null) {
      sanitized['area'] = InputValidator.sanitizeTextForStorage(userData['area'].toString());
    }

    // Copy other safe fields
    for (String field in ['role', 'preferredLanguage', 'walletBalance', 'createdAt', 'lastPaymentDate', 'isActive']) {
      if (userData[field] != null) {
        sanitized[field] = userData[field];
      }
    }

    return sanitized;
  }

  /// Sanitizes payment data before saving to database
  static Map<String, dynamic> sanitizePaymentData(Map<String, dynamic> paymentData) {
    Map<String, dynamic> sanitized = {};

    // Sanitize transaction ID
    if (paymentData['transactionId'] != null) {
      sanitized['transactionId'] = InputValidator.sanitizeTextForStorage(paymentData['transactionId'].toString());
    }

    // Validate and sanitize amounts
    if (paymentData['amount'] != null) {
      sanitized['amount'] = _sanitizeAmount(paymentData['amount']);
    }

    if (paymentData['extraCharges'] != null) {
      sanitized['extraCharges'] = _sanitizeAmount(paymentData['extraCharges']);
    }

    // Copy other safe fields
    for (String field in ['userId', 'method', 'status', 'screenshotUrl', 'createdAt', 'approvedAt', 'approvedBy', 'receiptNumber', 'year']) {
      if (paymentData[field] != null) {
        sanitized[field] = paymentData[field];
      }
    }

    return sanitized;
  }

  /// Sanitizes search query input
  static String sanitizeSearchQuery(String query) {
    if (query.isEmpty) return query;

    String sanitized = query;

    // Remove script tags but keep content (less strict for search)
    sanitized = sanitized.replaceAll(RegExp(r'</?script[^>]*>', caseSensitive: false), '');
    
    // Remove other dangerous characters
    sanitized = sanitized.replaceAll('<', '');
    sanitized = sanitized.replaceAll('>', '');
    sanitized = sanitized.replaceAll('"', '');
    sanitized = sanitized.replaceAll("'", '');
    sanitized = sanitized.replaceAll('&', '');
    sanitized = sanitized.replaceAll('\$', '');
    
    // Limit length
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }

    // Normalize whitespace
    sanitized = sanitized.trim().replaceAll(RegExp(r'\s+'), ' ');

    return sanitized;
  }

  /// Sanitizes filter parameters for database queries
  static Map<String, dynamic> sanitizeFilterParams(Map<String, dynamic> filters) {
    Map<String, dynamic> sanitized = {};

    filters.forEach((key, value) {
      if (value != null) {
        switch (key) {
          case 'area':
          case 'status':
          case 'method':
            sanitized[key] = InputValidator.sanitizeTextForStorage(value.toString());
            break;
          case 'startDate':
          case 'endDate':
            // DateTime objects are safe
            sanitized[key] = value;
            break;
          case 'minAmount':
          case 'maxAmount':
            sanitized[key] = _sanitizeAmount(value);
            break;
          default:
            // For unknown fields, apply general sanitization
            if (value is String) {
              sanitized[key] = InputValidator.sanitizeTextForStorage(value);
            } else {
              sanitized[key] = value;
            }
        }
      }
    });

    return sanitized;
  }

  /// Sanitizes report parameters
  static Map<String, dynamic> sanitizeReportParams(Map<String, dynamic> params) {
    Map<String, dynamic> sanitized = {};

    params.forEach((key, value) {
      if (value != null) {
        switch (key) {
          case 'reportType':
          case 'format':
          case 'area':
            sanitized[key] = InputValidator.sanitizeTextForStorage(value.toString());
            break;
          case 'startDate':
          case 'endDate':
            sanitized[key] = value; // DateTime objects are safe
            break;
          case 'includeUnpaid':
          case 'includeApproved':
          case 'includeRejected':
            sanitized[key] = value is bool ? value : false;
            break;
          default:
            if (value is String) {
              sanitized[key] = InputValidator.sanitizeTextForStorage(value);
            } else {
              sanitized[key] = value;
            }
        }
      }
    });

    return sanitized;
  }

  /// Sanitizes notification data
  static Map<String, dynamic> sanitizeNotificationData(Map<String, dynamic> notificationData) {
    Map<String, dynamic> sanitized = {};

    // Sanitize message content
    if (notificationData['title'] != null) {
      sanitized['title'] = InputValidator.sanitizeTextForStorage(notificationData['title'].toString());
    }

    if (notificationData['body'] != null) {
      sanitized['body'] = InputValidator.sanitizeTextForStorage(notificationData['body'].toString());
    }

    // Copy other safe fields
    for (String field in ['userId', 'type', 'createdAt', 'isRead', 'data']) {
      if (notificationData[field] != null) {
        sanitized[field] = notificationData[field];
      }
    }

    return sanitized;
  }

  /// Private helper to sanitize amount values
  static double _sanitizeAmount(dynamic amount) {
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) {
      // Sanitize the string first to remove non-numeric characters
      String sanitized = amount.replaceAll(RegExp(r'[^0-9\.]'), '');
      double? parsed = double.tryParse(sanitized);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  /// Validates file upload data
  static Map<String, String?> validateFileUpload(String fileName, int fileSizeBytes, List<int> fileBytes) {
    Map<String, String?> errors = {};

    // Validate file name
    String? nameError = InputValidator.validateFileName(fileName);
    if (nameError != null) {
      errors['fileName'] = nameError;
    }

    // Validate file extension for images
    List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'pdf'];
    String? extensionError = InputValidator.validateFileExtension(fileName, allowedExtensions);
    if (extensionError != null) {
      errors['extension'] = extensionError;
    }

    // Validate file size (5MB limit)
    String? sizeError = InputValidator.validateFileSize(fileSizeBytes, 5 * 1024 * 1024);
    if (sizeError != null) {
      errors['size'] = sizeError;
    }

    // Basic file content validation
    if (fileBytes.isEmpty) {
      errors['content'] = 'File is empty';
    }

    // Validate file header matches extension
    String extension = fileName.split('.').last.toLowerCase();
    if (!_validateFileHeaders(fileBytes, extension)) {
      errors['content'] = 'File content does not match extension';
    }

    // Check for potential malicious content (basic check)
    if (_containsMaliciousContent(fileBytes)) {
      errors['content'] = 'File contains potentially malicious content';
    }

    return errors;
  }

  /// Validates file headers to ensure file type matches extension
  static bool _validateFileHeaders(List<int> fileBytes, String extension) {
    if (fileBytes.isEmpty) return false;

    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        // JPEG files start with FF D8 FF
        return fileBytes.length >= 3 &&
               fileBytes[0] == 0xFF &&
               fileBytes[1] == 0xD8 &&
               fileBytes[2] == 0xFF;
      
      case 'png':
        // PNG files start with 89 50 4E 47 0D 0A 1A 0A
        return fileBytes.length >= 8 &&
               fileBytes[0] == 0x89 &&
               fileBytes[1] == 0x50 &&
               fileBytes[2] == 0x4E &&
               fileBytes[3] == 0x47 &&
               fileBytes[4] == 0x0D &&
               fileBytes[5] == 0x0A &&
               fileBytes[6] == 0x1A &&
               fileBytes[7] == 0x0A;
      
      case 'pdf':
        // PDF files start with %PDF
        return fileBytes.length >= 4 &&
               fileBytes[0] == 0x25 && // %
               fileBytes[1] == 0x50 && // P
               fileBytes[2] == 0x44 && // D
               fileBytes[3] == 0x46;   // F
      
      default:
        return false;
    }
  }

  /// Basic check for malicious file content
  static bool _containsMaliciousContent(List<int> fileBytes) {
    // Convert first 1024 bytes to string for analysis
    String header = String.fromCharCodes(fileBytes.take(1024));
    
    // Check for script tags or executable signatures
    List<String> maliciousPatterns = [
      '<script',
      'javascript:',
      'vbscript:',
      'onload=',
      'onerror=',
      'MZ', // PE executable header
      '\x7fELF', // ELF executable header
    ];

    for (String pattern in maliciousPatterns) {
      if (header.toLowerCase().contains(pattern.toLowerCase())) {
        return true;
      }
    }

    return false;
  }

  /// Sanitizes log data to prevent log injection
  static String sanitizeLogData(String logMessage) {
    if (logMessage.isEmpty) return logMessage;

    // Remove newlines and carriage returns to prevent log injection
    // Handle \r\n as a single unit first, then individual \r and \n
    String sanitized = logMessage.replaceAll('\r\n', ' ');
    sanitized = sanitized.replaceAll(RegExp(r'[\r\n]'), ' ');
    
    // Remove control characters (but not regular spaces)
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    
    // Limit length
    if (sanitized.length > 500) {
      sanitized = '${sanitized.substring(0, 500)}...';
    }

    return sanitized;
  }
}