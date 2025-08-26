/// Comprehensive error handling models for Cashfree payment integration
/// 
/// This file contains error types, exception classes, and user-friendly
/// error message handling for the Cashfree payment system.

/// Error categories for Cashfree payment processing
enum CashfreeErrorType {
  /// Network-related errors (connection, timeout, DNS)
  network,
  
  /// API-related errors (HTTP status codes, malformed responses)
  api,
  
  /// Payment-specific errors (declined, insufficient funds, gateway issues)
  payment,
  
  /// Validation errors (invalid input, missing required fields)
  validation,
  
  /// System errors (SDK initialization, configuration issues)
  system,
  
  /// Configuration errors (missing keys, invalid environment setup)
  configuration,
  
  /// Security errors (authentication, authorization, signature verification)
  security,
  
  /// SDK-specific errors (Cashfree SDK internal errors)
  sdk,
  
  /// Unknown or unhandled errors
  unknown,
}

/// Severity levels for error handling and user feedback
enum CashfreeErrorSeverity {
  /// Low severity - informational, user can continue
  low,
  
  /// Medium severity - warning, user should be aware
  medium,
  
  /// High severity - error, user action required
  high,
  
  /// Critical severity - system failure, immediate attention needed
  critical,
}

/// Retry strategy for different error types
enum CashfreeRetryStrategy {
  /// No retry should be attempted
  none,
  
  /// Immediate retry without delay
  immediate,
  
  /// Linear retry with fixed delay
  linear,
  
  /// Exponential backoff retry
  exponential,
  
  /// Custom retry logic required
  custom,
}

/// Comprehensive error model for Cashfree payment processing
class CashfreeError {
  /// Error code for programmatic handling
  final String code;
  
  /// Technical error message for developers
  final String message;
  
  /// User-friendly error message for display
  final String userMessage;
  
  /// Detailed error description
  final String? description;
  
  /// Error type category
  final CashfreeErrorType type;
  
  /// Error severity level
  final CashfreeErrorSeverity severity;
  
  /// Retry strategy for this error
  final CashfreeRetryStrategy retryStrategy;
  
  /// Additional error details and context
  final Map<String, dynamic>? details;
  
  /// Timestamp when error occurred
  final DateTime timestamp;
  
  /// Stack trace for debugging
  final StackTrace? stackTrace;
  
  /// HTTP status code if applicable
  final int? httpStatusCode;
  
  /// Original exception that caused this error
  final dynamic originalException;
  
  /// Whether this error can be retried
  final bool canRetry;
  
  /// Maximum number of retry attempts for this error
  final int maxRetries;
  
  /// Suggested actions for resolving the error
  final List<String> suggestedActions;

  CashfreeError({
    required this.code,
    required this.message,
    required this.userMessage,
    this.description,
    required this.type,
    CashfreeErrorSeverity? severity,
    CashfreeRetryStrategy? retryStrategy,
    this.details,
    DateTime? timestamp,
    this.stackTrace,
    this.httpStatusCode,
    this.originalException,
    bool? canRetry,
    int? maxRetries,
    List<String>? suggestedActions,
  }) : 
    severity = severity ?? _getDefaultSeverity(type),
    retryStrategy = retryStrategy ?? _getDefaultRetryStrategy(type),
    timestamp = timestamp ?? DateTime.now(),
    canRetry = canRetry ?? _getDefaultCanRetry(type, retryStrategy ?? _getDefaultRetryStrategy(type)),
    maxRetries = maxRetries ?? _getDefaultMaxRetries(type, retryStrategy ?? _getDefaultRetryStrategy(type)),
    suggestedActions = suggestedActions ?? _getDefaultSuggestedActions(type);

