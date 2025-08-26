import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../config/cashfree_config.dart';
import '../models/cashfree_error_model.dart';

/// Service for handling Cashfree payment operations through Supabase Edge Functions
class SupabaseCashfreeService {
  final CashfreeConfig _config = CashfreeConfig.instance;
  
  /// Create a new payment order
  Future<CashfreeResult<Map<String, dynamic>>> createOrder({
    required String orderId,
    required double amount,
    required String customerId,
    required String customerEmail,
    required String customerPhone,
    required String customerName,
  }) async {
    try {
      final url = _config.createOrderEndpoint;
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        },
        body: jsonEncode({
          'orderId': orderId,
          'orderAmount': amount,
          'customerId': customerId,
          'customerEmail': customerEmail,
          'customerPhone': customerPhone,
          'customerName': customerName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CashfreeResult.success(data);
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        return CashfreeResult.failure(CashfreeError(
          code: 'ORDER_CREATION_FAILED',
          message: errorData['error'] ?? 'Failed to create order',
          userMessage: 'Unable to create payment order. Please try again.',
          type: CashfreeErrorType.api,
          httpStatusCode: response.statusCode,
        ));
      }
    } catch (e) {
      return CashfreeResult.failure(CashfreeError(
        code: 'ORDER_CREATION_ERROR',
        message: 'Exception during order creation: $e',
        userMessage: 'Network error. Please check your connection and try again.',
        type: CashfreeErrorType.network,
        originalException: e,
      ));
    }
  }

  /// Verify payment status
  Future<CashfreeResult<Map<String, dynamic>>> verifyPayment({
    required String orderId,
  }) async {
    try {
      final url = _config.verifyPaymentEndpoint;
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        },
        body: jsonEncode({
          'orderId': orderId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CashfreeResult.success(data);
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        return CashfreeResult.failure(CashfreeError(
          code: 'PAYMENT_VERIFICATION_FAILED',
          message: errorData['error'] ?? 'Failed to verify payment',
          userMessage: 'Unable to verify payment status. Please try again.',
          type: CashfreeErrorType.api,
          httpStatusCode: response.statusCode,
        ));
      }
    } catch (e) {
      return CashfreeResult.failure(CashfreeError(
        code: 'PAYMENT_VERIFICATION_ERROR',
        message: 'Exception during payment verification: $e',
        userMessage: 'Network error. Please check your connection and try again.',
        type: CashfreeErrorType.network,
        originalException: e,
      ));
    }
  }

  /// Get payment session details
  Future<CashfreeResult<Map<String, dynamic>>> getPaymentSession({
    required String orderId,
  }) async {
    try {
      final url = _config.paymentSessionEndpoint;
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${SupabaseConfig.supabaseAnonKey}',
        },
        body: jsonEncode({
          'orderId': orderId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CashfreeResult.success(data);
      } else {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        return CashfreeResult.failure(CashfreeError(
          code: 'SESSION_RETRIEVAL_FAILED',
          message: errorData['error'] ?? 'Failed to get payment session',
          userMessage: 'Unable to get payment session. Please try again.',
          type: CashfreeErrorType.api,
          httpStatusCode: response.statusCode,
        ));
      }
    } catch (e) {
      return CashfreeResult.failure(CashfreeError(
        code: 'SESSION_RETRIEVAL_ERROR',
        message: 'Exception during session retrieval: $e',
        userMessage: 'Network error. Please check your connection and try again.',
        type: CashfreeErrorType.network,
        originalException: e,
      ));
    }
  }
}
