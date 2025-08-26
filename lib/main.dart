import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/screens.dart';
import 'theme/theme.dart';
import 'l10n/app_localizations.dart';
import 'config/supabase_config.dart';
import 'services/localization_service.dart';
import 'services/cashfree_config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  // Initialize Cashfree configuration
  await CashfreeConfigService.instance.initialize();

  runApp(const TVSubscriptionApp());
}

class TVSubscriptionApp extends StatefulWidget {
  const TVSubscriptionApp({super.key});

  @override
  State<TVSubscriptionApp> createState() => _TVSubscriptionAppState();
}

class _TVSubscriptionAppState extends State<TVSubscriptionApp> {
  final LocalizationService _localizationService = LocalizationService();

  @override
  void initState() {
    super.initState();
    _initializeLocalization();
  }

  Future<void> _initializeLocalization() async {
    await _localizationService.initialize();
    setState(() {}); // Rebuild to apply the loaded language
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _localizationService,
      builder: (context, child) {
        return MaterialApp(
          title: 'Jafary Channel',
          theme: AppTheme.lightTheme,
          // Localization configuration
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: _localizationService.currentLocale,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const UserRegistrationScreen(),
            '/forgot-password': (context) => const ForgotPasswordScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/admin-dashboard': (context) => const AdminDashboardScreen(),
            '/collector-dashboard': (context) => const CollectorDashboardScreen(),
            '/language-selection': (context) => const LanguageSelectionScreen(),
          },
        );
      },
    );
  }
}

// Placeholder home screen - will be replaced with proper screens in later tasks
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Jafary Channel'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                boxShadow: AppTheme.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.tv, size: 80, color: AppColors.primary);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            const Text(
              'Jafary Channel',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Android-only project setup completed successfully!',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
