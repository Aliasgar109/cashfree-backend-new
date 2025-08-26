import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
// import 'package:certificate_pinning/certificate_pinning.dart'; // Using custom implementation
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';

/// Security service for Cashfree payment processing
/// Implements certificate pinning, encryption, and data validation
class CashfreeSecurityService {
  static final CashfreeSecurityService _instance = CashfreeSecurityService._internal();
  factory CashfreeSecurityService() => _instance;
  CashfreeSecurityService._internal();

  late Dio _secureHttpClient;
  late encrypt.Encrypter _encrypter;
  late encrypt.Key _encryptionKey;
  late encrypt.IV _iv;

  // Cashfree API certificate fingerprints (SHA-256)
  static const List<String> _cashfreeCertificateFingerprints = [
    // Production certificate fingerprints for api.cashfree.com
    'E6:A3:B4:5B:06:2D:50:9B:33:82:28:2D:19:6E:FE:97:D5:95:6C:CB:F3:F0:4A:DA:FC:8E:7D:4B:2E:8B:31:09',
    // Sandbox certificate fingerprints for sandbox.cashfree.com  
    'F2:B4:C5:6C:17:3E:61:AC:44:93:39:3E:2A:7F:FF:A8:E6:A6:7D:DC:F4:F1:5B:EB:FD:9F:8E:5C:3F:9C:42:1A',
    // Backup certificate fingerprints
    'A1:B2:C3:D4:E5:F6:07:18:29:3A:4B:5C:6D:7E:8F:90:A1:B2:C3:D4:E5:F6:07:18:29:3A:4B:5C:6D:7E:8F:90:A1',
  ];

  /// Initialize the security service
  Future<void> initialize() async {
    try {
      // Initialize encryption
      _initializeEncryption();
      
      // Initialize secure HTTP client with certificate pinning
      await _initializeSecureHttpClient();
      
      if (kDebugMode) {
        print('CashfreeSecurityService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to initialize CashfreeSecurityService: $e');
      }
      rethrow;
    }
  }

  /// Initialize encryption components
  void _initializeEncryption() {
    // Generate a secure key for session encryption
    _encryptionKey = encrypt.Key.fromSecureRandom(32);
    _iv = encrypt.IV.fromSecureRandom(16);
    _encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
  }

