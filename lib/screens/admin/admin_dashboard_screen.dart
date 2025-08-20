import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/supabase_payment_service.dart';
import '../../services/supabase_user_service.dart';
import '../../services/auth_service.dart';
import '../../models/payment_model.dart';
import '../../models/user_model.dart';
import '../../constants/app_constants.dart';
import 'payment_approval_screen.dart';
import 'user_management_screen.dart';
import 'fee_management_screen.dart';
import 'reports_screen.dart';

/// Admin dashboard screen with payment approval functionality
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SupabasePaymentService _paymentService = SupabasePaymentService();
  final SupabaseUserService _userService = SupabaseUserService();
  final AuthService _authService = AuthService();
  
  PaymentStatistics? _statistics;
  bool _isLoadingStats = true;
  String? _currentAdminId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Get current admin ID
    final currentUser = _authService.currentUser;
    _currentAdminId = currentUser?.uid;
    
    await _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _paymentService.getPaymentStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.appTitle} - ${AppConstants.adminTitle}'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: AppConstants.iconSize),
            onPressed: _loadStatistics,
            tooltip: AppConstants.refresh,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(l10n.logout),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStatistics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: AppConstants.smallPadding,
            vertical: AppConstants.defaultPadding,
          ),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppConstants.maxContentWidth,
                minHeight: MediaQuery.of(context).size.height - 
                    AppBar().preferredSize.height - 
                    MediaQuery.of(context).padding.top - 
                    AppConstants.defaultPadding * 2,
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics Overview
              _buildStatisticsSection(l10n, theme),
                  SizedBox(height: AppConstants.defaultPadding),
              
              // Pending Payments Queue
              _buildPendingPaymentsSection(l10n, theme),
                  SizedBox(height: AppConstants.defaultPadding),
              
              // Quick Actions
              _buildQuickActionsSection(l10n, theme),
                  SizedBox(height: AppConstants.largePadding),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection(AppLocalizations l10n, ThemeData theme) {
    return Card(
      elevation: AppConstants.cardElevation,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppConstants.smallPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.todaysOverview,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppConstants.smallPadding),
            if (_isLoadingStats)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(AppConstants.extraLargePadding),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_statistics != null)
              _buildStatisticsGrid(l10n, theme)
            else
              Center(
                child: Text(
                  AppConstants.errorLoadingStatistics,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsGrid(AppLocalizations l10n, ThemeData theme) {
    final stats = _statistics!;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > AppConstants.tabletBreakpoint 
        ? AppConstants.gridCrossAxisCountTablet 
        : AppConstants.gridCrossAxisCountMobile;
    
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: screenWidth > AppConstants.tabletBreakpoint ? 1.4 : 1.2,
      crossAxisSpacing: AppConstants.smallPadding,
      mainAxisSpacing: AppConstants.smallPadding,
      children: [
        _buildStatCard(
          title: l10n.pending,
          value: stats.pendingPayments.toString(),
          subtitle: '₹${stats.pendingAmount.toStringAsFixed(0)}',
          icon: Icons.pending_actions,
          color: Colors.orange,
          theme: theme,
        ),
        _buildStatCard(
          title: l10n.approved,
          value: stats.approvedPayments.toString(),
          subtitle: '${stats.approvalRate.toStringAsFixed(1)}%',
          icon: Icons.check_circle,
          color: Colors.green,
          theme: theme,
        ),
        _buildStatCard(
          title: l10n.totalRevenue,
          value: '₹${stats.totalRevenue.toStringAsFixed(0)}',
          subtitle: '${stats.currentYear}',
          icon: Icons.currency_rupee,
          color: Colors.blue,
          theme: theme,
        ),
        _buildStatCard(
          title: l10n.overdue,
          value: stats.overduePayments.toString(),
          subtitle: AppConstants.previousYears,
          icon: Icons.warning,
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
    return Container(
      padding: EdgeInsets.all(AppConstants.smallPadding),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Header row with icon and title
          Flexible(
            child: Row(
            children: [
                Icon(icon, color: color, size: 18),
                SizedBox(width: AppConstants.smallPadding),
              Expanded(
                child: Text(
                  title,
                    style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                      fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                ),
              ),
            ],
          ),
          ),
          
          // Main value - with flexible sizing
          Flexible(
            flex: 2,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
            value,
                  style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          
          // Subtitle
          Flexible(
            child: Center(
              child: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
                  fontSize: 10,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPaymentsSection(AppLocalizations l10n, ThemeData theme) {
    return Card(
      elevation: AppConstants.cardElevation,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppConstants.smallPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    AppConstants.pendingApprovals,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                SizedBox(width: AppConstants.smallPadding),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PaymentApprovalScreen(),
                      ),
                    );
                  },
                  icon: Icon(Icons.arrow_forward, size: AppConstants.iconSize),
                  label: Text(AppConstants.viewAll),
                ),
              ],
            ),
            SizedBox(height: AppConstants.defaultPadding),
            StreamBuilder<List<PaymentModel>>(
              stream: _paymentService.getPaymentsByStatus(PaymentStatus.PENDING),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppConstants.extraLargePadding),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      AppConstants.errorLoadingPayments,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  );
                }

                final pendingPayments = snapshot.data ?? [];

                if (pendingPayments.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppConstants.extraLargePadding),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: AppConstants.largeIconSize,
                            color: Colors.green.withOpacity(0.6),
                          ),
                          SizedBox(height: AppConstants.defaultPadding),
                          Text(
                            AppConstants.noPendingPayments,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            AppConstants.allPaymentsUpToDate,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Show first 3 pending payments
                final displayPayments = pendingPayments.take(3).toList();

                return Column(
                  children: [
                    ...displayPayments.map((payment) => 
                      _buildPendingPaymentCard(payment, l10n, theme)),
                    if (pendingPayments.length > 3)
                      Padding(
                        padding: EdgeInsets.only(top: AppConstants.smallPadding),
                        child: Text(
                          '+${pendingPayments.length - 3} ${AppConstants.morePendingPayments}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingPaymentCard(PaymentModel payment, AppLocalizations l10n, ThemeData theme) {
    return FutureBuilder<UserModel?>(
      future: _userService.getUserById(payment.userId),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        
        return Card(
          margin: EdgeInsets.only(bottom: AppConstants.smallPadding),
          elevation: AppConstants.cardElevation,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.2),
              child: Icon(
                _getPaymentMethodIcon(payment.method),
                color: Colors.orange,
                size: AppConstants.iconSize,
              ),
            ),
            title: Text(
              user?.name ?? AppConstants.loading,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${AppConstants.currency}${payment.totalAmount.toStringAsFixed(2)}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  payment.methodDisplayText,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
            trailing: SizedBox(
              width: 80,
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDate(payment.createdAt),
                  style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                ),
                  SizedBox(height: AppConstants.smallPadding / 2),
                Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppConstants.smallPadding, 
                      vertical: 2,
                    ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
                  ),
                  child: Text(
                    l10n.pending,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                  ),
                ),
              ],
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentApprovalScreen(
                    initialPaymentId: payment.id,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsSection(AppLocalizations l10n, ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > AppConstants.tabletBreakpoint 
        ? AppConstants.gridCrossAxisCountTablet 
        : AppConstants.gridCrossAxisCountMobile;
    
    return Card(
      elevation: AppConstants.cardElevation,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(AppConstants.smallPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.quickActions,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppConstants.smallPadding),
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: screenWidth > AppConstants.tabletBreakpoint ? 3.0 : 2.8,
              crossAxisSpacing: AppConstants.smallPadding,
              mainAxisSpacing: AppConstants.smallPadding,
              children: [
                _buildQuickActionCard(
                  title: AppConstants.approvePayments,
                  icon: Icons.approval,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PaymentApprovalScreen(),
                      ),
                    );
                  },
                  theme: theme,
                ),
                _buildQuickActionCard(
                  title: AppConstants.userManagement,
                  icon: Icons.people,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserManagementScreen(),
                      ),
                    );
                  },
                  theme: theme,
                ),
                _buildQuickActionCard(
                  title: l10n.feeManagement,
                  icon: Icons.settings,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FeeManagementScreen(
                          adminId: _currentAdminId ?? AppConstants.currentAdminId,
                        ),
                      ),
                    );
                  },
                  theme: theme,
                ),
                _buildQuickActionCard(
                  title: l10n.reports,
                  icon: Icons.analytics,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportsScreen(),
                      ),
                    );
                  },
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
      child: Container(
        padding: EdgeInsets.all(AppConstants.smallPadding),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppConstants.largeBorderRadius),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: AppConstants.smallPadding),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.UPI:
        return Icons.payment;
      case PaymentMethod.CASH:
        return Icons.money;
      case PaymentMethod.WALLET:
        return Icons.account_balance_wallet;
      case PaymentMethod.COMBINED:
        return Icons.compare_arrows;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return AppConstants.today;
    } else if (difference.inDays == 1) {
      return AppConstants.yesterday;
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${AppConstants.daysAgo}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
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
                _authService.signOut();
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        );
      },
    );
  }
}