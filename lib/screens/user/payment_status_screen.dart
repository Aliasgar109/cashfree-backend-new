import 'package:flutter/material.dart';
import '../../models/payment_model.dart';
import '../../services/supabase_payment_service.dart';
import '../../theme/theme.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String paymentId;

  const PaymentStatusScreen({
    super.key,
    required this.paymentId,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  final SupabasePaymentService _paymentService = SupabasePaymentService();
  PaymentModel? _payment;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentStatus();
  }

  Future<void> _loadPaymentStatus() async {
    try {
      setState(() => _isLoading = true);
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
            content: Text('Failed to load payment status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshStatus() async {
    await _loadPaymentStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Status'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildStatusContent(),
    );
  }

  Widget _buildStatusContent() {
    if (_payment == null) {
      return _buildErrorContent();
    }

    return RefreshIndicator(
      onRefresh: _refreshStatus,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatusTimeline(),
            const SizedBox(height: 24),
            _buildPaymentSummaryCard(),
            const SizedBox(height: 16),
            _buildStatusDetailsCard(),
            if (_payment!.status == PaymentStatus.PENDING)
              _buildPendingInstructions(),
          ],
        ),
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
            'Payment Not Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Unable to load payment status',
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

  Widget _buildStatusTimeline() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimelineStep(
              'Payment Initiated',
              _formatDateTime(_payment!.createdAt),
              true,
              Icons.payment,
              Colors.blue,
            ),
            if (_payment!.method == PaymentMethod.UPI || _payment!.method == PaymentMethod.COMBINED)
              _buildTimelineStep(
                'Under Review',
                _payment!.status == PaymentStatus.PENDING ? 'In Progress' : 'Completed',
                _payment!.status != PaymentStatus.PENDING,
                Icons.rate_review,
                _payment!.status == PaymentStatus.PENDING ? Colors.orange : Colors.green,
              ),
            _buildTimelineStep(
              _getStatusTitle(),
              _getStatusSubtitle(),
              _payment!.status != PaymentStatus.PENDING,
              _getStatusIcon(),
              _getStatusColor(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(
    String title,
    String subtitle,
    bool isCompleted,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted ? color : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? icon : Icons.radio_button_unchecked,
              color: isCompleted ? Colors.white : Colors.grey[600],
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.black : Colors.grey[600],
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount'),
                Text(
                  '₹${_payment!.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payment Method'),
                Text(_payment!.methodDisplayText),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Receipt Number'),
                Text(_payment!.receiptNumber),
              ],
            ),
            if (_payment!.transactionId != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transaction ID'),
                  Flexible(
                    child: Text(
                      _payment!.transactionId!,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDetailsCard() {
    return Card(
      color: _getStatusColor().withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _payment!.statusDisplayText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getStatusDescription(),
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            if (_payment!.approvedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Updated: ${_formatDateTime(_payment!.approvedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingInstructions() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                ),
                SizedBox(width: 8),
                Text(
                  'What happens next?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '• Your payment is being reviewed by our team\n'
              '• You will receive a notification once approved\n'
              '• This usually takes 1-2 business days\n'
              '• You can check status anytime from payment history',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _refreshStatus,
                child: const Text('Refresh Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusTitle() {
    switch (_payment!.status) {
      case PaymentStatus.PENDING:
        return 'Pending Approval';
      case PaymentStatus.APPROVED:
        return 'Payment Approved';
      case PaymentStatus.REJECTED:
        return 'Payment Rejected';
      case PaymentStatus.INCOMPLETE:
        return 'Payment Incomplete';
    }
  }

  String _getStatusSubtitle() {
    switch (_payment!.status) {
      case PaymentStatus.PENDING:
        return 'Awaiting admin approval';
      case PaymentStatus.APPROVED:
        return _payment!.approvedAt != null 
            ? _formatDateTime(_payment!.approvedAt!)
            : 'Approved';
      case PaymentStatus.REJECTED:
        return _payment!.approvedAt != null 
            ? _formatDateTime(_payment!.approvedAt!)
            : 'Rejected';
      case PaymentStatus.INCOMPLETE:
        return 'Payment not completed';
    }
  }

  IconData _getStatusIcon() {
    switch (_payment!.status) {
      case PaymentStatus.PENDING:
        return Icons.pending;
      case PaymentStatus.APPROVED:
        return Icons.check_circle;
      case PaymentStatus.REJECTED:
        return Icons.cancel;
      case PaymentStatus.INCOMPLETE:
        return Icons.schedule;
    }
  }

  Color _getStatusColor() {
    switch (_payment!.status) {
      case PaymentStatus.PENDING:
        return Colors.orange;
      case PaymentStatus.APPROVED:
        return Colors.green;
      case PaymentStatus.REJECTED:
        return Colors.red;
      case PaymentStatus.INCOMPLETE:
        return Colors.grey;
    }
  }

  String _getStatusDescription() {
    switch (_payment!.status) {
      case PaymentStatus.PENDING:
        if (_payment!.method == PaymentMethod.WALLET) {
          return 'Your wallet payment has been processed successfully.';
        }
        return 'Your payment is under review. You will be notified once it\'s approved.';
      case PaymentStatus.APPROVED:
        return 'Your payment has been approved and processed successfully.';
      case PaymentStatus.REJECTED:
        return 'Your payment has been rejected. Please contact support for more information.';
      case PaymentStatus.INCOMPLETE:
        return 'Your payment was not completed. Please try again.';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}