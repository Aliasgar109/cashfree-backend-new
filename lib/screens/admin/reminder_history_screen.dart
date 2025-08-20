import 'package:flutter/material.dart';
import '../../services/supabase_reminder_service.dart';
import '../../services/supabase_user_service.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../theme/dimensions.dart';


/// Screen for viewing reminder history and statistics
class ReminderHistoryScreen extends StatefulWidget {
  const ReminderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ReminderHistoryScreen> createState() => _ReminderHistoryScreenState();
}

class _ReminderHistoryScreenState extends State<ReminderHistoryScreen> {
  final SupabaseReminderService _reminderService = SupabaseReminderService();
  final SupabaseUserService _userService = SupabaseUserService();
  
  bool _isLoading = true;
  String? _errorMessage;
  
  ReminderStats? _stats;
  List<ReminderHistoryEntry> _historyEntries = [];
  Map<String, UserModel> _userCache = {};
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadReminderData();
  }

  Future<void> _loadReminderData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load stats and recent history
      final stats = await _reminderService.getReminderStats(
        startDate: _startDate,
        endDate: _endDate,
      );
      
      // Load recent reminder history (last 50 entries)
      final allUsers = await _userService.getAllUsers();
      final userMap = {for (var user in allUsers) user.id: user};
      
      // Get history for all users (limited to recent entries)
      final List<ReminderHistoryEntry> allHistory = [];
      for (final user in allUsers.where((u) => u.role == UserRole.USER)) {
        final userHistory = await _reminderService.getReminderHistory(
          userId: user.id,
          limit: 10, // Limit per user to avoid too much data
        );
        allHistory.addAll(userHistory);
      }
      
      // Sort by date (most recent first)
      allHistory.sort((a, b) => (b.sentAt ?? DateTime.now()).compareTo(a.sentAt ?? DateTime.now()));
      
      setState(() {
        _stats = stats;
        _historyEntries = allHistory.take(50).toList(); // Show top 50 recent entries
        _userCache = userMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load reminder data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReminderData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReminderData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.paddingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateRangeInfo(),
                      const SizedBox(height: AppDimensions.spacingMd),
                      _buildStatsSection(),
                      const SizedBox(height: AppDimensions.spacingLg),
                      _buildHistorySection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          ElevatedButton(
            onPressed: _loadReminderData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Row(
          children: [
            Icon(Icons.date_range, color: AppColors.primary),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Text(
                'Showing data from ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: _selectDateRange,
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_stats == null) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reminder Statistics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            
            // Overall stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Sent',
                    _stats!.totalSent.toString(),
                    Icons.send,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: _buildStatCard(
                    'Successful',
                    _stats!.successful.toString(),
                    Icons.check_circle,
                    AppColors.success,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppDimensions.spacingSm),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Push Notifications',
                    _stats!.pushNotificationsSent.toString(),
                    Icons.notifications,
                    AppColors.info,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: _buildStatCard(
                    'Success Rate',
                    _stats!.totalSent > 0 
                        ? '${((_stats!.successful / _stats!.totalSent) * 100).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.trending_up,
                    AppColors.warning,
                  ),
                ),
              ],
            ),
            
            // Breakdown by type
            if (_stats!.byType.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                'By Reminder Type',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              ..._stats!.byType.entries.map((entry) => 
                _buildTypeBreakdown(_typeFromString(entry.key), entry.value)
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBreakdown(ReminderType type, int count) {
    final typeInfo = _getReminderTypeInfo(type);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingXs),
      child: Row(
        children: [
          Icon(typeInfo.icon, size: 16, color: typeInfo.color),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(child: Text(typeInfo.label)),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingSm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: typeInfo.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: typeInfo.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Reminder History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            
            if (_historyEntries.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingLg),
                  child: Text('No reminder history found for the selected period'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _historyEntries.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = _historyEntries[index];
                  final user = _userCache[entry.userId];
                  return _buildHistoryItem(entry, user);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(ReminderHistoryEntry entry, UserModel? user) {
    final typeInfo = _getReminderTypeInfo(_typeFromString(entry.type));
    final statusInfo = _getReminderStatusInfo(_statusFromString(entry.status));
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: typeInfo.color.withOpacity(0.1),
        child: Icon(typeInfo.icon, color: typeInfo.color, size: 20),
      ),
      title: Text(user?.name ?? 'Unknown User'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(typeInfo.label),
          Text(
            _formatDateTime(entry.sentAt ?? DateTime.now()),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingSm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: statusInfo.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Text(
              statusInfo.label,
              style: TextStyle(
                color: statusInfo.color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.notificationSent)
                Icon(Icons.message, size: 16, color: AppColors.success)
              else
                Icon(Icons.message_outlined, size: 16, color: AppColors.error),
              const SizedBox(width: 4),
              if (entry.pushNotificationSent)
                Icon(Icons.notifications, size: 16, color: AppColors.success)
              else
                Icon(Icons.notifications_off, size: 16, color: AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  // Convert backend string values to enums expected by UI helpers
  ReminderType _typeFromString(String value) {
    final s = value.toUpperCase();
    switch (s) {
      case 'DUE_DATE':
      case 'PAYMENT_DUE':
      case 'DUE':
        return ReminderType.paymentDue;
      case 'OVERDUE':
      case 'OVERDUE_PAYMENT':
        return ReminderType.overduePayment;
      case 'FINAL_NOTICE':
        return ReminderType.finalNotice;
      case 'PAYMENT_RECEIVED':
        // Not specifically styled; treat as custom for now
        return ReminderType.CUSTOM;
      default:
        return ReminderType.CUSTOM;
    }
  }

  ReminderStatus _statusFromString(String value) {
    final s = value.toUpperCase();
    switch (s) {
      case 'SCHEDULED':
        return ReminderStatus.scheduled;
      case 'SENT':
      case 'DELIVERED': // show as sent/success
        return ReminderStatus.sent;
      case 'FAILED':
        return ReminderStatus.failed;
      case 'CANCELLED':
        return ReminderStatus.cancelled;
      default:
        return ReminderStatus.sent;
    }
  }

  ReminderTypeInfo _getReminderTypeInfo(ReminderType type) {
    switch (type) {
      case ReminderType.paymentDue:
        return ReminderTypeInfo(
          label: 'Payment Due',
          icon: Icons.schedule,
          color: AppColors.info,
        );
      case ReminderType.overduePayment:
        return ReminderTypeInfo(
          label: 'Overdue Payment',
          icon: Icons.warning,
          color: AppColors.warning,
        );
      case ReminderType.finalNotice:
        return ReminderTypeInfo(
          label: 'Final Notice',
          icon: Icons.error,
          color: AppColors.error,
        );
      default:
        return ReminderTypeInfo(
          label: 'Custom',
          icon: Icons.notification_important,
          color: AppColors.primary,
        );
    }
  }

  ReminderStatusInfo _getReminderStatusInfo(ReminderStatus status) {
    switch (status) {
      case ReminderStatus.scheduled:
        return ReminderStatusInfo(
          label: 'Scheduled',
          color: AppColors.info,
        );
      case ReminderStatus.sent:
        return ReminderStatusInfo(
          label: 'Sent',
          color: AppColors.success,
        );
      case ReminderStatus.failed:
        return ReminderStatusInfo(
          label: 'Failed',
          color: AppColors.error,
        );
      case ReminderStatus.cancelled:
        return ReminderStatusInfo(
          label: 'Cancelled',
          color: AppColors.textSecondary,
        );
      default:
        return ReminderStatusInfo(
          label: 'Unknown',
          color: AppColors.textSecondary,
        );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class ReminderTypeInfo {
  final String label;
  final IconData icon;
  final Color color;

  ReminderTypeInfo({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class ReminderStatusInfo {
  final String label;
  final Color color;

  ReminderStatusInfo({
    required this.label,
    required this.color,
  });
}