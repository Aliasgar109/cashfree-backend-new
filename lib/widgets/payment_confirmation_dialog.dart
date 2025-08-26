import 'package:flutter/material.dart';
import '../models/payment_model.dart';
import 'payment_amount_display.dart';
import 'cashfree_payment_method_selector.dart';

/// Dialog widget for confirming payment details before processing
/// 
/// This widget displays a confirmation dialog with payment details,
/// amount breakdown, and selected payment method for user verification.
class PaymentConfirmationDialog extends StatelessWidget {
  final double amount;
  final double extraCharges;
  final PaymentMethod paymentMethod;
  final String? customerName;
  final String? customerPhone;
  final String? customerArea;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isProcessing;

  const PaymentConfirmationDialog({
    super.key,
    required this.amount,
    this.extraCharges = 0.0,
    required this.paymentMethod,
    this.customerName,
    this.customerPhone,
    this.customerArea,
    required this.onConfirm,
    required this.onCancel,
    this.isProcessing = false,
  });

  double get totalAmount => amount + extraCharges;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.payment, color: Colors.blue),
          SizedBox(width: 8),
          Text('Confirm Payment'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomerDetails(),
            const SizedBox(height: 16),
            _buildPaymentMethodSection(),
            const SizedBox(height: 16),
            _buildAmountSection(),
            const SizedBox(height: 16),
            _buildSecurityNote(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isProcessing ? null : onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isProcessing ? null : onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Pay ₹${totalAmount.toStringAsFixed(2)}'),
        ),
      ],
    );
  }

  Widget _buildCustomerDetails() {
    if (customerName == null && customerPhone == null && customerArea == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (customerName != null)
          _buildDetailRow('Name', customerName!),
        if (customerPhone != null)
          _buildDetailRow('Phone', customerPhone!),
        if (customerArea != null)
          _buildDetailRow('Area', customerArea!),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              PaymentMethodIcon(method: paymentMethod, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getPaymentMethodDisplayName(paymentMethod),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        PaymentAmountDisplay(
          baseAmount: amount,
          extraCharges: extraCharges,
          showBreakdown: extraCharges > 0,
          backgroundColor: Colors.grey[50],
          padding: const EdgeInsets.all(12.0),
        ),
      ],
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(
            Icons.security,
            color: Colors.green[700],
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your payment is secured with 256-bit SSL encryption',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodDisplayName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.CASHFREE_CARD:
        return 'Credit/Debit Cards';
      case PaymentMethod.CASHFREE_UPI:
        return 'UPI Payment';
      case PaymentMethod.CASHFREE_NETBANKING:
        return 'Net Banking';
      case PaymentMethod.CASHFREE_WALLET:
        return 'Digital Wallets';
      case PaymentMethod.UPI:
        return 'UPI (Legacy)';
      case PaymentMethod.WALLET:
        return 'Wallet Payment';
      case PaymentMethod.COMBINED:
        return 'Wallet + UPI';
      case PaymentMethod.CASH:
        return 'Cash Payment';
    }
  }
}

/// Simple confirmation dialog for quick payment confirmations
class QuickPaymentConfirmationDialog extends StatelessWidget {
  final double amount;
  final String paymentMethodName;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isProcessing;

  const QuickPaymentConfirmationDialog({
    super.key,
    required this.amount,
    required this.paymentMethodName,
    required this.onConfirm,
    required this.onCancel,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pay ₹${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'using $paymentMethodName',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isProcessing ? null : onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isProcessing ? null : onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }
}