import 'package:flutter/material.dart';
import '../models/payment_model.dart';

/// Widget for selecting Cashfree payment methods
/// 
/// This widget provides a user-friendly interface for selecting
/// from available Cashfree payment methods including Cards, UPI,
/// NetBanking, and Wallets.
class CashfreePaymentMethodSelector extends StatelessWidget {
  final PaymentMethod selectedMethod;
  final Function(PaymentMethod) onMethodChanged;
  final double walletBalance;
  final double totalAmount;
  final bool enabled;

  const CashfreePaymentMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.onMethodChanged,
    this.walletBalance = 0.0,
    required this.totalAmount,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            const Text(
              'Select Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentMethodTile(
              PaymentMethod.CASHFREE_CARD,
              'Credit/Debit Cards',
              'Pay securely using your credit or debit card',
              Icons.credit_card,
              Colors.blue,
            ),
            _buildPaymentMethodTile(
              PaymentMethod.CASHFREE_UPI,
              'UPI Payment',
              'Pay using UPI apps like GPay, PhonePe, Paytm',
              Icons.payment,
              Colors.green,
            ),
            _buildPaymentMethodTile(
              PaymentMethod.CASHFREE_NETBANKING,
              'Net Banking',
              'Pay directly from your bank account',
              Icons.account_balance,
              Colors.orange,
            ),
            _buildPaymentMethodTile(
              PaymentMethod.CASHFREE_WALLET,
              'Digital Wallets',
              'Pay using digital wallets like Paytm, Amazon Pay',
              Icons.account_balance_wallet,
              Colors.purple,
            ),
            const SizedBox(height: 16),
            _buildLegacyPaymentMethods(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodTile(
    PaymentMethod method,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
  ) {
    final isSelected = selectedMethod == method;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? iconColor : Colors.grey.shade300,
          width: isSelected ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
        color: isSelected ? iconColor.withValues(alpha: 0.1) : null,
      ),
      child: RadioListTile<PaymentMethod>(
        value: method,
        groupValue: selectedMethod,
        onChanged: enabled ? (PaymentMethod? value) {
          if (value != null) onMethodChanged(value);
        } : null,
        title: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: enabled ? null : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        activeColor: iconColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
      ),
    );
  }

  Widget _buildLegacyPaymentMethods() {
    return ExpansionTile(
      title: const Text(
        'Other Payment Options',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      initiallyExpanded: false,
      children: [
        _buildLegacyPaymentMethodTile(
          PaymentMethod.UPI,
          'UPI (Legacy)',
          'Traditional UPI payment method',
          Icons.payment,
          Colors.grey,
        ),
        _buildLegacyPaymentMethodTile(
          PaymentMethod.WALLET,
          'Wallet Payment',
          'Pay using your wallet balance (₹${walletBalance.toStringAsFixed(2)} available)',
          Icons.account_balance_wallet,
          Colors.grey,
          enabled: walletBalance >= totalAmount,
        ),
        _buildLegacyPaymentMethodTile(
          PaymentMethod.COMBINED,
          'Wallet + UPI',
          'Use wallet balance first, then UPI for remaining amount',
          Icons.account_balance_wallet_outlined,
          Colors.grey,
          enabled: walletBalance > 0,
        ),
      ],
    );
  }

  Widget _buildLegacyPaymentMethodTile(
    PaymentMethod method,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor, {
    bool enabled = true,
  }) {
    final isSelected = selectedMethod == method;
    final isMethodEnabled = enabled && this.enabled;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4.0),
      child: RadioListTile<PaymentMethod>(
        value: method,
        groupValue: selectedMethod,
        onChanged: isMethodEnabled ? (PaymentMethod? value) {
          if (value != null) onMethodChanged(value);
        } : null,
        title: Row(
          children: [
            Icon(
              icon,
              color: isMethodEnabled ? iconColor : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: isMethodEnabled ? null : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMethodEnabled ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        activeColor: iconColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      ),
    );
  }
}

/// Widget for displaying payment method icons and labels
class PaymentMethodIcon extends StatelessWidget {
  final PaymentMethod method;
  final double size;
  final Color? color;

  const PaymentMethodIcon({
    super.key,
    required this.method,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconData = _getIconForMethod(method);
    final iconColor = color ?? _getColorForMethod(method);

    return Icon(
      iconData,
      size: size,
      color: iconColor,
    );
  }

  IconData _getIconForMethod(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.CASHFREE_CARD:
        return Icons.credit_card;
      case PaymentMethod.CASHFREE_UPI:
        return Icons.payment;
      case PaymentMethod.CASHFREE_NETBANKING:
        return Icons.account_balance;
      case PaymentMethod.CASHFREE_WALLET:
        return Icons.account_balance_wallet;
      case PaymentMethod.UPI:
        return Icons.payment;
      case PaymentMethod.WALLET:
        return Icons.account_balance_wallet;
      case PaymentMethod.COMBINED:
        return Icons.account_balance_wallet_outlined;
      case PaymentMethod.CASH:
        return Icons.money;
    }
  }

  Color _getColorForMethod(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.CASHFREE_CARD:
        return Colors.blue;
      case PaymentMethod.CASHFREE_UPI:
        return Colors.green;
      case PaymentMethod.CASHFREE_NETBANKING:
        return Colors.orange;
      case PaymentMethod.CASHFREE_WALLET:
        return Colors.purple;
      case PaymentMethod.UPI:
        return Colors.grey;
      case PaymentMethod.WALLET:
        return Colors.grey;
      case PaymentMethod.COMBINED:
        return Colors.grey;
      case PaymentMethod.CASH:
        return Colors.brown;
    }
  }
}