import 'dart:typed_data';
import '../models/models.dart';
import '../services/receipt_service.dart';
import '../services/supabase_receipt_service.dart';
import '../templates/receipt_template.dart';

/// Example demonstrating how to generate receipts for Cashfree payments
class CashfreeReceiptGenerationExample {
  final ReceiptService _receiptService = ReceiptService();
  final SupabaseReceiptService _supabaseReceiptService = SupabaseReceiptService();

  /// Example: Generate receipt for Cashfree card payment
  Future<void> generateCashfreeCardReceipt() async {
    try {
      // Create a Cashfree card payment
      final payment = PaymentModel(
        id: 'payment_cf_card_001',
        userId: 'user_123',
        amount: 1500.0,
        extraCharges: 150.0,
        method: PaymentMethod.CASHFREE_CARD,
        status: PaymentStatus.APPROVED,
        createdAt: DateTime.now(),
        receiptNumber: 'RCP2024001',
        year: 2024,
        transactionId: 'TXN_CARD_001',
        cashfreeOrderId: 'CF_ORDER_CARD_123',
        cashfreePaymentId: 'CF_PAYMENT_CARD_456',
        cashfreeSessionId: 'CF_SESSION_CARD_789',
        paymentGateway: 'cashfree',
        bankReference: 'CARD_BANK_REF_001',
        gatewayResponse: {
          'payment_method': 'card',
          'card_network': 'VISA',
          'card_type': 'credit_card',
          'card_last4': '1234',
          'bank_name': 'HDFC Bank',
        },
      );

      // Create user
      final user = UserModel(
        id: 'user_123',
        username: 'johndoe',
        name: 'John Doe',
        phoneNumber: '+919876543210',
        address: '123 Main Street, Apartment 4B',
        area: 'Downtown',
        role: UserRole.USER,
        preferredLanguage: 'en',
        createdAt: DateTime.now(),
      );

      // Generate complete receipt (PDF + Storage + Database)
      final receipt = await _receiptService.generateReceipt(
        payment: payment,
        user: user,
      );

      print('✅ Cashfree Card Receipt Generated Successfully!');
      print('Receipt ID: ${receipt.id}');
      print('Receipt Number: ${receipt.receiptNumber}');
      print('PDF URL: ${receipt.pdfUrl}');
      print('Cashfree Order ID: ${receipt.cashfreeOrderId}');
      print('Cashfree Payment ID: ${receipt.cashfreePaymentId}');
      print('Payment Gateway: ${receipt.paymentGateway}');
      print('Bank Reference: ${receipt.bankReference}');
    } catch (e) {
      print('❌ Error generating Cashfree card receipt: $e');
    }
  }

  /// Example: Generate receipt for Cashfree UPI payment
  Future<void> generateCashfreeUpiReceipt() async {
    try {
      // Create a Cashfree UPI payment
      final payment = PaymentModel(
        id: 'payment_cf_upi_002',
        userId: 'user_124',
        amount: 750.0,
        extraCharges: 25.0,
        method: PaymentMethod.CASHFREE_UPI,
        status: PaymentStatus.APPROVED,
        createdAt: DateTime.now(),
        receiptNumber: 'RCP2024002',
        year: 2024,
        transactionId: 'TXN_UPI_002',
        cashfreeOrderId: 'CF_ORDER_UPI_124',
        cashfreePaymentId: 'CF_PAYMENT_UPI_457',
        cashfreeSessionId: 'CF_SESSION_UPI_790',
        paymentGateway: 'cashfree',
        bankReference: 'UPI_BANK_REF_002',
        gatewayResponse: {
          'payment_method': 'upi',
          'upi_id': 'user@paytm',
          'bank_name': 'State Bank of India',
        },
      );

      // Create user
      final user = UserModel(
        id: 'user_124',
        username: 'janesmith',
        name: 'Jane Smith',
        phoneNumber: '+919876543211',
        address: '456 Oak Avenue',
        area: 'Uptown',
        role: UserRole.USER,
        preferredLanguage: 'en',
        createdAt: DateTime.now(),
      );

      // Generate PDF only
      final pdfBytes = await _receiptService.generateReceiptPDF(
        payment: payment,
        user: user,
        receiptNumber: 'RCP2024002',
        language: 'en',
      );

      print('✅ Cashfree UPI Receipt PDF Generated Successfully!');
      print('PDF Size: ${pdfBytes.length} bytes');
      print('Payment Method: ${payment.method}');
      print('UPI ID from Gateway: ${payment.gatewayResponse?['upi_id']}');
    } catch (e) {
      print('❌ Error generating Cashfree UPI receipt: $e');
    }
  }

