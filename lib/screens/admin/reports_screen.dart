import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../l10n/app_localizations.dart';
import '../../services/supabase_report_service.dart';
import '../../models/report_model.dart';
import '../../models/payment_model.dart';
import '../../theme/colors.dart';
import '../../theme/dimensions.dart';

/// Admin reports screen with filtering and export functionality
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  final SupabaseReportService _reportService = SupabaseReportService();
  late TabController _tabController;
  
  // Filter state
  ReportFilter _currentFilter = ReportFilter(year: DateTime.now().year);
  List<String> _availableAreas = [];
  
  // Report data
  dynamic _currentReportData;
  bool _isLoadingReport = false;
  bool _isExporting = false;
  
  // Date range
  DateTimeRange? _selectedDateRange;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAvailableAreas();
    _loadReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableAreas() async {
    try {
      final areas = await _reportService.getAvailableAreas();
      if (mounted) {
        setState(() {
          _availableAreas = areas;
        });
      }
    } catch (e) {
      // Handle error silently for now
    }
  }

  Future<void> _loadReport() async {
    if (_isLoadingReport) return;
    
    setState(() {
      _isLoadingReport = true;
    });

    try {
      dynamic reportData;
      
      switch (_tabController.index) {
        case 0:
          reportData = await _reportService.generatePaymentSummaryReport(
            startDate: _currentFilter.startDate,
            endDate: _currentFilter.endDate,
            area: _currentFilter.area,
            status: _currentFilter.status,
          );
          break;
        case 1:
          reportData = await _reportService.generateAreaWiseReport(_currentFilter.area ?? '');
          break;
        case 2:
          reportData = await _reportService.generateUnpaidUsersReport();
          break;
        case 3:
          reportData = await _reportService.generateDateWiseReport(
            startDate: _currentFilter.startDate,
            endDate: _currentFilter.endDate,
          );
          break;
        default:
          reportData = await _reportService.generatePaymentSummaryReport(
            startDate: _currentFilter.startDate,
            endDate: _currentFilter.endDate,
            area: _currentFilter.area,
            status: _currentFilter.status,
          );
      }
      
      if (mounted) {
        setState(() {
          _currentReportData = reportData;
          _isLoadingReport = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReport = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.appTitle} - Reports'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter Reports',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => _loadReport(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Summary', icon: Icon(Icons.summarize, size: 20)),
            Tab(text: 'Area-wise', icon: Icon(Icons.location_on, size: 20)),
            Tab(text: 'Unpaid', icon: Icon(Icons.warning, size: 20)),
            Tab(text: 'Date-wise', icon: Icon(Icons.calendar_today, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter summary bar
          _buildFilterSummary(l10n, theme),
          
          // Report content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentSummaryTab(l10n, theme),
                _buildAreaWiseTab(l10n, theme),
                _buildUnpaidUsersTab(l10n, theme),
                _buildDateWiseTab(l10n, theme),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _currentReportData != null
          ? FloatingActionButton.extended(
              onPressed: _isExporting ? null : _showExportDialog,
              backgroundColor: AppColors.primary,
              icon: _isExporting 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(_isExporting ? 'Exporting...' : 'Export'),
            )
          : null,
    );
  }

  Widget _buildFilterSummary(AppLocalizations l10n, ThemeData theme) {
    final hasFilters = _currentFilter.area != null ||
        _currentFilter.status != null ||
        _currentFilter.method != null ||
        _selectedDateRange != null ||
        _currentFilter.year != DateTime.now().year;

    if (!hasFilters) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_currentFilter.area != null)
            _buildFilterChip('Area: ${_currentFilter.area}', () {
              setState(() {
                _currentFilter = _currentFilter.copyWith(area: null);
              });
              _loadReport();
            }),
          if (_currentFilter.status != null)
            _buildFilterChip('Status: ${_currentFilter.status.toString().split('.').last}', () {
              setState(() {
                _currentFilter = _currentFilter.copyWith(status: null);
              });
              _loadReport();
            }),
          if (_currentFilter.method != null)
            _buildFilterChip('Method: ${_currentFilter.method.toString().split('.').last}', () {
              setState(() {
                _currentFilter = _currentFilter.copyWith(method: null);
              });
              _loadReport();
            }),
          if (_selectedDateRange != null)
            _buildFilterChip(
              'Date: ${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}',
              () {
                setState(() {
                  _selectedDateRange = null;
                  _currentFilter = _currentFilter.copyWith(
                    startDate: null,
                    endDate: null,
                  );
                });
                _loadReport();
              },
            ),
          if (_currentFilter.year != DateTime.now().year)
            _buildFilterChip('Year: ${_currentFilter.year}', () {
              setState(() {
                _currentFilter = _currentFilter.copyWith(year: DateTime.now().year);
              });
              _loadReport();
            }),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _currentFilter = ReportFilter(year: DateTime.now().year);
                _selectedDateRange = null;
              });
              _loadReport();
            },
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear All'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: onRemove,
      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
      deleteIconColor: AppColors.primary,
    );
  }

  Widget _buildPaymentSummaryTab(AppLocalizations l10n, ThemeData theme) {
    if (_isLoadingReport) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentReportData == null) {
      return const Center(child: Text('No data available'));
    }

    final summary = _currentReportData!.summary;
    if (summary == null) {
      return const Center(child: Text('No summary data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary statistics cards
          _buildSummaryStatsGrid(summary, theme),
          const SizedBox(height: AppDimensions.spacingLg),
          
          // Payment method breakdown
          _buildPaymentMethodBreakdown(summary, theme),
          const SizedBox(height: AppDimensions.spacingLg),
          
          // Recent payments list
          if (_currentReportData!.payments != null && _currentReportData!.payments!.isNotEmpty)
            _buildRecentPaymentsList(_currentReportData!.payments!, theme),
        ],
      ),
    );
  }

  Widget _buildSummaryStatsGrid(PaymentSummary summary, ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: AppDimensions.spacingMd,
      mainAxisSpacing: AppDimensions.spacingMd,
      children: [
        _buildStatCard(
          title: 'Total Payments',
          value: summary.totalPayments.toString(),
          subtitle: '₹${summary.totalAmount.toStringAsFixed(0)}',
          icon: Icons.payments,
          color: Colors.blue,
          theme: theme,
        ),
        _buildStatCard(
          title: 'Approved',
          value: summary.approvedPayments.toString(),
          subtitle: '₹${summary.approvedAmount.toStringAsFixed(0)}',
          icon: Icons.check_circle,
          color: Colors.green,
          theme: theme,
        ),
        _buildStatCard(
          title: 'Pending',
          value: summary.pendingPayments.toString(),
          subtitle: '₹${summary.pendingAmount.toStringAsFixed(0)}',
          icon: Icons.pending,
          color: Colors.orange,
          theme: theme,
        ),
        _buildStatCard(
          title: 'Rejected',
          value: summary.rejectedPayments.toString(),
          subtitle: 'Review needed',
          icon: Icons.cancel,
          color: Colors.red,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodBreakdown(PaymentSummary summary, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Methods',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            ...summary.paymentsByMethod.entries.map((entry) {
              final method = entry.key;
              final count = entry.value;
              final percentage = summary.totalPayments > 0 
                  ? (count / summary.totalPayments * 100).toStringAsFixed(1)
                  : '0.0';
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(_getPaymentMethodIcon(method), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(method.toString().split('.').last),
                    ),
                    Text('$count ($percentage%)'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPaymentsList(List<PaymentModel> payments, ThemeData theme) {
    final recentPayments = payments.take(10).toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Payments',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentPayments.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final payment = recentPayments[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(payment.status).withValues(alpha: 0.2),
                    child: Icon(
                      _getPaymentMethodIcon(payment.method),
                      color: _getStatusColor(payment.status),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    payment.receiptNumber,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${payment.methodDisplayText} • ${DateFormat('MMM dd, yyyy').format(payment.createdAt)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${payment.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(payment.status).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          payment.statusDisplayText,
                          style: TextStyle(
                            color: _getStatusColor(payment.status),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAreaWiseTab(AppLocalizations l10n, ThemeData theme) {
    if (_isLoadingReport) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentReportData?.areaWiseData == null || _currentReportData!.areaWiseData!.isEmpty) {
      return const Center(child: Text('No area data available'));
    }

    final areaData = _currentReportData!.areaWiseData!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Area summary cards
          Text(
            'Area-wise Collection Summary',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: areaData.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingMd),
            itemBuilder: (context, index) {
              final area = areaData[index];
              final collectionRate = area.totalUsers > 0 
                  ? (area.paidUsers / area.totalUsers * 100)
                  : 0.0;
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              area.area,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCollectionRateColor(collectionRate).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${collectionRate.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: _getCollectionRateColor(collectionRate),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingMd),
                      
                      // Progress bar
                      LinearProgressIndicator(
                        value: collectionRate / 100,
                        backgroundColor: Colors.grey.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getCollectionRateColor(collectionRate),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingMd),
                      
                      // Statistics grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildAreaStatItem(
                              'Total Users',
                              area.totalUsers.toString(),
                              Icons.people,
                              Colors.blue,
                            ),
                          ),
                          Expanded(
                            child: _buildAreaStatItem(
                              'Paid',
                              area.paidUsers.toString(),
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ),
                          Expanded(
                            child: _buildAreaStatItem(
                              'Unpaid',
                              area.unpaidUsers.toString(),
                              Icons.warning,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildAreaStatItem(
                              'Collected',
                              '₹${area.totalCollected.toStringAsFixed(0)}',
                              Icons.currency_rupee,
                              Colors.green,
                            ),
                          ),
                          Expanded(
                            child: _buildAreaStatItem(
                              'Pending',
                              '₹${area.pendingAmount.toStringAsFixed(0)}',
                              Icons.pending,
                              Colors.orange,
                            ),
                          ),
                          const Expanded(child: SizedBox()), // Empty space for alignment
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAreaStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUnpaidUsersTab(AppLocalizations l10n, ThemeData theme) {
    if (_isLoadingReport) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentReportData?.unpaidUsers == null || _currentReportData!.unpaidUsers!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'All users are up to date!',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No unpaid users found for the selected filters.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final unpaidUsers = _currentReportData!.unpaidUsers!;
    final totalDue = unpaidUsers.fold(0.0, (sum, user) => sum + user.totalDue);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Card(
            color: Colors.red.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${unpaidUsers.length} Unpaid Users',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          'Total Outstanding: ₹${totalDue.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.red.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          
          // Unpaid users list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: unpaidUsers.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingSm),
            itemBuilder: (context, index) {
              final unpaidUser = unpaidUsers[index];
              final user = unpaidUser.user;
              
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withValues(alpha: 0.2),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  title: Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${user.phoneNumber} • ${user.area}'),
                      Text(
                        'Unpaid Years: ${unpaidUser.unpaidYears.join(', ')}',
                        style: TextStyle(
                          color: Colors.red.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${unpaidUser.totalDue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${unpaidUser.yearsMissed} years',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateWiseTab(AppLocalizations l10n, ThemeData theme) {
    if (_isLoadingReport) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentReportData?.payments == null || _currentReportData!.payments!.isEmpty) {
      return const Center(child: Text('No payment data available'));
    }

    final payments = _currentReportData!.payments!;
    
    // Group payments by date
    final paymentsByDate = <String, List<PaymentModel>>{};
    for (final payment in payments) {
      final dateKey = DateFormat('yyyy-MM-dd').format(payment.createdAt);
      paymentsByDate.putIfAbsent(dateKey, () => []).add(payment);
    }

    final sortedDates = paymentsByDate.keys.toList()..sort((a, b) => b.compareTo(a));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          if (_currentReportData!.summary != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date Range Summary',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryItem(
                            'Total Payments',
                            _currentReportData!.summary!.totalPayments.toString(),
                            Icons.payments,
                            Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildSummaryItem(
                            'Total Amount',
                            '₹${_currentReportData!.summary!.totalAmount.toStringAsFixed(0)}',
                            Icons.currency_rupee,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppDimensions.spacingMd),
          
          // Daily breakdown
          Text(
            'Daily Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedDates.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppDimensions.spacingSm),
            itemBuilder: (context, index) {
              final dateKey = sortedDates[index];
              final dayPayments = paymentsByDate[dateKey]!;
              final approvedPayments = dayPayments.where((p) => p.status == PaymentStatus.APPROVED).toList();
              final totalAmount = dayPayments.fold(0.0, (sum, p) => sum + p.totalAmount);
              final approvedAmount = approvedPayments.fold(0.0, (sum, p) => sum + p.totalAmount);
              
              return Card(
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      dayPayments.length.toString(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    DateFormat('EEEE, MMM dd, yyyy').format(DateTime.parse(dateKey)),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${dayPayments.length} payments • ₹${totalAmount.toStringAsFixed(2)}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingMd),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDayStatItem(
                                  'Total',
                                  dayPayments.length.toString(),
                                  '₹${totalAmount.toStringAsFixed(2)}',
                                  Colors.blue,
                                ),
                              ),
                              Expanded(
                                child: _buildDayStatItem(
                                  'Approved',
                                  approvedPayments.length.toString(),
                                  '₹${approvedAmount.toStringAsFixed(2)}',
                                  Colors.green,
                                ),
                              ),
                              Expanded(
                                child: _buildDayStatItem(
                                  'Pending',
                                  (dayPayments.length - approvedPayments.length).toString(),
                                  '₹${(totalAmount - approvedAmount).toStringAsFixed(2)}',
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacingMd),
                          
                          // Payment list for the day
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: dayPayments.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, paymentIndex) {
                              final payment = dayPayments[paymentIndex];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  _getPaymentMethodIcon(payment.method),
                                  color: _getStatusColor(payment.status),
                                  size: 20,
                                ),
                                title: Text(
                                  payment.receiptNumber,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  DateFormat('HH:mm').format(payment.createdAt),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${payment.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(payment.status).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        payment.statusDisplayText,
                                        style: TextStyle(
                                          color: _getStatusColor(payment.status),
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDayStatItem(String label, String count, String amount, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: color,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Filter Dialog
  Future<void> _showFilterDialog() async {
    final result = await showDialog<ReportFilter>(
      context: context,
      builder: (context) => _FilterDialog(
        currentFilter: _currentFilter,
        availableAreas: _availableAreas,
        selectedDateRange: _selectedDateRange,
      ),
    );

    if (result != null) {
      setState(() {
        _currentFilter = result;
        if (result.startDate != null && result.endDate != null) {
          _selectedDateRange = DateTimeRange(
            start: result.startDate!,
            end: result.endDate!,
          );
        } else {
          _selectedDateRange = null;
        }
      });
      _loadReport();
    }
  }

  // Export Dialog
  Future<void> _showExportDialog() async {
    if (_currentReportData == null) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export as CSV'),
              subtitle: const Text('Comma-separated values format'),
              onTap: () => Navigator.of(context).pop('csv'),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on),
              title: const Text('Export as Excel'),
              subtitle: const Text('Microsoft Excel format'),
              onTap: () => Navigator.of(context).pop('excel'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _exportReport(result);
    }
  }

  Future<void> _exportReport(String format) async {
    if (_currentReportData == null) return;

    setState(() {
      _isExporting = true;
    });

    try {
      File file;
      
      if (format == 'csv') {
        file = await _reportService.exportToCSV(_currentReportData!, 'report_${DateTime.now().millisecondsSinceEpoch}');
      } else {
        file = await _reportService.exportToExcel(_currentReportData!, 'report_${DateTime.now().millisecondsSinceEpoch}');
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
        });

        // Show success dialog with share option
        final shouldShare = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Successful'),
            content: Text('Report exported successfully to:\n${file.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('OK'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Share'),
              ),
            ],
          ),
        );

        if (shouldShare == true) {
          await _reportService.shareReport(file, 'Report');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper methods for UI
  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.UPI:
        return Icons.qr_code;
      case PaymentMethod.CASH:
        return Icons.money;
      case PaymentMethod.WALLET:
        return Icons.account_balance_wallet;
      case PaymentMethod.COMBINED:
        return Icons.payment;
    }
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.APPROVED:
        return Colors.green;
      case PaymentStatus.PENDING:
        return Colors.orange;
      case PaymentStatus.REJECTED:
        return Colors.red;
      case PaymentStatus.INCOMPLETE:
        return Colors.grey;
    }
  }

  Color _getCollectionRateColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 60) return Colors.orange;
    return Colors.red;
  }
}

// Filter Dialog Widget
class _FilterDialog extends StatefulWidget {
  final ReportFilter currentFilter;
  final List<String> availableAreas;
  final DateTimeRange? selectedDateRange;

  const _FilterDialog({
    required this.currentFilter,
    required this.availableAreas,
    this.selectedDateRange,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late ReportFilter _filter;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _filter = widget.currentFilter;
    _dateRange = widget.selectedDateRange;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Filter Reports'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Year filter
            Text(
              'Year',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _filter.year,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: List.generate(10, (index) {
                final year = DateTime.now().year - index;
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              }),
              onChanged: (value) {
                setState(() {
                  _filter = _filter.copyWith(year: value);
                });
              },
            ),
            const SizedBox(height: 16),

            // Date range filter
            Text(
              'Date Range',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDateRange,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _dateRange != null
                            ? '${DateFormat('MMM dd, yyyy').format(_dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}'
                            : 'Select date range',
                      ),
                    ),
                    if (_dateRange != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _dateRange = null;
                            _filter = _filter.copyWith(
                              startDate: null,
                              endDate: null,
                            );
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Area filter
            Text(
              'Area',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _filter.area,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('All Areas'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Areas'),
                ),
                ...widget.availableAreas.map((area) => DropdownMenuItem(
                  value: area,
                  child: Text(area),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _filter = _filter.copyWith(area: value);
                });
              },
            ),
            const SizedBox(height: 16),

            // Status filter
            Text(
              'Payment Status',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PaymentStatus>(
              value: _filter.status,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('All Statuses'),
              items: [
                const DropdownMenuItem<PaymentStatus>(
                  value: null,
                  child: Text('All Statuses'),
                ),
                ...PaymentStatus.values.map((status) => DropdownMenuItem(
                  value: status,
                  child: Text(status.toString().split('.').last),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _filter = _filter.copyWith(status: value);
                });
              },
            ),
            const SizedBox(height: 16),

            // Method filter
            Text(
              'Payment Method',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PaymentMethod>(
              value: _filter.method,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('All Methods'),
              items: [
                const DropdownMenuItem<PaymentMethod>(
                  value: null,
                  child: Text('All Methods'),
                ),
                ...PaymentMethod.values.map((method) => DropdownMenuItem(
                  value: method,
                  child: Text(method.toString().split('.').last),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _filter = _filter.copyWith(method: value);
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _filter = ReportFilter(year: DateTime.now().year);
              _dateRange = null;
            });
          },
          child: const Text('Clear All'),
        ),
        ElevatedButton(
          onPressed: () {
            // Update filter with date range
            final updatedFilter = _dateRange != null
                ? _filter.copyWith(
                    startDate: _dateRange!.start,
                    endDate: _dateRange!.end,
                  )
                : _filter;
            Navigator.of(context).pop(updatedFilter);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Future<void> _selectDateRange() async {
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );

    if (dateRange != null) {
      setState(() {
        _dateRange = dateRange;
        _filter = _filter.copyWith(
          startDate: dateRange.start,
          endDate: dateRange.end,
        );
      });
    }
  }
}
