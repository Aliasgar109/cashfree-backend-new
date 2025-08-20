import 'package:flutter/material.dart';

/// App color palette for TV Subscription Payment App
class AppColors {
  // Primary colors - TV/Entertainment theme
  static const Color primary = Color(0xFF1565C0); // Deep blue
  static const Color primaryLight = Color(0xFF5E92F3);
  static const Color primaryDark = Color(0xFF003C8F);
  
  // Secondary colors - Payment/Money theme
  static const Color secondary = Color(0xFF4CAF50); // Success green
  static const Color secondaryLight = Color(0xFF80E27E);
  static const Color secondaryDark = Color(0xFF087F23);
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Payment status colors
  static const Color paid = Color(0xFF4CAF50);
  static const Color pending = Color(0xFFFF9800);
  static const Color overdue = Color(0xFFF44336);
  static const Color cancelled = Color(0xFF9E9E9E);
  
  // Background colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8F9FA);
  
  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  
  // Card and container colors
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color cardShadow = Color(0x1F000000);
  static const Color divider = Color(0xFFE0E0E0);
  
  // Admin panel colors
  static const Color adminPrimary = Color(0xFF6A1B9A);
  static const Color adminSecondary = Color(0xFF9C27B0);
  
  // Collector colors
  static const Color collectorPrimary = Color(0xFF795548);
  static const Color collectorSecondary = Color(0xFFA1887F);
  
  // UPI and payment method colors
  static const Color upiColor = Color(0xFF00A86B);
  static const Color walletColor = Color(0xFF673AB7);
  static const Color cashColor = Color(0xFF4CAF50);
  
  // Gradient colors
  static const List<Color> primaryGradient = [
    Color(0xFF1565C0),
    Color(0xFF1976D2),
  ];
  
  static const List<Color> successGradient = [
    Color(0xFF4CAF50),
    Color(0xFF66BB6A),
  ];
  
  static const List<Color> warningGradient = [
    Color(0xFFFF9800),
    Color(0xFFFFB74D),
  ];
}