  /// Example: Generate receipt for Cashfree NetBanking payment in Gujarati
  Future<void> generateCashfreeNetbankingReceiptGujarati() async {
    try {
      // Create a Cashfree NetBanking payment
      final payment = PaymentModel(
        id: 'payment_cf_nb_003',
        userId: 'user_125',
        amount: 2000.0,
        extraCharges: 200.0,
        method: PaymentMethod.CASHFREE_NETBANKING,
        status: PaymentStatus.APPROVED,
        createdAt: DateTime.now(),
        receiptNumber: 'RCP2024003',
        year: 2024,
        transactionId: 'TXN_NB_003',
        cashfreeOrderId: 'CF_ORDER_NB_125',
        cashfreePaymentId: 'CF_PAYMENT_NB_458',
        cashfreeSessionId: 'CF_SESSION_NB_791',
        paymentGateway: 'cashfree',
        bankReference: 'NB_BANK_REF_003',
        gatewayResponse: {
          'payment_method': 'netbanking',
          'bank_name': 'ICICI Bank',
          'bank_code': 'ICIC',
        },
      );

      // Create Gujarati user
      final user = UserModel(
        id: 'user_125',
        username: 'rajeshpatel',
        name: 'રાજેશ પટેલ',
        phoneNumber: '+919876543212',
        address: '789 ગાંધી રોડ, નવરંગપુરા',
        area: 'અમદાવાદ',
        role: UserRole.USER,
        preferredLanguage: 'gu',
        createdAt: DateTime.now(),
      );

      // Generate PDF in Gujarati
      final pdfBytes = await _receiptService.generateReceiptPDF(
        payment: payment,
        user: user,
        receiptNumber: 'RCP2024003',
        language: 'gu',
      );

      print('✅ Cashfree NetBanking Receipt (Gujarati) Generated Successfully!');
      print('PDF Size: ${pdfBytes.length} bytes');
      print('Language: Gujarati');
      print('Bank: ${payment.gatewayResponse?['bank_name']}');
    } catch (e) {
      print('❌ Error generating Cashfree NetBanking receipt: $e');
    }
  }

  /// Example: Generate receipt for Cashfree Wallet payment using Supabase
  Future<void> generateCashfreeWalletReceiptSupabase() async {
    try {
      // Create a Cashfree Wallet payment
      final payment = PaymentModel(
        id: 'payment_cf_wallet_004',
        userId: 'user_126',
        amount: 500.0,
        extraCharges: 50.0,
        method: PaymentMethod.CASHFREE_WALLET,
        status: PaymentStatus.APPROVED,
        createdAt: DateTime.now(),
        receiptNumber: 'RCP2024004',
        year: 2024,
        transactionId: 'TXN_WALLET_004',
        cashfreeOrderId: 'CF_ORDER_WALLET_126',
        cashfreePaymentId: 'CF_PAYMENT_WALLET_459',
        cashfreeSessionId: 'CF_SESSION_WALLET_792',
        paymentGateway: 'cashfree',
        bankReference: 'WALLET_BANK_REF_004',
        gatewayResponse: {
          'payment_method': 'wallet',
          'wallet_name': 'Paytm',
          'wallet_id': 'paytm_wallet_123',
        },
      );

      // Create user
      final user = UserModel(
        id: 'user_126',
        username: 'alicejohnson',
        name: 'Alice Johnson',
        phoneNumber: '+919876543213',
        address: '321 Pine Street',
        area: 'Midtown',
        role: UserRole.USER,
        preferredLanguage: 'en',
        createdAt: DateTime.now(),
      );

      // Create receipt model
      final receipt = ReceiptModel(
        id: 'receipt_004',
        paymentId: payment.id,
        receiptNumber: payment.receiptNumber,
        pdfUrl: 'https://example.com/receipts/RCP2024004.pdf',
        generatedAt: DateTime.now(),
        language: user.preferredLanguage,
        userId: user.id,
        amount: payment.amount,
        extraCharges: payment.extraCharges,
        paymentMethod: payment.method.toString().split('.').last,
        year: payment.year,
        cashfreeOrderId: payment.cashfreeOrderId,
        cashfreePaymentId: payment.cashfreePaymentId,
        cashfreeSessionId: payment.cashfreeSessionId,
        paymentGateway: payment.paymentGateway,
        bankReference: payment.bankReference,
        gatewayResponse: payment.gatewayResponse,
      );

      // Generate PDF using Supabase service
      final pdfBytes = await _supabaseReceiptService.generateReceiptPDF(
        receipt: receipt,
        user: user,
        payment: payment,
      );

      print('✅ Cashfree Wallet Receipt (Supabase) Generated Successfully!');
      print('PDF Size: ${pdfBytes.length} bytes');
      print('Wallet: ${payment.gatewayResponse?['wallet_name']}');
      print('Receipt has Cashfree data: ${receipt.hasCashfreeData}');
      print('Is Cashfree payment: ${receipt.isCashfreePayment}');
    } catch (e) {
      print('❌ Error generating Cashfree wallet receipt: $e');
    }
  }

