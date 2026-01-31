import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:scalable_short_video_app/src/features/auth/presentation/screens/registration_method_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/forgot_password_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/phone_register_screen.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  final _apiService = ApiService();
  final _themeService = ThemeService();
  final _localeService = LocaleService();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _buttonScaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.elasticOut),
    );
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
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
      // Get device info
      String platform = 'unknown';
      try {
        if (Platform.isAndroid) {
          platform = 'android';
        } else if (Platform.isIOS) {
          platform = 'ios';
        } else if (Platform.isWindows) {
          platform = 'windows';
        } else if (Platform.isMacOS) {
          platform = 'macos';
        } else if (Platform.isLinux) {
          platform = 'linux';
        }
      } catch (e) {
        platform = 'web';
      }

      final result = await _apiService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        deviceInfo: {
          'platform': platform,
          'deviceName': platform,
          'appVersion': '1.0.0',
        },
      );

      if (result['success']) {
        // Lấy dữ liệu người dùng từ API response
        final responseData = result['data'];
        
        // Check if account requires reactivation
        if (responseData['requiresReactivation'] == true) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showReactivationDialog(
              userId: responseData['userId'],
              daysRemaining: responseData['daysRemaining'] ?? 30,
            );
          }
          return;
        }
        
        // Check if 2FA is required
        if (responseData['requires2FA'] == true) {
          if (mounted) {
            setState(() => _isLoading = false);
            _show2FAVerificationDialog(
              userId: responseData['userId'],
              methods: List<String>.from(responseData['twoFactorMethods'] ?? []),
            );
          }
          return;
        }
        
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

  /// Show reactivation dialog for deactivated accounts
  void _showReactivationDialog({required int userId, required int daysRemaining}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_circle_outlined, color: Colors.deepOrange, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _localeService.get('account_deactivated'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _localeService.get('reactivate_account_prompt'),
              style: TextStyle(color: _themeService.textSecondaryColor, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.deepOrange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_localeService.get('days_remaining')}: $daysRemaining',
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localeService.get('cancel'), style: TextStyle(color: _themeService.textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _reactivateAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_localeService.get('reactivate_account')),
          ),
        ],
      ),
    );
  }

  /// Reactivate the account
  Future<void> _reactivateAccount() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _apiService.reactivateAccount(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      
      if (result['success'] == true) {
        // Now login normally
        final loginResult = await _apiService.login(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        
        if (loginResult['success'] == true) {
          final responseData = loginResult['data'];
          final userData = responseData['user'];
          final token = responseData['access_token'];
          await _auth.login(userData, token);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_localeService.get('account_reactivated')),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? _localeService.get('error')),
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
        setState(() => _isLoading = false);
      }
    }
  }

  /// Show 2FA verification dialog
  void _show2FAVerificationDialog({required int userId, required List<String> methods}) {
    String selectedMethod = methods.isNotEmpty ? methods.first : 'email';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => _TwoFactorVerificationSheet(
        userId: userId,
        methods: methods,
        selectedMethod: selectedMethod,
        themeService: _themeService,
        localeService: _localeService,
        apiService: _apiService,
        authService: _auth,
        onSuccess: () {
          Navigator.pop(context); // Close bottom sheet
          Navigator.pop(context, true); // Return success to previous screen
        },
      ),
    );
  }

  void _navigateToRegister() async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const RegistrationMethodScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
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
      
      // Step 3: Check if 2FA is required
      if (backendResult['requires2FA'] == true) {
        setState(() => _isGoogleLoading = false);
        _show2FAVerificationDialog(
          userId: backendResult['userId'],
          methods: List<String>.from(backendResult['twoFactorMethods'] ?? []),
        );
        return;
      }
      
      // Step 4: Check if user needs to complete registration
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left,
            color: _themeService.iconColor,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Text(
            _localeService.get('login'),
            style: TextStyle(
              color: _themeService.textPrimaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        
                        // Welcome text
                        Text(
                          _localeService.isVietnamese ? 'Chào mừng trở lại!' : 'Welcome back!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _themeService.textPrimaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _localeService.isVietnamese 
                              ? 'Đăng nhập để tiếp tục khám phá' 
                              : 'Sign in to continue exploring',
                          style: TextStyle(
                            fontSize: 15,
                            color: _themeService.textSecondaryColor,
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Email field
                        _buildModernTextField(
                          controller: _usernameController,
                          hint: _localeService.get('email'),
                          icon: Icons.email_outlined,
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
                        
                        // Password field
                        _buildModernTextField(
                          controller: _passwordController,
                          hint: _localeService.get('password'),
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: _themeService.textSecondaryColor,
                              size: 22,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return _localeService.get('please_enter_password');
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _localeService.get('forgot_password'),
                              style: TextStyle(
                                color: _themeService.textSecondaryColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Login button with animation
                        ScaleTransition(
                          scale: _buttonScaleAnimation,
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ThemeService.accentColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: ThemeService.accentColor.withOpacity(0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      _localeService.get('login'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Divider
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: _themeService.dividerColor,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                _localeService.get('or_login_with'),
                                style: TextStyle(
                                  color: _themeService.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: _themeService.dividerColor,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Social login buttons - Modern style
                        Row(
                          children: [
                            Expanded(
                              child: _ModernSocialButton(
                                icon: Icons.facebook_rounded,
                                iconColor: const Color(0xFF1877F2),
                                label: 'Facebook',
                                onTap: () {},
                                themeService: _themeService,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ModernSocialButton(
                                iconWidget: Image.network(
                                  'https://www.google.com/favicon.ico',
                                  width: 22,
                                  height: 22,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.g_mobiledata,
                                    size: 26,
                                    color: Colors.red,
                                  ),
                                ),
                                label: 'Google',
                                onTap: _isGoogleLoading ? () {} : _handleGoogleLogin,
                                isLoading: _isGoogleLoading,
                                themeService: _themeService,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ModernSocialButton(
                                icon: Icons.phone_android_rounded,
                                iconColor: ThemeService.accentColor,
                                label: _localeService.isVietnamese ? 'Điện thoại' : 'Phone',
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const PhoneRegisterScreen()),
                                  );
                                  if (result == true && mounted) {
                                    Navigator.pop(context, true);
                                  }
                                },
                                themeService: _themeService,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Register link
                        Center(
                          child: GestureDetector(
                            onTap: _navigateToRegister,
                            child: RichText(
                              text: TextSpan(
                                text: _localeService.get('no_account'),
                                style: TextStyle(
                                  color: _themeService.textSecondaryColor,
                                  fontSize: 15,
                                ),
                                children: [
                                  TextSpan(
                                    text: _localeService.get('register'),
                                    style: const TextStyle(
                                      color: ThemeService.accentColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
        color: _themeService.textPrimaryColor,
        fontSize: 16,
      ),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: _themeService.textSecondaryColor,
          fontSize: 16,
        ),
        prefixIcon: Icon(
          icon,
          color: _themeService.textSecondaryColor,
          size: 22,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _themeService.isLightMode 
            ? Colors.grey[100] 
            : Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: _themeService.isLightMode 
                ? Colors.grey[200]! 
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: ThemeService.accentColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }
}

class _ModernSocialButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;
  final ThemeService themeService;
  final bool isLoading;
  
  const _ModernSocialButton({
    this.icon,
    this.iconWidget,
    this.iconColor,
    required this.label, 
    required this.onTap, 
    required this.themeService,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: themeService.isLightMode 
                ? Colors.white 
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: themeService.isLightMode 
                  ? Colors.grey[200]! 
                  : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: themeService.textPrimaryColor,
                  ),
                )
              else if (iconWidget != null)
                iconWidget!
              else
                Icon(icon, color: iconColor ?? themeService.textPrimaryColor, size: 24),
              const SizedBox(height: 6),
              Text(
                label, 
                style: TextStyle(
                  color: themeService.textPrimaryColor, 
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/// Two-Factor Authentication Verification Sheet
class _TwoFactorVerificationSheet extends StatefulWidget {
  final int userId;
  final List<String> methods;
  final String selectedMethod;
  final ThemeService themeService;
  final LocaleService localeService;
  final ApiService apiService;
  final AuthService authService;
  final VoidCallback onSuccess;

  const _TwoFactorVerificationSheet({
    required this.userId,
    required this.methods,
    required this.selectedMethod,
    required this.themeService,
    required this.localeService,
    required this.apiService,
    required this.authService,
    required this.onSuccess,
  });

  @override
  State<_TwoFactorVerificationSheet> createState() => _TwoFactorVerificationSheetState();
}

class _TwoFactorVerificationSheetState extends State<_TwoFactorVerificationSheet> {
  late String _selectedMethod;
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.selectedMethod;
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() {
      _isSendingOtp = true;
      _errorMessage = null;
    });

    final result = await widget.apiService.send2FAOtp(widget.userId, _selectedMethod);
    
    if (mounted) {
      setState(() {
        _isSendingOtp = false;
        if (result['success'] == true) {
          _otpSent = true;
          _successMessage = result['message'];
        } else {
          _errorMessage = result['message'];
        }
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().isEmpty) {
      setState(() => _errorMessage = widget.localeService.get('enter_otp'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.apiService.verify2FAOtp(
      widget.userId,
      _otpController.text.trim(),
      _selectedMethod,
    );

    if (mounted) {
      if (result['success'] == true) {
        // Login successful
        final userData = result['user'];
        final token = result['access_token'];
        await widget.authService.login(userData, token);
        widget.onSuccess();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['message'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: widget.themeService.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.security, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.localeService.get('two_factor_verification'),
                          style: TextStyle(
                            color: widget.themeService.textPrimaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.localeService.get('verify_identity'),
                          style: TextStyle(
                            color: widget.themeService.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Method selection (if multiple methods)
              if (widget.methods.length > 1) ...[
                Text(
                  widget.localeService.get('select_verification_method'),
                  style: TextStyle(
                    color: widget.themeService.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: widget.methods.map((method) {
                    final isSelected = method == _selectedMethod;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMethod = method;
                            _otpSent = false;
                            _errorMessage = null;
                            _successMessage = null;
                            _otpController.clear();
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.withOpacity(0.2) : widget.themeService.inputBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey[700]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                method == 'email' ? Icons.email_outlined : Icons.sms_outlined,
                                color: isSelected ? Colors.blue : widget.themeService.textSecondaryColor,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                method == 'email' ? 'Email' : 'SMS',
                                style: TextStyle(
                                  color: isSelected ? Colors.blue : widget.themeService.textSecondaryColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
              
              // Success message
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.green, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // OTP input
              if (_otpSent) ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.themeService.textPrimaryColor,
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '------',
                    hintStyle: TextStyle(color: widget.themeService.textSecondaryColor),
                    counterText: '',
                    filled: true,
                    fillColor: widget.themeService.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        widget.localeService.get('cancel'),
                        style: TextStyle(color: widget.themeService.textSecondaryColor, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (_isSendingOtp || _isLoading)
                          ? null
                          : (_otpSent ? _verifyOtp : _sendOtp),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: (_isSendingOtp || _isLoading)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _otpSent
                                  ? widget.localeService.get('verify')
                                  : widget.localeService.get('send_otp'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
              
              // Resend OTP
              if (_otpSent)
                Center(
                  child: TextButton(
                    onPressed: _isSendingOtp ? null : _sendOtp,
                    child: Text(
                      widget.localeService.get('resend_otp'),
                      style: TextStyle(color: Colors.blue.withOpacity(_isSendingOtp ? 0.5 : 1)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}