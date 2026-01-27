import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

/// TikTok-style email/password input screen
/// Step 4: Enter email and password (for email registration only)
class EmailPasswordScreen extends StatefulWidget {
  final String username;
  final DateTime dateOfBirth;

  const EmailPasswordScreen({
    super.key,
    required this.username,
    required this.dateOfBirth,
  });

  @override
  State<EmailPasswordScreen> createState() => _EmailPasswordScreenState();
}

class _EmailPasswordScreenState extends State<EmailPasswordScreen> {
  final _themeService = ThemeService();
  final _localeService = LocaleService();
  
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  // Password requirements
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordRequirements);
    _themeService.addListener(_onServiceChanged);
    _localeService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _themeService.removeListener(_onServiceChanged);
    _localeService.removeListener(_onServiceChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _validatePasswordRequirements() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool _isPasswordStrong() {
    return _hasMinLength && _hasUppercase && _hasLowercase && _hasNumber && _hasSpecialChar;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _canSubmit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    
    return _isValidEmail(email) && 
           _isPasswordStrong() && 
           password == confirmPassword &&
           password.isNotEmpty;
  }

  Future<void> _handleRegister() async {
    // Validate email
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _emailError = _localeService.get('invalid_email');
      });
      return;
    }
    
    // Validate password
    if (!_isPasswordStrong()) {
      setState(() {
        _passwordError = _localeService.get('password_too_weak');
      });
      return;
    }
    
    // Validate confirm password
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _confirmPasswordError = _localeService.get('passwords_dont_match');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });

    try {
      // TODO: Call API to register
      // final response = await authService.emailRegister(
      //   email: email,
      //   password: _passwordController.text,
      //   username: widget.username,
      //   dateOfBirth: widget.dateOfBirth,
      // );

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      
      // Success - navigate to select interests screen for onboarding
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localeService.get('registration_successful')),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate to select interests screen for onboarding
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/select-interests',
        (route) => route.isFirst,
      );
      
    } catch (e) {
      setState(() {
        _emailError = _localeService.get('registration_failed');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = !_themeService.isLightMode;
    final accentColor = ThemeService.accentColor;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Title
              Text(
                _localeService.get('enter_email_password'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Username display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '@${widget.username}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Email input
              _buildInputField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                label: _localeService.get('email'),
                hint: 'example@email.com',
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                isDarkMode: isDarkMode,
                onChanged: (_) => setState(() => _emailError = null),
              ),
              
              const SizedBox(height: 16),
              
              // Password input
              _buildInputField(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                label: _localeService.get('password'),
                hint: _localeService.get('enter_password'),
                obscureText: _obscurePassword,
                errorText: _passwordError,
                isDarkMode: isDarkMode,
                onChanged: (_) => setState(() => _passwordError = null),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Password requirements
              _buildPasswordRequirements(isDarkMode),
              
              const SizedBox(height: 16),
              
              // Confirm password input
              _buildInputField(
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocusNode,
                label: _localeService.get('confirm_password'),
                hint: _localeService.get('enter_confirm_password'),
                obscureText: _obscureConfirmPassword,
                errorText: _confirmPasswordError,
                isDarkMode: isDarkMode,
                onChanged: (_) => setState(() => _confirmPasswordError = null),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Register button
              ElevatedButton(
                onPressed: (_canSubmit() && !_isLoading) ? _handleRegister : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canSubmit() ? accentColor : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _localeService.get('sign_up'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              
              const SizedBox(height: 24),
              
              // Terms
              Text(
                _localeService.get('terms_agreement'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required bool isDarkMode,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? errorText,
    Widget? suffixIcon,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: errorText != null
                  ? Colors.red
                  : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: onChanged,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.red,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordRequirements(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequirementRow(
          _localeService.get('password_min_chars'),
          _hasMinLength,
          isDarkMode,
        ),
        _buildRequirementRow(
          _localeService.get('password_uppercase'),
          _hasUppercase,
          isDarkMode,
        ),
        _buildRequirementRow(
          _localeService.get('password_lowercase'),
          _hasLowercase,
          isDarkMode,
        ),
        _buildRequirementRow(
          _localeService.get('password_number'),
          _hasNumber,
          isDarkMode,
        ),
        _buildRequirementRow(
          _localeService.get('password_special_char'),
          _hasSpecialChar,
          isDarkMode,
        ),
      ],
    );
  }

  Widget _buildRequirementRow(String text, bool isMet, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isMet ? Colors.green : (isDarkMode ? Colors.grey[500] : Colors.grey[400]),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isMet ? Colors.green : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
