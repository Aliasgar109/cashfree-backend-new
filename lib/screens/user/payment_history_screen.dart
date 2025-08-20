import 'package:flutter/material.dart';
import '../../services/supabase_payment_service.dart';
import '../../services/auth_service.dart';
import '../../models/payment_model.dart';
import '../../theme/theme.dart';
import 'payment_status_screen.dart';

/// Payment history screen showing payment transaction details
class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final SupabasePaymentService _paymentService = SupabasePaymentService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  
  List<PaymentModel> _allPayments = [];
  List<PaymentModel> _filteredPayments = [];
  bool _isLoading = true;
  String? _error;
  PaymentMethod? _selectedMethod;
  PaymentStatus? _selectedStatus;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    _loadPayments();
    _searchController.addListener(_filterPayments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      _paymentService.getUserPayments(user.uid).listen(
        (payments) {
          setState(() {
            _allPayments = payments;
            _isLoading = false;
          });
          _filterPayments();
        },
        onError: (error) {
          setState(() {
            _error = error.toString();
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterPayments() {
    List<PaymentModel> filtered = List.from(_allPayments);

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((payment) {
        return payment.receiptNumber.toLowerCase().contains(searchQuery) ||
               payment.id.toLowerCase().contains(searchQuery) ||
               (payment.transactionId?.toLowerCase().contains(searchQuery) ?? false);
      }).toList();
    }

    // Apply method filter
    if (_selectedMethod != null) {
      filtered = filtered.where((payment) => payment.method == _selectedMethod).toList();
    }

    // Apply status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((payment) => payment.status == _selectedStatus).toList();
    }

    // Apply year filter
    if (_selectedYear != null) {
      filtered = filtered.where((payment) => payment.year == _selectedYear).toList();
    }

    setState(() {
      _filteredPayments = filtered;
    });
  }

  void _showFilterDialog() {
    PaymentMethod? tempMethod = _selectedMethod;
    PaymentStatus? tempStatus = _selectedStatus;
    int? tempYear = _selectedYear;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Payments'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<PaymentMethod?>(
                  value: tempMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Methods')),
                    ...PaymentMethod.values.map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(method.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => tempMethod = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<PaymentStatus?>(
                  value: tempStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Statuses')),
                    ...PaymentStatus.values.map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => tempStatus = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  value: tempYear,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Years')),
                    ...List.generate(5, (index) {
                      final year = DateTime.now().year - index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                  ],
                  onChanged: (value) => setDialogState(() => tempYear = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedMethod = null;
                  _selectedStatus = null;
                  _selectedYear = null;
                });
                _filterPayments();
                Navigator.of(context).pop();
              },
              child: const Text('Clear All'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedMethod = tempMethod;
                  _selectedStatus = tempStatus;
                  _selectedYear = tempYear;
                });
                _filterPayments();
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedMethod = null;
      _selectedStatus = null;
      _selectedYear = null;
    });
    _searchController.clear();
    _filterPayments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          if (_selectedMethod != null || _selectedStatus != null || _selectedYear != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPayments,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPayments,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSearchAndFilters(),
        Expanded(
          child: _filteredPayments.isEmpty
              ? _buildEmptyState()
              : _buildPaymentsList(),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by receipt number, payment ID, or transaction ID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterPayments();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (_selectedMethod != null || _selectedStatus != null || _selectedYear != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedMethod != null)
                    Chip(
                      label: Text('Method: ${_selectedMethod!.name}'),
                      onDeleted: () {
                        setState(() => _selectedMethod = null);
                        _filterPayments();
                      },
                    ),
                  if (_selectedStatus != null)
                    Chip(
                      label: Text('Status: ${_selectedStatus!.name}'),
                      onDeleted: () {
                        setState(() => _selectedStatus = null);
                        _filterPayments();
                      },
                    ),
                  if (_selectedYear != null)
                    Chip(
                      label: Text('Year: $_selectedYear'),
                      onDeleted: () {
                        setState(() => _selectedYear = null);
                        _filterPayments();
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _allPayments.isEmpty ? 'No payments found' : 'No payments match your filters',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _allPayments.isEmpty 
                ? 'Your payment history will appear here'
                : 'Try adjusting your search or filters',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredPayments.length,
      itemBuilder: (context, index) {
        final payment = _filteredPayments[index];
        return _buildPaymentCard(payment);
      },
    );
  }

  Widget _buildPaymentCard(PaymentModel payment) {
    Color statusColor;
    IconData statusIcon;
    
    switch (payment.status) {
      case PaymentStatus.PENDING:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case PaymentStatus.APPROVED:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PaymentStatus.REJECTED:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case PaymentStatus.INCOMPLETE:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        break;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PaymentStatusScreen(paymentId: payment.id),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TV Subscription ${payment.year}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Receipt: ${payment.receiptNumber}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _formatDateTime(payment.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
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
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildStatusChip(payment.status),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip('Method', payment.methodDisplayText),
                  const SizedBox(width: 8),
                  if (payment.extraCharges > 0)
                    _buildInfoChip('Extra', '₹${payment.extraCharges.toStringAsFixed(2)}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(PaymentStatus status) {
    Color color;
    switch (status) {
      case PaymentStatus.APPROVED:
        color = Colors.green;
        break;
      case PaymentStatus.PENDING:
        color = Colors.orange;
        break;
      case PaymentStatus.REJECTED:
        color = Colors.red;
        break;
      case PaymentStatus.INCOMPLETE:
        color = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.name,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}