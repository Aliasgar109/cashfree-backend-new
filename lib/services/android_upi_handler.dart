import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android-specific UPI intent handler for Cashfree payments
class AndroidUpiHandler {
  static const String _tag = 'AndroidUpiHandler';
  static const MethodChannel _channel = MethodChannel('cashfree_upi_handler');

  /// Check if UPI apps are available on the device
  static Future<bool> isUpiAvailable() async {
    try {
      if (!Platform.isAndroid) return false;
      
      final bool isAvailable = await _channel.invokeMethod('isUpiAvailable') ?? false;
      debugPrint('$_tag: UPI availability: $isAvailable');
      return isAvailable;
    } catch (e) {
      debugPrint('$_tag: Error checking UPI availability: $e');
      return false;
    }
  }

  /// Get list of installed UPI apps
  static Future<List<String>> getInstalledUpiApps() async {
    try {
      if (!Platform.isAndroid) return [];
      
      final List<dynamic> apps = await _channel.invokeMethod('getInstalledUpiApps') ?? [];
      final List<String> upiApps = apps.cast<String>();
      debugPrint('$_tag: Installed UPI apps: $upiApps');
      return upiApps;
    } catch (e) {
      debugPrint('$_tag: Error getting UPI apps: $e');
      return [];
    }
  }

  /// Handle UPI intent for Cashfree payments
  static Future<Map<String, dynamic>> handleUpiIntent({
    required String upiUrl,
    String? preferredApp,
  }) async {
    try {
      if (!Platform.isAndroid) {
        throw UnsupportedError('UPI intents are only supported on Android');
      }

      final Map<String, dynamic> arguments = {
        'upiUrl': upiUrl,
        if (preferredApp != null) 'preferredApp': preferredApp,
      };

      final Map<dynamic, dynamic> result = 
          await _channel.invokeMethod('handleUpiIntent', arguments) ?? {};
      
      final Map<String, dynamic> response = Map<String, dynamic>.from(result);
      debugPrint('$_tag: UPI intent result: $response');
      
      return response;
    } catch (e) {
      debugPrint('$_tag: Error handling UPI intent: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Check if specific UPI app is installed
  static Future<bool> isUpiAppInstalled(String packageName) async {
    try {
      if (!Platform.isAndroid) return false;
      
      final bool isInstalled = await _channel.invokeMethod('isUpiAppInstalled', {
        'packageName': packageName,
      }) ?? false;
      
      debugPrint('$_tag: UPI app $packageName installed: $isInstalled');
      return isInstalled;
    } catch (e) {
      debugPrint('$_tag: Error checking UPI app installation: $e');
      return false;
    }
  }

  /// Get UPI app display names and package names
  static Future<Map<String, String>> getUpiAppDetails() async {
    try {
      if (!Platform.isAndroid) return {};
      
      final Map<dynamic, dynamic> details = 
          await _channel.invokeMethod('getUpiAppDetails') ?? {};
      
      final Map<String, String> appDetails = Map<String, String>.from(details);
      debugPrint('$_tag: UPI app details: $appDetails');
      return appDetails;
    } catch (e) {
      debugPrint('$_tag: Error getting UPI app details: $e');
      return {};
    }
  }

  /// Handle UPI payment response from external apps
  static Future<Map<String, dynamic>> parseUpiResponse(String response) async {
    try {
      final Map<String, dynamic> arguments = {'response': response};
      
      final Map<dynamic, dynamic> result = 
          await _channel.invokeMethod('parseUpiResponse', arguments) ?? {};
      
      final Map<String, dynamic> parsedResponse = Map<String, dynamic>.from(result);
      debugPrint('$_tag: Parsed UPI response: $parsedResponse');
      
      return parsedResponse;
    } catch (e) {
      debugPrint('$_tag: Error parsing UPI response: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Common UPI app package names
  static const Map<String, String> commonUpiApps = {
    'Google Pay': 'com.google.android.apps.nbu.paisa.user',
    'PhonePe': 'com.phonepe.app',
    'Paytm': 'net.one97.paytm',
    'BHIM': 'in.org.npci.upiapp',
    'Amazon Pay': 'in.amazon.mShop.android.shopping',
    'WhatsApp': 'com.whatsapp',
    'Cred': 'com.dreamplug.androidapp',
    'MobiKwik': 'com.mobikwik_new',
  };

  /// Get user-friendly names for UPI apps
  static String getUpiAppDisplayName(String packageName) {
    for (final entry in commonUpiApps.entries) {
      if (entry.value == packageName) {
        return entry.key;
      }
    }
    return packageName;
  }
}