  /// Example: Generate receipt using template directly
  Future<void> generateReceiptUsingTemplate() async {
    try {
      // Create a combined Cashfree payment (wallet + card)
      final payment = PaymentModel(
        id: 'payment_cf_combined_005',
        userId: 'user_127',
        amount: 1200.0,
        extraCharges: 120.0,
        method: PaymentMethod.CASHFREE_CARD,
        status: PaymentStatus.APPROVED,
        createdAt: DateTime.now(),
        receiptNumber: 'RCP2024005',
        year: 2024,
        transactionId: 'TXN_COMBINED_005',
        walletAmountUsed: 200.0,
        upiAmountPaid: 1000.0,
        cashfreeOrderId: 'CF_ORDER_COMBINED_127',
        cashfreePaymentId: 'CF_PAYMENT_COMBINED_460',
        cashfreeSessionId: 'CF_SESSION_COMBINED_793',
        paymentGateway: 'cashfree',
        bankReference: 'COMBINED_BANK_REF_005',
        gatewayResponse: {
          'payment_method': 'card',
          'card_network': 'MasterCard',
          'wallet_used': true,
          'wallet_amount': 200.0,
          'card_amount': 1000.0,
        },
      );

      // Create user
      final user = UserModel(
        id: 'user_127',
        username: 'bobwilson',
        name: 'Bob Wilson',
        phoneNumber: '+919876543214',
        address: '654 Elm Street',
        area: 'Westside',
        role: UserRole.USER,
        preferredLanguage: 'en',
        createdAt: DateTime.now(),
      );

      // Use template directly (requires BuildContext in real app)
      print('✅ Receipt Template Ready for Combined Payment!');
      print('Payment Method: ${payment.method}');
      print('Wallet Amount Used: ₹${payment.walletAmountUsed}');
      print('Card Amount Paid: ₹${payment.upiAmountPaid}');
      print('Total Amount: ₹${payment.amount}');
      print('Cashfree Order ID: ${payment.cashfreeOrderId}');
      print('Gateway Response: ${payment.gatewayResponse}');
    } catch (e) {
      print('❌ Error preparing receipt template: $e');
    }
  }

  /// Example: Validate receipt data before generation
  Future<void> validateReceiptData() async {
    try {
      // Create receipt with potential validation issues
      final receipt = ReceiptModel(
        id: 'receipt_validation_test',
        paymentId: 'payment_validation_test',
        receiptNumber: 'RCP2024006',
        pdfUrl: 'https://example.com/receipts/RCP2024006.pdf',
        generatedAt: DateTime.now(),
        language: 'en',
        userId: 'user_validation_test',
        amount: 800.0,
        extraCharges: 80.0,
        paymentMethod: 'CASHFREE_UPI',
        year: 2024,
        cashfreeOrderId: 'CF_ORDER_VALIDATION_128',
        cashfreePaymentId: 'CF_PAYMENT_VALIDATION_461',
        cashfreeSessionId: 'CF_SESSION_VALIDATION_794',
        paymentGateway: 'cashfree',
        bankReference: 'VALIDATION_BANK_REF_006',
        gatewayResponse: {
          'payment_method': 'upi',
          'validation_test': true,
        },
      );

      // Validate receipt data
      final validationErrors = receipt.validate();
      
      if (validationErrors.isEmpty) {
        print('✅ Receipt validation passed!');
        print('Receipt is valid: ${receipt.isValid}');
        print('Is Cashfree payment: ${receipt.isCashfreePayment}');
        print('Has Cashfree data: ${receipt.hasCashfreeData}');
        print('Primary transaction ID: ${receipt.primaryTransactionId}');
        print('Payment method display: ${receipt.paymentMethodDisplayText}');
      } else {
        print('❌ Receipt validation failed:');
        validationErrors.forEach((field, error) {
          print('  - $field: $error');
        });
      }
    } catch (e) {
      print('❌ Error validating receipt data: $e');
    }
  }

  /// Example: Handle different Cashfree payment scenarios
  Future<void> handleDifferentCashfreeScenarios() async {
    print('\n🔄 Testing Different Cashfree Payment Scenarios...\n');

    // Scenario 1: Successful card payment
    await _handleSuccessfulCardPayment();

    // Scenario 2: Failed UPI payment
    await _handleFailedUpiPayment();

    // Scenario 3: Pending NetBanking payment
    await _handlePendingNetbankingPayment();

    // Scenario 4: Wallet payment with partial amount
    await _handlePartialWalletPayment();
  }

