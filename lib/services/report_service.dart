import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:jafary_channel_app/models/models.dart';
import 'package:jafary_channel_app/services/user_service.dart';
import 'package:jafary_channel_app/services/settings_service.dart';

class ReportService {
  final FirebaseFirestore _firestore;
  final UserService _userService;
  final SettingsService _settingsService;

  ReportService({
    FirebaseFirestore? firestore,
    UserService? userService,
    SettingsService? settingsService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _userService = userService ?? UserService(),
       _settingsService = settingsService ?? SettingsService();

  // Generate payment summary report
  Future<ReportData> generatePaymentSummaryReport(ReportFilter filter) async {
    try {
      final payments = await _getFilteredPayments(filter);
      final summary = PaymentSummary.fromPayments(payments);

      return ReportData(
        type: ReportType.paymentSummary,
        filter: filter,
        generatedAt: DateTime.now(),
        summary: summary,
        payments: payments,
      );
    } catch (e) {
      throw Exception('Failed to generate payment summary report: $e');
    }
  }

  // Generate unpaid users report
  Future<ReportData> generateUnpaidUsersReport(ReportFilter filter) async {
    try {
      final users = await _userService.getAllUsers();
      final currentYear = DateTime.now().year;
      final targetYear = filter.year ?? currentYear;
      final unpaidUsers = <UnpaidUser>[];

      for (final user in users) {
        if (user.role != UserRole.USER) continue;
        if (filter.area != null && user.area != filter.area) continue;

        final userPayments = await _getUserPayments(user.id);
        final paidYears = userPayments
            .where((p) => p.status == PaymentStatus.APPROVED)
            .map((p) => p.year)
            .toSet();

        final unpaidYears = <int>[];
        double totalDue = 0.0;

        // Check for unpaid years from 2020 to target year
        for (int year = 2020; year <= targetYear; year++) {
          if (!paidYears.contains(year)) {
            unpaidYears.add(year);
            // Get yearly fee for that year (use current settings as fallback)
            final settings = await _settingsService.getSettings();
            totalDue += settings.yearlyFee;
          }
        }

        if (unpaidYears.isNotEmpty) {
          unpaidUsers.add(UnpaidUser(
            user: user,
            yearsMissed: unpaidYears.length,
            unpaidYears: unpaidYears,
            totalDue: totalDue,
          ));
        }
      }

      return ReportData(
        type: ReportType.unpaidUsers,
        filter: filter,
        generatedAt: DateTime.now(),
        unpaidUsers: unpaidUsers,
      );
    } catch (e) {
      throw Exception('Failed to generate unpaid users report: $e');
    }
  }

  // Generate area-wise report
  Future<ReportData> generateAreaWiseReport(ReportFilter filter) async {
    try {
      final users = await _userService.getAllUsers();
      final payments = await _getFilteredPayments(filter);
      final areaWiseData = <String, AreaWiseReport>{};

      // Group users by area
      final usersByArea = <String, List<UserModel>>{};
      for (final user in users) {
        if (user.role != UserRole.USER) continue;
        usersByArea.putIfAbsent(user.area, () => []).add(user);
      }

      // Group payments by user area
      final paymentsByArea = <String, List<PaymentModel>>{};
      for (final payment in payments) {
        final user = users.firstWhere((u) => u.id == payment.userId);
        paymentsByArea.putIfAbsent(user.area, () => []).add(payment);
      }

      // Calculate area-wise statistics
      for (final area in usersByArea.keys) {
        final areaUsers = usersByArea[area]!;
        final areaPayments = paymentsByArea[area] ?? [];
        
        final approvedPayments = areaPayments
            .where((p) => p.status == PaymentStatus.APPROVED)
            .toList();
        
        final paidUserIds = approvedPayments.map((p) => p.userId).toSet();
        final totalCollected = approvedPayments
            .fold(0.0, (total, p) => total + p.totalAmount);
        
        final pendingPayments = areaPayments
            .where((p) => p.status == PaymentStatus.PENDING)
            .toList();
        final pendingAmount = pendingPayments
            .fold(0.0, (total, p) => total + p.totalAmount);

        areaWiseData[area] = AreaWiseReport(
          area: area,
          totalUsers: areaUsers.length,
          paidUsers: paidUserIds.length,
          unpaidUsers: areaUsers.length - paidUserIds.length,
          totalCollected: totalCollected,
          pendingAmount: pendingAmount,
        );
      }

      return ReportData(
        type: ReportType.areaWise,
        filter: filter,
        generatedAt: DateTime.now(),
        areaWiseData: areaWiseData.values.toList(),
      );
    } catch (e) {
      throw Exception('Failed to generate area-wise report: $e');
    }
  }

  // Generate date-wise report
  Future<ReportData> generateDateWiseReport(ReportFilter filter) async {
    try {
      final payments = await _getFilteredPayments(filter);
      
      return ReportData(
        type: ReportType.dateWise,
        filter: filter,
        generatedAt: DateTime.now(),
        payments: payments,
        summary: PaymentSummary.fromPayments(payments),
      );
    } catch (e) {
      throw Exception('Failed to generate date-wise report: $e');
    }
  }

  // Export report to Excel (XLSX format)
  Future<String> exportToExcel(ReportData reportData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${reportData.type.toString().split('.').last.toLowerCase()}_report_$timestamp.xlsx';
      final filePath = '${directory.path}/$fileName';

      // For now, we'll export as CSV with .xlsx extension
      // In a real implementation, you'd use a package like excel
      final csvData = _generateCSVData(reportData);
      final csvString = const ListToCsvConverter().convert(csvData);
      final file = File(filePath.replaceAll('.xlsx', '.csv'));
      await file.writeAsString(csvString);

      return file.path;
    } catch (e) {
      throw Exception('Failed to export Excel: $e');
    }
  }

  // Export report to CSV
  Future<String> exportToCSV(ReportData reportData) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${reportData.type.toString().split('.').last.toLowerCase()}_report_$timestamp.csv';
      final filePath = '${directory.path}/$fileName';

      final csvData = _generateCSVData(reportData);

      final csvString = const ListToCsvConverter().convert(csvData);
      final file = File(filePath);
      await file.writeAsString(csvString);

      return filePath;
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  // Share report file
  Future<void> shareReport(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      throw Exception('Failed to share report: $e');
    }
  }

