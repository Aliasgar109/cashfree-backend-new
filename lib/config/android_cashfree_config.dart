import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfdropcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cftheme/cftheme.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';

/// Android-specific configuration for Cashfree SDK
class AndroidCashfreeConfig {
  static const String _tag = 'AndroidCashfreeConfig';

  /// Initialize Cashfree SDK for Android
  static Future<void> initializeCashfreeSDK({
    required bool isSandbox,
  }) async {
    try {
      if (!Platform.isAndroid) {
        throw UnsupportedError('This configuration is only for Android platform');
      }

      // Set environment
      final environment = isSandbox ? CFEnvironment.SANDBOX : CFEnvironment.PRODUCTION;
      
      // Initialize the payment gateway service with callbacks
      CFPaymentGatewayService().setCallback(
        (String orderId) {
          debugPrint('$_tag: Payment verification required for order: $orderId');
        },
        (CFErrorResponse errorResponse, String orderId) {
          debugPrint('$_tag: Payment error for order $orderId: ${errorResponse.getMessage()}');
        },
      );

      debugPrint('$_tag: Cashfree SDK initialized for Android with environment: ${environment.name}');
    } catch (e) {
      debugPrint('$_tag: Failed to initialize Cashfree SDK: $e');
      rethrow;
    }
  }

  /// Create Android-optimized payment session
  static CFSession createPaymentSession({
    required String paymentSessionId,
    required String orderId,
    required CFEnvironment environment,
  }) {
    return CFSessionBuilder()
        .setEnvironment(environment)
        .setPaymentSessionId(paymentSessionId)
        .setOrderId(orderId)
        .build();
  }

  /// Create Android-optimized theme configuration
  static CFTheme createAndroidTheme() {
    return CFThemeBuilder()
        .setNavigationBarBackgroundColorColor("#FF6B35")
        .setNavigationBarTextColor("#FFFFFF")
        .setButtonBackgroundColor("#FF6B35")
        .setButtonTextColor("#FFFFFF")
        .setPrimaryTextColor("#000000")
        .setSecondaryTextColor("#666666")
        .build();
  }

  /// Create drop checkout payment configuration for Android
  static CFDropCheckoutPayment createDropCheckoutPayment({
    required CFSession session,
    CFTheme? theme,
  }) {
    return CFDropCheckoutPaymentBuilder()
        .setSession(session)
        .setTheme(theme ?? createAndroidTheme())
        .build();
  }

  /// Check if device supports UPI payments
  static Future<bool> isUpiSupported() async {
    try {
      if (!Platform.isAndroid) return false;
      
      // This would typically check for UPI apps installed
      // For now, we'll assume UPI is supported on Android devices
      return true;
    } catch (e) {
      debugPrint('$_tag: Error checking UPI support: $e');
      return false;
    }
  }

  /// Get recommended payment methods for Android
  static List<String> getRecommendedPaymentMethods() {
    return [
      'upi',
      'card',
      'netbanking',
      'wallet',
    ];
  }
}