/// Utility class for validating user input
class InputValidator {
  /// Validates username input
  static String? validateUsername(String? username) {
    if (username == null || username.trim().isEmpty) {
      return 'Username is required';
    }
    if (username.trim().length < 3) {
      return 'Username must be at least 3 characters long';
    }
    if (username.trim().length > 20) {
      return 'Username must be less than 20 characters';
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!usernameRegex.hasMatch(username.trim())) {
      return 'Username can only contain letters, numbers, underscores, and hyphens';
    }
    return null;
  }

  /// Validates password input
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  /// Validates name input
  static String? validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Name is required';
    }
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }
    return null;
  }

  /// Validates phone number input
  static String? validatePhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^[0-9]{10}$');
    if (!phoneRegex.hasMatch(phoneNumber.trim())) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  /// Validates address input
  static String? validateAddress(String? address) {
    if (address == null || address.trim().isEmpty) {
      return 'Address is required';
    }
    if (address.trim().length < 10) {
      return 'Address must be at least 10 characters long';
    }
    return null;
  }

  /// Validates area input
  static String? validateArea(String? area) {
    if (area == null || area.trim().isEmpty) {
      return 'Area is required';
    }
    if (area.trim().length < 2) {
      return 'Area must be at least 2 characters long';
    }
    return null;
  }

  /// Sanitizes text for database storage
  static String sanitizeTextForStorage(String input) {
    if (input.isEmpty) return input;

    String sanitized = input;

    // Remove script tags and their content first
    sanitized = sanitized.replaceAll(RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', caseSensitive: false), '');

    // Remove specific known HTML tags
    List<String> htmlTags = ['script', 'div', 'span', 'p', 'a', 'img', 'br', 'hr', 'b', 'i', 'u', 'strong', 'em', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'table', 'tr', 'td', 'th', 'form', 'input', 'button', 'select', 'option', 'textarea', 'iframe', 'object', 'embed'];
    
    for (String tag in htmlTags) {
      // Remove opening tags
      sanitized = sanitized.replaceAll(RegExp('<$tag[^>]*>', caseSensitive: false), '');
      // Remove closing tags
      sanitized = sanitized.replaceAll(RegExp('</$tag>', caseSensitive: false), '');
    }

    // Remove potentially dangerous characters
    sanitized = sanitized.replaceAll('<', '');
    sanitized = sanitized.replaceAll('>', '');
    sanitized = sanitized.replaceAll('"', '');
    sanitized = sanitized.replaceAll("'", '');
    sanitized = sanitized.replaceAll('&', '');

    // Only trim leading and trailing whitespace, preserve internal spacing
    sanitized = sanitized.trim();

    return sanitized;
  }

  /// Validates file name for uploads
  static String? validateFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) {
      return 'File name is required';
    }

    // Check length
    if (fileName.length > 100) {
      return 'File name too long';
    }

    // Check for dangerous characters
    if (RegExp(r'[<>:"/\\|?*]').hasMatch(fileName)) {
      return 'File name contains invalid characters';
    }

    // Check for reserved names (Windows)
    List<String> reservedNames = ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'];
    String nameWithoutExtension = fileName.split('.').first.toUpperCase();
    if (reservedNames.contains(nameWithoutExtension)) {
      return 'File name is reserved';
    }

    return null;
  }

  /// Validates file extension for uploads
  static String? validateFileExtension(String fileName, List<String> allowedExtensions) {
    String extension = fileName.split('.').last.toLowerCase();
    
    if (!allowedExtensions.contains(extension)) {
      return 'File type not allowed. Allowed types: ${allowedExtensions.join(', ')}';
    }

    return null;
  }

  /// Validates file size
  static String? validateFileSize(int fileSizeBytes, int maxSizeBytes) {
    if (fileSizeBytes > maxSizeBytes) {
      double maxSizeMB = maxSizeBytes / (1024 * 1024);
      return 'File size exceeds ${maxSizeMB.toStringAsFixed(1)}MB limit';
    }

    return null;
  }
}