  // Generate comprehensive collection report
  Future<ReportData> generateCollectionReport(ReportFilter filter) async {
    try {
      final payments = await _getFilteredPayments(filter);
      final users = await _userService.getAllUsers();
      final summary = PaymentSummary.fromPayments(payments);

      // Calculate additional metrics
      final totalUsers = users.where((u) => u.role == UserRole.USER).length;
      final paidUserIds = payments
          .where((p) => p.status == PaymentStatus.APPROVED)
          .map((p) => p.userId)
          .toSet();
      final collectionRate = totalUsers > 0 ? (paidUserIds.length / totalUsers * 100) : 0.0;

      return ReportData(
        type: ReportType.paymentSummary,
        filter: filter,
        generatedAt: DateTime.now(),
        summary: summary,
        payments: payments,
        users: users.where((u) => u.role == UserRole.USER).toList(),
      );
    } catch (e) {
      throw Exception('Failed to generate collection report: $e');
    }
  }

  // Get available areas for filtering
  Future<List<String>> getAvailableAreas() async {
    try {
      final users = await _userService.getAllUsers();
      final areas = users
          .where((u) => u.role == UserRole.USER)
          .map((u) => u.area)
          .toSet()
          .toList();
      areas.sort();
      return areas;
    } catch (e) {
      throw Exception('Failed to get available areas: $e');
    }
  }

  // Get payment statistics for dashboard
  Future<Map<String, dynamic>> getPaymentStatistics({int? year}) async {
    try {
      final targetYear = year ?? DateTime.now().year;
      final filter = ReportFilter(year: targetYear);
      final payments = await _getFilteredPayments(filter);
      final users = await _userService.getAllUsers();
      
      final totalUsers = users.where((u) => u.role == UserRole.USER).length;
      final paidUserIds = payments
          .where((p) => p.status == PaymentStatus.APPROVED)
          .map((p) => p.userId)
          .toSet();
      
      final pendingPayments = payments.where((p) => p.status == PaymentStatus.PENDING).length;
      final approvedAmount = payments
          .where((p) => p.status == PaymentStatus.APPROVED)
          .fold(0.0, (total, p) => total + p.totalAmount);
      
      return {
        'totalUsers': totalUsers,
        'paidUsers': paidUserIds.length,
        'unpaidUsers': totalUsers - paidUserIds.length,
        'collectionRate': totalUsers > 0 ? (paidUserIds.length / totalUsers * 100) : 0.0,
        'pendingPayments': pendingPayments,
        'totalCollected': approvedAmount,
        'year': targetYear,
      };
    } catch (e) {
      throw Exception('Failed to get payment statistics: $e');
    }
  }

