class AppConstants {
  // App Information
  static const String appName = 'TV Subscription';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String baseUrl = 'https://api.tvsubscription.com';
  static const int apiTimeout = 30000; // 30 seconds
  
  // Payment Configuration
  static const double defaultSubscriptionFee = 1.0;
  static const String currency = '₹';
  
  // 🎯 TV CHANNEL PAYMENT DETAILS
  static const String tvChannelUpiId = 'uniqu98981307@barodampay'; // Replace with your UPI ID
  static const String tvChannelName = 'UNIQUE PVC FURNITURE'; // Replace with your channel name
  static const String tvChannelMerchantCode = '5712'; // Merchant Category Code for furniture store
  
  static const List<String> supportedUpiApps = [
    'com.google.android.apps.nbu.paisa.user',
    'net.one97.paytm',
    'com.phonepe.app',
    'in.org.npci.upiapp',
  ];
  
  // User Roles
  static const String roleUser = 'user';
  static const String roleCollector = 'collector';
  static const String roleAdmin = 'admin';
  
  // Payment Status
  static const String paymentPending = 'pending';
  static const String paymentCompleted = 'completed';
  static const String paymentFailed = 'failed';
  static const String paymentCancelled = 'cancelled';
  
  // Notification Types
  static const String notificationPaymentDue = 'payment_due';
  static const String notificationPaymentReceived = 'payment_received';
  static const String notificationPaymentApproved = 'payment_approved';
  
  // Storage Keys
  static const String keyUserToken = 'user_token';
  static const String keyUserData = 'user_data';
  static const String keyLanguage = 'selected_language';
  static const String keyThemeMode = 'theme_mode';
  
  // Validation
  static const int phoneNumberLength = 10;
  static const int otpLength = 6;
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  static const int maxUsernameLength = 20;
  static const int minUsernameLength = 3;
  static const int maxNameLength = 50;
  static const int minNameLength = 2;
  static const int maxAddressLength = 200;
  static const int minAddressLength = 10;
  static const int maxAreaLength = 50;
  static const int minAreaLength = 2;
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double extraLargePadding = 32.0;
  static const double borderRadius = 8.0;
  static const double largeBorderRadius = 12.0;
  static const double buttonHeight = 48.0;
  static const double smallButtonHeight = 36.0;
  static const double cardElevation = 4.0;
  static const double iconSize = 24.0;
  static const double largeIconSize = 48.0;
  
  // Grid and Layout Constants
  static const int gridCrossAxisCount = 2;
  static const int gridCrossAxisCountMobile = 2;
  static const int gridCrossAxisCountTablet = 3;
  static const double gridChildAspectRatio = 1.5;
  static const double gridMainAxisSpacing = 16.0;
  static const double gridCrossAxisSpacing = 16.0;
  static const double listItemHeight = 72.0;
  static const double maxContentWidth = 1200.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Text and Content Constants
  static const String adminTitle = 'Admin';
  static const String loading = 'Loading...';
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String edit = 'Edit';
  static const String delete = 'Delete';
  static const String viewAll = 'View All';
  static const String change = 'Change';
  static const String refresh = 'Refresh';
  static const String noData = 'No data available';
  static const String pendingApprovals = 'Pending Approvals';
  static const String approvePayments = 'Approve Payments';
  static const String userManagement = 'User Management';
  static const String reminderSettings = 'Reminder Settings';
  static const String reminderHistory = 'Reminder History';
  static const String statisticsOverview = 'Statistics Overview';
  static const String recentTransactions = 'Recent Transactions';
  static const String currentConfiguration = 'Current Configuration';
  static const String reminderConfiguration = 'Reminder Configuration';
  static const String reminderActions = 'Reminder Actions';
  static const String noPendingPayments = 'No pending payments';
  static const String allPaymentsUpToDate = 'All payments are up to date';
  static const String morePendingPayments = 'more pending payments';
  static const String previousYears = 'Previous years';
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';
  static const String daysAgo = 'days ago';
  static const String unknownUser = 'Unknown User';
  static const String currentAdminId = 'current_admin_id';
  
  // Error Messages
  static const String errorNetworkConnection = 'No internet connection';
  static const String errorServerError = 'Server error occurred';
  static const String errorInvalidCredentials = 'Invalid credentials';
  static const String errorPaymentFailed = 'Payment failed';
  static const String errorLoadingStatistics = 'Failed to load statistics';
  static const String errorLoadingUsers = 'Failed to load users';
  static const String errorLoadingPayments = 'Error loading pending payments';
  static const String errorLoadingData = 'Failed to load data';
  static const String errorSavingSettings = 'Failed to save settings';
  static const String errorUpdatingUser = 'Failed to update user';
  static const String errorDeletingUser = 'Failed to delete user';
  
  // Success Messages
  static const String successPaymentCompleted = 'Payment completed successfully';
  static const String successRegistrationCompleted = 'Registration completed';
  static const String successOtpVerified = 'OTP verified successfully';
  static const String successSettingsSaved = 'Settings saved successfully';
  static const String successUserUpdated = 'User updated successfully';
  static const String successUserDeleted = 'User deleted successfully';
  
  // Responsive Breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;
  static const double desktopBreakpoint = 1440.0;
}