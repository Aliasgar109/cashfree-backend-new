import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Helper class for easy access to localized strings
class LocalizationHelper {
  /// Get AppLocalizations instance from context
  static AppLocalizations of(BuildContext context) {
    return AppLocalizations.of(context)!;
  }
  
  /// Get localized string with fallback
  static String getString(BuildContext context, String Function(AppLocalizations) getter) {
    try {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        return getter(localizations);
      }
    } catch (e) {
      debugPrint('Localization error: $e');
    }
    return 'Missing translation';
  }
  
  /// Format currency amount based on locale
  static String formatCurrency(BuildContext context, double amount) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'gu') {
      return '₹${amount.toStringAsFixed(2)}';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }
  
  /// Format date based on locale
  static String formatDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'gu') {
      // Gujarati date format
      return '${date.day}/${date.month}/${date.year}';
    }
    // English date format
    return '${date.day}/${date.month}/${date.year}';
  }
  
  /// Format phone number based on locale
  static String formatPhoneNumber(BuildContext context, String phoneNumber) {
    // Remove any existing formatting
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Add Indian country code if not present
    if (!cleaned.startsWith('+91') && cleaned.length == 10) {
      cleaned = '+91$cleaned';
    }
    
    // Format as +91 XXXXX XXXXX
    if (cleaned.startsWith('+91') && cleaned.length == 13) {
      return '${cleaned.substring(0, 3)} ${cleaned.substring(3, 8)} ${cleaned.substring(8)}';
    }
    
    return phoneNumber; // Return original if formatting fails
  }
  
  /// Get receipt number format based on locale
  static String formatReceiptNumber(BuildContext context, String receiptNumber) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'gu') {
      return 'રસીદ નં. $receiptNumber';
    }
    return 'Receipt No. $receiptNumber';
  }
  
  /// Get payment status display text
  static String getPaymentStatusText(BuildContext context, String status) {
    final l10n = of(context);
    switch (status.toLowerCase()) {
      case 'pending':
        return l10n.paymentPending;
      case 'approved':
        return l10n.paymentApproved;
      case 'rejected':
        return l10n.paymentRejected;
      case 'incomplete':
        return 'Payment Incomplete';
      default:
        return status;
    }
  }
  
  /// Get payment method display text
  static String getPaymentMethodText(BuildContext context, String method) {
    final l10n = of(context);
    switch (method.toLowerCase()) {
      case 'upi':
        return l10n.upiPayment;
      case 'wallet':
        return l10n.walletPayment;
      case 'cash':
        return l10n.cashPayment;
      case 'combined':
        return l10n.combinedPayment;
      default:
        return method;
    }
  }
  
  /// Get user role display text
  static String getUserRoleText(BuildContext context, String role) {
    final l10n = of(context);
    switch (role.toLowerCase()) {
      case 'user':
        return l10n.user;
      case 'collector':
        return l10n.collector;
      case 'admin':
        return l10n.admin;
      default:
        return role;
    }
  }
}