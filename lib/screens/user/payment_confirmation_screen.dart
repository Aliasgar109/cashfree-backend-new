import 'package:flutter/material.dart';
import '../../models/payment_model.dart';
import '../../services/supabase_payment_service.dart';

import 'payment_status_screen.dart';
import 'payment_history_screen.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String paymentId;
  final PaymentMethod paymentMethod;
  final double amount;

  const PaymentConfirmationScreen({
    super.key,
    required this.paymentId,
    required this.paymentMethod,
    required this.amount,
  });

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  final SupabasePaymentService _paymentService = SupabasePaymentService();
  PaymentModel? _payment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentDetails();
  }

  Future<void> _loadPaymentDetails() async {
    try {
      final payment = await _paymentService.getPayment(widget.paymentId);
      setState(() {
        _payment = payment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load payment details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Confirmation'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildConfirmationContent(),
    );
  }

  Widget _buildConfirmationContent() {
    if (_payment == null) {
      return _buildErrorContent();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildSuccessIcon(),
          const SizedBox(height: 24),
          _buildConfirmationMessage(),
          const SizedBox(height: 32),
          _buildPaymentDetailsCard(),
          const SizedBox(height: 24),
          _buildStatusCard(),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildErrorContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Payment Details Not Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Unable to load payment information',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.green[100],
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_circle,
        size: 60,
        color: Colors.green,
      ),
    );
  }

  Widget _buildConfirmationMessage() {
    String message;
    String subtitle;

    switch (widget.paymentMethod) {
      case PaymentMethod.UPI:
        message = 'UPI Payment Initiated';
        subtitle = 'Your payment request has been sent for processing';
        break;
      case PaymentMethod.WALLET:
        message = 'Payment Successful';
        subtitle = 'Your wallet payment has been processed successfully';
        break;
      case PaymentMethod.COMBINED:
        message = 'Combined Payment Initiated';
        subtitle = 'Wallet amount deducted, UPI payment initiated';
        break;
      case PaymentMethod.CASH:
        message = 'Cash Payment Recorded';
        subtitle = 'Your cash payment has been recorded';
        break;
      case PaymentMethod.CASHFREE_CARD:
        message = 'Card Payment Initiated';
        subtitle = 'Your card payment is being processed securely';
        break;
      case PaymentMethod.CASHFREE_UPI:
        message = 'UPI Payment Initiated';
        subtitle = 'Your UPI payment is being processed';
        break;
      case PaymentMethod.CASHFREE_NETBANKING:
        message = 'Net Banking Payment Initiated';
        subtitle = 'Your net banking payment is being processed';
        break;
      case PaymentMethod.CASHFREE_WALLET:
        message = 'Wallet Payment Initiated';
        subtitle = 'Your digital wallet payment is being processed';
        break;
    }

    return Column(
      children: [
        Text(
          message,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPaymentDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Payment ID', _payment!.id),
            _buildDetailRow('Receipt Number', _payment!.receiptNumber),
            _buildDetailRow('Amount', '₹${_payment!.totalAmount.toStringAsFixed(2)}'),
            _buildDetailRow('Payment Method', _payment!.methodDisplayText),
            _buildDetailRow('Year', _payment!.year.toString()),
            _buildDetailRow('Date', _formatDateTime(_payment!.createdAt)),
            if (_payment!.transactionId != null)
              _buildDetailRow('Transaction ID', _payment!.transactionId!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusMessage;

    switch (_payment!.status) {
      case PaymentStatus.PENDING:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusMessage = widget.paymentMethod == PaymentMethod.WALLET
            ? 'Payment completed successfully'
            : 'Payment is pending approval';
        break;
      case PaymentStatus.APPROVED:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusMessage = 'Payment has been approved';
        break;
      case PaymentStatus.REJECTED:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusMessage = 'Payment has been rejected';
        break;
      case PaymentStatus.INCOMPLETE:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        statusMessage = 'Payment was not completed';
        break;
    }

    return Card(
      color: statusColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              statusIcon,
              color: statusColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _payment!.statusDisplayText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusMessage,
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PaymentStatusScreen(paymentId: widget.paymentId),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Track Payment Status',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const PaymentHistoryScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'View Payment History',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text(
            'Back to Dashboard',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}