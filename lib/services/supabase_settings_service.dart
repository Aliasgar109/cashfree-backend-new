import '../models/settings_model.dart';
import '../config/supabase_config.dart';
import 'supabase_service.dart';

/// Settings service using Supabase for data operations
/// Firebase Auth is still used for authentication
class SupabaseSettingsService extends SupabaseService {
  static const String _settingsTable = 'settings';
  static const String _appSettingsId = 'app_settings';

  /// Get current app settings
  Future<SettingsModel> getSettings() async {
    return await executeWithErrorHandling(() async {
      final response = await SupabaseConfig.adminClient
          .from(_settingsTable)
          .select()
          .eq('id', _appSettingsId)
          .maybeSingle();

      if (response != null) {
        return SettingsModel.fromSupabase(response);
      } else {
        // Create default settings if none exist
        final defaultSettings = SettingsModel.defaultSettings();
        await _createDefaultSettings(defaultSettings);
        return defaultSettings;
      }
    });
  }

  /// Get settings as a stream for real-time updates
  Stream<SettingsModel> getSettingsStream() {
    return SupabaseConfig.adminClient
        .from(_settingsTable)
        .stream(primaryKey: ['id'])
        .eq('id', _appSettingsId)
        .map((data) {
          if (data.isNotEmpty) {
            return SettingsModel.fromSupabase(data.first);
          } else {
            return SettingsModel.defaultSettings();
          }
        });
  }

  /// Update yearly fee
  Future<SettingsUpdateResult> updateYearlyFee({
    required double newFee,
    required String updatedBy,
  }) async {
    try {
      if (newFee <= 0) {
        return SettingsUpdateResult(
          success: false,
          error: 'Yearly fee must be greater than 0',
        );
      }

      await executeWithErrorHandling(() async {
        await SupabaseConfig.adminClient
            .from(_settingsTable)
            .update({
              'yearly_fee': newFee,
              'last_updated': DateTime.now().toIso8601String(),
              'last_updated_by': updatedBy,
            })
            .eq('id', _appSettingsId);
      });

      return SettingsUpdateResult(
        success: true,
        message: 'Yearly fee updated successfully',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to update yearly fee: ${e.toString()}',
      );
    }
  }

  /// Update installation charges
  Future<SettingsUpdateResult> updateInstallationCharges({
    required double newCharges,
    required String updatedBy,
  }) async {
    try {
      if (newCharges < 0) {
        return SettingsUpdateResult(
          success: false,
          error: 'Installation charges cannot be negative',
        );
      }

      await executeWithErrorHandling(() async {
        await SupabaseConfig.adminClient
            .from(_settingsTable)
            .update({
              'installation_charges': newCharges,
              'last_updated': DateTime.now().toIso8601String(),
              'last_updated_by': updatedBy,
            })
            .eq('id', _appSettingsId);
      });

      return SettingsUpdateResult(
        success: true,
        message: 'Installation charges updated successfully',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to update installation charges: ${e.toString()}',
      );
    }
  }

  /// Update late fee percentage
  Future<SettingsUpdateResult> updateLateFeePercentage({
    required double newPercentage,
    required String updatedBy,
  }) async {
    try {
      if (newPercentage < 0 || newPercentage > 100) {
        return SettingsUpdateResult(
          success: false,
          error: 'Late fee percentage must be between 0 and 100',
        );
      }

      await executeWithErrorHandling(() async {
        await SupabaseConfig.adminClient
            .from(_settingsTable)
            .update({
              'late_fee_percentage': newPercentage,
              'last_updated': DateTime.now().toIso8601String(),
              'last_updated_by': updatedBy,
            })
            .eq('id', _appSettingsId);
      });

      return SettingsUpdateResult(
        success: true,
        message: 'Late fee percentage updated successfully',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to update late fee percentage: ${e.toString()}',
      );
    }
  }

  /// Update payment grace period (in days)
  Future<SettingsUpdateResult> updateGracePeriod({
    required int newGracePeriod,
    required String updatedBy,
  }) async {
    try {
      if (newGracePeriod < 0) {
        return SettingsUpdateResult(
          success: false,
          error: 'Grace period cannot be negative',
        );
      }

      await executeWithErrorHandling(() async {
        await SupabaseConfig.adminClient
            .from(_settingsTable)
            .update({
              'grace_period_days': newGracePeriod,
              'last_updated': DateTime.now().toIso8601String(),
              'last_updated_by': updatedBy,
            })
            .eq('id', _appSettingsId);
      });

      return SettingsUpdateResult(
        success: true,
        message: 'Grace period updated successfully',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to update grace period: ${e.toString()}',
      );
    }
  }

