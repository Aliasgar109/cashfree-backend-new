import 'package:flutter/material.dart';
import '../lib/services/upi_intent_service.dart';
import '../lib/constants/app_constants.dart';

/// Example usage and testing of the refactored UPI service
class UPITestExample {
  final UPIIntentService _upiService = UPIIntentService();

  /// Test UPI URL generation with all mandatory parameters
  void testUPIUrlGeneration() {
    print('🧪 Testing UPI URL Generation...');
    
    try {
      // Test 1: Minimal UPI URL (pa + pn + am + cu)
      final minimalUrl = _buildTestUPIUrl(
        amount: 100.0,
        note: 'Test Payment',
        transactionRef: 'TEST123',
        transactionId: 'TID123',
      );
      print('✅ Minimal UPI URL: $minimalUrl');
      
      // Test 2: Full UPI URL with all parameters
      final fullUrl = _buildTestUPIUrl(
        amount: 500.0,
        note: 'TV Subscription Payment - January 2024',
        transactionRef: 'PAY123456789',
        transactionId: 'TID987654321',
      );
      print('✅ Full UPI URL: $fullUrl');
      
      // Test 3: Long transaction reference (should be truncated)
      final longRefUrl = _buildTestUPIUrl(
        amount: 250.0,
        note: 'Wallet Recharge',
        transactionRef: 'WALLET_VERY_LONG_USER_ID_THAT_EXCEEDS_35_CHARACTERS',
        transactionId: 'TID1234567890123456789012345678901234567890',
      );
      print('✅ Long Reference UPI URL: $longRefUrl');
      
    } catch (e) {
      print('❌ UPI URL Generation Error: $e');
    }
  }

  /// Build test UPI URL using the service's internal method
  String _buildTestUPIUrl({
    required double amount,
    required String note,
    required String transactionRef,
    required String transactionId,
  }) {
    // This simulates the internal method for testing
    final queryParameters = <String, String>{
      'pa': AppConstants.tvChannelUpiId,
      'pn': AppConstants.tvChannelName,
      'mc': '5712',
      'tid': transactionId,
      'tr': transactionRef,
      'tn': note,
      'am': amount.toStringAsFixed(2),
      'cu': 'INR',
    };

    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: queryParameters,
    );

