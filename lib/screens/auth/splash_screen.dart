import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_user_service.dart';
import '../../services/language_storage_service.dart';
import '../../theme/theme.dart';
import 'language_selection_screen.dart';
import 'login_screen.dart';
import '../user/dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../collector/collector_dashboard_screen.dart';
import '../../models/user_model.dart';

/// Splash screen that handles initial app loading and navigation
/// Shows app logo and determines where to navigate based on auth state
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  final AuthService _authService = AuthService();
  final SupabaseUserService _userService = SupabaseUserService();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Wait for animation to complete
      await Future.delayed(const Duration(seconds: 2));

      // First, check if language is already selected
      final isLanguageSelected = await LanguageStorageService.isLanguageSelected();
      
      if (!isLanguageSelected) {
        // First time user - show language selection
        _navigateToLanguageSelection();
        return;
      }
      
      // Language already selected - check authentication
      final currentUser = _authService.currentUser;
      
      if (currentUser != null) {
        // User is authenticated, get user data and navigate to appropriate screen
        final userData = await _userService.getUserById(currentUser.uid);
        
        if (userData != null) {
          _navigateToRoleBasedScreen(userData);
        } else {
          // User authenticated but no user data found
          // Check if it's admin user based on email
          if (currentUser.email == 'admin@tvapp.local') {
            // Navigate to admin dashboard directly
            _navigateToAdminDashboard();
          } else {
            // Go to login for other users
            _navigateToLogin();
          }
        }
      } else {
        // No authenticated user, go to login (language already selected)
        _navigateToLogin();
      }
    } catch (e) {
      // Error during initialization, check if language is selected
      final isLanguageSelected = await LanguageStorageService.isLanguageSelected();
      if (!isLanguageSelected) {
        _navigateToLanguageSelection();
      } else {
        _navigateToLogin();
      }
    }
  }

  void _navigateToLanguageSelection() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LanguageSelectionScreen(),
        ),
      );
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  void _navigateToRoleBasedScreen(UserModel user) {
    if (!mounted) return;

    Widget targetScreen;
    switch (user.role) {
      case UserRole.ADMIN:
        targetScreen = const AdminDashboardScreen();
        break;
      case UserRole.COLLECTOR:
        targetScreen = const CollectorDashboardScreen();
        break;
      case UserRole.USER:
      default:
        targetScreen = const DashboardScreen();
        break;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  void _navigateToAdminDashboard() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const AdminDashboardScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to TV icon if logo fails to load
                            return Icon(
                              Icons.tv,
                              size: AppDimensions.iconXl + 12,
                              color: AppColors.primary,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),
                    
                    // App Title
                    Text(
                      'Jafary Channel',
                      style: AppTextStyles.displayMedium.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    
                    // Subtitle
                    Text(
                      'Payment App',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.textOnPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXxl),
                    
                    // Loading indicator
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.textOnPrimary),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}