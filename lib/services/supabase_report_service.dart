import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../config/supabase_config.dart';
import 'supabase_service.dart';
import 'supabase_user_service.dart';
import 'supabase_settings_service.dart';

/// Report service using Supabase for data operations
/// Firebase Auth is still used for authentication
class SupabaseReportService extends SupabaseService {
  final SupabaseUserService _userService = SupabaseUserService();
  final SupabaseSettingsService _settingsService = SupabaseSettingsService();

  /// Generate payment summary report
  Future<PaymentSummaryReport> generatePaymentSummaryReport({
    DateTime? startDate,
    DateTime? endDate,
    String? area,
    PaymentStatus? status,
  }) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase.rpc('generate_payment_summary_report', params: {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'area_filter': area,
        'status_filter': status?.toString().split('.').last,
      });

      return PaymentSummaryReport.fromMap(response);
    });
  }

  /// Generate user-wise payment report
  Future<List<UserPaymentReport>> generateUserPaymentReport({
    DateTime? startDate,
    DateTime? endDate,
    String? area,
    UserRole? role,
  }) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase.rpc('generate_user_payment_report', params: {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'area_filter': area,
        'role_filter': role?.toString().split('.').last,
      });

      return (response as List)
          .map((item) => UserPaymentReport.fromMap(item))
          .toList();
    });
  }

  /// Generate monthly revenue report
  Future<List<MonthlyRevenueReport>> generateMonthlyRevenueReport({
    required int year,
    String? area,
  }) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase.rpc('generate_monthly_revenue_report', params: {
        'report_year': year,
        'area_filter': area,
      });

      return (response as List)
          .map((item) => MonthlyRevenueReport.fromMap(item))
          .toList();
    });
  }

  /// Generate area-wise collection report
  Future<List<AreaCollectionReport>> generateAreaCollectionReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase.rpc('generate_area_collection_report', params: {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      });

      return (response as List)
          .map((item) => AreaCollectionReport.fromMap(item))
          .toList();
    });
  }

  /// Generate overdue payments report
  Future<List<OverduePaymentReport>> generateOverduePaymentsReport({
    String? area,
    int? daysPastDue,
  }) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase.rpc('generate_overdue_payments_report', params: {
        'area_filter': area,
        'days_past_due': daysPastDue,
      });

      return (response as List)
          .map((item) => OverduePaymentReport.fromMap(item))
          .toList();
    });
  }

  /// Generate collection efficiency report
  Future<CollectionEfficiencyReport> generateCollectionEfficiencyReport({
    DateTime? startDate,
    DateTime? endDate,
    String? collectorId,
  }) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase.rpc('generate_collection_efficiency_report', params: {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'collector_firebase_uid': collectorId,
      });

      return CollectionEfficiencyReport.fromMap(response);
    });
  }

  /// Export payment report to CSV
  Future<File> exportPaymentReportToCSV({
    required List<PaymentModel> payments,
    String? fileName,
  }) async {
    final csvData = <List<String>>[];
    
    // Header row
    csvData.add([
      'Payment ID',
      'User Name',
      'Phone Number',
      'Area',
      'Amount',
      'Late Fees',
      'Extra Charges',
      'Wire Charges',
      'Total Amount',
      'Payment Method',
      'Status',
      'Created Date',
      'Paid Date',
      'Service Period Start',
      'Service Period End',
      'UPI Transaction ID',
      'Notes',
    ]);

    // Data rows
    for (final payment in payments) {
      // Get user data for this payment
      final user = await _userService.getUserById(payment.userId);
      
      csvData.add([
        payment.id,
        user?.name ?? 'Unknown',
        user?.phoneNumber ?? 'Unknown',
        user?.area ?? 'Unknown',
        payment.amount.toStringAsFixed(2),
        (payment.lateFees ?? 0).toStringAsFixed(2),
        (payment.extraCharges ?? 0).toStringAsFixed(2),
        (payment.wireCharges ?? 0).toStringAsFixed(2),
        payment.totalAmount.toStringAsFixed(2),
        payment.paymentMethod,
        payment.status.toString().split('.').last,
        _formatDate(payment.createdAt),
        payment.paidAt != null ? _formatDate(payment.paidAt!) : '',
        _formatDate(payment.servicePeriodStart ?? payment.createdAt),
        _formatDate(payment.servicePeriodEnd ?? payment.createdAt),
        payment.upiTransactionId ?? '',
        payment.notes ?? '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(csvData);
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${fileName ?? 'payment_report_${DateTime.now().millisecondsSinceEpoch}'}.csv');
    await file.writeAsString(csv);

    return file;
  }

  /// Export user report to CSV
  Future<File> exportUserReportToCSV({
    required List<UserPaymentReport> userReports,
    String? fileName,
  }) async {
    final csvData = <List<String>>[];
    
    // Header row
    csvData.add([
      'User Name',
      'Phone Number',
      'Area',
      'Role',
      'Total Payments',
      'Total Amount Paid',
      'Pending Payments',
      'Pending Amount',
      'Overdue Payments',
      'Overdue Amount',
      'Last Payment Date',
    ]);

    // Data rows
    for (final report in userReports) {
      csvData.add([
        report.userName,
        report.phoneNumber,
        report.area,
        report.role,
        report.totalPayments.toString(),
        report.totalAmountPaid.toStringAsFixed(2),
        report.pendingPayments.toString(),
        report.pendingAmount.toStringAsFixed(2),
        report.overduePayments.toString(),
        report.overdueAmount.toStringAsFixed(2),
        report.lastPaymentDate != null ? _formatDate(report.lastPaymentDate!) : '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(csvData);
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${fileName ?? 'user_report_${DateTime.now().millisecondsSinceEpoch}'}.csv');
    await file.writeAsString(csv);

    return file;
  }

  /// Share report file
  Future<void> shareReportFile(File file, String reportType) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: '$reportType generated on ${_formatDate(DateTime.now())}',
      subject: reportType,
    );
  }

  /// Get dashboard analytics data
  Future<DashboardAnalytics> getDashboardAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase.rpc('get_dashboard_analytics', params: {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      });

      return DashboardAnalytics.fromMap(response);
    });
  }

  /// Helper method to format dates
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Get available areas for reports
  Future<List<String>> getAvailableAreas() async {
    return await executeWithErrorHandling(() async {
      final response = await supabase
          .from('users')
          .select('area')
          .not('area', 'is', null);

      final areas = <String>{};
      for (final item in response) {
        if (item['area'] != null) {
          areas.add(item['area']);
        }
      }

      return areas.toList()..sort();
    });
  }

  /// Generate area-wise report
  Future<AreaWiseReport> generateAreaWiseReport(String area) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase.rpc('generate_area_wise_report', params: {
        'area_param': area,
      });

      return AreaWiseReport.fromMap(response);
    });
  }

  /// Generate unpaid users report
  Future<List<UnpaidUserReport>> generateUnpaidUsersReport() async {
    return await executeWithErrorHandling(() async {
      final response = await supabase.rpc('generate_unpaid_users_report');

      return (response as List)
          .map((item) => UnpaidUserReport.fromMap(item))
          .toList();
    });
  }

  /// Generate date-wise report
  Future<DateWiseReport> generateDateWiseReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await executeWithErrorHandling(() async {
      final response = await supabase.rpc('generate_date_wise_report', params: {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      });

      return DateWiseReport.fromMap(response);
    });
  }

  /// Export report to CSV
  Future<File> exportToCSV(List<dynamic> data, String fileName) async {
    final csvData = <List<String>>[];
    
    // This is a placeholder implementation
    // The actual implementation would depend on the data structure
    
    final csv = const ListToCsvConverter().convert(csvData);
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName.csv');
    await file.writeAsString(csv);

    return file;
  }

  /// Export report to Excel
  Future<File> exportToExcel(List<dynamic> data, String fileName) async {
    // This is a placeholder implementation
    // Excel export would require additional packages
    
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName.xlsx');
    await file.writeAsString('Excel export not implemented yet');

    return file;
  }

  /// Share report
  Future<void> shareReport(File file, String reportType) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: '$reportType generated on ${_formatDate(DateTime.now())}',
      subject: reportType,
    );
  }
}