  /// Get default severity based on error type
  static CashfreeErrorSeverity _getDefaultSeverity(CashfreeErrorType type) {
    switch (type) {
      case CashfreeErrorType.network:
      case CashfreeErrorType.api:
      case CashfreeErrorType.validation:
      case CashfreeErrorType.unknown:
        return CashfreeErrorSeverity.medium;
      case CashfreeErrorType.payment:
      case CashfreeErrorType.system:
      case CashfreeErrorType.configuration:
      case CashfreeErrorType.security:
      case CashfreeErrorType.sdk:
        return CashfreeErrorSeverity.high;
    }
  }

  /// Get default retry strategy based on error type
  static CashfreeRetryStrategy _getDefaultRetryStrategy(CashfreeErrorType type) {
    switch (type) {
      case CashfreeErrorType.network:
        return CashfreeRetryStrategy.exponential;
      case CashfreeErrorType.api:
      case CashfreeErrorType.system:
      case CashfreeErrorType.sdk:
        return CashfreeRetryStrategy.linear;
      case CashfreeErrorType.payment:
      case CashfreeErrorType.validation:
      case CashfreeErrorType.configuration:
      case CashfreeErrorType.security:
      case CashfreeErrorType.unknown:
        return CashfreeRetryStrategy.none;
    }
  }

  /// Determine default retry capability based on error type and strategy
  static bool _getDefaultCanRetry(CashfreeErrorType type, CashfreeRetryStrategy strategy) {
    // If strategy is explicitly set to none, don't retry
    if (strategy == CashfreeRetryStrategy.none) return false;
    
    // If strategy is not none, check if error type supports retry
    switch (type) {
      case CashfreeErrorType.network:
      case CashfreeErrorType.api:
      case CashfreeErrorType.system:
      case CashfreeErrorType.sdk:
        return true;
      case CashfreeErrorType.payment:
      case CashfreeErrorType.validation:
      case CashfreeErrorType.configuration:
      case CashfreeErrorType.security:
      case CashfreeErrorType.unknown:
        return false;
    }
  }
  
  /// Determine default max retries based on error type and strategy
  static int _getDefaultMaxRetries(CashfreeErrorType type, CashfreeRetryStrategy strategy) {
    if (strategy == CashfreeRetryStrategy.none) return 0;
    
    switch (type) {
      case CashfreeErrorType.network:
        return 3;
      case CashfreeErrorType.api:
        return 2;
      case CashfreeErrorType.system:
        return 1;
      default:
        return 0;
    }
  }
  
  /// Get default suggested actions based on error type
  static List<String> _getDefaultSuggestedActions(CashfreeErrorType type) {
    switch (type) {
      case CashfreeErrorType.network:
        return [
          'Check your internet connection',
          'Try again in a few moments',
          'Switch to a different network if available'
        ];
      case CashfreeErrorType.api:
        return [
          'Try again in a few moments',
          'Contact support if the problem persists'
        ];
      case CashfreeErrorType.payment:
        return [
          'Check your payment details',
          'Ensure sufficient balance in your account',
          'Try a different payment method'
        ];
      case CashfreeErrorType.validation:
        return [
          'Check the entered information',
          'Ensure all required fields are filled',
          'Verify the format of entered data'
        ];
      case CashfreeErrorType.system:
      case CashfreeErrorType.configuration:
      case CashfreeErrorType.security:
      case CashfreeErrorType.sdk:
        return [
          'Try again later',
          'Contact support if the problem persists'
        ];
      case CashfreeErrorType.unknown:
        return [
          'Try again',
          'Contact support with error details'
        ];
    }
  }

