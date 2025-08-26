import 'package:flutter/foundation.dart';

import '../services/cashfree_wallet_integration_service.dart';
import '../models/payment_model.dart';
import '../models/cashfree_error_model.dart';

/// Example demonstrating how to use the CashfreeWalletIntegrationService
/// for combined wallet + Cashfree payments
void main() async {
  await combinedPaymentExamples();
}

Future<void> combinedPaymentExamples() async {
  if (kDebugMode) {
    print('=== Combined Payment Examples ===\n');
  }
  
  final integrationService = CashfreeWalletIntegrationService.instance;
  const userId = 'example_user_123';

  try {
    // Example 1: Check wallet balance
    if (kDebugMode) {
      print('1. Checking wallet balance...');
    }
    final walletBalance = await integrationService.getWalletBalance(userId);
    if (kDebugMode) {
      print('Current wallet balance: ₹${walletBalance.toStringAsFixed(2)}\n');
    }

    // Example 2: Calculate payment breakdown for different scenarios
    await _demonstratePaymentCalculations(integrationService, userId);

    // Example 3: Process combined payments
    await _demonstrateCombinedPayments(integrationService, userId);

    // Example 4: Process wallet-only payments
    await _demonstrateWalletOnlyPayments(integrationService, userId);

    // Example 5: Verify combined payments
    await _demonstratePaymentVerification(integrationService);

    // Example 6: Handle error scenarios
    await _demonstrateErrorHandling(integrationService);

  } catch (e) {
    if (kDebugMode) {
      print('Error in combined payment examples: $e\n');
    }
  }
}

/// Demonstrate payment calculation scenarios
Future<void> _demonstratePaymentCalculations(
  CashfreeWalletIntegrationService service,
  String userId,
) async {
  if (kDebugMode) {
    print('2. Payment calculation scenarios...');
  }

  // Scenario 1: Full wallet payment
  try {
    final calculation1 = await service.calculateCombinedPayment(
      userId: userId,
      totalAmount: 300.0,
      extraCharges: 20.0,
    );
    
    if (kDebugMode) {
      print('Scenario 1 - Small amount (₹320):');
      print('  Total: ${calculation1.formattedTotalAmount}');
      print('  Wallet: ${calculation1.formattedWalletAmount}');
      print('  Cashfree: ${calculation1.formattedCashfreeAmount}');
      print('  Can pay fully from wallet: ${calculation1.canPayFullyFromWallet}');
      print('  Requires Cashfree: ${calculation1.requiresCashfreePayment}');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error in scenario 1: $e');
    }
  }

  // Scenario 2: Partial wallet + Cashfree payment
  try {
    final calculation2 = await service.calculateCombinedPayment(
      userId: userId,
      totalAmount: 1500.0,
      extraCharges: 100.0,
    );
    
    if (kDebugMode) {
      print('\nScenario 2 - Large amount (₹1600):');
      print('  Total: ${calculation2.formattedTotalAmount}');
      print('  Wallet: ${calculation2.formattedWalletAmount}');
      print('  Cashfree: ${calculation2.formattedCashfreeAmount}');
      print('  Can pay fully from wallet: ${calculation2.canPayFullyFromWallet}');
      print('  Requires Cashfree: ${calculation2.requiresCashfreePayment}');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error in scenario 2: $e');
    }
  }

  if (kDebugMode) {
    print('');
  }
}

