import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_settings_service.dart';
import '../../models/settings_model.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/theme.dart';

/// Admin screen for managing fees and charges
class FeeManagementScreen extends StatefulWidget {
  final String adminId;

  const FeeManagementScreen({
    Key? key,
    required this.adminId,
  }) : super(key: key);

  @override
  State<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends State<FeeManagementScreen> {
  final SupabaseSettingsService _settingsService = SupabaseSettingsService();
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  final _yearlyFeeController = TextEditingController();
  final _lateFeesController = TextEditingController();
  final _wireChargeController = TextEditingController();
  final _reminderDaysController = TextEditingController();
  
  bool _autoApprovalEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  SettingsModel? _currentSettings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _yearlyFeeController.dispose();
    _lateFeesController.dispose();
    _wireChargeController.dispose();
    _reminderDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);
      
      final settings = await _settingsService.getSettings();
      
      setState(() {
        _currentSettings = settings;
        _yearlyFeeController.text = settings.yearlyFee.toStringAsFixed(2);
        _lateFeesController.text = settings.lateFeesPercentage.toStringAsFixed(1);
        _wireChargeController.text = settings.wireChargePerMeter.toStringAsFixed(2);
        _reminderDaysController.text = settings.reminderDaysBefore.toString();
        _autoApprovalEnabled = settings.autoApprovalEnabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isSaving = true);

      final yearlyFee = double.parse(_yearlyFeeController.text);
      final lateFeesPercentage = double.parse(_lateFeesController.text);
      final wireChargePerMeter = double.parse(_wireChargeController.text);
      final reminderDays = int.parse(_reminderDaysController.text);

      final updatedSettings = _currentSettings!.copyWith(
        yearlyFee: yearlyFee,
        lateFeesPercentage: lateFeesPercentage,
        wireChargePerMeter: wireChargePerMeter,
        autoApprovalEnabled: _autoApprovalEnabled,
        reminderDaysBefore: reminderDays,
        lastUpdatedBy: widget.adminId,
      );

      final result = await _settingsService.updateSettings(
        settings: updatedSettings,
        updatedBy: widget.adminId,
      );

      setState(() => _isSaving = false);

      if (result.success) {
        _showSuccessSnackBar(result.message ?? 'Settings updated successfully');
        await _loadSettings(); // Reload to show updated values
      } else {
        _showErrorSnackBar(result.error ?? 'Failed to update settings');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar('Failed to save settings: $e');
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await _showConfirmationDialog(
      'Reset to Defaults',
      'Are you sure you want to reset all settings to default values? This action cannot be undone.',
    );

    if (!confirmed) return;

    try {
      setState(() => _isSaving = true);

      final result = await _settingsService.resetToDefaults(
        updatedBy: widget.adminId,
      );

      setState(() => _isSaving = false);

      if (result.success) {
        _showSuccessSnackBar(result.message ?? 'Settings reset successfully');
        await _loadSettings();
      } else {
        _showErrorSnackBar(result.error ?? 'Failed to reset settings');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar('Failed to reset settings: $e');
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLogoutDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.logout),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(l10n.logout),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        );
      },
    );
  }

  void _testAdminClient() async {
    try {
      final result = await _settingsService.testAdminClientAccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result ? 'Admin client test passed!' : 'Admin client test failed!'),
            backgroundColor: result ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.feeManagement),
        actions: [
          if (!_isLoading && !_isSaving)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'reset') {
                  _resetToDefaults();
                } else if (value == 'test') {
                  _testAdminClient();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'test',
                  child: Row(
                    children: [
                      const Icon(Icons.security, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Test Admin Client'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      const Icon(Icons.restore, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(l10n.resetToDefaults),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 200,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSettingsCard(),
                      const SizedBox(height: 16),
                      _buildCalculationPreview(),
                      const SizedBox(height: 24),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSettingsCard() {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.feeConfiguration,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            // Yearly Fee
            TextFormField(
              controller: _yearlyFeeController,
              decoration: InputDecoration(
                labelText: l10n.yearlyFee,
                prefixText: '₹ ',
                suffixText: '₹',
                border: const OutlineInputBorder(),
                helperText: l10n.yearlyFeeHelp,
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.pleaseEnterYearlyFee;
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return l10n.pleaseEnterValidAmount;
                }
                if (amount > 100000) {
                  return l10n.amountTooHigh;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Late Fees Percentage
            TextFormField(
              controller: _lateFeesController,
              decoration: InputDecoration(
                labelText: l10n.lateFeesPercentage,
                suffixText: '%',
                border: const OutlineInputBorder(),
                helperText: l10n.lateFeesHelp,
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.pleaseEnterLateFeesPercentage;
                }
                final percentage = double.tryParse(value);
                if (percentage == null || percentage < 0 || percentage > 100) {
                  return l10n.pleaseEnterValidPercentage;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Wire Charge Per Meter
            TextFormField(
              controller: _wireChargeController,
              decoration: InputDecoration(
                labelText: l10n.wireChargePerMeter,
                prefixText: '₹ ',
                suffixText: '/m',
                border: const OutlineInputBorder(),
                helperText: l10n.wireChargeHelp,
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.pleaseEnterWireCharge;
                }
                final charge = double.tryParse(value);
                if (charge == null || charge < 0) {
                  return l10n.pleaseEnterValidCharge;
                }
                if (charge > 1000) {
                  return l10n.chargeTooHigh;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Reminder Days
            TextFormField(
              controller: _reminderDaysController,
              decoration: InputDecoration(
                labelText: l10n.reminderDaysBefore,
                suffixText: 'days',
                border: const OutlineInputBorder(),
                helperText: l10n.reminderDaysHelp,
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.pleaseEnterReminderDays;
                }
                final days = int.tryParse(value);
                if (days == null || days <= 0) {
                  return l10n.pleaseEnterValidDays;
                }
                if (days > 365) {
                  return l10n.daysTooHigh;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Auto Approval Toggle
            SwitchListTile(
              title: Text(l10n.autoApproval),
              subtitle: Text(l10n.autoApprovalHelp),
              value: _autoApprovalEnabled,
              onChanged: (value) {
                setState(() => _autoApprovalEnabled = value);
              },
            ),

            if (_currentSettings != null) ...[
              const Divider(height: 32),
              Text(
                l10n.lastUpdated,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${_currentSettings!.lastUpdated.toString().split('.')[0]} by ${_currentSettings!.lastUpdatedBy}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationPreview() {
    final l10n = AppLocalizations.of(context)!;
    
    if (_currentSettings == null) return const SizedBox.shrink();

    final yearlyFee = double.tryParse(_yearlyFeeController.text) ?? _currentSettings!.yearlyFee;
    final lateFeesPercentage = double.tryParse(_lateFeesController.text) ?? _currentSettings!.lateFeesPercentage;
    final wireChargePerMeter = double.tryParse(_wireChargeController.text) ?? _currentSettings!.wireChargePerMeter;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.calculationPreview,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            
            _buildPreviewRow(l10n.baseYearlyFee, '₹${yearlyFee.toStringAsFixed(2)}'),
            _buildPreviewRow(l10n.wireChargeExample, '₹${(wireChargePerMeter * 10).toStringAsFixed(2)} (10 meters)'),
            _buildPreviewRow(l10n.lateFeesExample, '₹${(yearlyFee * lateFeesPercentage / 100).toStringAsFixed(2)} (1 year overdue)'),
            
            const Divider(),
            _buildPreviewRow(
              l10n.totalExample,
              '₹${(yearlyFee + (wireChargePerMeter * 10) + (yearlyFee * lateFeesPercentage / 100)).toStringAsFixed(2)}',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: isTotal 
                  ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                  : Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: isTotal 
                  ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                  : Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l10n.saveSettings),
      ),
    );
  }
}