  /// Create a copy of this error with updated fields
  CashfreeError copyWith({
    String? code,
    String? message,
    String? userMessage,
    String? description,
    CashfreeErrorType? type,
    CashfreeErrorSeverity? severity,
    CashfreeRetryStrategy? retryStrategy,
    Map<String, dynamic>? details,
    DateTime? timestamp,
    StackTrace? stackTrace,
    int? httpStatusCode,
    dynamic originalException,
    bool? canRetry,
    int? maxRetries,
    List<String>? suggestedActions,
  }) {
    return CashfreeError(
      code: code ?? this.code,
      message: message ?? this.message,
      userMessage: userMessage ?? this.userMessage,
      description: description ?? this.description,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      retryStrategy: retryStrategy ?? this.retryStrategy,
      details: details ?? this.details,
      timestamp: timestamp ?? this.timestamp,
      stackTrace: stackTrace ?? this.stackTrace,
      httpStatusCode: httpStatusCode ?? this.httpStatusCode,
      originalException: originalException ?? this.originalException,
      canRetry: canRetry ?? this.canRetry,
      maxRetries: maxRetries ?? this.maxRetries,
      suggestedActions: suggestedActions ?? this.suggestedActions,
    );
  }

  /// Convert error to JSON for logging and debugging
  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'userMessage': userMessage,
      'description': description,
      'type': type.name,
      'severity': severity.name,
      'retryStrategy': retryStrategy.name,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
      'httpStatusCode': httpStatusCode,
      'canRetry': canRetry,
      'maxRetries': maxRetries,
      'suggestedActions': suggestedActions,
    };
  }

  /// Create error from JSON
  factory CashfreeError.fromJson(Map<String, dynamic> json) {
    return CashfreeError(
      code: json['code'] ?? 'UNKNOWN_ERROR',
      message: json['message'] ?? 'Unknown error occurred',
      userMessage: json['userMessage'] ?? 'An error occurred. Please try again.',
      description: json['description'],
      type: CashfreeErrorType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CashfreeErrorType.unknown,
      ),
      severity: CashfreeErrorSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => CashfreeErrorSeverity.medium,
      ),
      retryStrategy: CashfreeRetryStrategy.values.firstWhere(
        (e) => e.name == json['retryStrategy'],
        orElse: () => CashfreeRetryStrategy.none,
      ),
      details: json['details'],
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      httpStatusCode: json['httpStatusCode'],
      canRetry: json['canRetry'] ?? false,
      maxRetries: json['maxRetries'] ?? 0,
      suggestedActions: List<String>.from(json['suggestedActions'] ?? []),
    );
  }

  @override
  String toString() {
    return 'CashfreeError{code: $code, type: ${type.name}, message: $message}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CashfreeError &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          message == other.message &&
          type == other.type &&
          timestamp == other.timestamp;

  @override
  int get hashCode =>
      code.hashCode ^
      message.hashCode ^
      type.hashCode ^
      timestamp.hashCode;
}

/// Custom exception class for Cashfree payment processing
class CashfreeServiceException implements Exception {
  /// The error details
  final CashfreeError error;

  CashfreeServiceException(this.error);

  /// Create exception with basic error information
  CashfreeServiceException.basic(
    String message,
    CashfreeErrorType type, {
    String? code,
    String? userMessage,
    Map<String, dynamic>? details,
    StackTrace? stackTrace,
    dynamic originalException,
  }) : error = CashfreeError(
          code: code ?? _generateErrorCode(type),
          message: message,
          userMessage: userMessage ?? _generateUserMessage(type, message),
          type: type,
          details: details,
          stackTrace: stackTrace,
          originalException: originalException,
        );

  /// Generate error code based on type
  static String _generateErrorCode(CashfreeErrorType type) {
    switch (type) {
      case CashfreeErrorType.network:
        return 'CF_NETWORK_ERROR';
      case CashfreeErrorType.api:
        return 'CF_API_ERROR';
      case CashfreeErrorType.payment:
        return 'CF_PAYMENT_ERROR';
      case CashfreeErrorType.validation:
        return 'CF_VALIDATION_ERROR';
      case CashfreeErrorType.system:
        return 'CF_SYSTEM_ERROR';
      case CashfreeErrorType.configuration:
        return 'CF_CONFIG_ERROR';
      case CashfreeErrorType.security:
        return 'CF_SECURITY_ERROR';
      case CashfreeErrorType.sdk:
        return 'CF_SDK_ERROR';
      case CashfreeErrorType.unknown:
        return 'CF_UNKNOWN_ERROR';
    }
  }