/// Demonstrate combined payment processing
Future<void> _demonstrateCombinedPayments(
  CashfreeWalletIntegrationService service,
  String userId,
) async {
  if (kDebugMode) {
    print('3. Processing combined payments...');
  }

  // Example 1: Combined payment with UPI
  try {
    if (kDebugMode) {
      print('Processing combined payment with UPI...');
    }
    
    final result1 = await service.processCombinedPayment(
      userId: userId,
      totalAmount: 1200.0,
      cashfreeMethod: PaymentMethod.CASHFREE_UPI,
      extraCharges: 50.0,
      note: 'TV Subscription - Annual Plan',
    );

    if (result1.success) {
      if (kDebugMode) {
        print('✓ Combined payment successful!');
        print('  Payment ID: ${result1.paymentId}');
        print('  Total: ${result1.formattedTotalAmount}');
        print('  Wallet portion: ${result1.formattedWalletAmount}');
        print('  Cashfree portion: ${result1.formattedCashfreeAmount}');
        print('  Wallet Transaction ID: ${result1.walletTransactionId}');
        print('  Cashfree Order ID: ${result1.cashfreeOrderId}');
        print('  Message: ${result1.message}');
      }
    } else {
      if (kDebugMode) {
        print('✗ Combined payment failed: ${result1.error}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error in combined UPI payment: $e');
    }
  }

  // Example 2: Combined payment with Card
  try {
    if (kDebugMode) {
      print('\nProcessing combined payment with Card...');
    }
    
    final result2 = await service.processCombinedPayment(
      userId: userId,
      totalAmount: 800.0,
      cashfreeMethod: PaymentMethod.CASHFREE_CARD,
      note: 'TV Subscription - Quarterly Plan',
      paymentId: 'CUSTOM_PAY_ID_123',
    );

    if (result2.success) {
      if (kDebugMode) {
        print('✓ Combined card payment successful!');
        print('  Payment ID: ${result2.paymentId}');
        print('  Message: ${result2.message}');
      }
    } else {
      if (kDebugMode) {
        print('✗ Combined card payment failed: ${result2.error}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error in combined card payment: $e');
    }
  }

  if (kDebugMode) {
    print('');
  }
}

/// Demonstrate wallet-only payments
Future<void> _demonstrateWalletOnlyPayments(
  CashfreeWalletIntegrationService service,
  String userId,
) async {
  if (kDebugMode) {
    print('4. Processing wallet-only payments...');
  }

  // Example 1: Successful wallet-only payment
  try {
    if (kDebugMode) {
      print('Processing wallet-only payment...');
    }
    
    final result1 = await service.processWalletOnlyPayment(
      userId: userId,
      totalAmount: 250.0,
      extraCharges: 25.0,
      note: 'TV Subscription - Monthly Plan',
    );

    if (result1.success) {
      if (kDebugMode) {
        print('✓ Wallet-only payment successful!');
        print('  Payment ID: ${result1.paymentId}');
        print('  Total: ${result1.formattedTotalAmount}');
        print('  Wallet Transaction ID: ${result1.walletTransactionId}');
        print('  Message: ${result1.message}');
      }
    } else {
      if (kDebugMode) {
        print('✗ Wallet-only payment failed: ${result1.error}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error in wallet-only payment: $e');
    }
  }

  // Example 2: Insufficient wallet balance
  try {
    if (kDebugMode) {
      print('\nTrying wallet-only payment with insufficient balance...');
    }
    
    final result2 = await service.processWalletOnlyPayment(
      userId: userId,
      totalAmount: 5000.0, // Likely more than wallet balance
      note: 'Large payment test',
    );

    if (result2.success) {
      if (kDebugMode) {
        print('✓ Large wallet payment successful!');
      }
    } else {
      if (kDebugMode) {
        print('✗ Expected failure - insufficient balance: ${result2.error}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error in large wallet payment: $e');
    }
  }

  if (kDebugMode) {
    print('');
  }
}

/// Demonstrate payment verification
Future<void> _demonstratePaymentVerification(
  CashfreeWalletIntegrationService service,
) async {
  if (kDebugMode) {
    print('5. Payment verification examples...');
  }

  // Example 1: Verify combined payment
  try {
    if (kDebugMode) {
      print('Verifying combined payment...');
    }
    
    final verification1 = await service.verifyCombinedPayment(
      paymentId: 'PAY_example_user_123_1234567890',
      walletTransactionId: 'wallet_txn_123',
      cashfreeOrderId: 'order_123',
    );

    if (verification1.success) {
      if (kDebugMode) {
        print('✓ Combined payment verification successful!');
        print('  Payment ID: ${verification1.paymentId}');
        print('  Wallet verified: ${verification1.walletTransactionVerified}');
        print('  Cashfree verified: ${verification1.cashfreePaymentVerified}');
        print('  Message: ${verification1.message}');
      }
    } else {
      if (kDebugMode) {
        print('✗ Combined payment verification failed: ${verification1.error}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error in combined payment verification: $e');
    }
  }

  // Example 2: Verify wallet-only payment
  try {
    if (kDebugMode) {
      print('\nVerifying wallet-only payment...');
    }
    
    final verification2 = await service.verifyCombinedPayment(
      paymentId: 'PAY_wallet_only_123',
      walletTransactionId: 'wallet_txn_456',
    );

    if (verification2.success) {
      if (kDebugMode) {
        print('✓ Wallet-only payment verification successful!');
        print('  Payment ID: ${verification2.paymentId}');
        print('  Wallet verified: ${verification2.walletTransactionVerified}');
      }
    } else {
      if (kDebugMode) {
        print('✗ Wallet-only payment verification failed: ${verification2.error}');
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error in wallet-only payment verification: $e');
    }
  }

  if (kDebugMode) {
    print('');
  }
}

/// Demonstrate error handling scenarios
Future<void> _demonstrateErrorHandling(
  CashfreeWalletIntegrationService service,
) async {
  if (kDebugMode) {
    print('6. Error handling scenarios...');
  }

  // Example 1: Invalid user ID
  try {
    if (kDebugMode) {
      print('Testing invalid user ID...');
    }
    
    await service.calculateCombinedPayment(
      userId: '', // Invalid empty user ID
      totalAmount: 100.0,
    );
  } catch (e) {
    if (e is CashfreeServiceException) {
      if (kDebugMode) {
        print('✓ Expected validation error caught: ${e.message}');
      }
    } else {
      if (kDebugMode) {
        print('Unexpected error: $e');
      }
    }
  }

  // Example 2: Invalid amount
  try {
    if (kDebugMode) {
      print('\nTesting invalid amount...');
    }
    
    await service.calculateCombinedPayment(
      userId: 'test_user',
      totalAmount: -100.0, // Invalid negative amount
    );
  } catch (e) {
    if (e is CashfreeServiceException) {
      if (kDebugMode) {
        print('✓ Expected validation error caught: ${e.message}');
      }
    } else {
      if (kDebugMode) {
        print('Unexpected error: $e');
      }
    }
  }

  // Example 3: Invalid payment method
  try {
    if (kDebugMode) {
      print('\nTesting invalid payment method...');
    }
    
    await service.processCombinedPayment(
      userId: 'test_user',
      totalAmount: 100.0,
      cashfreeMethod: PaymentMethod.UPI, // Not a Cashfree method
    );
  } catch (e) {
    if (e is CashfreeServiceException) {
      if (kDebugMode) {
        print('✓ Expected validation error caught: ${e.message}');
      }
    } else {
      if (kDebugMode) {
        print('Unexpected error: $e');
      }
    }
  }

  if (kDebugMode) {
    print('');
  }
}

/// Example of a complete payment flow with proper error handling
Future<void> completePaymentFlow() async {
  if (kDebugMode) {
    print('=== Complete Payment Flow Example ===\n');
  }
  
  final integrationService = CashfreeWalletIntegrationService.instance;
  const userId = 'flow_example_user';
  const totalAmount = 1200.0;
  const extraCharges = 80.0;

  try {
    // Step 1: Check wallet balance
    if (kDebugMode) {
      print('Step 1: Checking wallet balance...');
    }
    final walletBalance = await integrationService.getWalletBalance(userId);
    if (kDebugMode) {
      print('Current wallet balance: ₹${walletBalance.toStringAsFixed(2)}');
    }

    // Step 2: Calculate payment breakdown
    if (kDebugMode) {
      print('\nStep 2: Calculating payment breakdown...');
    }
    final calculation = await integrationService.calculateCombinedPayment(
      userId: userId,
      totalAmount: totalAmount,
      extraCharges: extraCharges,
    );

    if (kDebugMode) {
      print('Payment breakdown:');
      print('  Total amount: ${calculation.formattedTotalAmount}');
      print('  Wallet portion: ${calculation.formattedWalletAmount}');
      print('  Cashfree portion: ${calculation.formattedCashfreeAmount}');
      print('  Can pay fully from wallet: ${calculation.canPayFullyFromWallet}');
    }

    // Step 3: Process payment based on calculation
    if (kDebugMode) {
      print('\nStep 3: Processing payment...');
    }
    
    CombinedPaymentResult paymentResult;
    
    if (calculation.canPayFullyFromWallet) {
      // Process wallet-only payment
      paymentResult = await integrationService.processWalletOnlyPayment(
        userId: userId,
        totalAmount: totalAmount,
        extraCharges: extraCharges,
        note: 'TV Subscription - Complete Payment Flow',
      );
    } else {
      // Process combined payment
      paymentResult = await integrationService.processCombinedPayment(
        userId: userId,
        totalAmount: totalAmount,
        cashfreeMethod: PaymentMethod.CASHFREE_UPI,
        extraCharges: extraCharges,
        note: 'TV Subscription - Complete Payment Flow',
      );
    }

    // Step 4: Handle payment result
    if (paymentResult.success) {
      if (kDebugMode) {
        print('✓ Payment successful!');
        print('  Payment ID: ${paymentResult.paymentId}');
        print('  Total amount: ${paymentResult.formattedTotalAmount}');
        print('  Message: ${paymentResult.message}');
      }

      // Step 5: Verify payment
      if (kDebugMode) {
        print('\nStep 5: Verifying payment...');
      }
      
      final verification = await integrationService.verifyCombinedPayment(
        paymentId: paymentResult.paymentId!,
        walletTransactionId: paymentResult.walletTransactionId,
        cashfreeOrderId: paymentResult.cashfreeOrderId,
      );

      if (verification.success) {
        if (kDebugMode) {
          print('✓ Payment verification successful!');
          print('Complete payment flow finished successfully.');
        }
      } else {
        if (kDebugMode) {
          print('✗ Payment verification failed: ${verification.error}');
        }
      }
    } else {
      if (kDebugMode) {
        print('✗ Payment failed: ${paymentResult.error}');
        print('Error type: ${paymentResult.errorType}');
      }
    }

  } catch (e) {
    if (kDebugMode) {
      print('Error in complete payment flow: $e');
    }
  }
}

/// Example of handling payment method selection
Future<void> paymentMethodSelectionExample() async {
  if (kDebugMode) {
    print('=== Payment Method Selection Example ===\n');
  }
  
  final integrationService = CashfreeWalletIntegrationService.instance;
  const userId = 'method_selection_user';
  const totalAmount = 800.0;

  try {
    // Get wallet balance first
    final walletBalance = await integrationService.getWalletBalance(userId);
    
    // Calculate what payment methods are available
    final calculation = await integrationService.calculateCombinedPayment(
      userId: userId,
      totalAmount: totalAmount,
    );

    if (kDebugMode) {
      print('Available payment options for ₹${totalAmount.toStringAsFixed(2)}:');
      print('Current wallet balance: ₹${walletBalance.toStringAsFixed(2)}');
    }

    // Option 1: Wallet-only (if sufficient balance)
    if (calculation.canPayFullyFromWallet) {
      if (kDebugMode) {
        print('\n✓ Option 1: Pay entirely from wallet');
        print('  Amount: ${calculation.formattedWalletAmount}');
      }
    }

    // Option 2: Combined payment (if partial wallet balance)
    if (calculation.requiresCashfreePayment && calculation.walletAmount > 0) {
      if (kDebugMode) {
        print('\n✓ Option 2: Combined payment');
        print('  Wallet portion: ${calculation.formattedWalletAmount}');
        print('  Cashfree portion: ${calculation.formattedCashfreeAmount}');
        print('  Available Cashfree methods:');
        print('    - UPI Payment');
        print('    - Card Payment');
        print('    - Net Banking');
        print('    - Wallet Payment');
      }
    }

    // Option 3: Full Cashfree payment (always available)
    if (kDebugMode) {
      print('\n✓ Option 3: Pay entirely via Cashfree');
      print('  Amount: ₹${totalAmount.toStringAsFixed(2)}');
      print('  Available methods: UPI, Card, Net Banking, Wallet');
    }

    // Demonstrate processing different payment methods
    if (kDebugMode) {
      print('\nProcessing payment with different methods...');
    }

    // Try UPI payment
    final upiResult = await integrationService.processCombinedPayment(
      userId: userId,
      totalAmount: totalAmount,
      cashfreeMethod: PaymentMethod.CASHFREE_UPI,
      note: 'Payment via UPI',
    );

    if (kDebugMode) {
      print('UPI payment result: ${upiResult.success ? 'Success' : 'Failed'}');
    }

  } catch (e) {
    if (kDebugMode) {
      print('Error in payment method selection: $e');
    }
  }
}