  Future<void> _handleSuccessfulCardPayment() async {
    final payment = PaymentModel(
      id: 'payment_success_card',
      userId: 'user_success',
      amount: 1000.0,
      method: PaymentMethod.CASHFREE_CARD,
      status: PaymentStatus.APPROVED,
      createdAt: DateTime.now(),
      receiptNumber: 'RCP2024007',
      year: 2024,
      cashfreeOrderId: 'CF_ORDER_SUCCESS',
      cashfreePaymentId: 'CF_PAYMENT_SUCCESS',
      paymentGateway: 'cashfree',
      gatewayResponse: {'status': 'SUCCESS', 'message': 'Payment completed successfully'},
    );

    print('✅ Scenario 1: Successful Card Payment');
    print('   Status: ${payment.status}');
    print('   Gateway Response: ${payment.gatewayResponse?['message']}');
  }

  Future<void> _handleFailedUpiPayment() async {
    final payment = PaymentModel(
      id: 'payment_failed_upi',
      userId: 'user_failed',
      amount: 500.0,
      method: PaymentMethod.CASHFREE_UPI,
      status: PaymentStatus.REJECTED,
      createdAt: DateTime.now(),
      receiptNumber: 'RCP2024008',
      year: 2024,
      cashfreeOrderId: 'CF_ORDER_FAILED',
      paymentGateway: 'cashfree',
      gatewayResponse: {'status': 'FAILED', 'message': 'UPI transaction declined'},
    );

    print('❌ Scenario 2: Failed UPI Payment');
    print('   Status: ${payment.status}');
    print('   Gateway Response: ${payment.gatewayResponse?['message']}');
  }

  Future<void> _handlePendingNetbankingPayment() async {
    final payment = PaymentModel(
      id: 'payment_pending_nb',
      userId: 'user_pending',
      amount: 1500.0,
      method: PaymentMethod.CASHFREE_NETBANKING,
      status: PaymentStatus.PENDING,
      createdAt: DateTime.now(),
      receiptNumber: 'RCP2024009',
      year: 2024,
      cashfreeOrderId: 'CF_ORDER_PENDING',
      paymentGateway: 'cashfree',
      gatewayResponse: {'status': 'PENDING', 'message': 'Awaiting bank confirmation'},
    );

    print('⏳ Scenario 3: Pending NetBanking Payment');
    print('   Status: ${payment.status}');
    print('   Gateway Response: ${payment.gatewayResponse?['message']}');
  }

  Future<void> _handlePartialWalletPayment() async {
    final payment = PaymentModel(
      id: 'payment_partial_wallet',
      userId: 'user_partial',
      amount: 800.0,
      method: PaymentMethod.CASHFREE_WALLET,
      status: PaymentStatus.APPROVED,
      createdAt: DateTime.now(),
      receiptNumber: 'RCP2024010',
      year: 2024,
      walletAmountUsed: 300.0,
      upiAmountPaid: 500.0,
      cashfreeOrderId: 'CF_ORDER_PARTIAL',
      cashfreePaymentId: 'CF_PAYMENT_PARTIAL',
      paymentGateway: 'cashfree',
      gatewayResponse: {
        'status': 'SUCCESS',
        'wallet_amount': 300.0,
        'remaining_amount': 500.0,
        'payment_methods_used': ['wallet', 'upi']
      },
    );

    print('💰 Scenario 4: Partial Wallet Payment');
    print('   Status: ${payment.status}');
    print('   Wallet Used: ₹${payment.walletAmountUsed}');
    print('   UPI Paid: ₹${payment.upiAmountPaid}');
    print('   Total: ₹${payment.amount}');
  }

  /// Run all examples
  Future<void> runAllExamples() async {
    print('🚀 Starting Cashfree Receipt Generation Examples...\n');

    await generateCashfreeCardReceipt();
    print('\n' + '='*50 + '\n');

    await generateCashfreeUpiReceipt();
    print('\n' + '='*50 + '\n');

    await generateCashfreeNetbankingReceiptGujarati();
    print('\n' + '='*50 + '\n');

    await generateCashfreeWalletReceiptSupabase();
    print('\n' + '='*50 + '\n');

    await generateReceiptUsingTemplate();
    print('\n' + '='*50 + '\n');

    await validateReceiptData();
    print('\n' + '='*50 + '\n');

    await handleDifferentCashfreeScenarios();

    print('\n✅ All Cashfree Receipt Generation Examples Completed!');
  }
}

/// Usage example
void main() async {
  final example = CashfreeReceiptGenerationExample();
  await example.runAllExamples();
}