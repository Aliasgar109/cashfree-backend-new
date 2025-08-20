import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/supabase_payment_service.dart';
import '../../services/supabase_user_service.dart';
import '../../models/payment_model.dart';
import '../../models/user_model.dart';
import '../../theme/theme.dart';

/// Detailed view of a payment for admin review and approval
class PaymentDetailScreen extends StatefulWidget {
  final String paymentId;
  
  const PaymentDetailScreen({
    super.key,
    required this.paymentId,
  });

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  final SupabasePaymentService _paymentService = SupabasePaymentService();
  final SupabaseUserService _userService = SupabaseUserService();
  
  PaymentModel? _payment;
  UserModel? _user;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPaymentDetails();
  }

  Future<void> _loadPaymentDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final payment = await _paymentService.getPayment(widget.paymentId);
      if (payment == null) {
        setState(() {
          _error = 'Payment not found';
          _isLoading = false;
        });
        return;
      }

      final user = await _userService.getUserById(payment.userId);
      
      if (mounted) {
        setState(() {
          _payment = payment;
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load payment details: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Details'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_payment != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadPaymentDetails,
              tooltip: l10n.refreshStatus,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView(theme)
              : _payment != null
                  ? _buildPaymentDetailView(l10n, theme)
                  : _buildNotFoundView(theme),
      bottomNavigationBar: _payment?.status == PaymentStatus.PENDING
          ? _buildActionButtons(l10n, theme)
          : null,
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _error!,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadPaymentDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Payment Not Found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The requested payment could not be found.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailView(AppLocalizations l10n, ThemeData theme) {
    final payment = _payment!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status header
          _buildStatusHeader(payment, l10n, theme),
          const SizedBox(height: 24),
          
          // User information
          _buildUserInfoCard(l10n, theme),
          const SizedBox(height: 16),
          
          // Payment information
          _buildPaymentInfoCard(payment, l10n, theme),
          const SizedBox(height: 16),
          
          // Transaction details (for UPI/Combined payments)
          if (payment.method == PaymentMethod.UPI || payment.method == PaymentMethod.COMBINED)
            _buildTransactionDetailsCard(payment, l10n, theme),
          
          // Screenshot display (if available)
          if (payment.screenshotUrl != null) ...[
            const SizedBox(height: 16),
            _buildScreenshotCard(payment, l10n, theme),
          ],
          
          // Payment timeline
          const SizedBox(height: 16),
          _buildPaymentTimelineCard(payment, l10n, theme),
          
          // Add bottom padding for action buttons
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(PaymentModel payment, AppLocalizations l10n, ThemeData theme) {
    final statusColor = _getStatusColor(payment.status);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            _getStatusIcon(payment.status),
            size: 48,
            color: statusColor,
          ),
          const SizedBox(height: 12),
          Text(
            _getStatusDisplayText(payment.status, l10n),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${payment.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            payment.methodDisplayText,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Information',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_user != null) ...[
              _buildInfoRow('Name', _user!.name, Icons.person, theme),
              _buildInfoRow('Phone', _user!.phoneNumber, Icons.phone, theme),
              _buildInfoRow('Address', _user!.address, Icons.location_on, theme),
              if (_user!.area.isNotEmpty)
                _buildInfoRow('Area', _user!.area, Icons.map, theme),
            ] else
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoCard(PaymentModel payment, AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.paymentDetails,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(l10n.receiptNumber, payment.receiptNumber, Icons.receipt, theme),
            _buildInfoRow('Payment Method', payment.methodDisplayText, Icons.payment, theme),
            _buildInfoRow('Year', payment.year.toString(), Icons.calendar_today, theme),
            _buildInfoRow('Created', _formatDateTime(payment.createdAt), Icons.access_time, theme),
            
            if (payment.approvedAt != null) ...[
              _buildInfoRow('Approved', _formatDateTime(payment.approvedAt!), Icons.check_circle, theme),
              if (payment.approvedBy != null)
                _buildInfoRow('Approved By', payment.approvedBy!, Icons.admin_panel_settings, theme),
            ],
            
            const Divider(height: 24),
            
            // Amount breakdown
            Text(
              l10n.feeBreakdown,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildAmountRow(l10n.baseAmount, payment.amount, theme),
            if (payment.extraCharges > 0)
              _buildAmountRow(l10n.extraCharges, payment.extraCharges, theme),
            const Divider(height: 16),
            _buildAmountRow(l10n.totalAmount, payment.totalAmount, theme, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionDetailsCard(PaymentModel payment, AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction Details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            if (payment.transactionId != null)
              _buildInfoRow(l10n.transactionId, payment.transactionId!, Icons.confirmation_number, theme),
            
            if (payment.method == PaymentMethod.COMBINED) ...[
              if (payment.walletAmountUsed != null)
                _buildAmountRow('Wallet Amount', payment.walletAmountUsed!, theme),
              if (payment.upiAmountPaid != null)
                _buildAmountRow('UPI Amount', payment.upiAmountPaid!, theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScreenshotCard(PaymentModel payment, AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Screenshot',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  payment.screenshotUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: theme.colorScheme.errorContainer,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load screenshot',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Implement full-screen image view
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(payment.screenshotUrl!),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('View Full Size'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTimelineCard(PaymentModel payment, AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.paymentTimeline,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              'Payment Created',
              _formatDateTime(payment.createdAt),
              Icons.add_circle,
              Colors.blue,
              isCompleted: true,
              theme: theme,
            ),
            if (payment.status == PaymentStatus.PENDING)
              _buildTimelineItem(
                l10n.underReview,
                'Waiting for admin approval',
                Icons.pending,
                Colors.orange,
                isCompleted: false,
                isActive: true,
                theme: theme,
              ),
            if (payment.status == PaymentStatus.APPROVED)
              _buildTimelineItem(
                'Payment Approved',
                payment.approvedAt != null ? _formatDateTime(payment.approvedAt!) : 'Approved',
                Icons.check_circle,
                Colors.green,
                isCompleted: true,
                theme: theme,
              ),
            if (payment.status == PaymentStatus.REJECTED)
              _buildTimelineItem(
                'Payment Rejected',
                payment.approvedAt != null ? _formatDateTime(payment.approvedAt!) : 'Rejected',
                Icons.cancel,
                Colors.red,
                isCompleted: true,
                theme: theme,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    required bool isCompleted,
    bool isActive = false,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted || isActive ? color : color.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
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
                    color: isCompleted || isActive ? color : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, double amount, ThemeData theme, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? null : theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : () => _rejectPayment(l10n),
              icon: const Icon(Icons.close),
              label: const Text('Reject Payment'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _approvePayment(l10n),
              icon: _isProcessing 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isProcessing ? l10n.processing : 'Approve Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approvePayment(AppLocalizations l10n) async {
    final confirmed = await _showConfirmationDialog(
      title: 'Approve Payment',
      message: 'Are you sure you want to approve this payment of ₹${_payment!.totalAmount.toStringAsFixed(2)}?\n\nThis will generate a receipt and notify the user.',
      confirmText: 'Approve',
      confirmColor: Colors.green,
    );

    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _paymentService.updatePaymentStatus(
        paymentId: _payment!.id,
        newStatus: PaymentStatus.APPROVED,
        adminId: 'current_admin_id', // TODO: Get from auth service
      );

      if (result.success) {
        // Reload payment details to show updated status
        await _loadPaymentDetails();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Payment approved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to approve payment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _rejectPayment(AppLocalizations l10n) async {
    final rejectionReason = await _showRejectionDialog();
    if (rejectionReason == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _paymentService.updatePaymentStatus(
        paymentId: _payment!.id,
        newStatus: PaymentStatus.REJECTED,
        adminId: 'current_admin_id', // TODO: Get from auth service
        rejectionReason: rejectionReason,
      );

      if (result.success) {
        // Reload payment details to show updated status
        await _loadPaymentDetails();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'Payment rejected successfully'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to reject payment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _showRejectionDialog() async {
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this payment:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isNotEmpty) {
                Navigator.of(context).pop(reason);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    
    controller.dispose();
    return result;
  }

  String _getStatusDisplayText(PaymentStatus status, AppLocalizations l10n) {
    switch (status) {
      case PaymentStatus.PENDING:
        return l10n.paymentPending;
      case PaymentStatus.APPROVED:
        return l10n.paymentApproved;
      case PaymentStatus.REJECTED:
        return l10n.paymentRejected;
      case PaymentStatus.INCOMPLETE:
        return 'Payment Incomplete';
    }
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
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

  IconData _getStatusIcon(PaymentStatus status) {
    switch (status) {
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}