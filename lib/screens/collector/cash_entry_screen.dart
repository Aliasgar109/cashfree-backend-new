import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_model.dart';
import '../../models/payment_model.dart';
import '../../services/supabase_user_service.dart';
import '../../services/supabase_payment_service.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_receipt_service.dart';
import '../../services/whatsapp_service.dart';
import '../../theme/theme.dart';

/// Screen for collectors to enter cash payments
class CashEntryScreen extends StatefulWidget {
  const CashEntryScreen({super.key});

  @override
  State<CashEntryScreen> createState() => _CashEntryScreenState();
}

class _CashEntryScreenState extends State<CashEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  final _extraChargesController = TextEditingController();
  final _wireChargesController = TextEditingController();
  final _notesController = TextEditingController();

  final SupabaseUserService _userService = SupabaseUserService();
  final SupabasePaymentService _paymentService = SupabasePaymentService();
  final AuthService _authService = AuthService();
  final SupabaseReceiptService _receiptService = SupabaseReceiptService();
  final WhatsAppService _whatsAppService = WhatsAppService();

  UserModel? _selectedUser;
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  bool _isProcessing = false;
  double _wireLength = 0.0;
  FeeCalculation? _feeCalculation;

  @override
  void initState() {
    super.initState();
    _amountController.text = '1000'; // Default yearly fee
    _calculateFees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _extraChargesController.dispose();
    _wireChargesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      List<UserModel> results = [];
      
      // Search by name
      final nameResults = await _userService.searchUsersByName(query);
      results.addAll(nameResults);
      
      // Search by phone number if query looks like a phone number
      if (RegExp(r'^\d+$').hasMatch(query)) {
        final phoneUser = await _userService.getUserByPhoneNumber(query);
        if (phoneUser != null && !results.any((u) => u.id == phoneUser.id)) {
          results.add(phoneUser);
        }
      }

      // Filter to only show regular users (not collectors/admins)
      results = results.where((user) => user.role == UserRole.USER && user.isActive).toList();

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectUser(UserModel user) {
    setState(() {
      _selectedUser = user;
      _searchController.text = '${user.name} (${user.phoneNumber})';
      _searchResults = [];
    });
    _calculateFees();
  }

  Future<void> _calculateFees() async {
    if (_selectedUser == null) return;

    try {
      final amount = double.tryParse(_amountController.text) ?? 1000.0;
      final extraCharges = double.tryParse(_extraChargesController.text) ?? 0.0;
      
      final calculation = await _paymentService.calculateYearlyFee(
        userId: _selectedUser!.id,
        customAmount: amount,
        extraCharges: extraCharges,
        wireLength: _wireLength > 0 ? _wireLength : null,
      );

      setState(() {
        _feeCalculation = calculation;
      });
    } catch (e) {
      // Handle calculation error silently
    }
  }

  Future<void> _processCashPayment() async {
    if (!_formKey.currentState!.validate() || _selectedUser == null) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Collector not authenticated');
      }

      final amount = double.parse(_amountController.text);
      final extraCharges = double.parse(_extraChargesController.text.isEmpty ? '0' : _extraChargesController.text);
      final totalAmount = amount + extraCharges;

      // Create cash payment
      final paymentResult = await _paymentService.createPayment(
        userId: _selectedUser!.id,
        amount: totalAmount,
        method: PaymentMethod.CASH,
        extraCharges: extraCharges,
        note: _notesController.text.isEmpty ? 'Cash payment collected by ${currentUser.uid}' : _notesController.text,
      );

      if (!paymentResult.success || paymentResult.paymentId == null) {
        throw Exception(paymentResult.error ?? 'Failed to create payment');
      }

      // Auto-approve cash payments and generate receipt
      final updateResult = await _paymentService.updatePaymentStatus(
        paymentId: paymentResult.paymentId!,
        newStatus: PaymentStatus.APPROVED,
        adminId: currentUser.uid,
      );

      if (!updateResult.success) {
        throw Exception(updateResult.error ?? 'Failed to approve payment');
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash payment recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reset form
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
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

  void _resetForm() {
    setState(() {
      _selectedUser = null;
      _feeCalculation = null;
      _wireLength = 0.0;
    });
    _searchController.clear();
    _amountController.text = '1000';
    _extraChargesController.clear();
    _wireChargesController.clear();
    _notesController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Entry'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedUser != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetForm,
              tooltip: 'Reset Form',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User selection section
              _buildUserSelectionSection(l10n),
              const SizedBox(height: 24),

              // Payment details section
              if (_selectedUser != null) ...[
                _buildPaymentDetailsSection(l10n),
                const SizedBox(height: 24),
              ],

              // Fee breakdown section
              if (_feeCalculation != null) ...[
                _buildFeeBreakdownSection(l10n),
                const SizedBox(height: 24),
              ],

              // Submit button
              if (_selectedUser != null)
                _buildSubmitSection(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserSelectionSection(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select User',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by name or phone number',
                hintText: 'Enter name or phone number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _selectedUser != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _selectedUser = null;
                                _feeCalculation = null;
                              });
                              _searchController.clear();
                            },
                          )
                        : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _searchUsers,
              validator: (value) {
                if (_selectedUser == null) {
                  return 'Please select a user';
                }
                return null;
              },
            ),
            
            // Search results
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user.name.substring(0, 1).toUpperCase()),
                      ),
                      title: Text(user.name),
                      subtitle: Text('${user.phoneNumber} • ${user.area}'),
                      onTap: () => _selectUser(user),
                    );
                  },
                ),
              ),
            ],

            // Selected user display
            if (_selectedUser != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Text(
                        _selectedUser!.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedUser!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _selectedUser!.phoneNumber,
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            _selectedUser!.area,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailsSection(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.paymentDetails,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Base amount
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: l10n.baseAmount,
                prefixText: '₹',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Amount is required';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Please enter a valid amount';
                }
                return null;
              },
              onChanged: (value) => _calculateFees(),
            ),
            const SizedBox(height: 16),

            // Extra charges
            TextFormField(
              controller: _extraChargesController,
              decoration: InputDecoration(
                labelText: l10n.extraCharges,
                prefixText: '₹',
                hintText: '0',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final amount = double.tryParse(value);
                  if (amount == null || amount < 0) {
                    return 'Please enter a valid amount';
                  }
                }
                return null;
              },
              onChanged: (value) => _calculateFees(),
            ),
            const SizedBox(height: 16),

            // Wire length for wire charges
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _wireChargesController,
                    decoration: const InputDecoration(
                      labelText: 'Wire Length (meters)',
                      hintText: '0',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    onChanged: (value) {
                      _wireLength = double.tryParse(value) ?? 0.0;
                      _calculateFees();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹5/meter',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Additional notes about the payment',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeBreakdownSection(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.feeBreakdown,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildFeeRow(l10n.baseAmount, _feeCalculation!.baseAmount),
            
            if (_feeCalculation!.extraCharges > 0)
              _buildFeeRow(l10n.extraCharges, _feeCalculation!.extraCharges),
            
            if (_feeCalculation!.wireCharges > 0)
              _buildFeeRow(l10n.wireCharges, _feeCalculation!.wireCharges),
            
            if (_feeCalculation!.lateFees > 0) ...[
              _buildFeeRow(l10n.lateFees, _feeCalculation!.lateFees),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Late fees applied for previous unpaid years',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const Divider(),
            _buildFeeRow(
              l10n.totalAmount,
              _feeCalculation!.totalAmount,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitSection(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processCashPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isProcessing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Processing...'),
                ],
              )
            : const Text(
                'Record Cash Payment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}