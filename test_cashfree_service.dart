import 'package:jafary_channel_app/services/cashfree_payment_service.dart';
import 'package:jafary_channel_app/models/payment_model.dart';

void main() async {
  print('Testing Cashfree Payment Service...');
  
  final service = CashfreePaymentService.instance;
  
  // Test singleton pattern
  final service2 = CashfreePaymentService.instance;
  print('Singleton test: ${identical(service, service2)}');
  
  // Test initial state
  print('Initial state - isInitialized: ${service.isInitialized}');
  print('Initial state - initializationFailed: ${service.initializationFailed}');
  
  // Test validation without initialization
  try {
    await service.createPaymentSession(
      userId: '',
      amount: 100.0,
      orderId: 'test123',
    );
  } catch (e) {
    print('Expected error when not initialized: $e');
  }
  
  // Test error types
  final errorTypes = CashfreeErrorType.values;
  print('Available error types: ${errorTypes.map((e) => e.name).join(', ')}');
  
  // Test result classes
  final sessionResult = CashfreePaymentSessionResult(
    success: true,
    sessionId: 'session123',
    orderId: 'order123',
    amount: 100.0,
    message: 'Test success',
  );
  print('Session result: $sessionResult');
  
  final paymentResult = CashfreePaymentResult(
    success: false,
    error: 'Test error',
    errorType: CashfreeErrorType.validation,
  );
  print('Payment result: $paymentResult');
  
  final verificationResult = CashfreeVerificationResult(
    success: true,
    orderId: 'order123',
    paymentStatus: 'SUCCESS',
    transactionId: 'txn123',
    amount: 100.0,
    message: 'Verified',
  );
  print('Verification result: $verificationResult');
  
  print('Core Cashfree Payment Service architecture test completed successfully!');
}