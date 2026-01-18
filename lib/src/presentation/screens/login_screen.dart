import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/features/auth/presentation/screens/registration_method_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/forgot_password_screen.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  final _apiService = ApiService();
  final _themeService = ThemeService();
  final _localeService = LocaleService();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (result['success']) {
        // Lấy dữ liệu người dùng từ API response
        final responseData = result['data'];
        final userData = responseData['user'];
        final token = responseData['access_token'];
        await _auth.login(userData, token);
        if (mounted) {
          Navigator.pop(context, true); // Trả về thành công
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? _localeService.get('login_failed')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_localeService.get('error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToRegister() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegistrationMethodScreen()),
    );
    if (result == true) {
      Navigator.pop(context, true); // Đăng ký thành công -> tự động đăng nhập và quay lại
    }
  }

  /// Show modern dialog when Google account is not registered
  Future<bool?> _showRegistrationConfirmDialog({
    String? email,
    String? displayName,
    String? photoUrl,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _themeService.isLightMode ? Colors.white : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey[600],
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey[600],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Title with icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _localeService.get('account_not_found'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _themeService.textPrimaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Email info
              if (email != null && email.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _themeService.isLightMode 
                        ? Colors.grey[100] 
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 16,
                        color: _themeService.textSecondaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: _themeService.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                _localeService.get('account_not_registered_description'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _themeService.textSecondaryColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  // Cancel button
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _themeService.isLightMode 
                                ? Colors.grey[300]! 
                                : Colors.grey[700]!,
                          ),
                        ),
                      ),
                      child: Text(
                        _localeService.get('cancel'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _themeService.textSecondaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Register button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _localeService.get('register_now'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleLogin() async {
    if (_isGoogleLoading) return;
    
    setState(() => _isGoogleLoading = true);
    
    try {
      // Step 1: Sign in with Google to get ID token
      final googleResult = await _auth.signInWithGoogle();
      
      if (googleResult.cancelled) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      
      if (!googleResult.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(googleResult.error ?? _localeService.get('google_signin_failed')),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isGoogleLoading = false);
        return;
      }
      
      // Step 2: Send ID token to backend
      final backendResult = await _auth.googleAuthWithBackend(googleResult.idToken!);
      
      if (!mounted) return;
      
      // Step 3: Check if user needs to complete registration
      if (backendResult['isNewUser'] == true) {
        // User not found - need to register first
        // Show confirmation dialog
        final googleUser = backendResult['googleUser'] as Map<String, dynamic>?;
        
        final shouldRegister = await _showRegistrationConfirmDialog(
          email: googleUser?['email'] ?? googleResult.email,
          displayName: googleUser?['fullName'] ?? googleResult.displayName,
          photoUrl: googleUser?['avatar'] ?? googleResult.photoUrl,
        );
        
        if (shouldRegister != true) {
          // User cancelled, stay on login screen
          setState(() => _isGoogleLoading = false);
          return;
        }
        
        // Navigate to registration screen with Google user data pre-filled
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RegistrationMethodScreen(
              prefilledOAuthData: {
                'provider': 'google',
                'providerId': googleUser?['providerId'] ?? googleResult.providerId,
                'email': googleUser?['email'] ?? googleResult.email,
                'displayName': googleUser?['fullName'] ?? googleResult.displayName,
                'photoUrl': googleUser?['avatar'] ?? googleResult.photoUrl,
              },
            ),
          ),
        );
        
        if (result == true && mounted) {
          Navigator.pop(context, true); // Registration successful
        }
      } else {
        // User exists - login directly
        final userData = backendResult['user'];
        final token = backendResult['access_token'];
        
        await _auth.login(userData, token);
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.get('login_successful')),
            backgroundColor: Colors.green,
          ),
        );
        
        // Pop back to previous screen with success
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_localeService.get('error')}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        title: Text(_localeService.get('login'), style: TextStyle(color: _themeService.textPrimaryColor)),
        iconTheme: IconThemeData(color: _themeService.iconColor),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _usernameController,
                    style: TextStyle(color: _themeService.textPrimaryColor),
                    decoration: _inputDecoration(_localeService.get('email')),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _localeService.get('please_enter_email');
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return _localeService.get('invalid_email');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: _themeService.textPrimaryColor),
                    decoration: _inputDecoration(_localeService.get('password')),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _localeService.get('please_enter_password');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(_localeService.get('login'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      );
                    }, 
                    child: Text(_localeService.get('forgot_password'), style: TextStyle(color: _themeService.textSecondaryColor)),
                  ),
                  const SizedBox(height: 32),
                  Text(_localeService.get('or_login_with'), style: TextStyle(color: _themeService.textSecondaryColor)),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12.0,
                    runSpacing: 12.0,
                    children: [
                      _SocialButton(icon: Icons.facebook, label: _localeService.get('facebook'), onTap: () {}, themeService: _themeService),
                      _SocialButton(
                        icon: Icons.g_mobiledata, 
                        label: _localeService.get('google'), 
                        onTap: _isGoogleLoading ? () {} : _handleGoogleLogin, 
                        themeService: _themeService,
                        isLoading: _isGoogleLoading,
                      ),
                      _SocialButton(icon: Icons.phone, label: _localeService.get('phone'), onTap: () {}, themeService: _themeService),
                    ],
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _navigateToRegister,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: _localeService.get('no_account'), style: TextStyle(color: _themeService.textSecondaryColor)),
                        TextSpan(text: _localeService.get('register'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 60), // Extra space for language button
                ],
              ),
            ),
          ),
          // Language toggle button at bottom right
          Positioned(
            right: 16,
            bottom: 16,
            child: _buildLanguageToggleButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageToggleButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showLanguageDialog,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _themeService.isLightMode 
                  ? Colors.grey[400]! 
                  : Colors.grey[600]!,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language,
                size: 16,
                color: _themeService.textSecondaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                _localeService.isVietnamese ? 'VI' : 'EN',
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _themeService.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: _themeService.textSecondaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _localeService.get('language'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildLanguageOption(
              title: 'Tiếng Việt',
              value: 'vi',
              isSelected: _localeService.currentLocale == 'vi',
            ),
            _buildLanguageOption(
              title: 'English',
              value: 'en',
              isSelected: _localeService.currentLocale == 'en',
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required String title,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        _localeService.setLocale(value);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? ThemeService.accentColor 
                      : _themeService.textSecondaryColor,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: ThemeService.accentColor,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: ThemeService.accentColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _themeService.textSecondaryColor),
        filled: true,
        fillColor: _themeService.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeService themeService;
  final bool isLoading;
  const _SocialButton({
    required this.icon, 
    required this.label, 
    required this.onTap, 
    required this.themeService,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: themeService.dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: themeService.textPrimaryColor,
                ),
              )
            else
              Icon(icon, color: themeService.textPrimaryColor),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: themeService.textPrimaryColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
