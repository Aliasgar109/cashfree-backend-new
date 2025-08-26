import 'package:flutter/material.dart';

/// Widget for displaying payment amount breakdown and total
/// 
/// This widget provides a clear display of payment amounts,
/// including base amount, fees, and total with proper formatting.
class PaymentAmountDisplay extends StatelessWidget {
  final double baseAmount;
  final double extraCharges;
  final double lateFees;
  final String currency;
  final bool showBreakdown;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  const PaymentAmountDisplay({
    super.key,
    required this.baseAmount,
    this.extraCharges = 0.0,
    this.lateFees = 0.0,
    this.currency = '₹',
    this.showBreakdown = true,
    this.backgroundColor,
    this.padding,
  });

  double get totalAmount => baseAmount + extraCharges + lateFees;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor ?? Colors.blue[50],
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showBreakdown) ...[
              const Text(
                'Payment Breakdown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildAmountRow('Base Amount', baseAmount),
              if (extraCharges > 0) _buildAmountRow('Extra Charges', extraCharges),
              if (lateFees > 0) _buildAmountRow('Late Fees', lateFees),
              const Divider(height: 20),
            ],
            _buildTotalAmountRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '$currency${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAmountRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total Amount',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '$currency${totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}

/// Compact version of payment amount display for confirmation screens
class CompactPaymentAmountDisplay extends StatelessWidget {
  final double amount;
  final String currency;
  final String? label;
  final Color? textColor;
  final double fontSize;

  const CompactPaymentAmountDisplay({
    super.key,
    required this.amount,
    this.currency = '₹',
    this.label,
    this.textColor,
    this.fontSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label ?? 'Amount',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        Text(
          '$currency${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: textColor ?? Colors.blue,
          ),
        ),
      ],
    );
  }
}

/// Widget for displaying payment amount with method-specific styling
class PaymentMethodAmountDisplay extends StatelessWidget {
  final double amount;
  final String paymentMethodName;
  final IconData? methodIcon;
  final Color? methodColor;
  final String currency;

  const PaymentMethodAmountDisplay({
    super.key,
    required this.amount,
    required this.paymentMethodName,
    this.methodIcon,
    this.methodColor,
    this.currency = '₹',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: (methodColor ?? Colors.blue).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: methodColor ?? Colors.blue,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          if (methodIcon != null) ...[
            Icon(
              methodIcon,
              color: methodColor ?? Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paymentMethodName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: methodColor ?? Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$currency${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}