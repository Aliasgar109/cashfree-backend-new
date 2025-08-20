import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for app settings and fee configuration
class SettingsModel {
  final String id;
  final double yearlyFee;
  final double lateFeesPercentage;
  final double wireChargePerMeter;
  final bool autoApprovalEnabled;
  final int reminderDaysBefore;
  final List<String> supportedLanguages;
  final DateTime lastUpdated;
  final String lastUpdatedBy;
  
  // 🎯 Payment Configuration
  final String upiId;
  final String merchantName;
  final String merchantCode;

  SettingsModel({
    required this.id,
    required this.yearlyFee,
    required this.lateFeesPercentage,
    required this.wireChargePerMeter,
    required this.autoApprovalEnabled,
    required this.reminderDaysBefore,
    required this.supportedLanguages,
    required this.lastUpdated,
    required this.lastUpdatedBy,
    required this.upiId,
    required this.merchantName,
    required this.merchantCode,
  });

  /// Create SettingsModel from Firestore document
  factory SettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SettingsModel(
      id: doc.id,
      yearlyFee: (data['yearlyFee'] as num?)?.toDouble() ?? 1.0,
      lateFeesPercentage: (data['lateFeesPercentage'] as num?)?.toDouble() ?? 10.0,
      wireChargePerMeter: (data['wireChargePerMeter'] as num?)?.toDouble() ?? 5.0,
      autoApprovalEnabled: data['autoApprovalEnabled'] as bool? ?? false,
      reminderDaysBefore: data['reminderDaysBefore'] as int? ?? 30,
      supportedLanguages: List<String>.from(data['supportedLanguages'] ?? ['en', 'gu']),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdatedBy: data['lastUpdatedBy'] as String? ?? 'system',
      upiId: data['upiId'] as String? ?? 'your-tv-channel@upi',
      merchantName: data['merchantName'] as String? ?? 'Your TV Channel Name',
      merchantCode: data['merchantCode'] as String? ?? 'TVCHANNEL',
    );
  }

  /// Convert SettingsModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'yearlyFee': yearlyFee,
      'lateFeesPercentage': lateFeesPercentage,
      'wireChargePerMeter': wireChargePerMeter,
      'autoApprovalEnabled': autoApprovalEnabled,
      'reminderDaysBefore': reminderDaysBefore,
      'supportedLanguages': supportedLanguages,
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastUpdatedBy': lastUpdatedBy,
    };
  }

  /// Create SettingsModel from Supabase row
  factory SettingsModel.fromSupabase(Map<String, dynamic> data) {
    return SettingsModel(
      id: data['id'] ?? 'app_settings',
      yearlyFee: (data['yearly_fee'] as num?)?.toDouble() ?? 1.0,
      lateFeesPercentage: (data['late_fees_percentage'] as num?)?.toDouble() ?? 10.0,
      wireChargePerMeter: (data['wire_charge_per_meter'] as num?)?.toDouble() ?? 5.0,
      autoApprovalEnabled: data['auto_approval_enabled'] as bool? ?? false,
      reminderDaysBefore: data['reminder_days_before'] as int? ?? 30,
      supportedLanguages: data['supported_languages'] != null
          ? List<String>.from(data['supported_languages'])
          : ['en', 'gu'],
      lastUpdated: data['last_updated'] != null
          ? DateTime.parse(data['last_updated'])
          : DateTime.now(),
      lastUpdatedBy: data['last_updated_by'] as String? ?? 'system',
      upiId: data['upi_id'] as String? ?? 'your-tv-channel@upi',
      merchantName: data['merchant_name'] as String? ?? 'Your TV Channel Name',
      merchantCode: data['merchant_code'] as String? ?? 'TVCHANNEL',
    );
  }

  /// Convert SettingsModel to Supabase row
  Map<String, dynamic> toSupabase() {
    return {
      'yearly_fee': yearlyFee,
      'late_fees_percentage': lateFeesPercentage,
      'wire_charge_per_meter': wireChargePerMeter,
      'auto_approval_enabled': autoApprovalEnabled,
      'reminder_days_before': reminderDaysBefore,
      'supported_languages': supportedLanguages,
      'last_updated': lastUpdated.toIso8601String(),
      'last_updated_by': lastUpdatedBy,
      'upi_id': upiId,
      'merchant_name': merchantName,
      'merchant_code': merchantCode,
    };
  }

  /// Create default settings
  factory SettingsModel.defaultSettings() {
    return SettingsModel(
      id: 'app_settings',
      yearlyFee: 1.0,
      lateFeesPercentage: 10.0,
      wireChargePerMeter: 5.0,
      autoApprovalEnabled: false,
      reminderDaysBefore: 30,
      supportedLanguages: ['en', 'gu'],
      lastUpdated: DateTime.now(),
      lastUpdatedBy: 'system',
      upiId: 'your-tv-channel@upi',
      merchantName: 'Your TV Channel Name',
      merchantCode: 'TVCHANNEL',
    );
  }

  /// Create a copy with updated values
  SettingsModel copyWith({
    String? id,
    double? yearlyFee,
    double? lateFeesPercentage,
    double? wireChargePerMeter,
    bool? autoApprovalEnabled,
    int? reminderDaysBefore,
    List<String>? supportedLanguages,
    DateTime? lastUpdated,
    String? lastUpdatedBy,
    String? upiId,
    String? merchantName,
    String? merchantCode,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      yearlyFee: yearlyFee ?? this.yearlyFee,
      lateFeesPercentage: lateFeesPercentage ?? this.lateFeesPercentage,
      wireChargePerMeter: wireChargePerMeter ?? this.wireChargePerMeter,
      autoApprovalEnabled: autoApprovalEnabled ?? this.autoApprovalEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      supportedLanguages: supportedLanguages ?? this.supportedLanguages,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      upiId: upiId ?? this.upiId,
      merchantName: merchantName ?? this.merchantName,
      merchantCode: merchantCode ?? this.merchantCode,
    );
  }

  /// Validate settings values
  bool isValid() {
    return yearlyFee > 0 &&
           lateFeesPercentage >= 0 &&
           lateFeesPercentage <= 100 &&
           wireChargePerMeter >= 0 &&
           reminderDaysBefore > 0 &&
           supportedLanguages.isNotEmpty;
  }

  /// Get formatted yearly fee
  String get formattedYearlyFee => '₹${yearlyFee.toStringAsFixed(2)}';

  /// Get formatted late fees percentage
  String get formattedLateFeesPercentage => '${lateFeesPercentage.toStringAsFixed(1)}%';

  /// Get formatted wire charge per meter
  String get formattedWireChargePerMeter => '₹${wireChargePerMeter.toStringAsFixed(2)}/meter';

  @override
  String toString() {
    return 'SettingsModel{id: $id, yearlyFee: $yearlyFee, lateFeesPercentage: $lateFeesPercentage, wireChargePerMeter: $wireChargePerMeter}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          yearlyFee == other.yearlyFee &&
          lateFeesPercentage == other.lateFeesPercentage &&
          wireChargePerMeter == other.wireChargePerMeter &&
          autoApprovalEnabled == other.autoApprovalEnabled &&
          reminderDaysBefore == other.reminderDaysBefore;

  @override
  int get hashCode =>
      id.hashCode ^
      yearlyFee.hashCode ^
      lateFeesPercentage.hashCode ^
      wireChargePerMeter.hashCode ^
      autoApprovalEnabled.hashCode ^
      reminderDaysBefore.hashCode;
}

