import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('gu'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'TV Subscription'**
  String get appTitle;

  /// Welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Wallet balance label
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance'**
  String get walletBalance;

  /// Recharge wallet button text
  ///
  /// In en, this message translates to:
  /// **'Recharge Wallet'**
  String get rechargeWallet;

  /// Quick actions section title
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// Pay now button text
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// Pay subscription fee subtitle
  ///
  /// In en, this message translates to:
  /// **'Pay subscription fee'**
  String get paySubscriptionFee;

  /// History button text
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// View transactions subtitle
  ///
  /// In en, this message translates to:
  /// **'View transactions'**
  String get viewTransactions;

  /// Recent transactions section title
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No transactions message
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get noTransactionsYet;

  /// Transactions placeholder message
  ///
  /// In en, this message translates to:
  /// **'Your wallet transactions will appear here'**
  String get transactionsWillAppearHere;

  /// Payment history screen title
  ///
  /// In en, this message translates to:
  /// **'Payment History'**
  String get paymentHistory;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Profile information section title
  ///
  /// In en, this message translates to:
  /// **'Profile Information'**
  String get profileInformation;

  /// Preferences section title
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Account section title
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Logout button text
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Payment method label
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// UPI payment method
  ///
  /// In en, this message translates to:
  /// **'UPI Payment'**
  String get upiPayment;

  /// Wallet payment method
  ///
  /// In en, this message translates to:
  /// **'Wallet Payment'**
  String get walletPayment;

  /// Combined payment method
  ///
  /// In en, this message translates to:
  /// **'Wallet + UPI'**
  String get combinedPayment;

  /// Payment confirmation screen title
  ///
  /// In en, this message translates to:
  /// **'Payment Confirmation'**
  String get paymentConfirmation;

  /// Payment status screen title
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get paymentStatus;

  /// Track payment status button
  ///
  /// In en, this message translates to:
  /// **'Track Payment Status'**
  String get trackPaymentStatus;

  /// Back to dashboard button
  ///
  /// In en, this message translates to:
  /// **'Back to Dashboard'**
  String get backToDashboard;

  /// Fee breakdown section title
  ///
  /// In en, this message translates to:
  /// **'Fee Breakdown'**
  String get feeBreakdown;

  /// Base amount label
  ///
  /// In en, this message translates to:
  /// **'Base Amount'**
  String get baseAmount;

  /// Extra charges label
  ///
  /// In en, this message translates to:
  /// **'Extra Charges'**
  String get extraCharges;

  /// Wire charges label
  ///
  /// In en, this message translates to:
  /// **'Wire Charges'**
  String get wireCharges;

  /// Late fees label
  ///
  /// In en, this message translates to:
  /// **'Late Fees'**
  String get lateFees;

  /// Total amount label
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// Payment initiated message
  ///
  /// In en, this message translates to:
  /// **'Payment Initiated'**
  String get paymentInitiated;

  /// Payment successful message
  ///
  /// In en, this message translates to:
  /// **'Payment Successful'**
  String get paymentSuccessful;

  /// Payment pending status
  ///
  /// In en, this message translates to:
  /// **'Payment Pending'**
  String get paymentPending;

  /// Payment approved status
  ///
  /// In en, this message translates to:
  /// **'Payment Approved'**
  String get paymentApproved;

  /// Payment rejected status
  ///
  /// In en, this message translates to:
  /// **'Payment Rejected'**
  String get paymentRejected;

  /// Search payments placeholder
  ///
  /// In en, this message translates to:
  /// **'Search payments...'**
  String get searchPayments;

  /// Filter payments dialog title
  ///
  /// In en, this message translates to:
  /// **'Filter Payments'**
  String get filterPayments;

  /// All payment methods filter option
  ///
  /// In en, this message translates to:
  /// **'All Methods'**
  String get allMethods;

  /// All payment statuses filter option
  ///
  /// In en, this message translates to:
  /// **'All Statuses'**
  String get allStatuses;

  /// All years filter option
  ///
  /// In en, this message translates to:
  /// **'All Years'**
  String get allYears;

  /// Clear all filters button
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// Apply filters button
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Receipt number label
  ///
  /// In en, this message translates to:
  /// **'Receipt Number'**
  String get receiptNumber;

  /// Transaction ID label
  ///
  /// In en, this message translates to:
  /// **'Transaction ID'**
  String get transactionId;

  /// Payment details section title
  ///
  /// In en, this message translates to:
  /// **'Payment Details'**
  String get paymentDetails;

  /// Payment timeline section title
  ///
  /// In en, this message translates to:
  /// **'Payment Timeline'**
  String get paymentTimeline;

  /// Payment under review status
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get underReview;

  /// Refresh status button
  ///
  /// In en, this message translates to:
  /// **'Refresh Status'**
  String get refreshStatus;

  /// Download receipt button
  ///
  /// In en, this message translates to:
  /// **'Download Receipt'**
  String get downloadReceipt;

  /// Share receipt button
  ///
  /// In en, this message translates to:
  /// **'Share Receipt'**
  String get shareReceipt;

  /// Receipt generated message
  ///
  /// In en, this message translates to:
  /// **'Receipt Generated'**
  String get receiptGenerated;

  /// Receipt shared message
  ///
  /// In en, this message translates to:
  /// **'Receipt Shared'**
  String get receiptShared;

  /// Generating receipt loading message
  ///
  /// In en, this message translates to:
  /// **'Generating Receipt...'**
  String get generatingReceipt;

  /// Receipt not available message
  ///
  /// In en, this message translates to:
  /// **'Receipt Not Available'**
  String get receiptNotAvailable;

  /// Receipt generation info message
  ///
  /// In en, this message translates to:
  /// **'Receipt will be generated after payment approval'**
  String get receiptWillBeGenerated;

  /// Collector dashboard title
  ///
  /// In en, this message translates to:
  /// **'Collector Dashboard'**
  String get collectorDashboard;

  /// Cash entry screen title
  ///
  /// In en, this message translates to:
  /// **'Cash Entry'**
  String get cashEntry;

  /// Select user section title
  ///
  /// In en, this message translates to:
  /// **'Select User'**
  String get selectUser;

  /// Search user placeholder
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone number'**
  String get searchByNameOrPhone;

  /// Record cash payment button
  ///
  /// In en, this message translates to:
  /// **'Record Cash Payment'**
  String get recordCashPayment;

  /// Wire length input label
  ///
  /// In en, this message translates to:
  /// **'Wire Length (meters)'**
  String get wireLength;

  /// Notes input label
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get notes;

  /// Notes input hint
  ///
  /// In en, this message translates to:
  /// **'Additional notes about the payment'**
  String get additionalNotes;

  /// Cash payment success message
  ///
  /// In en, this message translates to:
  /// **'Cash payment recorded successfully!'**
  String get cashPaymentRecorded;

  /// Processing indicator text
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// Reset form tooltip
  ///
  /// In en, this message translates to:
  /// **'Reset Form'**
  String get resetForm;

  /// User selection validation message
  ///
  /// In en, this message translates to:
  /// **'Please select a user'**
  String get pleaseSelectUser;

  /// Amount validation message
  ///
  /// In en, this message translates to:
  /// **'Amount is required'**
  String get amountRequired;

  /// Valid amount validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get validAmountRequired;

  /// Late fees warning message
  ///
  /// In en, this message translates to:
  /// **'Late fees applied for previous unpaid years'**
  String get lateFeesApplied;

  /// Today's overview section title
  ///
  /// In en, this message translates to:
  /// **'Today\'s Overview'**
  String get todaysOverview;

  /// Pending status
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// Approved status
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// Total revenue label
  ///
  /// In en, this message translates to:
  /// **'Total Revenue'**
  String get totalRevenue;

  /// Overdue status
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// Collector role title
  ///
  /// In en, this message translates to:
  /// **'Cash Collection Officer'**
  String get cashCollectionOfficer;

  /// Area label
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get area;

  /// Record cash payment description
  ///
  /// In en, this message translates to:
  /// **'Record cash payment'**
  String get recordCashPaymentDesc;

  /// Search users placeholder
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get searchUsers;

  /// Find user description
  ///
  /// In en, this message translates to:
  /// **'Find user by name/phone'**
  String get findUserByNamePhone;

  /// View all payments description
  ///
  /// In en, this message translates to:
  /// **'View all payments'**
  String get viewAllPayments;

  /// Reports action
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// Generate reports description
  ///
  /// In en, this message translates to:
  /// **'Generate collection reports'**
  String get generateCollectionReports;

  /// Recent activities section title
  ///
  /// In en, this message translates to:
  /// **'Recent Activities'**
  String get recentActivities;

  /// No recent activities message
  ///
  /// In en, this message translates to:
  /// **'No recent activities'**
  String get noRecentActivities;

  /// Activities placeholder message
  ///
  /// In en, this message translates to:
  /// **'Cash entries and payment activities will appear here'**
  String get activitiesWillAppearHere;

  /// Feature coming soon message
  ///
  /// In en, this message translates to:
  /// **'Feature coming soon'**
  String get featureComingSoon;

  /// Admin dashboard title
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// Payment approvals screen title
  ///
  /// In en, this message translates to:
  /// **'Payment Approvals'**
  String get paymentApprovals;

  /// Approve payment button
  ///
  /// In en, this message translates to:
  /// **'Approve Payment'**
  String get approvePayment;

  /// Reject payment button
  ///
  /// In en, this message translates to:
  /// **'Reject Payment'**
  String get rejectPayment;

  /// Rejection reason label
  ///
  /// In en, this message translates to:
  /// **'Rejection Reason'**
  String get rejectionReason;

  /// Rejection reason input hint
  ///
  /// In en, this message translates to:
  /// **'Enter rejection reason...'**
  String get enterRejectionReason;

  /// Payment approval success message
  ///
  /// In en, this message translates to:
  /// **'Payment approved successfully'**
  String get paymentApprovedSuccessfully;

  /// Payment rejection success message
  ///
  /// In en, this message translates to:
  /// **'Payment rejected successfully'**
  String get paymentRejectedSuccessfully;

  /// No pending payments message
  ///
  /// In en, this message translates to:
  /// **'No pending payments'**
  String get noPendingPayments;

  /// All payments up to date message
  ///
  /// In en, this message translates to:
  /// **'All payments are up to date'**
  String get allPaymentsUpToDate;

  /// View full size image button
  ///
  /// In en, this message translates to:
  /// **'View Full Size'**
  String get viewFullSize;

  /// Payment screenshot section title
  ///
  /// In en, this message translates to:
  /// **'Payment Screenshot'**
  String get paymentScreenshot;

  /// User information section title
  ///
  /// In en, this message translates to:
  /// **'User Information'**
  String get userInformation;

  /// Transaction details section title
  ///
  /// In en, this message translates to:
  /// **'Transaction Details'**
  String get transactionDetails;

  /// Screenshot loading error message
  ///
  /// In en, this message translates to:
  /// **'Failed to load screenshot'**
  String get failedToLoadScreenshot;

  /// User management screen title
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get userManagement;

  /// Add user button
  ///
  /// In en, this message translates to:
  /// **'Add User'**
  String get addUser;

  /// Edit user button
  ///
  /// In en, this message translates to:
  /// **'Edit User'**
  String get editUser;

  /// Delete user button
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get deleteUser;

  /// Filter by role label
  ///
  /// In en, this message translates to:
  /// **'Filter by Role'**
  String get filterByRole;

  /// Filter by area label
  ///
  /// In en, this message translates to:
  /// **'Filter by Area'**
  String get filterByArea;

  /// All roles filter option
  ///
  /// In en, this message translates to:
  /// **'All Roles'**
  String get allRoles;

  /// All areas filter option
  ///
  /// In en, this message translates to:
  /// **'All Areas'**
  String get allAreas;

  /// User role
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// Collector role
  ///
  /// In en, this message translates to:
  /// **'Collector'**
  String get collector;

  /// Admin role
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// Phone number field label
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// Address field label
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// Role field label
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// Active status
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// Inactive status
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// Last payment label
  ///
  /// In en, this message translates to:
  /// **'Last Payment'**
  String get lastPayment;

  /// Never paid indicator
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// User details section title
  ///
  /// In en, this message translates to:
  /// **'User Details'**
  String get userDetails;

  /// User activity section title
  ///
  /// In en, this message translates to:
  /// **'User Activity'**
  String get userActivity;

  /// Payment count label
  ///
  /// In en, this message translates to:
  /// **'Payment Count'**
  String get paymentCount;

  /// Total paid amount label
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get totalPaid;

  /// User joined date label
  ///
  /// In en, this message translates to:
  /// **'Joined Date'**
  String get joinedDate;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirm delete dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// Delete user confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this user? This action cannot be undone.'**
  String get deleteUserConfirmation;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// User creation success message
  ///
  /// In en, this message translates to:
  /// **'User created successfully'**
  String get userCreatedSuccessfully;

  /// User update success message
  ///
  /// In en, this message translates to:
  /// **'User updated successfully'**
  String get userUpdatedSuccessfully;

  /// User deletion success message
  ///
  /// In en, this message translates to:
  /// **'User deleted successfully'**
  String get userDeletedSuccessfully;

  /// No users found message
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// Users placeholder message
  ///
  /// In en, this message translates to:
  /// **'Users matching your search criteria will appear here'**
  String get usersWillAppearHere;

  /// Name input hint
  ///
  /// In en, this message translates to:
  /// **'Enter name'**
  String get enterName;

  /// Phone number input hint
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enterPhoneNumber;

  /// Address input hint
  ///
  /// In en, this message translates to:
  /// **'Enter address'**
  String get enterAddress;

  /// Role selection hint
  ///
  /// In en, this message translates to:
  /// **'Select role'**
  String get selectRole;

  /// Area selection hint
  ///
  /// In en, this message translates to:
  /// **'Select area'**
  String get selectArea;

  /// Required field indicator
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// Invalid phone number error
  ///
  /// In en, this message translates to:
  /// **'Invalid phone number'**
  String get invalidPhoneNumber;

  /// Phone number exists error
  ///
  /// In en, this message translates to:
  /// **'Phone number already exists'**
  String get phoneNumberAlreadyExists;

  /// Fee management screen title
  ///
  /// In en, this message translates to:
  /// **'Fee Management'**
  String get feeManagement;

  /// Fee configuration section title
  ///
  /// In en, this message translates to:
  /// **'Fee Configuration'**
  String get feeConfiguration;

  /// Yearly fee label
  ///
  /// In en, this message translates to:
  /// **'Yearly Fee'**
  String get yearlyFee;

  /// Yearly fee help text
  ///
  /// In en, this message translates to:
  /// **'Base subscription fee for one year'**
  String get yearlyFeeHelp;

  /// Late fees percentage label
  ///
  /// In en, this message translates to:
  /// **'Late Fees Percentage'**
  String get lateFeesPercentage;

  /// Late fees help text
  ///
  /// In en, this message translates to:
  /// **'Percentage charged for overdue payments per year'**
  String get lateFeesHelp;

  /// Wire charge per meter label
  ///
  /// In en, this message translates to:
  /// **'Wire Charge Per Meter'**
  String get wireChargePerMeter;

  /// Wire charge help text
  ///
  /// In en, this message translates to:
  /// **'Additional charge per meter of wire installation'**
  String get wireChargeHelp;

  /// Reminder days before label
  ///
  /// In en, this message translates to:
  /// **'Reminder Days Before'**
  String get reminderDaysBefore;

  /// Reminder days help text
  ///
  /// In en, this message translates to:
  /// **'Days before due date to send payment reminders'**
  String get reminderDaysHelp;

  /// Auto approval label
  ///
  /// In en, this message translates to:
  /// **'Auto Approval'**
  String get autoApproval;

  /// Auto approval help text
  ///
  /// In en, this message translates to:
  /// **'Automatically approve payments without manual review'**
  String get autoApprovalHelp;

  /// Last updated label
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get lastUpdated;

  /// Calculation preview section title
  ///
  /// In en, this message translates to:
  /// **'Calculation Preview'**
  String get calculationPreview;

  /// Base yearly fee label
  ///
  /// In en, this message translates to:
  /// **'Base Yearly Fee'**
  String get baseYearlyFee;

  /// Wire charge example label
  ///
  /// In en, this message translates to:
  /// **'Wire Charge (10m example)'**
  String get wireChargeExample;

  /// Late fees example label
  ///
  /// In en, this message translates to:
  /// **'Late Fees (1 year example)'**
  String get lateFeesExample;

  /// Total example label
  ///
  /// In en, this message translates to:
  /// **'Total (with all charges)'**
  String get totalExample;

  /// Save settings button
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// Reset to defaults button
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get resetToDefaults;

  /// Yearly fee validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter yearly fee'**
  String get pleaseEnterYearlyFee;

  /// Valid amount validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get pleaseEnterValidAmount;

  /// Amount too high validation message
  ///
  /// In en, this message translates to:
  /// **'Amount is too high (max ₹1,00,000)'**
  String get amountTooHigh;

  /// Late fees percentage validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter late fees percentage'**
  String get pleaseEnterLateFeesPercentage;

  /// Valid percentage validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid percentage (0-100)'**
  String get pleaseEnterValidPercentage;

  /// Wire charge validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter wire charge per meter'**
  String get pleaseEnterWireCharge;

  /// Valid charge validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid charge (≥0)'**
  String get pleaseEnterValidCharge;

  /// Charge too high validation message
  ///
  /// In en, this message translates to:
  /// **'Charge is too high (max ₹1,000/meter)'**
  String get chargeTooHigh;

  /// Reminder days validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter reminder days'**
  String get pleaseEnterReminderDays;

  /// Valid days validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter valid days (>0)'**
  String get pleaseEnterValidDays;

  /// Days too high validation message
  ///
  /// In en, this message translates to:
  /// **'Days too high (max 365)'**
  String get daysTooHigh;

  /// Cash payment method
  ///
  /// In en, this message translates to:
  /// **'Cash Payment'**
  String get cashPayment;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Continue button text
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Language selection validation message
  ///
  /// In en, this message translates to:
  /// **'Please select a language to continue'**
  String get pleaseSelectLanguage;

  /// Language update success message
  ///
  /// In en, this message translates to:
  /// **'Language updated successfully'**
  String get languageUpdated;

  /// Language update error message
  ///
  /// In en, this message translates to:
  /// **'Failed to update language preference'**
  String get failedToUpdateLanguage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'gu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
