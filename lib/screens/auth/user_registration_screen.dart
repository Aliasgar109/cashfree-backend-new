import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../theme/theme.dart';
import '../../utils/input_validator.dart';
import '../../widgets/widgets.dart';

class UserRegistrationScreen extends StatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String _selectedLanguage = 'en';
  String? _errorMessage;
  bool _isCheckingPhone = false;
  String? _phoneValidationMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signUpWithUsername(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        address: '', // Default empty address
        area: '', // Default empty area
        preferredLanguage: _selectedLanguage,
      );

      if (user != null && mounted) {
        // Show success message and navigate to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please sign in.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/login');
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

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    });
  }

  // Check phone number availability
  Future<void> _checkPhoneNumberAvailability(String phoneNumber) async {
    if (phoneNumber.length != 10) {
      setState(() {
        _phoneValidationMessage = null;
        _isCheckingPhone = false;
      });
      return;
    }

    setState(() {
      _isCheckingPhone = true;
      _phoneValidationMessage = null;
    });

    try {
      final exists = await _authService.phoneNumberExists(phoneNumber);
      if (mounted) {
        setState(() {
          _isCheckingPhone = false;
          if (exists) {
            _phoneValidationMessage = 'Phone number already registered';
          } else {
            _phoneValidationMessage = 'Phone number available';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingPhone = false;
          _phoneValidationMessage = 'Error checking phone number';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: SafeArea(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacingLg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                // Title
                Text(
                  'Create Your Account',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: AppDimensions.spacingSm),
                              
                              Text(
                  'Create your account to manage Jafary Channel subscriptions',
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
                    hintText: 'Choose a unique username',
                    prefixIcon: Icon(Icons.person, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusMd)),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: InputValidator.validateUsername,
                ),
                
                const SizedBox(height: AppDimensions.spacingMd),
                
                // Password Field
                        TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Create a strong password',
                    prefixIcon: Icon(Icons.lock, color: AppColors.primary),
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
                  ),
                  textInputAction: TextInputAction.next,
                  validator: InputValidator.validatePassword,
                ),
                
                const SizedBox(height: AppDimensions.spacingMd),
                
                // Confirm Password Field
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Confirm your password',
                    prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary),
                    suffixIcon: IconButton(
                      onPressed: _toggleConfirmPasswordVisibility,
                      icon: Icon(
                        _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusMd)),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: AppDimensions.spacingMd),
                        
                        // Name Field
                        TextFormField(
                          controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                            hintText: 'Enter your full name',
                    prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                            border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusMd)),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: InputValidator.validateName,
                ),
                
                const SizedBox(height: AppDimensions.spacingMd),
                
                // Phone Number Field
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'Enter your 10-digit phone number',
                    prefixIcon: const Icon(Icons.phone, color: AppColors.primary),
                    suffixIcon: _isCheckingPhone
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : _phoneValidationMessage != null
                            ? Icon(
                                _phoneValidationMessage!.contains('available')
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _phoneValidationMessage!.contains('available')
                                    ? Colors.green
                                    : Colors.red,
                              )
                            : null,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusMd)),
                    ),
                    helperText: _phoneValidationMessage,
                    helperStyle: TextStyle(
                      color: _phoneValidationMessage?.contains('available') == true
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final phoneValidation = InputValidator.validatePhoneNumber(value);
                    if (phoneValidation != null) {
                      return phoneValidation;
                    }
                    if (_phoneValidationMessage?.contains('already registered') == true) {
                      return 'Phone number already registered';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (value.length == 10) {
                      _checkPhoneNumberAvailability(value);
                    } else {
                      setState(() {
                        _phoneValidationMessage = null;
                        _isCheckingPhone = false;
                      });
                    }
                  },
                ),
                
                const SizedBox(height: AppDimensions.spacingMd),
                        
                        // Language Selection
                DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Preferred Language',
                    prefixIcon: Icon(Icons.language, color: AppColors.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(AppDimensions.radiusMd)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'gu', child: Text('ગુજરાતી')),
                  ],
                  onChanged: (value) {
                                    setState(() {
                      _selectedLanguage = value!;
                                    });
                                  },
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
                        
                        // Create Account Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
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
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.textOnPrimary),
                                    ),
                                  )
                      : Text(
                                    'Create Account',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.textOnPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                
                const SizedBox(height: AppDimensions.spacingLg),
                
                // Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : () {
                        Navigator.of(context).pop();
                      },
                          child: Text(
                        'Sign In',
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