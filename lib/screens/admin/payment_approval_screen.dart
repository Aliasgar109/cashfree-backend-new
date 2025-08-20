import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/supabase_payment_service.dart';
import '../../services/supabase_user_service.dart';
import '../../models/payment_model.dart';
import '../../models/user_model.dart';

import 'payment_detail_screen.dart';

/// Screen for reviewing and approving/rejecting payments
class PaymentApprovalScreen extends StatefulWidget {
  final String? initialPaymentId;
  
  const PaymentApprovalScreen({
    super.key,
    this.initialPaymentId,
  });

  @override
  State<PaymentApprovalScreen> createState() => _PaymentApprovalScreenState();
}

class _PaymentApprovalScreenState extends State<PaymentApprovalScreen> {
  final SupabasePaymentService _paymentService = SupabasePaymentService();
  final SupabaseUserService _userService = SupabaseUserService();
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  PaymentStatus _selectedStatus = PaymentStatus.PENDING;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPaymentId != null) {
      // If we have an initial payment ID, navigate to its detail screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToPaymentDetail(widget.initialPaymentId!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToPaymentDetail(String paymentId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentDetailScreen(paymentId: paymentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Approvals'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by user name, phone, or receipt number...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Status filter
                Row(
                  children: [
                    Text(
                      'Status: ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: PaymentStatus.values.map((status) {
                            final isSelected = _selectedStatus == status;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: FilterChip(
                                label: Text(_getStatusDisplayText(status, l10n)),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedStatus = status;
                                  });
                                },
                                backgroundColor: Colors.white.withOpacity(0.2),
                                selectedColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSelected ? theme.primaryColor : Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<PaymentModel>>(
        stream: _paymentService.getPaymentsByStatus(_selectedStatus),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
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
                    'Error loading payments',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final allPayments = snapshot.data ?? [];
          final filteredPayments = _filterPayments(allPayments);

          if (filteredPayments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedStatus == PaymentStatus.PENDING
                        ? Icons.check_circle_outline
                        : Icons.inbox_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedStatus == PaymentStatus.PENDING
                        ? 'No pending payments'
                        : 'No ${_getStatusDisplayText(_selectedStatus, l10n).toLowerCase()} payments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Try adjusting your search criteria'
                        : _selectedStatus == PaymentStatus.PENDING
                            ? 'All payments are up to date'
                            : 'No payments found for this status',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: filteredPayments.length,
            itemBuilder: (context, index) {
              final payment = filteredPayments[index];
              return _buildPaymentCard(payment, l10n, theme);
            },
          );
        },
      ),
    );
  }

  List<PaymentModel> _filterPayments(List<PaymentModel> payments) {
    if (_searchQuery.isEmpty) {
      return payments;
    }

    return payments.where((payment) {
      // Search by receipt number
      if (payment.receiptNumber.toLowerCase().contains(_searchQuery)) {
        return true;
      }
      
      // Search by transaction ID
      if (payment.transactionId?.toLowerCase().contains(_searchQuery) == true) {
        return true;
      }

      // We'll need to load user data to search by name/phone
      // For now, just return based on receipt number and transaction ID
      return false;
    }).toList();
  }

  Widget _buildPaymentCard(PaymentModel payment, AppLocalizations l10n, ThemeData theme) {
    return FutureBuilder<UserModel?>(
      future: _userService.getUserById(payment.userId),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        
        // Filter by user name/phone if we have user data and search query
        if (_searchQuery.isNotEmpty && user != null) {
          final matchesUser = user.name.toLowerCase().contains(_searchQuery) ||
                             user.phoneNumber.toLowerCase().contains(_searchQuery);
          if (!matchesUser && 
              !payment.receiptNumber.toLowerCase().contains(_searchQuery) &&
              !(payment.transactionId?.toLowerCase().contains(_searchQuery) == true)) {
            return const SizedBox.shrink();
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 2,
          child: InkWell(
            onTap: () => _navigateToPaymentDetail(payment.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getStatusColor(payment.status).withOpacity(0.2),
                        child: Icon(
                          _getPaymentMethodIcon(payment.method),
                          color: _getStatusColor(payment.status),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Loading...',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              user?.phoneNumber ?? '',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${payment.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(payment.status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getStatusDisplayText(payment.status, l10n),
                              style: TextStyle(
                                color: _getStatusColor(payment.status),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Payment details
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Method',
                          payment.methodDisplayText,
                          theme,
                        ),
                      ),
                      Expanded(
                        child: _buildDetailItem(
                          'Receipt',
                          payment.receiptNumber,
                          theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailItem(
                          'Date',
                          _formatDate(payment.createdAt),
                          theme,
                        ),
                      ),
                      if (payment.transactionId != null)
                        Expanded(
                          child: _buildDetailItem(
                            'Transaction ID',
                            payment.transactionId!,
                            theme,
                          ),
                        ),
                    ],
                  ),
                  
                  // Quick action buttons for pending payments
                  if (payment.status == PaymentStatus.PENDING) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isProcessing ? null : () => _rejectPayment(payment, l10n),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : () => _approvePayment(payment, l10n),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value, ThemeData theme) {
    return Column(
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
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _approvePayment(PaymentModel payment, AppLocalizations l10n) async {
    final confirmed = await _showConfirmationDialog(
      title: 'Approve Payment',
      message: 'Are you sure you want to approve this payment of ₹${payment.totalAmount.toStringAsFixed(2)}?',
      confirmText: 'Approve',
      confirmColor: Colors.green,
    );

    if (!confirmed) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _paymentService.updatePaymentStatus(
        paymentId: payment.id,
        newStatus: PaymentStatus.APPROVED,
        adminId: 'current_admin_id', // TODO: Get from auth service
      );

      if (result.success) {
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

  Future<void> _rejectPayment(PaymentModel payment, AppLocalizations l10n) async {
    final rejectionReason = await _showRejectionDialog();
    if (rejectionReason == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _paymentService.updatePaymentStatus(
        paymentId: payment.id,
        newStatus: PaymentStatus.REJECTED,
        adminId: 'current_admin_id', // TODO: Get from auth service
        rejectionReason: rejectionReason,
      );

      if (result.success) {
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
        return l10n.pending;
      case PaymentStatus.APPROVED:
        return l10n.approved;
      case PaymentStatus.REJECTED:
        return 'Rejected';
      case PaymentStatus.INCOMPLETE:
        return 'Incomplete';
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

  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.UPI:
        return Icons.payment;
      case PaymentMethod.CASH:
        return Icons.money;
      case PaymentMethod.WALLET:
        return Icons.account_balance_wallet;
      case PaymentMethod.COMBINED:
        return Icons.compare_arrows;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}