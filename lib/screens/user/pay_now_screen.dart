import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/payment_model.dart';
import '../../services/supabase_payment_service.dart';
import '../../services/supabase_wallet_service.dart';
import '../../services/cashfree_payment_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/cashfree_payment_method_selector.dart';
import '../../widgets/payment_amount_display.dart';
import '../../widgets/payment_confirmation_dialog.dart';
import 'payment_confirmation_screen.dart';


class PayNowScreen extends StatefulWidget {
  const PayNowScreen({super.key});

  @override
  State<PayNowScreen> createState() => _PayNowScreenState();
}

class _PayNowScreenState extends State<PayNowScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabasePaymentService _paymentService = SupabasePaymentService();
  final SupabaseWalletService _walletService = SupabaseWalletService();
  final CashfreePaymentService _cashfreeService = CashfreePaymentService.instance;
  final AuthService _authService = AuthService();

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();

  bool _isLoading = true;
  bool _isProcessing = false;
  FeeCalculation? _feeCalculation;
  double _walletBalance = 0.0;
  PaymentMethod _selectedMethod = PaymentMethod.CASHFREE_UPI;

  // Form validation
  String? _nameError;
  String? _mobileError;
  String? _areaError;

  @override
  void initState() {
    super.initState();
    _loadPaymentData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentData() async {
    try {
      setState(() => _isLoading = true);

      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Load wallet balance and fee calculation in parallel
      final results = await Future.wait([
        _walletService.getWalletBalance(user.uid),
        _paymentService.calculateYearlyFee(userId: user.uid),
      ]);

      setState(() {
        _walletBalance = results[0] as double;
        _feeCalculation = results[1] as FeeCalculation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load payment data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _validateName(String value) {
    setState(() {
      if (value.isEmpty) {
        _nameError = 'Full name is required';
      } else if (value.length < 2) {
        _nameError = 'Name must be at least 2 characters';
      } else if (value.length > 50) {
        _nameError = 'Name cannot exceed 50 characters';
      } else {
        _nameError = null;
      }
    });
  }

  void _validateMobile(String value) {
    setState(() {
      if (value.isEmpty) {
        _mobileError = 'Mobile number is required';
      } else if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
        _mobileError = 'Please enter a valid 10-digit mobile number';
      } else {
        _mobileError = null;
      }
    });
  }

  void _validateArea(String value) {
    setState(() {
      if (value.isEmpty) {
        _areaError = 'Area is required';
      } else if (value.length < 2) {
        _areaError = 'Area must be at least 2 characters';
      } else {
        _areaError = null;
      }
    });
  }

  bool get _canProceed {
    return _formKey.currentState?.validate() == true &&
        _feeCalculation != null &&
        _nameError == null &&
        _mobileError == null &&
        _areaError == null &&
        !_isProcessing;
  }

  Future<void> _processPayment() async {
    if (!_canProceed) return;

    // Show confirmation dialog first
    final confirmed = await _showPaymentConfirmationDialog();
    if (!confirmed) return;

    try {
      setState(() => _isProcessing = true);

      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final totalAmount = _feeCalculation!.totalAmount;

      dynamic result;

      // Check if it's a Cashfree payment method
      if (_isCashfreePaymentMethod(_selectedMethod)) {
        result = await _cashfreeService.processPaymentWithErrorHandling(
          userId: user.uid,
          amount: totalAmount,
          method: _selectedMethod,
          extraCharges: 0.0,
          note: 'TV Subscription Payment ${DateTime.now().year}',
        );
      } else {
        // Handle legacy payment methods
        switch (_selectedMethod) {
          case PaymentMethod.UPI:
            result = await _paymentService.processUPIPayment(
              userId: user.uid,
              amount: totalAmount,
              extraCharges: 0.0,
              note: 'TV Subscription Payment ${DateTime.now().year}',
            );
            break;

          case PaymentMethod.WALLET:
            result = await _paymentService.processWalletPayment(
              userId: user.uid,
              amount: totalAmount,
              extraCharges: 0.0,
              note: 'TV Subscription Payment ${DateTime.now().year}',
            );
            break;

          case PaymentMethod.COMBINED:
            result = await _paymentService.processCombinedPayment(
              userId: user.uid,
              amount: totalAmount,
              extraCharges: 0.0,
              note: 'TV Subscription Payment ${DateTime.now().year}',
            );
            break;

          case PaymentMethod.CASH:
            throw Exception('Cash payments are not available in this screen');
          
          default:
            throw Exception('Unsupported payment method: ${_selectedMethod.name}');
        }
      }

      setState(() => _isProcessing = false);

      if (result.success && result.paymentId != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PaymentConfirmationScreen(
                paymentId: result.paymentId!,
                paymentMethod: _selectedMethod,
                amount: totalAmount,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Payment failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment processing failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isCashfreePaymentMethod(PaymentMethod method) {
    return [
      PaymentMethod.CASHFREE_CARD,
      PaymentMethod.CASHFREE_UPI,
      PaymentMethod.CASHFREE_NETBANKING,
      PaymentMethod.CASHFREE_WALLET,
    ].contains(method);
  }

  Future<bool> _showPaymentConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentConfirmationDialog(
        amount: _feeCalculation!.baseAmount,
        extraCharges: _feeCalculation!.lateFees,
        paymentMethod: _selectedMethod,
        customerName: _nameController.text.trim(),
        customerPhone: _mobileController.text.trim(),
        customerArea: _areaController.text.trim(),
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
        isProcessing: false,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Now'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildPaymentForm(),
    );
  }

  Widget _buildPaymentForm() {
    if (_feeCalculation == null) {
      return const Center(child: Text('Failed to load payment information'));
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserDetailsCard(),
            const SizedBox(height: 16),
            _buildFeeBreakdownCard(),
            const SizedBox(height: 16),
            _buildPaymentMethodSelection(),
            const SizedBox(height: 24),
            _buildPaymentAmountDisplay(),
            const SizedBox(height: 24),
            _buildPaymentButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Full Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
                errorText: _nameError,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: _validateName,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Full name is required';
                }
                if (value.length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Mobile Number Field
            TextFormField(
              controller: _mobileController,
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone),
                errorText: _mobileError,
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: _validateMobile,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Mobile number is required';
                }
                if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                  return 'Please enter a valid 10-digit mobile number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Area Field
            TextFormField(
              controller: _areaController,
              decoration: InputDecoration(
                labelText: 'Area',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on),
                errorText: _areaError,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: _validateArea,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Area is required';
                }
                if (value.length < 2) {
                  return 'Area must be at least 2 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeBreakdownCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fee Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildFeeRow('Base Amount', _feeCalculation!.baseAmount),
            if (_feeCalculation!.lateFees > 0) ...[
              _buildFeeRow('Late Fees', _feeCalculation!.lateFees),
              Text(
                'Late fees applied at ${_feeCalculation!.lateFeesPercentage}% per year',
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            ],
            const Divider(),
            _buildFeeRow(
              'Total Amount',
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
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return CashfreePaymentMethodSelector(
      selectedMethod: _selectedMethod,
      onMethodChanged: (method) => setState(() => _selectedMethod = method),
      walletBalance: _walletBalance,
      totalAmount: _feeCalculation!.totalAmount,
      enabled: !_isProcessing,
    );
  }



  Widget _buildPaymentAmountDisplay() {
    return PaymentAmountDisplay(
      baseAmount: _feeCalculation!.baseAmount,
      extraCharges: 0.0,
      lateFees: _feeCalculation!.lateFees,
      showBreakdown: _feeCalculation!.lateFees > 0,
    );
  }

  Widget _buildPaymentButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _canProceed ? _processPayment : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Pay ₹${_feeCalculation!.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