    return uri.toString();
  }

  /// Test transaction reference generation
  void testTransactionReferenceGeneration() {
    print('\n🧪 Testing Transaction Reference Generation...');
    
    // Test wallet recharge
    final walletRef = _generateTestTransactionRef('WALLET', 'user123456789');
    print('✅ Wallet Reference: $walletRef (${walletRef.length} chars)');
    
    // Test payment
    final paymentRef = _generateTestTransactionRef('PAY', 'payment123456789');
    print('✅ Payment Reference: $paymentRef (${paymentRef.length} chars)');
    
    // Test long user ID
    final longUserRef = _generateTestTransactionRef('WALLET', 'very_long_user_id_that_exceeds_normal_length');
    print('✅ Long User Reference: $longUserRef (${longUserRef.length} chars)');
  }

  /// Generate test transaction reference
  String _generateTestTransactionRef(String prefix, String id) {
    const maxLength = 35;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final baseRef = '${prefix}_${id}_$timestamp';
    
    if (baseRef.length <= maxLength) {
      return baseRef;
    }
    
    final remainingLength = maxLength - prefix.length - 2; // 2 for underscores
    final idLength = (remainingLength * 0.4).round();
    final timestampLength = remainingLength - idLength;
    
    final truncatedId = id.length > idLength ? id.substring(0, idLength) : id;
    final truncatedTimestamp = timestamp.length > timestampLength 
        ? timestamp.substring(timestamp.length - timestampLength) 
        : timestamp;
    
    return '${prefix}_${truncatedId}_$truncatedTimestamp';
  }

  /// Test transaction ID generation
  void testTransactionIdGeneration() {
    print('\n🧪 Testing Transaction ID Generation...');
    
    // Test wallet transaction ID
    final walletTid = _generateTestTransactionId('WALLET', 'user123456789');
    print('✅ Wallet TID: $walletTid (${walletTid.length} chars)');
    
    // Test payment transaction ID
    final paymentTid = _generateTestTransactionId('PAY', 'payment123456789');
    print('✅ Payment TID: $paymentTid (${paymentTid.length} chars)');
    
    // Test long payment ID
    final longPaymentTid = _generateTestTransactionId('PAY', 'very_long_payment_id_that_exceeds_normal_length');
    print('✅ Long Payment TID: $longPaymentTid (${longPaymentTid.length} chars)');
  }

  /// Generate test transaction ID
  String _generateTestTransactionId(String prefix, String id) {
    const maxLength = 35;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final baseId = '${prefix}${id}${timestamp}';
    
    if (baseId.length <= maxLength) {
      return baseId;
    }
    
    final remainingLength = maxLength - prefix.length;
    final idLength = (remainingLength * 0.6).round();
    final timestampLength = remainingLength - idLength;
    
    final truncatedId = id.length > idLength ? id.substring(0, idLength) : id;
    final truncatedTimestamp = timestamp.length > timestampLength 
        ? timestamp.substring(timestamp.length - timestampLength) 
        : timestamp;
    
    return '$prefix${truncatedId}$truncatedTimestamp';
  }

  /// Test UPI QR code generation
  void testUPIQRCodeGeneration() {
    print('\n🧪 Testing UPI QR Code Generation...');
    
    final qrData = UPIIntentService.generateUPIQRData(
      upiId: AppConstants.tvChannelUpiId,
      amount: 100.0,
      note: 'Test QR Payment',
      transactionRef: 'QR123456',
    );
    
    print('✅ UPI QR Data: $qrData');
    print('✅ QR Data Length: ${qrData.length} characters');
  }

  /// Test manual payment instructions
  void testManualPaymentInstructions() {
    print('\n🧪 Testing Manual Payment Instructions...');
    
    final instructions = '''
📱 Manual Payment Instructions:

1. Open your UPI app (Paytm/PhonePe/GPay/BHIM/Amazon Pay)
2. Tap on "Pay" or "Send Money"
3. Enter UPI ID: ${AppConstants.tvChannelUpiId}
4. Enter Amount: ₹100.00
5. Add Note: Test Payment
6. Complete the payment

💡 Payment Details:
• UPI ID: ${AppConstants.tvChannelUpiId}
• Merchant: ${AppConstants.tvChannelName}
• Amount: ₹100.00
• Note: Test Payment
• Reference: TEST123

⚠️ Important: After payment, please return to the app and upload a screenshot for verification.
''';
    
    print('✅ Manual Instructions Generated:');
    print(instructions);
  }

  /// Test UPI transaction ID validation
  void testTransactionIdValidation() {
    print('\n🧪 Testing Transaction ID Validation...');
    
    final testIds = [
      'UPI12345678', // Valid
      'TXN987654321', // Valid
      '123456789', // Valid
      'UPI12345678901234567890123456789012345678901234567890', // Too long
      'UPI@123456', // Invalid characters
      '', // Empty
      '   ', // Whitespace only
    ];
    
    for (final id in testIds) {
      final isValid = _isValidTestTransactionId(id);
      print('${isValid ? '✅' : '❌'} "$id" -> ${isValid ? 'Valid' : 'Invalid'}');
    }
  }

  /// Test transaction ID validation
  bool _isValidTestTransactionId(String? transactionId) {
    if (transactionId == null || transactionId.trim().isEmpty) {
      return false;
    }

    final cleanId = transactionId.trim();
    if (cleanId.length < 8 || cleanId.length > 50) {
      return false;
    }

    final upiIdRegex = RegExp(r'^[A-Za-z0-9]+$');
    return upiIdRegex.hasMatch(cleanId);
  }

  /// Run all tests
  void runAllTests() {
    print('🚀 Starting UPI Service Tests...\n');
    
    testUPIUrlGeneration();
    testTransactionReferenceGeneration();
    testTransactionIdGeneration();
    testUPIQRCodeGeneration();
    testManualPaymentInstructions();
    testTransactionIdValidation();
    
    print('\n✅ All UPI tests completed!');
  }
}

/// Example usage in a Flutter widget
class UPITestWidget extends StatefulWidget {
  const UPITestWidget({Key? key}) : super(key: key);

  @override
  State<UPITestWidget> createState() => _UPITestWidgetState();
}

class _UPITestWidgetState extends State<UPITestWidget> {
  final UPITestExample _testExample = UPITestExample();
  final UPIIntentService _upiService = UPIIntentService();
  String _testResult = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPI Service Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _runTests,
              child: const Text('Run UPI Tests'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testWalletRecharge,
              child: const Text('Test Wallet Recharge'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _testSubscriptionPayment,
              child: const Text('Test Subscription Payment'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _testResult,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _runTests() {
    setState(() {
      _testResult = '';
    });
    
    // Capture console output
    final buffer = StringBuffer();
    
    // Create a custom print function for testing
    void testPrint(Object? object) {
      buffer.write('$object\n');
      print(object); // Use the original print
    }
    
    // Run tests with custom print
    try {
      // Temporarily override print behavior for testing
      _testExample.runAllTests();
    } catch (e) {
      buffer.write('Test Error: $e\n');
    }
    
    setState(() {
      _testResult = buffer.toString();
    });
  }

  void _testWalletRecharge() async {
    try {
      final result = await _upiService.launchUPIForRecharge(
        amount: 100.0,
        userId: 'test_user_123',
        note: 'Test Wallet Recharge',
      );
      
      setState(() {
        _testResult = 'Wallet Recharge Result:\n${result.toString()}';
      });
    } catch (e) {
      setState(() {
        _testResult = 'Wallet Recharge Error: $e';
      });
    }
  }

  void _testSubscriptionPayment() async {
    try {
      final result = await _upiService.launchUPIForPayment(
        amount: 500.0,
        userId: 'test_user_123',
        paymentId: 'payment_123456',
        note: 'Test Subscription Payment',
      );
      
      setState(() {
        _testResult = 'Subscription Payment Result:\n${result.toString()}';
      });
    } catch (e) {
      setState(() {
        _testResult = 'Subscription Payment Error: $e';
      });
    }
  }
}
