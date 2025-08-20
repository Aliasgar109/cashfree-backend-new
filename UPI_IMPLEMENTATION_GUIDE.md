# UPI Implementation Guide - Production Ready

## Overview

This document outlines the complete refactoring of the UPI service to address all production issues and ensure standards compliance.

## Issues Fixed

### 1. Missing Mandatory Parameters ✅

**Problem**: Previous implementation was missing critical UPI parameters that many PSPs require.

**Solution**: Added all mandatory UPI parameters:
- `pa` (Payee VPA) - Merchant UPI ID
- `pn` (Payee Name) - Merchant name
- `mc` (Merchant Category Code) - Set to '5712' for furniture store
- `tid` (Transaction ID) - Unique per attempt (≤ 35 chars)
- `tr` (Transaction Reference) - Short reference (≤ 35 chars)
- `tn` (Transaction Note) - Payment description
- `am` (Amount) - Amount with 2 decimal places
- `cu` (Currency) - Set to 'INR'

### 2. Transaction Reference Length ✅

**Problem**: Generated `tr` values exceeded 35-character limit, causing Paytm and other PSPs to reject payments.

**Solution**: Implemented smart truncation algorithm:
```dart
String _generateSafeTransactionRef(String prefix, String id) {
  const maxLength = 35;
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final baseRef = '${prefix}_${id}_$timestamp';
  
  if (baseRef.length <= maxLength) {
    return baseRef;
  }
  
  // Calculate optimal truncation
  final remainingLength = maxLength - prefix.length - 2;
  final idLength = (remainingLength * 0.4).round();
  final timestampLength = remainingLength - idLength;
  
  final truncatedId = id.length > idLength ? id.substring(0, idLength) : id;
  final truncatedTimestamp = timestamp.length > timestampLength 
      ? timestamp.substring(timestamp.length - timestampLength) 
      : timestamp;
  
  return '${prefix}_${truncatedId}_$truncatedTimestamp';
}
```

### 3. Unsafe URL Encoding ✅

**Problem**: Manual `Uri.encodeComponent()` usage was inconsistent and error-prone.

**Solution**: Used Dart's built-in `Uri` class with `queryParameters`:
```dart
final queryParameters = <String, String>{
  'pa': AppConstants.tvChannelUpiId,
  'pn': AppConstants.tvChannelName,
  'mc': _merchantCategoryCode,
  'tid': transactionId,
  'tr': transactionRef,
  'tn': note,
  'am': amount.toStringAsFixed(2),
  'cu': _currency,
};

final uri = Uri(
  scheme: 'upi',
  host: 'pay',
  queryParameters: queryParameters,
);
```

### 4. Incorrect Launch Attempts ✅

**Problem**: Code built non-standard URIs like `com.phonepe.app://upi/pay?...` which are invalid.

**Solution**: Always use standard `upi://pay?...` scheme with proper fallback strategy:
```dart
// Method 1: LaunchMode.externalApplication (shows app chooser)
// Method 2: LaunchMode.platformDefault
// Method 3: intent:// fallback for better compatibility
// Method 4: Manual instructions if all fail
```

### 5. No Direct Success/Failure Result ✅

**Problem**: `url_launcher` only tells if an app opened, not if payment succeeded.

**Solution**: Implemented PENDING status + admin verification flow:
- Mark transaction as PENDING after UPI launch
- Allow screenshot upload for proof
- Admin approval/rejection workflow
- Real-time status tracking

## Implementation Details

### UPI URL Builder

```dart
String _buildStandardsCompliantUPIUrl({
  required double amount,
  required String note,
  required String transactionRef,
  required String transactionId,
}) {
  // Validate inputs
  if (amount <= 0) {
    throw ArgumentError('Amount must be greater than 0');
  }
  if (transactionRef.length > _maxTransactionRefLength) {
    throw ArgumentError('Transaction reference exceeds $_maxTransactionRefLength characters');
  }
  if (transactionId.length > _maxTransactionIdLength) {
    throw ArgumentError('Transaction ID exceeds $_maxTransactionIdLength characters');
  }

  // Build query parameters using Uri.queryParameters for proper encoding
  final queryParameters = <String, String>{
    'pa': AppConstants.tvChannelUpiId, // Payee VPA (mandatory)
    'pn': AppConstants.tvChannelName, // Payee name (mandatory)
    'mc': _merchantCategoryCode, // Merchant Category Code (mandatory)
    'tid': transactionId, // Transaction ID (mandatory)
    'tr': transactionRef, // Transaction reference (mandatory)
    'tn': note, // Transaction note (mandatory)
    'am': amount.toStringAsFixed(2), // Amount (mandatory)
    'cu': _currency, // Currency (mandatory)
  };

  // Build URI with proper encoding
  final uri = Uri(
    scheme: 'upi',
    host: 'pay',
    queryParameters: queryParameters,
  );

  return uri.toString();
}
```

### Launch Strategy

