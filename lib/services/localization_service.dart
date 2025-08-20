import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import 'language_storage_service.dart';

/// Service to manage app localization and language preferences
class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const String _defaultLanguage = 'en';
  
  Locale _currentLocale = const Locale(_defaultLanguage);
  
  /// Get the current locale
  Locale get currentLocale => _currentLocale;
  
  /// Get the current language code
  String get currentLanguageCode => _currentLocale.languageCode;
  
  /// Check if current language is English
  bool get isEnglish => _currentLocale.languageCode == 'en';
  
  /// Check if current language is Gujarati
  bool get isGujarati => _currentLocale.languageCode == 'gu';
  
  /// Get supported locales
  static List<Locale> get supportedLocales => AppLocalizations.supportedLocales;
  
  /// Get language display names
  static Map<String, String> get languageNames => {
    'en': 'English',
    'gu': 'ગુજરાતી',
  };
  
  /// Initialize the service and load saved language preference
  Future<void> initialize() async {
    // Try to get saved language from LanguageStorageService first
    final savedLanguage = await LanguageStorageService.getLanguage() ?? _defaultLanguage;
    
    // Validate that the saved language is supported
    if (supportedLocales.any((locale) => locale.languageCode == savedLanguage)) {
      _currentLocale = Locale(savedLanguage);
    } else {
      _currentLocale = const Locale(_defaultLanguage);
    }
    
    notifyListeners();
  }
  
  /// Change the app language
  Future<void> changeLanguage(String languageCode) async {
    if (_currentLocale.languageCode == languageCode) return;
    
    // Validate language code
    if (!supportedLocales.any((locale) => locale.languageCode == languageCode)) {
      throw ArgumentError('Unsupported language code: $languageCode');
    }
    
    _currentLocale = Locale(languageCode);
    
    // Save preference using LanguageStorageService
    await LanguageStorageService.saveLanguage(languageCode);
    
    notifyListeners();
  }
  
  /// Toggle between English and Gujarati
  Future<void> toggleLanguage() async {
    final newLanguage = isEnglish ? 'gu' : 'en';
    await changeLanguage(newLanguage);
  }
  
  /// Get localized string for language name
  String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? languageCode;
  }
  
  /// Get current language display name
  String get currentLanguageName => getLanguageName(currentLanguageCode);
  
  /// Reset to default language
  Future<void> resetToDefault() async {
    await changeLanguage(_defaultLanguage);
  }
  
  /// Check if a language is currently selected
  bool isLanguageSelected(String languageCode) {
    return _currentLocale.languageCode == languageCode;
  }
}