import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/settings_model.dart';

/// Service for managing app settings and fee configuration
class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _settingsCollection = 'settings';
  static const String _appSettingsDocId = 'app_settings';

  /// Get current app settings
  Future<SettingsModel> getSettings() async {
    try {
      final doc = await _firestore
          .collection(_settingsCollection)
          .doc(_appSettingsDocId)
          .get();

      if (doc.exists) {
        return SettingsModel.fromFirestore(doc);
      } else {
        // Create default settings if none exist
        final defaultSettings = SettingsModel.defaultSettings();
        await _createDefaultSettings(defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      throw Exception('Failed to get settings: $e');
    }
  }

  /// Get settings as a stream for real-time updates
  Stream<SettingsModel> getSettingsStream() {
    return _firestore
        .collection(_settingsCollection)
        .doc(_appSettingsDocId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return SettingsModel.fromFirestore(doc);
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

      await _firestore
          .collection(_settingsCollection)
          .doc(_appSettingsDocId)
          .update({
        'yearlyFee': newFee,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastUpdatedBy': updatedBy,
      });

      return SettingsUpdateResult(
        success: true,
        message: 'Yearly fee updated successfully to ₹${newFee.toStringAsFixed(2)}',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to update yearly fee: $e',
      );
    }
  }

  /// Update late fees percentage
  Future<SettingsUpdateResult> updateLateFeesPercentage({
    required double newPercentage,
    required String updatedBy,
  }) async {
    try {
      if (newPercentage < 0 || newPercentage > 100) {
        return SettingsUpdateResult(
          success: false,
          error: 'Late fees percentage must be between 0 and 100',
        );
      }

      await _firestore
          .collection(_settingsCollection)
          .doc(_appSettingsDocId)
          .update({
        'lateFeesPercentage': newPercentage,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastUpdatedBy': updatedBy,
      });

      return SettingsUpdateResult(
        success: true,
        message: 'Late fees percentage updated successfully to ${newPercentage.toStringAsFixed(1)}%',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to update late fees percentage: $e',
      );
    }
  }

  /// Update wire charge per meter
  Future<SettingsUpdateResult> updateWireChargePerMeter({
    required double newCharge,
    required String updatedBy,
  }) async {
    try {
      if (newCharge < 0) {
        return SettingsUpdateResult(
          success: false,
          error: 'Wire charge per meter cannot be negative',
        );
      }

      await _firestore
          .collection(_settingsCollection)
          .doc(_appSettingsDocId)
          .update({
        'wireChargePerMeter': newCharge,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastUpdatedBy': updatedBy,
      });

      return SettingsUpdateResult(
        success: true,
        message: 'Wire charge per meter updated successfully to ₹${newCharge.toStringAsFixed(2)}',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to update wire charge per meter: $e',
      );
    }
  }

  /// Update multiple settings at once
  Future<SettingsUpdateResult> updateSettings({
    required SettingsModel settings,
    required String updatedBy,
  }) async {
    try {
      if (!settings.isValid()) {
        return SettingsUpdateResult(
          success: false,
          error: 'Invalid settings values provided',
        );
      }

      final updateData = settings.toFirestore();
      updateData['lastUpdatedBy'] = updatedBy;

      await _firestore
          .collection(_settingsCollection)
          .doc(_appSettingsDocId)
          .set(updateData, SetOptions(merge: true));

      return SettingsUpdateResult(
        success: true,
        message: 'Settings updated successfully',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to update settings: $e',
      );
    }
  }

  /// Update auto approval setting
  Future<SettingsUpdateResult> updateAutoApproval({
    required bool enabled,
    required String updatedBy,
  }) async {
    try {
      await _firestore
          .collection(_settingsCollection)
          .doc(_appSettingsDocId)
          .update({
        'autoApprovalEnabled': enabled,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastUpdatedBy': updatedBy,
      });

      return SettingsUpdateResult(
        success: true,
        message: 'Auto approval ${enabled ? 'enabled' : 'disabled'} successfully',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to update auto approval setting: $e',
      );
    }
  }

  /// Update reminder days before due date
  Future<SettingsUpdateResult> updateReminderDays({
    required int days,
    required String updatedBy,
  }) async {
    try {
      if (days <= 0) {
        return SettingsUpdateResult(
          success: false,
          error: 'Reminder days must be greater than 0',
        );
      }

      await _firestore
          .collection(_settingsCollection)
          .doc(_appSettingsDocId)
          .update({
        'reminderDaysBefore': days,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastUpdatedBy': updatedBy,
      });

      return SettingsUpdateResult(
        success: true,
        message: 'Reminder days updated successfully to $days days',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to update reminder days: $e',
      );
    }
  }

  /// Calculate fee breakdown with current settings
  Future<FeeBreakdown> calculateFeeBreakdown({
    required String userId,
    double? customBaseAmount,
    double extraCharges = 0.0,
    double? wireLength,
  }) async {
    try {
      final settings = await getSettings();
      final baseAmount = customBaseAmount ?? settings.yearlyFee;

      // Calculate wire charges
      double wireCharges = 0.0;
      if (wireLength != null && wireLength > 0) {
        wireCharges = wireLength * settings.wireChargePerMeter;
      }

      // Calculate late fees from previous unpaid years
      final currentYear = DateTime.now().year;
      double lateFees = 0.0;
      int yearsOverdue = 0;

      // Get all unpaid payments from previous years
      final unpaidQuery = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['PENDING', 'REJECTED'])
          .where('year', isLessThan: currentYear)
          .get();

      for (final doc in unpaidQuery.docs) {
        final paymentData = doc.data();
        final paymentYear = paymentData['year'] as int;
        final paymentAmount = (paymentData['amount'] as num?)?.toDouble() ?? baseAmount;
        final yearsDifference = currentYear - paymentYear;
        
        if (yearsDifference > yearsOverdue) {
          yearsOverdue = yearsDifference;
        }

        // Apply compound late fees for each year overdue
        double paymentLateFee = paymentAmount;
        for (int i = 0; i < yearsDifference; i++) {
          paymentLateFee *= (1 + settings.lateFeesPercentage / 100);
        }
        lateFees += paymentLateFee - paymentAmount;
      }

      final totalAmount = baseAmount + extraCharges + wireCharges + lateFees;

      return FeeBreakdown(
        baseAmount: baseAmount,
        extraCharges: extraCharges,
        wireCharges: wireCharges,
        lateFees: lateFees,
        totalAmount: totalAmount,
        hasLateFees: lateFees > 0,
        hasWireCharges: wireCharges > 0,
        hasExtraCharges: extraCharges > 0,
        wireLength: wireLength,
        wireChargePerMeter: settings.wireChargePerMeter,
        lateFeesPercentage: settings.lateFeesPercentage,
        yearsOverdue: yearsOverdue > 0 ? yearsOverdue : null,
      );
    } catch (e) {
      // Return basic calculation on error
      final baseAmount = customBaseAmount ?? 1000.0;
      return FeeBreakdown(
        baseAmount: baseAmount,
        extraCharges: extraCharges,
        wireCharges: 0.0,
        lateFees: 0.0,
        totalAmount: baseAmount + extraCharges,
        hasLateFees: false,
        hasWireCharges: false,
        hasExtraCharges: extraCharges > 0,
        wireLength: wireLength,
        wireChargePerMeter: 5.0,
        lateFeesPercentage: 10.0,
        yearsOverdue: null,
      );
    }
  }

  /// Calculate wire charges for given length
  Future<double> calculateWireCharges(double wireLength) async {
    try {
      final settings = await getSettings();
      return wireLength * settings.wireChargePerMeter;
    } catch (e) {
      return wireLength * 5.0; // Default rate
    }
  }

  /// Calculate late fees for a specific amount and years overdue
  Future<double> calculateLateFees({
    required double originalAmount,
    required int yearsOverdue,
  }) async {
    try {
      if (yearsOverdue <= 0) return 0.0;

      final settings = await getSettings();
      double totalWithLateFees = originalAmount;
      
      for (int i = 0; i < yearsOverdue; i++) {
        totalWithLateFees *= (1 + settings.lateFeesPercentage / 100);
      }
      
      return totalWithLateFees - originalAmount;
    } catch (e) {
      // Default calculation with 10% late fees
      double totalWithLateFees = originalAmount;
      for (int i = 0; i < yearsOverdue; i++) {
        totalWithLateFees *= 1.10;
      }
      return totalWithLateFees - originalAmount;
    }
  }

  /// Get settings history (if implemented)
  Future<List<SettingsHistoryEntry>> getSettingsHistory() async {
    try {
      // This would require a separate collection to track changes
      // For now, return empty list
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Reset settings to default values
  Future<SettingsUpdateResult> resetToDefaults({
    required String updatedBy,
  }) async {
    try {
      final defaultSettings = SettingsModel.defaultSettings();
      final updateData = defaultSettings.toFirestore();
      updateData['lastUpdatedBy'] = updatedBy;

      await _firestore
          .collection(_settingsCollection)
          .doc(_appSettingsDocId)
          .set(updateData);

      return SettingsUpdateResult(
        success: true,
        message: 'Settings reset to default values successfully',
      );
    } catch (e) {
      return SettingsUpdateResult(
        success: false,
        error: 'Failed to reset settings: $e',
      );
    }
  }

  /// Create default settings document
  Future<void> _createDefaultSettings(SettingsModel settings) async {
    await _firestore
        .collection(_settingsCollection)
        .doc(_appSettingsDocId)
        .set(settings.toFirestore());
  }

  /// Validate fee amount
  bool isValidFeeAmount(double amount) {
    return amount > 0 && amount <= 100000; // Max 1 lakh
  }

  /// Validate percentage
  bool isValidPercentage(double percentage) {
    return percentage >= 0 && percentage <= 100;
  }

  /// Validate wire charge
  bool isValidWireCharge(double charge) {
    return charge >= 0 && charge <= 1000; // Max 1000 per meter
  }

  /// Get formatted settings summary
  Future<String> getSettingsSummary() async {
    try {
      final settings = await getSettings();
      return '''
Settings Summary:
- Yearly Fee: ${settings.formattedYearlyFee}
- Late Fees: ${settings.formattedLateFeesPercentage}
- Wire Charge: ${settings.formattedWireChargePerMeter}
- Auto Approval: ${settings.autoApprovalEnabled ? 'Enabled' : 'Disabled'}
- Reminder Days: ${settings.reminderDaysBefore} days
- Last Updated: ${settings.lastUpdated.toString().split('.')[0]}
- Updated By: ${settings.lastUpdatedBy}
''';
    } catch (e) {
      return 'Failed to load settings summary: $e';
    }
  }
}

/// Result of settings update operations
class SettingsUpdateResult {
  final bool success;
  final String? message;
  final String? error;

  SettingsUpdateResult({
    required this.success,
    this.message,
    this.error,
  });

  @override
  String toString() {
    return 'SettingsUpdateResult{success: $success, message: $message, error: $error}';
  }
}

/// Settings history entry (for future implementation)
class SettingsHistoryEntry {
  final String id;
  final String field;
  final dynamic oldValue;
  final dynamic newValue;
  final DateTime timestamp;
  final String updatedBy;

  SettingsHistoryEntry({
    required this.id,
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
    required this.updatedBy,
  });
}