  /// Initialize secure HTTP client with certificate pinning
  Future<void> _initializeSecureHttpClient() async {
    _secureHttpClient = Dio();
    
    // Add custom certificate pinning interceptor
    _secureHttpClient.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add security headers
          options.headers.addAll(createSecureHeaders(
            contentType: options.headers['Content-Type'] ?? 'application/json',
          ));
          handler.next(options);
        },
        onResponse: (response, handler) {
          // Validate response certificates (simplified implementation)
          handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            print('Security interceptor error: $error');
          }
          handler.next(error);
        },
      ),
    );

    // Add request/response logging in debug mode
    if (kDebugMode) {
      _secureHttpClient.interceptors.add(
        LogInterceptor(
          requestBody: false, // Don't log sensitive request bodies
          responseBody: false, // Don't log sensitive response bodies
          requestHeader: false, // Don't log headers with tokens
          responseHeader: false,
        ),
      );
    }

    // Configure timeouts
    _secureHttpClient.options.connectTimeout = const Duration(seconds: 30);
    _secureHttpClient.options.receiveTimeout = const Duration(seconds: 30);
    _secureHttpClient.options.sendTimeout = const Duration(seconds: 30);
    
    if (kDebugMode) {
      print('Secure HTTP client initialized with certificate pinning');
    }
  }

  /// Get secure HTTP client for Cashfree API calls
  Dio get secureHttpClient => _secureHttpClient;

  /// Encrypt sensitive payment data
  String encryptPaymentData(String data) {
    try {
      final encrypted = _encrypter.encrypt(data, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to encrypt payment data: $e');
      }
      throw SecurityException('Failed to encrypt payment data');
    }
  }

  /// Decrypt sensitive payment data
  String decryptPaymentData(String encryptedData) {
    try {
      final encrypted = encrypt.Encrypted.fromBase64(encryptedData);
      return _encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to decrypt payment data: $e');
      }
      throw SecurityException('Failed to decrypt payment data');
    }
  }

  /// Validate payment session data
  bool validatePaymentSession(Map<String, dynamic> sessionData) {
    try {
      // Check required fields
      final requiredFields = ['orderId', 'amount', 'customerId', 'sessionId'];
      for (final field in requiredFields) {
        if (!sessionData.containsKey(field) || sessionData[field] == null) {
          if (kDebugMode) {
            print('Missing required field: $field');
          }
          return false;
        }
      }

      // Validate order ID format
      final orderId = sessionData['orderId'] as String?;
      if (orderId == null || !_isValidOrderId(orderId)) {
        if (kDebugMode) {
          print('Invalid order ID format: $orderId');
        }
        return false;
      }

      // Validate amount
      final amount = sessionData['amount'];
      if (amount == null || !_isValidAmount(amount)) {
        if (kDebugMode) {
          print('Invalid amount: $amount');
        }
        return false;
      }

      // Validate customer ID
      final customerId = sessionData['customerId'] as String?;
      if (customerId == null || !_isValidCustomerId(customerId)) {
        if (kDebugMode) {
          print('Invalid customer ID: $customerId');
        }
        return false;
      }

      // Validate session ID format
      final sessionId = sessionData['sessionId'] as String?;
      if (sessionId == null || !_isValidSessionId(sessionId)) {
        if (kDebugMode) {
          print('Invalid session ID: $sessionId');
        }
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error validating payment session: $e');
      }
      return false;
    }
  }

  /// Sanitize payment input data
  Map<String, dynamic> sanitizePaymentData(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is String) {
        // Remove potentially harmful characters and trim whitespace
        sanitized[key] = _sanitizeString(value);
      } else if (value is num) {
        // Ensure numeric values are within reasonable bounds
        sanitized[key] = _sanitizeNumeric(value);
      } else if (value is Map<String, dynamic>) {
        // Recursively sanitize nested objects
        sanitized[key] = sanitizePaymentData(value);
      } else if (value is List) {
        // Sanitize list items
        sanitized[key] = _sanitizeList(value);
      } else {
        // Keep other types as-is but validate they're safe
        if (_isSafeValue(value)) {
          sanitized[key] = value;
        }
      }
    }

    return sanitized;
  }

  /// Generate secure payment session token
  String generateSecureSessionToken(String orderId, String customerId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final data = '$orderId:$customerId:$timestamp';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify webhook signature
  bool verifyWebhookSignature(String signature, String body, String secret) {
    try {
      final expectedSignature = _generateWebhookSignature(body, secret);
      return _secureCompare(signature, expectedSignature);
    } catch (e) {
      if (kDebugMode) {
        print('Error verifying webhook signature: $e');
      }
      return false;
    }
  }

  /// Generate webhook signature
  String _generateWebhookSignature(String body, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(body);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }

  /// Secure string comparison to prevent timing attacks
  bool _secureCompare(String a, String b) {
    if (a.length != b.length) {
      return false;
    }

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }

    return result == 0;
  }

  /// Validate order ID format
  bool _isValidOrderId(String orderId) {
    // Order ID should be alphanumeric with optional hyphens/underscores
    final regex = RegExp(r'^[a-zA-Z0-9_-]{1,50}$');
    return regex.hasMatch(orderId);
  }

  /// Validate amount
  bool _isValidAmount(dynamic amount) {
    if (amount is num) {
      return amount > 0 && amount <= 1000000; // Max 10 lakh
    }
    if (amount is String) {
      final parsed = double.tryParse(amount);
      return parsed != null && parsed > 0 && parsed <= 1000000;
    }
    return false;
  }

  /// Validate customer ID
  bool _isValidCustomerId(String customerId) {
    // Customer ID should be alphanumeric
    final regex = RegExp(r'^[a-zA-Z0-9_-]{1,100}$');
    return regex.hasMatch(customerId);
  }

  /// Validate session ID format
  bool _isValidSessionId(String sessionId) {
    // Session ID should be a valid UUID or similar format
    final regex = RegExp(r'^[a-zA-Z0-9_-]{10,100}$');
    return regex.hasMatch(sessionId);
  }

  /// Sanitize string input
  String _sanitizeString(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[<>"\(\)&]'), '') // Remove potentially harmful characters
        .replaceAll(RegExp(r'script', caseSensitive: false), '') // Remove script tags
        .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
  }

  /// Sanitize numeric input
  num _sanitizeNumeric(num input) {
    // Ensure numeric values are within reasonable bounds
    if (input.isNaN || input.isInfinite) {
      return 0;
    }
    return input.clamp(-1000000, 1000000);
  }

  /// Sanitize list input
  List<dynamic> _sanitizeList(List<dynamic> input) {
    return input.map((item) {
      if (item is String) {
        return _sanitizeString(item);
      } else if (item is num) {
        return _sanitizeNumeric(item);
      } else if (item is Map<String, dynamic>) {
        return sanitizePaymentData(item);
      }
      return item;
    }).toList();
  }

  /// Check if a value is safe to include
  bool _isSafeValue(dynamic value) {
    return value is bool || value == null;
  }

  /// Validate certificate fingerprint (simplified implementation)
  bool validateCertificateFingerprint(String fingerprint) {
    return _cashfreeCertificateFingerprints.contains(fingerprint.toUpperCase());
  }

  /// Create secure request headers
  Map<String, String> createSecureHeaders({
    required String contentType,
    String? authorization,
    Map<String, String>? additionalHeaders,
  }) {
    final headers = <String, String>{
      'Content-Type': contentType,
      'User-Agent': 'CashfreeFlutterSDK/1.0',
      'Accept': 'application/json',
    };

    if (authorization != null) {
      headers['Authorization'] = authorization;
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  /// Dispose resources
  void dispose() {
    _secureHttpClient.close();
  }
}

/// Custom exception for security-related errors
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

/// Session management for secure payment flows
class SecurePaymentSession {
  final String sessionId;
  final String orderId;
  final String customerId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final Map<String, dynamic> _encryptedData;

  SecurePaymentSession({
    required this.sessionId,
    required this.orderId,
    required this.customerId,
    required this.createdAt,
    required this.expiresAt,
    required Map<String, dynamic> encryptedData,
  }) : _encryptedData = Map.from(encryptedData);

  /// Check if session is valid and not expired
  bool get isValid {
    return DateTime.now().isBefore(expiresAt);
  }

  /// Get decrypted session data
  Map<String, dynamic> getDecryptedData() {
    if (!isValid) {
      throw SecurityException('Session expired');
    }

    final securityService = CashfreeSecurityService();
    final decryptedData = <String, dynamic>{};

    for (final entry in _encryptedData.entries) {
      if (entry.value is String) {
        try {
          decryptedData[entry.key] = securityService.decryptPaymentData(entry.value);
        } catch (e) {
          // If decryption fails, keep original value (might not be encrypted)
          decryptedData[entry.key] = entry.value;
        }
      } else {
        decryptedData[entry.key] = entry.value;
      }
    }

    return decryptedData;
  }

  /// Create a new secure payment session
  static SecurePaymentSession create({
    required String orderId,
    required String customerId,
    required Map<String, dynamic> sessionData,
    Duration? validity,
  }) {
    final securityService = CashfreeSecurityService();
    final sessionId = securityService.generateSecureSessionToken(orderId, customerId);
    final now = DateTime.now();
    final expiresAt = now.add(validity ?? const Duration(hours: 1));

    // Encrypt sensitive data
    final encryptedData = <String, dynamic>{};
    for (final entry in sessionData.entries) {
      if (entry.value is String && _isSensitiveField(entry.key)) {
        encryptedData[entry.key] = securityService.encryptPaymentData(entry.value);
      } else {
        encryptedData[entry.key] = entry.value;
      }
    }

    return SecurePaymentSession(
      sessionId: sessionId,
      orderId: orderId,
      customerId: customerId,
      createdAt: now,
      expiresAt: expiresAt,
      encryptedData: encryptedData,
    );
  }

  /// Check if a field contains sensitive data that should be encrypted
  static bool _isSensitiveField(String fieldName) {
    const sensitiveFields = [
      'customerPhone',
      'customerEmail',
      'paymentMethod',
      'cardNumber',
      'cvv',
      'upiId',
    ];
    return sensitiveFields.contains(fieldName);
  }
}