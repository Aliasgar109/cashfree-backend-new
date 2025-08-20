import 'package:jafary_channel_app/models/payment_model.dart';
import 'package:jafary_channel_app/models/user_model.dart';

enum ReportType { paymentSummary, unpaidUsers, areaWise, dateWise }

class ReportFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? area;
  final PaymentStatus? status;
  final PaymentMethod? method;
  final int? year;

  ReportFilter({
    this.startDate,
    this.endDate,
    this.area,
    this.status,
    this.method,
    this.year,
  });

  ReportFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? area,
    PaymentStatus? status,
    PaymentMethod? method,
    int? year,
  }) {
    return ReportFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      area: area ?? this.area,
      status: status ?? this.status,
      method: method ?? this.method,
      year: year ?? this.year,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'area': area,
      'status': status?.toString().split('.').last,
      'method': method?.toString().split('.').last,
      'year': year,
    };
  }

  @override
  String toString() {
    return 'ReportFilter{startDate: $startDate, endDate: $endDate, area: $area, status: $status, method: $method, year: $year}';
  }
}

class PaymentSummary {
  final int totalPayments;
  final int approvedPayments;
  final int pendingPayments;
  final int rejectedPayments;
  final double totalAmount;
  final double approvedAmount;
  final double pendingAmount;
  final Map<PaymentMethod, int> paymentsByMethod;
  final Map<String, int> paymentsByArea;

  PaymentSummary({
    required this.totalPayments,
    required this.approvedPayments,
    required this.pendingPayments,
    required this.rejectedPayments,
    required this.totalAmount,
    required this.approvedAmount,
    required this.pendingAmount,
    required this.paymentsByMethod,
    required this.paymentsByArea,
  });

  factory PaymentSummary.fromPayments(List<PaymentModel> payments) {
    final paymentsByMethod = <PaymentMethod, int>{};
    final paymentsByArea = <String, int>{};
    
    int approvedCount = 0;
    int pendingCount = 0;
    int rejectedCount = 0;
    double totalAmt = 0.0;
    double approvedAmt = 0.0;
    double pendingAmt = 0.0;

    for (final payment in payments) {
      // Count by status
      switch (payment.status) {
        case PaymentStatus.APPROVED:
          approvedCount++;
          approvedAmt += payment.totalAmount;
          break;
        case PaymentStatus.PENDING:
          pendingCount++;
          pendingAmt += payment.totalAmount;
          break;
        case PaymentStatus.REJECTED:
          rejectedCount++;
          break;
        case PaymentStatus.INCOMPLETE:
          // Skip incomplete payments in reports
          break;
      }

      totalAmt += payment.totalAmount;

      // Count by method
      paymentsByMethod[payment.method] = (paymentsByMethod[payment.method] ?? 0) + 1;
    }

    return PaymentSummary(
      totalPayments: payments.length,
      approvedPayments: approvedCount,
      pendingPayments: pendingCount,
      rejectedPayments: rejectedCount,
      totalAmount: totalAmt,
      approvedAmount: approvedAmt,
      pendingAmount: pendingAmt,
      paymentsByMethod: paymentsByMethod,
      paymentsByArea: paymentsByArea,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalPayments': totalPayments,
      'approvedPayments': approvedPayments,
      'pendingPayments': pendingPayments,
      'rejectedPayments': rejectedPayments,
      'totalAmount': totalAmount,
      'approvedAmount': approvedAmount,
      'pendingAmount': pendingAmount,
      'paymentsByMethod': paymentsByMethod.map((k, v) => MapEntry(k.toString().split('.').last, v)),
      'paymentsByArea': paymentsByArea,
    };
  }
}

class UnpaidUser {
  final UserModel user;
  final int yearsMissed;
  final List<int> unpaidYears;
  final double totalDue;

  UnpaidUser({
    required this.user,
    required this.yearsMissed,
    required this.unpaidYears,
    required this.totalDue,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': user.id,
      'name': user.name,
      'phoneNumber': user.phoneNumber,
      'address': user.address,
      'area': user.area,
      'yearsMissed': yearsMissed,
      'unpaidYears': unpaidYears,
      'totalDue': totalDue,
    };
  }
}

class AreaWiseReport {
  final String area;
  final int totalUsers;
  final int paidUsers;
  final int unpaidUsers;
  final double totalCollected;
  final double pendingAmount;

  AreaWiseReport({
    required this.area,
    required this.totalUsers,
    required this.paidUsers,
    required this.unpaidUsers,
    required this.totalCollected,
    required this.pendingAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'area': area,
      'totalUsers': totalUsers,
      'paidUsers': paidUsers,
      'unpaidUsers': unpaidUsers,
      'totalCollected': totalCollected,
      'pendingAmount': pendingAmount,
      'collectionPercentage': totalUsers > 0 ? (paidUsers / totalUsers * 100).toStringAsFixed(1) : '0.0',
    };
  }
}

class ReportData {
  final ReportType type;
  final ReportFilter filter;
  final DateTime generatedAt;
  final PaymentSummary? summary;
  final List<UnpaidUser>? unpaidUsers;
  final List<AreaWiseReport>? areaWiseData;
  final List<PaymentModel>? payments;
  final List<UserModel>? users;

  ReportData({
    required this.type,
    required this.filter,
    required this.generatedAt,
    this.summary,
    this.unpaidUsers,
    this.areaWiseData,
    this.payments,
    this.users,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'filter': filter.toMap(),
      'generatedAt': generatedAt.toIso8601String(),
      'summary': summary?.toMap(),
      'unpaidUsers': unpaidUsers?.map((u) => u.toMap()).toList(),
      'areaWiseData': areaWiseData?.map((a) => a.toMap()).toList(),
      'payments': payments?.map((p) => p.toFirestore()).toList(),
      'users': users?.map((u) => u.toFirestore()).toList(),
    };
  }
}