  // Private helper methods

  List<List<dynamic>> _generateCSVData(ReportData reportData) {
    switch (reportData.type) {
      case ReportType.paymentSummary:
        return _generatePaymentSummaryCSV(reportData);
      case ReportType.unpaidUsers:
        return _generateUnpaidUsersCSV(reportData);
      case ReportType.areaWise:
        return _generateAreaWiseCSV(reportData);
      case ReportType.dateWise:
        return _generateDateWiseCSV(reportData);
    }
  }

  Future<List<PaymentModel>> _getFilteredPayments(ReportFilter filter) async {
    try {
      Query query = _firestore.collection('payments');

      // Apply filters
      if (filter.startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(filter.startDate!));
      }
      if (filter.endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(filter.endDate!));
      }
      if (filter.status != null) {
        query = query.where('status', isEqualTo: filter.status.toString().split('.').last);
      }
      if (filter.method != null) {
        query = query.where('method', isEqualTo: filter.method.toString().split('.').last);
      }
      if (filter.year != null) {
        query = query.where('year', isEqualTo: filter.year);
      }

      final snapshot = await query.get();
      final payments = snapshot.docs.map((doc) => PaymentModel.fromFirestore(doc)).toList();

      // Apply area filter (requires user lookup)
      if (filter.area != null) {
        final users = await _userService.getAllUsers();
        final areaUserIds = users
            .where((u) => u.area == filter.area)
            .map((u) => u.id)
            .toSet();
        
        return payments.where((p) => areaUserIds.contains(p.userId)).toList();
      }

