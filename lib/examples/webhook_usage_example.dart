import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../services/cashfree_webhook_service.dart';
import '../models/payment_model.dart';

/// Example usage of CashfreeWebhookService
/// 
/// This example demonstrates how to handle Cashfree webhook notifications
/// in your application. In a real implementation, this would typically
/// be part of your backend API endpoint handler.
class WebhookUsageExample {
  final CashfreeWebhookService _webhookService = CashfreeWebhookService.instance;

  /// Initialize the webhook service
  Future<bool> initialize() async {
    return await _webhookService.initialize();
  }

  /// Handle incoming webhook from Cashfree
  /// 
  /// This method would typically be called from your backend API endpoint
  /// that receives webhook notifications from Cashfree.
  Future<Map<String, dynamic>> handleCashfreeWebhook({
    required Map<String, dynamic> webhookBody,
    required String signature,
    String? timestamp,
    Map<String, String>? headers,
  }) async {
    try {
      if (kDebugMode) {
        print('WebhookExample: Received webhook notification');
        print('WebhookExample: Event type: ${webhookBody['type']}');
        print('WebhookExample: Order ID: ${webhookBody['order_id']}');
      }

      // Process the webhook using the service
      final result = await _webhookService.handleWebhook(
        webhookData: webhookBody,
        signature: signature,
        timestamp: timestamp,
        headers: headers,
      );

      if (result.success) {
        if (kDebugMode) {
          print('WebhookExample: Webhook processed successfully');
          print('WebhookExample: Order ID: ${result.orderId}');
          print('WebhookExample: Payment Status: ${result.paymentStatus}');
          print('WebhookExample: Event Type: ${result.eventType}');
        }

        // Here you would typically update your database
        await _updatePaymentInDatabase(result);

        // Return success response
        return {
          'status': 'success',
          'message': 'Webhook processed successfully',
          'order_id': result.orderId,
          'payment_status': result.paymentStatus?.name,
        };
      } else {
        if (kDebugMode) {
          print('WebhookExample: Webhook processing failed: ${result.error}');
        }

        // Return error response
        return {
          'status': 'error',
          'message': result.error ?? 'Unknown error',
          'error_type': result.errorType?.name,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebhookExample: Exception handling webhook: $e');
      }

      return {
        'status': 'error',
        'message': 'Internal server error',
        'details': e.toString(),
      };
    }
  }

  /// Example of updating payment in database
  /// 
  /// In a real implementation, this would update your payment records
  /// in your database (Firestore, Supabase, etc.)
  Future<void> _updatePaymentInDatabase(CashfreeWebhookResult result) async {
    try {
      if (result.paymentData == null || result.orderId == null) {
        if (kDebugMode) {
          print('WebhookExample: No payment data to update');
        }
        return;
      }

      // Example: Create/update payment model
      final paymentData = result.paymentData!;
      
      if (kDebugMode) {
        print('WebhookExample: Updating payment in database');
        print('WebhookExample: Cashfree Order ID: ${paymentData['cashfree_order_id']}');
        print('WebhookExample: Payment Status: ${paymentData['payment_status']}');
        print('WebhookExample: Payment Amount: ${paymentData['payment_amount']}');
      }

      // Here you would typically:
      // 1. Find the existing payment record by cashfree_order_id
      // 2. Update the payment status and other fields
      // 3. Save to your database
      
      // Example pseudo-code:
      // final payment = await PaymentRepository.findByCashfreeOrderId(result.orderId!);
      // if (payment != null) {
      //   final updatedPayment = payment.copyWith(
      //     status: result.paymentStatus,
      //     cashfreePaymentId: paymentData['cashfree_payment_id'],
      //     bankReference: paymentData['bank_reference'],
      //     paymentTime: paymentData['payment_time'] != null 
      //         ? DateTime.parse(paymentData['payment_time'])
      //         : null,
      //     gatewayResponse: paymentData['gateway_response'],
      //   );
      //   await PaymentRepository.update(updatedPayment);
      // }

      if (kDebugMode) {
        print('WebhookExample: Payment updated successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('WebhookExample: Error updating payment in database: $e');
      }
      rethrow;
    }
  }

  /// Example webhook payload for testing
  /// 
  /// This shows what a typical Cashfree webhook payload looks like
  static Map<String, dynamic> get exampleSuccessWebhook => {
    'type': 'PAYMENT_SUCCESS_WEBHOOK',
    'order_id': 'order_123456789',
    'data': {
      'payment_session_id': 'session_abc123def456',
      'order_status': 'PAID',
      'cf_payment_id': 'payment_789012345',
      'payment_method': 'upi',
      'payment_amount': 299.0,
      'order_amount': 299.0,
      'bank_reference': 'bank_ref_123456',
      'payment_time': '2024-01-15T10:30:00Z',
      'failure_reason': null,
    },
  };

  /// Example webhook payload for failed payment
  static Map<String, dynamic> get exampleFailedWebhook => {
    'type': 'PAYMENT_FAILED_WEBHOOK',
    'order_id': 'order_123456789',
    'data': {
      'payment_session_id': 'session_abc123def456',
      'order_status': 'FAILED',
      'cf_payment_id': 'payment_789012345',
      'payment_method': 'upi',
      'payment_amount': 0.0,
      'order_amount': 299.0,
      'bank_reference': null,
      'payment_time': null,
      'failure_reason': 'Insufficient funds',
    },
  };

  /// Test webhook signature verification
  /// 
  /// This method demonstrates how to test webhook signature verification
  Future<bool> testWebhookSignature() async {
    try {
      const testBody = '{"type":"PAYMENT_SUCCESS_WEBHOOK","order_id":"test_order"}';
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      
      // In a real scenario, this signature would come from Cashfree
      const testSignature = 't=1640995200,v1=test_signature';
      
      final isValid = await _webhookService.verifyWebhookSignature(
        signature: testSignature,
        body: testBody,
        timestamp: timestamp,
      );

      if (kDebugMode) {
        print('WebhookExample: Signature verification result: $isValid');
      }

      return isValid;
    } catch (e) {
      if (kDebugMode) {
        print('WebhookExample: Error testing signature: $e');
      }
      return false;
    }
  }

  /// Example of handling different webhook event types
  Future<void> handleWebhookEventTypes() async {
    final eventHandlers = {
      'PAYMENT_SUCCESS_WEBHOOK': _handlePaymentSuccess,
      'PAYMENT_FAILED_WEBHOOK': _handlePaymentFailed,
      'PAYMENT_USER_DROPPED_WEBHOOK': _handlePaymentDropped,
      'ORDER_PAID': _handleOrderPaid,
    };

    // Example: Process different event types
    for (final eventType in eventHandlers.keys) {
      if (kDebugMode) {
        print('WebhookExample: Handler available for event: $eventType');
      }
    }
  }

  /// Handle successful payment webhook
  Future<void> _handlePaymentSuccess(CashfreeWebhookResult result) async {
    if (kDebugMode) {
      print('WebhookExample: Processing successful payment');
      print('WebhookExample: Order ID: ${result.orderId}');
    }
    
    // Update payment status to approved
    // Send confirmation email/SMS to user
    // Update subscription status if applicable
    // Trigger any post-payment workflows
  }

  /// Handle failed payment webhook
  Future<void> _handlePaymentFailed(CashfreeWebhookResult result) async {
    if (kDebugMode) {
      print('WebhookExample: Processing failed payment');
      print('WebhookExample: Order ID: ${result.orderId}');
    }
    
    // Update payment status to failed
    // Send failure notification to user
    // Log failure reason for analysis
    // Optionally retry payment or suggest alternatives
  }

  /// Handle user dropped payment webhook
  Future<void> _handlePaymentDropped(CashfreeWebhookResult result) async {
    if (kDebugMode) {
      print('WebhookExample: Processing dropped payment');
      print('WebhookExample: Order ID: ${result.orderId}');
    }
    
    // Update payment status to incomplete
    // Send reminder to complete payment
    // Track abandonment analytics
  }

  /// Handle order paid webhook
  Future<void> _handleOrderPaid(CashfreeWebhookResult result) async {
    if (kDebugMode) {
      print('WebhookExample: Processing order paid');
      print('WebhookExample: Order ID: ${result.orderId}');
    }
    
    // Final confirmation of payment
    // Update order status
    // Trigger fulfillment processes
  }
}

/// Example usage in your application
/// 
/// ```dart
/// final webhookExample = WebhookUsageExample();
/// await webhookExample.initialize();
/// 
/// // In your webhook endpoint handler:
/// final response = await webhookExample.handleCashfreeWebhook(
///   webhookBody: requestBody,
///   signature: request.headers['x-cashfree-signature'],
///   timestamp: request.headers['x-cashfree-timestamp'],
/// );
/// 
/// return Response.json(response);
/// ```