/// Fee calculation breakdown for detailed display
class FeeBreakdown {
  final double baseAmount;
  final double extraCharges;
  final double wireCharges;
  final double lateFees;
  final double totalAmount;
  final bool hasLateFees;
  final bool hasWireCharges;
  final bool hasExtraCharges;
  final double? wireLength;
  final double wireChargePerMeter;
  final double lateFeesPercentage;
  final int? yearsOverdue;

  FeeBreakdown({
    required this.baseAmount,
    required this.extraCharges,
    required this.wireCharges,
    required this.lateFees,
    required this.totalAmount,
    required this.hasLateFees,
    required this.hasWireCharges,
    required this.hasExtraCharges,
    this.wireLength,
    required this.wireChargePerMeter,
    required this.lateFeesPercentage,
    this.yearsOverdue,
  });

  /// Get formatted amounts
  String get formattedBaseAmount => '₹${baseAmount.toStringAsFixed(2)}';
  String get formattedExtraCharges => '₹${extraCharges.toStringAsFixed(2)}';
  String get formattedWireCharges => '₹${wireCharges.toStringAsFixed(2)}';
  String get formattedLateFees => '₹${lateFees.toStringAsFixed(2)}';
  String get formattedTotalAmount => '₹${totalAmount.toStringAsFixed(2)}';

  /// Get wire charges description
  String get wireChargesDescription {
    if (wireLength != null && wireLength! > 0) {
      return '${wireLength!.toStringAsFixed(1)} meters × ₹${wireChargePerMeter.toStringAsFixed(2)}';
    }
    return 'Wire charges';
  }

  /// Get late fees description
  String get lateFeesDescription {
    if (yearsOverdue != null && yearsOverdue! > 0) {
      return '$yearsOverdue year(s) overdue @ ${lateFeesPercentage.toStringAsFixed(1)}%';
    }
    return 'Late fees';
  }

  @override
  String toString() {
    return 'FeeBreakdown{baseAmount: $baseAmount, totalAmount: $totalAmount, hasLateFees: $hasLateFees}';
  }
}