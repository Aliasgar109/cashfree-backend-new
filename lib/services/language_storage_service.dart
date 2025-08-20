import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle language preference storage
class LanguageStorageService {
  static const String _languageKey = 'selected_language';
  static const String _isFirstTimeKey = 'is_first_time_user';
  
  /// Save language preference permanently
  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
    await prefs.setBool(_isFirstTimeKey, false); // Mark as not first time
  }
  
  /// Get saved language preference
  static Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }
  
  /// Check if language is already selected (not first time user)
  static Future<bool> isLanguageSelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstTimeKey) != true; // Returns false if first time, true if not
  }
  
  /// Check if this is the first time user
  static Future<bool> isFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstTimeKey) != false; // Returns true if first time or null
  }
  
  /// Clear language preference (for testing or reset)
  static Future<void> clearLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_languageKey);
    await prefs.remove(_isFirstTimeKey);
  }
  
  /// Reset to first time user (for testing)
  static Future<void> resetToFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isFirstTimeKey);
  }
  
  /// Get default language if none is selected
  static String getDefaultLanguage() {
    return 'en'; // Default to English
  }
}
