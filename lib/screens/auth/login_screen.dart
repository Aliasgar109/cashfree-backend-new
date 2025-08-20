import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_user_service.dart';
import '../../models/user_model.dart';
import '../../theme/theme.dart';
import '../../utils/input_validator.dart';
import '../../widgets/widgets.dart';
import '../user/dashboard_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../collector/collector_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _userService = SupabaseUserService();
  
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signInWithUsername(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (user != null && mounted) {
        // Get user data to determine role and navigate accordingly
        final userData = await _userService.getUserById(user.uid);
        
        if (userData != null) {
          _navigateToRoleBasedScreen(userData);
        } else {
          // If no user data found, check if it's admin by email
          if (user.email == 'admin@tvapp.local') {
            _navigateToAdminDashboard();
          } else {
            // Default to user dashboard
            _navigateToUserDashboard();
          }
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
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

  void _navigateToUserDashboard() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DashboardScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                const SizedBox(height: AppDimensions.spacingXl),
                
                // App Logo/Icon
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
                        return Icon(
                          Icons.tv,
                          size: 80,
                          color: AppColors.primary,
                        );
                      },
                    ),
                  ),
                ),
                
                              const SizedBox(height: AppDimensions.spacingLg),
                              
                // Title
                              Text(
                  'Welcome Back!',
                  style: AppTextStyles.headlineMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                  textAlign: TextAlign.center,
                              ),
                
                              const SizedBox(height: AppDimensions.spacingSm),
                              
                              Text(
                  'Sign in to your Jafary Channel account',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppDimensions.spacingXl),
                
                // Username Field
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'Enter your username',
                    prefixIcon: Icon(
                      Icons.person,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusMd)),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: InputValidator.validateUsername,
                  enabled: !_isLoading,
                ),
                
                const SizedBox(height: AppDimensions.spacingMd),
                
                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: Icon(
                      Icons.lock,
                      color: AppColors.primary,
                    ),
                    suffixIcon: IconButton(
                      onPressed: _togglePasswordVisibility,
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusMd)),
                    ),
                    enabled: !_isLoading,
                  ),
                  textInputAction: TextInputAction.done,
                  validator: InputValidator.validatePassword,
                  onFieldSubmitted: (_) => _handleLogin(),
                ),
                
                const SizedBox(height: AppDimensions.spacingMd),
                
                // Forgot Password Link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : () {
                      // Navigate to forgot password screen
                      Navigator.of(context).pushNamed('/forgot-password');
                    },
                                    child: Text(
                      'Forgot Password?',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                
                const SizedBox(height: AppDimensions.spacingMd),
                
                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.spacingMd),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                const SizedBox(height: AppDimensions.spacingLg),
                        
                        // Login Button
                ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingMd,
                    ),
                              shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                          height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.textOnPrimary),
                                    ),
                                  )
                                : Text(
                          'Sign In',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textOnPrimary,
                                      fontWeight: FontWeight.w600,
                                  ),
                          ),
                        ),
                        
                const SizedBox(height: AppDimensions.spacingLg),
                
                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                      "Don't have an account? ",
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : () {
                        Navigator.of(context).pushNamed('/signup');
                      },
                      child: Text(
                        'Sign Up',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                                ),
                              ),
                            ],
                        ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }
}