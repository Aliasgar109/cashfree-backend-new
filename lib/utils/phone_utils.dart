/// Utility functions for phone number validation and formatting
class PhoneUtils {
  // Indian phone number regex pattern
  static final RegExp _indianPhoneRegex = RegExp(r'^[6-9]\d{9}$');
  
  // Full phone number with country code regex
  static final RegExp _fullPhoneRegex = RegExp(r'^\+91[6-9]\d{9}$');

  /// Validates if the phone number is a valid Indian mobile number
  /// Accepts 10-digit numbers starting with 6, 7, 8, or 9
  static bool isValidPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;
    
    // Remove any spaces, dashes, or other formatting
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Check if it's a 10-digit Indian number
    if (cleanNumber.length == 10) {
      return _indianPhoneRegex.hasMatch(cleanNumber);
    }
    
    // Check if it's a full number with +91 country code
    if (cleanNumber.length == 13 && cleanNumber.startsWith('+91')) {
      return _fullPhoneRegex.hasMatch(cleanNumber);
    }
    
    return false;
  }

  /// Formats phone number to include +91 country code
  /// Input: "9876543210" or "+919876543210"
  /// Output: "+919876543210"
  static String formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return '';
    
    // Remove any spaces, dashes, or other formatting
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // If it's already formatted with +91, return as is
    if (cleanNumber.startsWith('+91') && cleanNumber.length == 13) {
      return cleanNumber;
    }
    
    // If it's a 10-digit number, add +91
    if (cleanNumber.length == 10 && _indianPhoneRegex.hasMatch(cleanNumber)) {
      return '+91$cleanNumber';
    }
    
    // If it starts with 91 but no +, add the +
    if (cleanNumber.startsWith('91') && cleanNumber.length == 12) {
      return '+$cleanNumber';
    }
    
    return phoneNumber; // Return original if can't format
  }

  /// Formats phone number for display (with spaces for readability)
  /// Input: "+919876543210"
  /// Output: "+91 98765 43210"
  static String formatForDisplay(String phoneNumber) {
    String formatted = formatPhoneNumber(phoneNumber);
    
    if (formatted.length == 13 && formatted.startsWith('+91')) {
      return '${formatted.substring(0, 3)} ${formatted.substring(3, 8)} ${formatted.substring(8)}';
    }
    
    return phoneNumber;
  }

  /// Extracts 10-digit number from formatted phone number
  /// Input: "+919876543210"
  /// Output: "9876543210"
  static String extractTenDigitNumber(String phoneNumber) {
    String formatted = formatPhoneNumber(phoneNumber);
    
    if (formatted.length == 13 && formatted.startsWith('+91')) {
      return formatted.substring(3);
    }
    
    return phoneNumber;
  }

  /// Validates and formats phone number, returns null if invalid
  static String? validateAndFormat(String phoneNumber) {
    if (!isValidPhoneNumber(phoneNumber)) {
      return null;
    }
    
    return formatPhoneNumber(phoneNumber);
  }
}