import 'package:flutter/material.dart';
import '../../services/supabase_reminder_service.dart';
import '../../services/supabase_settings_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../theme/dimensions.dart';

/// Screen for configuring automated reminder settings
class ReminderSettingsScreen extends StatefulWidget {
  final String adminUserId;

  const ReminderSettingsScreen({
    Key? key,
    required this.adminUserId,
  }) : super(key: key);

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final SupabaseReminderService _reminderService = SupabaseReminderService();
  final SupabaseSettingsService _settingsService = SupabaseSettingsService();
  
  final _formKey = GlobalKey<FormState>();
  final _reminderDaysController = TextEditingController();
  final _escalationDaysController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _enableAutomaticReminders = true;
  bool _enableEscalatedReminders = true;
  
  ReminderConfig? _currentConfig;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadReminderConfig();
  }

  @override
  void dispose() {
    _reminderDaysController.dispose();
    _escalationDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadReminderConfig() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final config = await _reminderService.getReminderConfig();
      
      setState(() {
        _currentConfig = config;
        _enableAutomaticReminders = config.enableAutomaticReminders;
        _enableEscalatedReminders = config.enableEscalatedReminders;
        _reminderDaysController.text = config.reminderDaysBefore.toString();
        _escalationDaysController.text = config.escalationDays.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load reminder configuration: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveReminderConfig() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
        _successMessage = null;
      });

      final reminderDays = int.parse(_reminderDaysController.text);
      final escalationDays = int.parse(_escalationDaysController.text);

      await _reminderService.configureReminderSettings(
        reminderDaysBefore: reminderDays,
        enableAutomaticReminders: _enableAutomaticReminders,
        enableEscalatedReminders: _enableEscalatedReminders,
        escalationDays: escalationDays,
        updatedBy: widget.adminUserId,
      );

      setState(() {
        _successMessage = 'Settings saved successfully';
      });

      // Reload config to reflect changes
      await _loadReminderConfig();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save reminder configuration: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _scheduleReminders() async {
    try {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
        _successMessage = null;
      });

      await _reminderService.scheduleAutomaticReminders();

      setState(() {
        _successMessage = 'Reminders scheduled successfully';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to schedule reminders: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _sendEscalatedReminders() async {
    try {
      setState(() {
        _isSaving = true;
        _errorMessage = null;
        _successMessage = null;
      });

      await _reminderService.sendEscalatedReminders();

      setState(() {
        _successMessage = 'Escalated reminders sent successfully';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send escalated reminders: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Settings'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusMessages(),
                    const SizedBox(height: AppDimensions.spacingMd),
                    _buildConfigurationSection(),
                    const SizedBox(height: AppDimensions.spacingLg),
                    _buildActionsSection(),
                    const SizedBox(height: AppDimensions.spacingLg),
                    _buildStatsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusMessages() {
    return Column(
      children: [
        if (_errorMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: AppColors.error),
            ),
            child: Row(
              children: [
                Icon(Icons.error, color: AppColors.error),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        if (_successMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: AppColors.success),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: Text(
                    _successMessage!,
                    style: TextStyle(color: AppColors.success),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildConfigurationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reminder Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            
            // Automatic Reminders Toggle
            SwitchListTile(
              title: const Text('Enable Automatic Reminders'),
              subtitle: const Text('Send reminders before payment due date'),
              value: _enableAutomaticReminders,
              onChanged: (value) {
                setState(() {
                  _enableAutomaticReminders = value;
                });
              },
            ),
            
            // Reminder Days Before
            TextFormField(
              controller: _reminderDaysController,
              decoration: const InputDecoration(
                labelText: 'Reminder Days Before Due Date',
                hintText: 'Enter number of days',
                suffixText: 'days',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter reminder days';
                }
                final days = int.tryParse(value);
                if (days == null || days <= 0 || days > 365) {
                  return 'Please enter a valid number between 1 and 365';
                }
                return null;
              },
            ),
            
            const SizedBox(height: AppDimensions.spacingMd),
            
            // Escalated Reminders Toggle
            SwitchListTile(
              title: const Text('Enable Escalated Reminders'),
              subtitle: const Text('Send additional reminders for overdue payments'),
              value: _enableEscalatedReminders,
              onChanged: (value) {
                setState(() {
                  _enableEscalatedReminders = value;
                });
              },
            ),
            
            // Escalation Days
            TextFormField(
              controller: _escalationDaysController,
              decoration: const InputDecoration(
                labelText: 'Escalation Interval',
                hintText: 'Days between escalated reminders',
                suffixText: 'days',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter escalation days';
                }
                final days = int.tryParse(value);
                if (days == null || days <= 0 || days > 30) {
                  return 'Please enter a valid number between 1 and 30';
                }
                return null;
              },
            ),
            
            const SizedBox(height: AppDimensions.spacingLg),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveReminderConfig,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Configuration'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reminder Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            
            // Schedule Reminders Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _scheduleReminders,
                icon: const Icon(Icons.schedule),
                label: const Text('Schedule Automatic Reminders'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            
            const SizedBox(height: AppDimensions.spacingSm),
            
            // Send Escalated Reminders Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _sendEscalatedReminders,
                icon: const Icon(Icons.notification_important),
                label: const Text('Send Escalated Reminders'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_currentConfig == null) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            
            _buildConfigItem(
              'Automatic Reminders',
              _currentConfig!.enableAutomaticReminders ? 'Enabled' : 'Disabled',
              _currentConfig!.enableAutomaticReminders ? AppColors.success : AppColors.error,
            ),
            
            _buildConfigItem(
              'Reminder Days Before',
              '${_currentConfig!.reminderDaysBefore} days',
              AppColors.textSecondary,
            ),
            
            _buildConfigItem(
              'Escalated Reminders',
              _currentConfig!.enableEscalatedReminders ? 'Enabled' : 'Disabled',
              _currentConfig!.enableEscalatedReminders ? AppColors.success : AppColors.error,
            ),
            
            _buildConfigItem(
              'Escalation Interval',
              '${_currentConfig!.escalationDays} days',
              AppColors.textSecondary,
            ),
            
            _buildConfigItem(
              'Last Updated',
              _formatDateTime(_currentConfig!.lastUpdated),
              AppColors.textSecondary,
            ),
            
            _buildConfigItem(
              'Updated By',
              _currentConfig!.updatedBy,
              AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigItem(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}