```dart
Future<UPIResult> _launchAndroidUPIIntent(String upiUrl) async {
  try {
    final uri = Uri.parse(upiUrl);

    // Method 1: Try LaunchMode.externalApplication (shows app chooser)
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        return UPIResult(
          success: true,
          message: 'UPI app chooser opened. Please select your preferred UPI app and complete the payment.',
        );
      }
    } catch (launchError) {
      print('External application launch failed: $launchError');
    }

    // Method 2: Try LaunchMode.platformDefault
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (launched) {
        return UPIResult(
          success: true,
          message: 'UPI app launched successfully. Please complete the payment and return to the app.',
        );
      }
    } catch (fallbackError) {
      print('Platform default launch failed: $fallbackError');
    }

    // Method 3: Try intent:// fallback for better compatibility
    try {
      final intentUrl = 'intent://${uri.host}${uri.path}?${uri.query}#Intent;scheme=upi;action=android.intent.action.VIEW;package=;S.browser_fallback_url=${Uri.encodeComponent(upiUrl)};end';
      
      final launched = await launchUrl(
        Uri.parse(intentUrl),
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        return UPIResult(
          success: true,
          message: 'UPI app launched via intent. Please complete the payment and return to the app.',
        );
      }
    } catch (intentError) {
      print('Intent fallback launch failed: $intentError');
    }

    // If all methods fail, provide manual instructions
    final manualInstructions = _getManualPaymentInstructions(uri);
    
    return UPIResult(
      success: false,
      error: 'Unable to launch UPI app automatically.\n\n$manualInstructions',
    );
  } catch (e) {
    return UPIResult(success: false, error: 'Android UPI intent failed: $e');
  }
}
```

### Payment Flow

1. **User initiates payment**
2. **Generate safe transaction references** (≤ 35 chars each)
3. **Build standards-compliant UPI URL**
4. **Launch UPI app with fallback strategy**
5. **Mark payment as PENDING in database**
6. **User completes payment in UPI app**
7. **User returns to app and uploads screenshot**
8. **Admin verifies and approves/rejects**
9. **Real-time status updates**

## Configuration

### App Constants

```dart
class AppConstants {
  // UPI Configuration
  static const String tvChannelUpiId = '9023823153@upi';
  static const String tvChannelName = 'AGHARIA ALIASGAR MOHAMMEDHUSEN';
  static const String tvChannelMerchantCode = '5712'; // Furniture store MCC
}
```

### UPI Service Constants

```dart
class UPIIntentService {
  // UPI Configuration Constants
  static const String _merchantCategoryCode = '5712'; // Furniture store MCC
  static const String _currency = 'INR';
  static const int _maxTransactionRefLength = 35;
  static const int _maxTransactionIdLength = 35;
}
```

## Testing Strategy

### 1. Minimal UPI URL Test
Test with only essential parameters: `pa`, `pn`, `am`, `cu`

### 2. Full UPI URL Test
Test with all mandatory parameters including `mc`, `tid`, `tr`, `tn`

### 3. Long Reference Test
Test with transaction references that exceed 35 characters to ensure proper truncation

### 4. Launch Compatibility Test
Test on different Android devices with various UPI apps installed

### 5. Release Build Testing
**Critical**: Test on signed release builds as debug builds may be silently blocked by PSPs

## Example UPI URLs

### Minimal URL
```
upi://pay?pa=9023823153@upi&pn=AGHARIA ALIASGAR MOHAMMEDHUSEN&am=100.00&cu=INR
```

### Full URL
```
upi://pay?pa=9023823153@upi&pn=AGHARIA ALIASGAR MOHAMMEDHUSEN&mc=5712&tid=PAY12345678901234567890123456789012345&tr=PAY_123456_1703123456789&tn=TV Subscription Payment&am=500.00&cu=INR
```

## Error Handling

### UPI Launch Failures
- Try multiple launch methods
- Provide manual payment instructions
- Graceful degradation

### Transaction Reference Issues
- Automatic truncation to 35 characters
- Validation before URL generation
- Clear error messages

### Payment Verification
- Screenshot upload capability
- Admin approval workflow
- Real-time status tracking

## Best Practices

1. **Always use `Uri.queryParameters`** for proper URL encoding
2. **Validate all inputs** before building UPI URLs
3. **Enforce 35-character limits** for transaction references
4. **Test on release builds** for production accuracy
5. **Provide manual fallback** when UPI apps fail to launch
6. **Implement proper error handling** with user-friendly messages
7. **Use PENDING status** for UPI payments requiring verification
8. **Track payment status** in real-time

## Security Considerations

1. **Validate transaction IDs** before database updates
2. **Sanitize user inputs** for payment notes
3. **Use secure file upload** for payment screenshots
4. **Implement proper access controls** for admin approval
5. **Log all payment attempts** for audit trails

## Production Checklist

- [ ] All mandatory UPI parameters included
- [ ] Transaction references ≤ 35 characters
- [ ] Proper URL encoding using `Uri.queryParameters`
- [ ] Multiple launch fallback strategies
- [ ] Manual payment instructions provided
- [ ] PENDING status workflow implemented
- [ ] Screenshot upload functionality
- [ ] Admin approval system
- [ ] Real-time status tracking
- [ ] Comprehensive error handling
- [ ] Release build testing completed
- [ ] Security validations implemented

## Troubleshooting

### Common Issues

1. **UPI app not launching**
   - Check if UPI apps are installed
   - Try different launch modes
   - Provide manual instructions

2. **Payment rejected by PSP**
   - Verify all mandatory parameters
   - Check transaction reference length
   - Ensure proper URL encoding

3. **Transaction ID validation fails**
   - Check format (alphanumeric only)
   - Verify length (8-50 characters)
   - Remove special characters

4. **Screenshot upload fails**
   - Check file size (max 5MB)
   - Verify image format (JPG/PNG)
   - Ensure proper permissions

### Debug Information

Enable debug logging to track:
- UPI URL generation
- Launch attempts
- Error messages
- Transaction status changes

## Conclusion

This refactored UPI implementation addresses all production issues and provides a robust, standards-compliant solution for UPI payments. The service now includes proper parameter handling, safe URL generation, comprehensive fallback strategies, and a complete payment verification workflow.
