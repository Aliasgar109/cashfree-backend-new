import '../lib/services/wallet_service.dart';
import '../lib/services/upi_intent_service.dart';
import '../lib/models/wallet_transaction_model.dart';

/// Example demonstrating how to use the WalletService and UPIIntentService
/// for wallet management and UPI transactions
void main() async {
  await walletServiceExamples();
  await upiServiceExamples();
}

Future<void> walletServiceExamples() async {
  print('=== Wallet Service Examples ===\n');
  
  final walletService = WalletService();
  const userId = 'example_user_123';

  try {
    // Example 1: Check wallet balance
    print('1. Checking wallet balance...');
    final balance = await walletService.getWalletBalance(userId);
    print('Current wallet balance: ₹${balance.toStringAsFixed(2)}\n');

    // Example 2: Validate sufficient balance for payment
    print('2. Validating balance for payment...');
    const paymentAmount = 500.0;
    final hasSufficientBalance = await walletService.validateSufficientBalance(userId, paymentAmount);
    print('Has sufficient balance for ₹$paymentAmount: $hasSufficientBalance\n');

    // Example 3: Recharge wallet via UPI
    print('3. Recharging wallet...');
    const rechargeAmount = 1000.0;
    const upiTransactionId = 'UPI123456789012';
    
    final rechargeTransaction = await walletService.rechargeWallet(
      userId: userId,
      amount: rechargeAmount,
      upiTransactionId: upiTransactionId,
    );
    
    print('Recharge successful!');
    print('Transaction ID: ${rechargeTransaction.id}');
    print('Amount: ${rechargeTransaction.formattedAmount}');
    print('New balance: ₹${rechargeTransaction.balanceAfter.toStringAsFixed(2)}\n');

    // Example 4: Make a payment using wallet
    print('4. Making payment from wallet...');
    const paymentId = 'PAY987654321';
    const description = 'TV Subscription Payment - Annual Plan';
    
    final paymentTransaction = await walletService.deductFromWallet(
      userId: userId,
      amount: paymentAmount,
      paymentId: paymentId,
      description: description,
    );
    
    print('Payment successful!');
    print('Transaction ID: ${paymentTransaction.id}');
    print('Amount: ${paymentTransaction.formattedAmount}');
    print('Remaining balance: ₹${paymentTransaction.balanceAfter.toStringAsFixed(2)}\n');

    // Example 5: Get transaction history
    print('5. Fetching transaction history...');
    final transactions = await walletService.getTransactionHistory(
      userId: userId,
      limit: 10,
    );
    
    print('Recent transactions (${transactions.length}):');
    for (final transaction in transactions) {
      print('- ${transaction.typeDisplayText}: ${transaction.formattedAmount} '
            '(${transaction.statusDisplayText}) - ${transaction.description}');
    }
    print('');

    // Example 6: Get wallet summary
    print('6. Getting wallet summary...');
    final summary = await walletService.getWalletSummary(userId);
    
    print('Wallet Summary:');
    print('Current Balance: ${summary.formattedCurrentBalance}');
    print('Total Credits (30 days): ${summary.formattedTotalCredits}');
    print('Total Debits (30 days): ${summary.formattedTotalDebits}');
    print('Net Amount (30 days): ${summary.formattedNetAmount}');
    print('Total Transactions (30 days): ${summary.totalTransactions}\n');

    // Example 7: Calculate payment with wallet
    print('7. Calculating payment with wallet...');
    const totalPaymentAmount = 1500.0;
    
    final calculation = await walletService.calculatePaymentWithWallet(
      userId: userId,
      totalAmount: totalPaymentAmount,
    );
    
    print('Payment Calculation:');
    print('Total Amount: ${calculation.formattedTotalAmount}');
    print('Wallet Amount: ${calculation.formattedWalletAmount}');
    print('Remaining Amount: ${calculation.formattedRemainingAmount}');
    print('Can pay fully from wallet: ${calculation.canPayFully}\n');

    // Example 8: Reverse a transaction
    print('8. Reversing a transaction...');
    const reason = 'Duplicate payment - customer request';
    
    final reverseTransaction = await walletService.reverseTransaction(
      originalTransactionId: paymentTransaction.id,
      reason: reason,
    );
    
    print('Transaction reversed successfully!');
    print('Reverse Transaction ID: ${reverseTransaction.id}');
    print('Amount: ${reverseTransaction.formattedAmount}');
    print('New balance: ₹${reverseTransaction.balanceAfter.toStringAsFixed(2)}\n');

  } catch (e) {
    print('Error in wallet operations: $e\n');
  }
}