      return payments;
    } catch (e) {
      throw Exception('Failed to get filtered payments: $e');
    }
  }

  Future<List<PaymentModel>> _getUserPayments(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .get();
      
      return snapshot.docs.map((doc) => PaymentModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get user payments: $e');
    }
  }

  List<List<dynamic>> _generatePaymentSummaryCSV(ReportData reportData) {
    final csvData = <List<dynamic>>[];
    
    // Header
    csvData.add(['Payment Summary Report']);
    csvData.add(['Generated At', reportData.generatedAt.toString()]);
    csvData.add([]);
    
    // Summary statistics
    if (reportData.summary != null) {
      final summary = reportData.summary!;
      csvData.add(['Summary Statistics']);
      csvData.add(['Total Payments', summary.totalPayments]);
      csvData.add(['Approved Payments', summary.approvedPayments]);
      csvData.add(['Pending Payments', summary.pendingPayments]);
      csvData.add(['Rejected Payments', summary.rejectedPayments]);
      csvData.add(['Total Amount', '₹${summary.totalAmount.toStringAsFixed(2)}']);
      csvData.add(['Approved Amount', '₹${summary.approvedAmount.toStringAsFixed(2)}']);
      csvData.add(['Pending Amount', '₹${summary.pendingAmount.toStringAsFixed(2)}']);
      csvData.add([]);
    }

    // Payment details
    if (reportData.payments != null && reportData.payments!.isNotEmpty) {
      csvData.add(['Payment Details']);
      csvData.add([
        'Receipt Number',
        'User ID',
        'Amount',
        'Extra Charges',
        'Total Amount',
        'Method',
        'Status',
        'Transaction ID',
        'Created At',
        'Approved At',
        'Year'
      ]);
      
      for (final payment in reportData.payments!) {
        csvData.add([
          payment.receiptNumber,
          payment.userId,
          payment.amount,
          payment.extraCharges,
          payment.totalAmount,
          payment.methodDisplayText,
          payment.statusDisplayText,
          payment.transactionId ?? '',
          payment.createdAt.toString(),
          payment.approvedAt?.toString() ?? '',
          payment.year,
        ]);
      }
    }

    return csvData;
  }

  List<List<dynamic>> _generateUnpaidUsersCSV(ReportData reportData) {
    final csvData = <List<dynamic>>[];
    
    // Header
    csvData.add(['Unpaid Users Report']);
    csvData.add(['Generated At', reportData.generatedAt.toString()]);
    csvData.add([]);
    
    if (reportData.unpaidUsers != null && reportData.unpaidUsers!.isNotEmpty) {
      csvData.add([
        'Name',
        'Phone Number',
        'Address',
        'Area',
        'Years Missed',
        'Unpaid Years',
        'Total Due'
      ]);
      
      for (final unpaidUser in reportData.unpaidUsers!) {
        csvData.add([
          unpaidUser.user.name,
          unpaidUser.user.phoneNumber,
          unpaidUser.user.address,
          unpaidUser.user.area,
          unpaidUser.yearsMissed,
          unpaidUser.unpaidYears.join(', '),
          '₹${unpaidUser.totalDue.toStringAsFixed(2)}',
        ]);
      }
    } else {
      csvData.add(['No unpaid users found']);
    }

    return csvData;
  }

  List<List<dynamic>> _generateAreaWiseCSV(ReportData reportData) {
    final csvData = <List<dynamic>>[];
    
    // Header
    csvData.add(['Area-wise Report']);
    csvData.add(['Generated At', reportData.generatedAt.toString()]);
    csvData.add([]);
    
    if (reportData.areaWiseData != null && reportData.areaWiseData!.isNotEmpty) {
      csvData.add([
        'Area',
        'Total Users',
        'Paid Users',
        'Unpaid Users',
        'Collection %',
        'Total Collected',
        'Pending Amount'
      ]);
      
      for (final areaData in reportData.areaWiseData!) {
        final collectionPercentage = areaData.totalUsers > 0 
            ? (areaData.paidUsers / areaData.totalUsers * 100).toStringAsFixed(1)
            : '0.0';
            
        csvData.add([
          areaData.area,
          areaData.totalUsers,
          areaData.paidUsers,
          areaData.unpaidUsers,
          '$collectionPercentage%',
          '₹${areaData.totalCollected.toStringAsFixed(2)}',
          '₹${areaData.pendingAmount.toStringAsFixed(2)}',
        ]);
      }
    } else {
      csvData.add(['No area data found']);
    }

    return csvData;
  }

  List<List<dynamic>> _generateDateWiseCSV(ReportData reportData) {
    final csvData = <List<dynamic>>[];
    
    // Header
    csvData.add(['Date-wise Report']);
    csvData.add(['Generated At', reportData.generatedAt.toString()]);
    csvData.add([]);
    
    // Summary
    if (reportData.summary != null) {
      final summary = reportData.summary!;
      csvData.add(['Summary']);
      csvData.add(['Total Payments', summary.totalPayments]);
      csvData.add(['Total Amount', '₹${summary.totalAmount.toStringAsFixed(2)}']);
      csvData.add([]);
    }

    // Daily breakdown
    if (reportData.payments != null && reportData.payments!.isNotEmpty) {
      // Group payments by date
      final paymentsByDate = <String, List<PaymentModel>>{};
      for (final payment in reportData.payments!) {
        final dateKey = '${payment.createdAt.year}-${payment.createdAt.month.toString().padLeft(2, '0')}-${payment.createdAt.day.toString().padLeft(2, '0')}';
        paymentsByDate.putIfAbsent(dateKey, () => []).add(payment);
      }

      csvData.add(['Date', 'Payment Count', 'Total Amount', 'Approved Count', 'Approved Amount']);
      
      final sortedDates = paymentsByDate.keys.toList()..sort();
      for (final date in sortedDates) {
        final dayPayments = paymentsByDate[date]!;
        final approvedPayments = dayPayments.where((p) => p.status == PaymentStatus.APPROVED).toList();
        
        csvData.add([
          date,
          dayPayments.length,
          '₹${dayPayments.fold(0.0, (total, p) => total + p.totalAmount).toStringAsFixed(2)}',
          approvedPayments.length,
          '₹${approvedPayments.fold(0.0, (total, p) => total + p.totalAmount).toStringAsFixed(2)}',
        ]);
      }
    }

    return csvData;
  }
}