  /// Update multiple settings at once
  Future<SettingsUpdateResult> updateSettings({
    required SettingsModel settings,
    required String updatedBy,
  }) async {
    try {
      // Validate all settings
      if (!settings.isValid()) {
        return SettingsUpdateResult(
          success: false,
          error: 'Invalid settings values',
        );
      }

      await executeWithErrorHandling(() async {
        final updateData = {
          ...settings.toSupabase(),
          'last_updated': DateTime.now().toIso8601String(),
          'last_updated_by': updatedBy,
        };
        
        await SupabaseConfig.adminClient
            .from(_settingsTable)
            .update(updateData)
            .eq('id', _appSettingsId);
      });

      return SettingsUpdateResult(
        success: true,
        message: 'Settings updated successfully',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to update settings: ${e.toString()}',
      );
    }
  }

  /// Reset settings to default values
  Future<SettingsUpdateResult> resetToDefaults({
    required String updatedBy,
  }) async {
    try {
      final defaultSettings = SettingsModel.defaultSettings();

      await executeWithErrorHandling(() async {
        await SupabaseConfig.adminClient
            .from(_settingsTable)
            .update({
              ...defaultSettings.toSupabase(),
              'last_updated': DateTime.now().toIso8601String(),
              'last_updated_by': updatedBy,
            })
            .eq('id', _appSettingsId);
      });

      return SettingsUpdateResult(
        success: true,
        message: 'Settings reset to defaults successfully',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to reset settings: ${e.toString()}',
      );
    }
  }

  /// Get settings history/audit trail
  Future<List<SettingsAuditModel>> getSettingsHistory({
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await executeWithErrorHandling(() async {
      var query = SupabaseConfig.adminClient
          .from('settings_audit')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      // TODO: Implement date filtering when PostgrestTransformBuilder supports it
      // if (startDate != null) {
      //   query = query.gte('created_at', startDate.toIso8601String());
      // }
      // if (endDate != null) {
      //   query = query.lte('created_at', endDate.toIso8601String());
      // }

      final response = await query;
      
      return (response as List)
          .map((item) => SettingsAuditModel.fromSupabase(item))
          .toList();
    });
  }

  /// Create default settings if they don't exist
  Future<void> _createDefaultSettings(SettingsModel defaultSettings) async {
    await executeWithErrorHandling(() async {
      await SupabaseConfig.adminClient
          .from(_settingsTable)
          .insert({
            'id': _appSettingsId,
            ...defaultSettings.toSupabase(),
            'last_updated': DateTime.now().toIso8601String(),
          });
    });
  }

  /// Test method to verify admin client is working
  Future<bool> testAdminClientAccess() async {
    try {
      // Test 1: Try to read settings
      final readResult = await SupabaseConfig.adminClient
          .from(_settingsTable)
          .select()
          .eq('id', _appSettingsId)
          .maybeSingle();
      
      print('TEST: Read settings result: $readResult');
      
      // Test 2: Try to update a test field
      final updateResult = await SupabaseConfig.adminClient
          .from(_settingsTable)
          .update({
            'last_updated': DateTime.now().toIso8601String(),
          })
          .eq('id', _appSettingsId);
      
      print('TEST: Update settings result: $updateResult');
      
      return true;
    } catch (e) {
      print('TEST: Admin client access failed: $e');
      return false;
    }
  }
}

/// Model for settings audit history
class SettingsAuditModel {
  final String id;
  final String fieldName;
  final String? oldValue;
  final String newValue;
  final String updatedBy;
  final DateTime createdAt;
  final String? notes;

  const SettingsAuditModel({
    required this.id,
    required this.fieldName,
    this.oldValue,
    required this.newValue,
    required this.updatedBy,
    required this.createdAt,
    this.notes,
  });

  factory SettingsAuditModel.fromSupabase(Map<String, dynamic> data) {
    return SettingsAuditModel(
      id: data['id']?.toString() ?? '',
      fieldName: data['field_name'] ?? '',
      oldValue: data['old_value'],
      newValue: data['new_value'] ?? '',
      updatedBy: data['updated_by'] ?? '',
      createdAt: DateTime.parse(data['created_at']),
      notes: data['notes'],
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'field_name': fieldName,
      'old_value': oldValue,
      'new_value': newValue,
      'updated_by': updatedBy,
      'created_at': createdAt.toIso8601String(),
      'notes': notes,
    };
  }
}

/// Result class for settings update operations
class SettingsUpdateResult {
  final bool success;
  final String? message;
  final String? error;

  const SettingsUpdateResult({
    required this.success,
    this.message,
    this.error,
  });
}