Future<void> upiServiceExamples() async {
  print('=== UPI Intent Service Examples ===\n');
  
  final upiService = UPIIntentService();
  const userId = 'example_user_123';

  try {
    // Example 1: Get available UPI apps
    print('1. Getting available UPI apps...');
    final upiApps = await upiService.getAvailableUPIApps();
    
    print('Available UPI Apps (${upiApps.length}):');
    for (final app in upiApps) {
      print('- ${app.appName} (${app.packageName})');
    }
    print('');

    // Example 2: Launch UPI for wallet recharge
    print('2. Launching UPI for wallet recharge...');
    const rechargeAmount = 500.0;
    const rechargeNote = 'Wallet Top-up for TV Subscription';
    
    final rechargeResult = await upiService.launchUPIForRecharge(
      amount: rechargeAmount,
      userId: userId,
      note: rechargeNote,
    );
    
    if (rechargeResult.success) {
      print('UPI recharge launched successfully!');
      print('Transaction ID: ${rechargeResult.transactionId}');
      print('Message: ${rechargeResult.message}');
    } else {
      print('UPI recharge failed: ${rechargeResult.error}');
    }
    print('');

    // Example 3: Launch UPI for direct payment
    print('3. Launching UPI for direct payment...');
    const paymentAmount = 1200.0;
    const paymentId = 'PAY_DIRECT_123456';
    const paymentNote = 'TV Subscription - Annual Payment';
    
    final paymentResult = await upiService.launchUPIForPayment(
      amount: paymentAmount,
      userId: userId,
      paymentId: paymentId,
      note: paymentNote,
    );
    
    if (paymentResult.success) {
      print('UPI payment launched successfully!');
      print('Transaction ID: ${paymentResult.transactionId}');
      print('Message: ${paymentResult.message}');
    } else {
      print('UPI payment failed: ${paymentResult.error}');
    }
    print('');

    // Example 4: Validate UPI transaction IDs
    print('4. Validating UPI transaction IDs...');
    final testIds = [
      'UPI123456789',
      'TXN987654321',
      'INVALID@ID',
      '123', // Too short
      null,
    ];
    
    for (final id in testIds) {
      final isValid = _isValidTestTransactionId(id);
      print('ID: "$id" - Valid: $isValid');
    }
    print('');

    // Example 5: Format amounts for UPI
    print('5. Formatting amounts for UPI...');
    final testAmounts = [100.0, 99.99, 1000.5, 0.01];
    
    for (final amount in testAmounts) {
      final formatted = UPIIntentService.formatAmountForUPI(amount);
      print('Amount: $amount -> Formatted: $formatted');
    }
    print('');

    // Example 6: Generate transaction references
    print('6. Generating transaction references...');
    final walletRef = _generateTestTransactionRef('WALLET', 'user123');
    final paymentRef = _generateTestTransactionRef('PAY', 'payment123');
    final rechargeRef = _generateTestTransactionRef('RECHARGE', 'recharge123');
    
    print('Wallet Reference: $walletRef');
    print('Payment Reference: $paymentRef');
    print('Recharge Reference: $rechargeRef');
    print('');

  } catch (e) {
    print('Error in UPI operations: $e\n');
  }
}

/// Helper function to validate UPI transaction IDs for testing
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

/// Helper function to generate test transaction references
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