/// Payment Summary Report Model
class PaymentSummaryReport {
  final int totalPayments;
  final double totalAmount;
  final int pendingPayments;
  final double pendingAmount;
  final int approvedPayments;
  final double approvedAmount;
  final int rejectedPayments;
  final double rejectedAmount;
  final double totalLateFees;
  final double totalExtraCharges;
  final double totalWireCharges;

  const PaymentSummaryReport({
    required this.totalPayments,
    required this.totalAmount,
    required this.pendingPayments,
    required this.pendingAmount,
    required this.approvedPayments,
    required this.approvedAmount,
    required this.rejectedPayments,
    required this.rejectedAmount,
    required this.totalLateFees,
    required this.totalExtraCharges,
    required this.totalWireCharges,
  });

  factory PaymentSummaryReport.fromMap(Map<String, dynamic> map) {
    return PaymentSummaryReport(
      totalPayments: (map['total_payments'] as num?)?.toInt() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      pendingPayments: (map['pending_payments'] as num?)?.toInt() ?? 0,
      pendingAmount: (map['pending_amount'] as num?)?.toDouble() ?? 0.0,
      approvedPayments: (map['approved_payments'] as num?)?.toInt() ?? 0,
      approvedAmount: (map['approved_amount'] as num?)?.toDouble() ?? 0.0,
      rejectedPayments: (map['rejected_payments'] as num?)?.toInt() ?? 0,
      rejectedAmount: (map['rejected_amount'] as num?)?.toDouble() ?? 0.0,
      totalLateFees: (map['total_late_fees'] as num?)?.toDouble() ?? 0.0,
      totalExtraCharges: (map['total_extra_charges'] as num?)?.toDouble() ?? 0.0,
      totalWireCharges: (map['total_wire_charges'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// User Payment Report Model
class UserPaymentReport {
  final String userId;
  final String userName;
  final String phoneNumber;
  final String area;
  final String role;
  final int totalPayments;
  final double totalAmountPaid;
  final int pendingPayments;
  final double pendingAmount;
  final int overduePayments;
  final double overdueAmount;
  final DateTime? lastPaymentDate;

  const UserPaymentReport({
    required this.userId,
    required this.userName,
    required this.phoneNumber,
    required this.area,
    required this.role,
    required this.totalPayments,
    required this.totalAmountPaid,
    required this.pendingPayments,
    required this.pendingAmount,
    required this.overduePayments,
    required this.overdueAmount,
    this.lastPaymentDate,
  });

  factory UserPaymentReport.fromMap(Map<String, dynamic> map) {
    return UserPaymentReport(
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      area: map['area'] ?? '',
      role: map['role'] ?? '',
      totalPayments: (map['total_payments'] as num?)?.toInt() ?? 0,
      totalAmountPaid: (map['total_amount_paid'] as num?)?.toDouble() ?? 0.0,
      pendingPayments: (map['pending_payments'] as num?)?.toInt() ?? 0,
      pendingAmount: (map['pending_amount'] as num?)?.toDouble() ?? 0.0,
      overduePayments: (map['overdue_payments'] as num?)?.toInt() ?? 0,
      overdueAmount: (map['overdue_amount'] as num?)?.toDouble() ?? 0.0,
      lastPaymentDate: map['last_payment_date'] != null
          ? DateTime.parse(map['last_payment_date'])
          : null,
    );
  }
}

/// Monthly Revenue Report Model
class MonthlyRevenueReport {
  final int month;
  final int year;
  final double revenue;
  final int paymentCount;
  final double averagePayment;

  const MonthlyRevenueReport({
    required this.month,
    required this.year,
    required this.revenue,
    required this.paymentCount,
    required this.averagePayment,
  });

  factory MonthlyRevenueReport.fromMap(Map<String, dynamic> map) {
    return MonthlyRevenueReport(
      month: (map['month'] as num?)?.toInt() ?? 0,
      year: (map['year'] as num?)?.toInt() ?? 0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
      paymentCount: (map['payment_count'] as num?)?.toInt() ?? 0,
      averagePayment: (map['average_payment'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Area Collection Report Model
class AreaCollectionReport {
  final String area;
  final int totalUsers;
  final int totalPayments;
  final double totalAmount;
  final double collectionRate;

  const AreaCollectionReport({
    required this.area,
    required this.totalUsers,
    required this.totalPayments,
    required this.totalAmount,
    required this.collectionRate,
  });

  factory AreaCollectionReport.fromMap(Map<String, dynamic> map) {
    return AreaCollectionReport(
      area: map['area'] ?? '',
      totalUsers: (map['total_users'] as num?)?.toInt() ?? 0,
      totalPayments: (map['total_payments'] as num?)?.toInt() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      collectionRate: (map['collection_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Overdue Payment Report Model
class OverduePaymentReport {
  final String userId;
  final String userName;
  final String phoneNumber;
  final String area;
  final String paymentId;
  final double amount;
  final DateTime dueDate;
  final int daysPastDue;

  const OverduePaymentReport({
    required this.userId,
    required this.userName,
    required this.phoneNumber,
    required this.area,
    required this.paymentId,
    required this.amount,
    required this.dueDate,
    required this.daysPastDue,
  });

  factory OverduePaymentReport.fromMap(Map<String, dynamic> map) {
    return OverduePaymentReport(
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      area: map['area'] ?? '',
      paymentId: map['payment_id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.parse(map['due_date']),
      daysPastDue: (map['days_past_due'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Collection Efficiency Report Model
class CollectionEfficiencyReport {
  final String collectorId;
  final String collectorName;
  final int totalAssigned;
  final int totalCollected;
  final double collectionRate;
  final double totalAmountCollected;
  final double averageCollectionTime;

  const CollectionEfficiencyReport({
    required this.collectorId,
    required this.collectorName,
    required this.totalAssigned,
    required this.totalCollected,
    required this.collectionRate,
    required this.totalAmountCollected,
    required this.averageCollectionTime,
  });

  factory CollectionEfficiencyReport.fromMap(Map<String, dynamic> map) {
    return CollectionEfficiencyReport(
      collectorId: map['collector_id'] ?? '',
      collectorName: map['collector_name'] ?? '',
      totalAssigned: (map['total_assigned'] as num?)?.toInt() ?? 0,
      totalCollected: (map['total_collected'] as num?)?.toInt() ?? 0,
      collectionRate: (map['collection_rate'] as num?)?.toDouble() ?? 0.0,
      totalAmountCollected: (map['total_amount_collected'] as num?)?.toDouble() ?? 0.0,
      averageCollectionTime: (map['average_collection_time'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Dashboard Analytics Model
class DashboardAnalytics {
  final double totalRevenue;
  final int totalUsers;
  final int totalPayments;
  final double pendingAmount;
  final double collectionRate;
  final List<MonthlyRevenueReport> revenueChart;

  const DashboardAnalytics({
    required this.totalRevenue,
    required this.totalUsers,
    required this.totalPayments,
    required this.pendingAmount,
    required this.collectionRate,
    required this.revenueChart,
  });

  factory DashboardAnalytics.fromMap(Map<String, dynamic> map) {
    return DashboardAnalytics(
      totalRevenue: (map['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalUsers: (map['total_users'] as num?)?.toInt() ?? 0,
      totalPayments: (map['total_payments'] as num?)?.toInt() ?? 0,
      pendingAmount: (map['pending_amount'] as num?)?.toDouble() ?? 0.0,
      collectionRate: (map['collection_rate'] as num?)?.toDouble() ?? 0.0,
      revenueChart: (map['revenue_chart'] as List?)
          ?.map((item) => MonthlyRevenueReport.fromMap(item))
          .toList() ?? [],
    );
  }
}

/// Area-wise Report Model
class AreaWiseReport {
  final String area;
  final int totalUsers;
  final int totalPayments;
  final double totalAmount;
  final double pendingAmount;
  final double collectionRate;

  const AreaWiseReport({
    required this.area,
    required this.totalUsers,
    required this.totalPayments,
    required this.totalAmount,
    required this.pendingAmount,
    required this.collectionRate,
  });

  factory AreaWiseReport.fromMap(Map<String, dynamic> map) {
    return AreaWiseReport(
      area: map['area'] ?? '',
      totalUsers: (map['total_users'] as num?)?.toInt() ?? 0,
      totalPayments: (map['total_payments'] as num?)?.toInt() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (map['pending_amount'] as num?)?.toDouble() ?? 0.0,
      collectionRate: (map['collection_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Unpaid User Report Model
class UnpaidUserReport {
  final String userId;
  final String userName;
  final String phoneNumber;
  final String area;
  final double pendingAmount;
  final DateTime? lastPaymentDate;

  const UnpaidUserReport({
    required this.userId,
    required this.userName,
    required this.phoneNumber,
    required this.area,
    required this.pendingAmount,
    this.lastPaymentDate,
  });

  factory UnpaidUserReport.fromMap(Map<String, dynamic> map) {
    return UnpaidUserReport(
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? '',
      phoneNumber: map['phone_number'] ?? '',
      area: map['area'] ?? '',
      pendingAmount: (map['pending_amount'] as num?)?.toDouble() ?? 0.0,
      lastPaymentDate: map['last_payment_date'] != null
          ? DateTime.parse(map['last_payment_date'])
          : null,
    );
  }
}

/// Date-wise Report Model
class DateWiseReport {
  final DateTime date;
  final int totalPayments;
  final double totalAmount;
  final int newUsers;
  final double collectionRate;

  const DateWiseReport({
    required this.date,
    required this.totalPayments,
    required this.totalAmount,
    required this.newUsers,
    required this.collectionRate,
  });

  factory DateWiseReport.fromMap(Map<String, dynamic> map) {
    return DateWiseReport(
      date: DateTime.parse(map['date']),
      totalPayments: (map['total_payments'] as num?)?.toInt() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0.0,
      newUsers: (map['new_users'] as num?)?.toInt() ?? 0,
      collectionRate: (map['collection_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