  /// Generate user-friendly message based on type
  static String _generateUserMessage(CashfreeErrorType type, String technicalMessage) {
    switch (type) {
      case CashfreeErrorType.network:
        return 'Network connection error. Please check your internet connection and try again.';
      case CashfreeErrorType.api:
        return 'Service temporarily unavailable. Please try again in a few moments.';
      case CashfreeErrorType.payment:
        return 'Payment could not be processed. Please check your payment details and try again.';
      case CashfreeErrorType.validation:
        return 'Please check the entered information and try again.';
      case CashfreeErrorType.system:
      case CashfreeErrorType.configuration:
      case CashfreeErrorType.security:
      case CashfreeErrorType.sdk:
        return 'A technical error occurred. Please try again later.';
      case CashfreeErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get the error code
  String get code => error.code;

  /// Get the technical message
  String get message => error.message;

  /// Get the user-friendly message
  String get userMessage => error.userMessage;

  /// Get the error type
  CashfreeErrorType get type => error.type;

  /// Get error details
  Map<String, dynamic>? get details => error.details;

  /// Check if error can be retried
  bool get canRetry => error.canRetry;

  /// Get maximum retry attempts
  int get maxRetries => error.maxRetries;

  /// Get suggested actions
  List<String> get suggestedActions => error.suggestedActions;

  @override
  String toString() => 'CashfreeServiceException: ${error.message}';
}

/// Result wrapper for operations that can fail with Cashfree errors
class CashfreeResult<T> {
  /// The success value if operation succeeded
  final T? data;
  
  /// The error if operation failed
  final CashfreeError? error;
  
  /// Whether the operation was successful
  final bool isSuccess;

  CashfreeResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  /// Create a successful result
  factory CashfreeResult.success(T data) {
    return CashfreeResult._(
      data: data,
      isSuccess: true,
    );
  }

  /// Create a failed result
  factory CashfreeResult.failure(CashfreeError error) {
    return CashfreeResult._(
      error: error,
      isSuccess: false,
    );
  }

  /// Create a failed result from exception
  factory CashfreeResult.fromException(CashfreeServiceException exception) {
    return CashfreeResult._(
      error: exception.error,
      isSuccess: false,
    );
  }

  /// Whether the operation failed
  bool get isFailure => !isSuccess;

  /// Get the data or throw if failed
  T get dataOrThrow {
    if (isSuccess && data != null) {
      return data!;
    }
    throw CashfreeServiceException(error ?? CashfreeError(
      code: 'NO_DATA',
      message: 'No data available',
      userMessage: 'No data available',
      type: CashfreeErrorType.system,
    ));
  }

  /// Get the data or return default value
  T? get dataOrNull => isSuccess ? data : null;

  /// Transform the data if successful
  CashfreeResult<U> map<U>(U Function(T data) transform) {
    if (isSuccess && data != null) {
      try {
        return CashfreeResult.success(transform(data!));
      } catch (e) {
        return CashfreeResult.failure(CashfreeError(
          code: 'TRANSFORM_ERROR',
          message: 'Error transforming data: $e',
          userMessage: 'An error occurred while processing data',
          type: CashfreeErrorType.system,
          originalException: e,
        ));
      }
    }
    return CashfreeResult.failure(error!);
  }

  /// Chain operations that return CashfreeResult
  CashfreeResult<U> flatMap<U>(CashfreeResult<U> Function(T data) transform) {
    if (isSuccess && data != null) {
      try {
        return transform(data!);
      } catch (e) {
        return CashfreeResult.failure(CashfreeError(
          code: 'CHAIN_ERROR',
          message: 'Error chaining operation: $e',
          userMessage: 'An error occurred while processing',
          type: CashfreeErrorType.system,
          originalException: e,
        ));
      }
    }
    return CashfreeResult.failure(error!);
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'CashfreeResult.success($data)';
    } else {
      return 'CashfreeResult.failure($error)';
    }
  }
}