/// Example of a complete wallet recharge flow
Future<void> completeWalletRechargeFlow() async {
  print('=== Complete Wallet Recharge Flow ===\n');
  
  final walletService = WalletService();
  final upiService = UPIIntentService();
  const userId = 'flow_example_user';
  const rechargeAmount = 1000.0;

  try {
    // Step 1: Check current balance
    print('Step 1: Checking current wallet balance...');
    final currentBalance = await walletService.getWalletBalance(userId);
    print('Current balance: ₹${currentBalance.toStringAsFixed(2)}');

    // Step 2: Launch UPI for recharge
    print('\nStep 2: Launching UPI for recharge...');
    final upiResult = await upiService.launchUPIForRecharge(
      amount: rechargeAmount,
      userId: userId,
      note: 'Wallet Recharge - TV Subscription App',
    );

    if (!upiResult.success) {
      print('UPI launch failed: ${upiResult.error}');
      return;
    }

    print('UPI launched successfully. Transaction ID: ${upiResult.transactionId}');

    // Step 3: Process the recharge (after UPI success)
    print('\nStep 3: Processing wallet recharge...');
    final rechargeTransaction = await walletService.rechargeWallet(
      userId: userId,
      amount: rechargeAmount,
      upiTransactionId: upiResult.transactionId!,
    );

    print('Recharge processed successfully!');
    print('Transaction ID: ${rechargeTransaction.id}');
    print('Previous balance: ₹${rechargeTransaction.balanceBefore.toStringAsFixed(2)}');
    print('Recharged amount: ₹${rechargeTransaction.amount.toStringAsFixed(2)}');
    print('New balance: ₹${rechargeTransaction.balanceAfter.toStringAsFixed(2)}');

    // Step 4: Verify the transaction
    print('\nStep 4: Verifying transaction...');
    final verifiedTransaction = await walletService.getTransactionById(rechargeTransaction.id);
    
    if (verifiedTransaction != null) {
      print('Transaction verified successfully!');
      print('Status: ${verifiedTransaction.statusDisplayText}');
      print('UPI Transaction ID: ${verifiedTransaction.upiTransactionId}');
    }

  } catch (e) {
    print('Error in recharge flow: $e');
  }
}

/// Example of a complete payment flow using wallet + UPI
Future<void> completePaymentFlow() async {
  print('=== Complete Payment Flow (Wallet + UPI) ===\n');
  
  final walletService = WalletService();
  final upiService = UPIIntentService();
  const userId = 'payment_flow_user';
  const totalAmount = 1500.0;
  const paymentId = 'PAY_ANNUAL_SUBSCRIPTION_2024';

  try {
    // Step 1: Calculate payment with wallet
    print('Step 1: Calculating payment breakdown...');
    final calculation = await walletService.calculatePaymentWithWallet(
      userId: userId,
      totalAmount: totalAmount,
    );

    print('Payment Breakdown:');
    print('Total Amount: ${calculation.formattedTotalAmount}');
    print('Wallet Amount: ${calculation.formattedWalletAmount}');
    print('Remaining Amount: ${calculation.formattedRemainingAmount}');

    // Step 2: Process wallet payment (if any)
    if (calculation.walletAmount > 0) {
      print('\nStep 2: Processing wallet payment...');
      final walletTransaction = await walletService.deductFromWallet(
        userId: userId,
        amount: calculation.walletAmount,
        paymentId: paymentId,
        description: 'Partial payment from wallet - TV Subscription',
      );
      
      print('Wallet payment processed: ${walletTransaction.formattedAmount}');
    }

    // Step 3: Process UPI payment for remaining amount (if any)
    if (calculation.remainingAmount > 0) {
      print('\nStep 3: Processing UPI payment for remaining amount...');
      final upiResult = await upiService.launchUPIForPayment(
        amount: calculation.remainingAmount,
        userId: userId,
        paymentId: paymentId,
        note: 'TV Subscription Payment - Remaining Amount',
      );

      if (upiResult.success) {
        print('UPI payment successful: ₹${calculation.remainingAmount.toStringAsFixed(2)}');
        print('UPI Transaction ID: ${upiResult.transactionId}');
      } else {
        print('UPI payment failed: ${upiResult.error}');
        // In a real app, you might need to reverse the wallet transaction
      }
    }

    print('\nPayment flow completed successfully!');

  } catch (e) {
    print('Error in payment flow: $e');
  }
}