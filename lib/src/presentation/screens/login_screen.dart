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

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 3),
        content: Container(
          decoration: BoxDecoration(
            color: isError
                ? (_themeService.isLightMode
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFF3E1A1A))
                : (_themeService.isLightMode
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFF1A3E1A)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isError
                  ? Colors.red.withValues(alpha: 0.3)
                  : Colors.green.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isError
                      ? Colors.red.withValues(alpha: 0.15)
                      : Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                  color: isError ? Colors.red : Colors.green,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: isError
                        ? (_themeService.isLightMode ? Colors.red.shade800 : Colors.red.shade300)
                        : (_themeService.isLightMode ? Colors.green.shade800 : Colors.green.shade300),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          // Localize known backend error messages
          String errorMessage = result['message'] ?? _localeService.get('login_failed');
          if (errorMessage == 'Invalid credentials' || errorMessage == 'invalid credentials') {
            errorMessage = _localeService.get('invalid_credentials');
          }
          _showSnackBar(errorMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('${_localeService.get('error')}: $e');
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
            _showSnackBar(_localeService.get('account_reactivated'), isError: false);
            Navigator.pop(context, true);
          }
        }
      } else {
        if (mounted) {
          _showSnackBar(result['message'] ?? _localeService.get('error'));
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('${_localeService.get('error')}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Navigate to 2FA verification page
  void _show2FAVerificationDialog({required int userId, required List<String> methods}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _TwoFactorVerificationPage(
          userId: userId,
          methods: methods,
          themeService: _themeService,
          localeService: _localeService,
          apiService: _apiService,
          authService: _auth,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    ).then((success) {
      if (success == true && mounted) {
        Navigator.pop(context, true); // Return success to previous screen
      }
    });
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
        _showSnackBar(googleResult.error ?? _localeService.get('google_signin_failed'));
        setState(() => _isGoogleLoading = false);
        return;
      }
      
      // Step 2: Send ID token to backend
      final backendResult = await _auth.googleAuthWithBackend(googleResult.idToken!);
      
      if (!mounted) return;
      
      // Step 3: Check if account requires reactivation (deactivated)
      if (backendResult['requiresReactivation'] == true) {
        setState(() => _isGoogleLoading = false);
        _showReactivationDialog(
          userId: backendResult['userId'],
          daysRemaining: backendResult['daysRemaining'] ?? 30,
        );
        return;
      }

      // Step 4: Check if 2FA is required
      if (backendResult['requires2FA'] == true) {
        setState(() => _isGoogleLoading = false);
        _show2FAVerificationDialog(
          userId: backendResult['userId'],
          methods: List<String>.from(backendResult['twoFactorMethods'] ?? []),
        );
        return;
      }
      
      // Step 5: Check if user needs to complete registration
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
        
        _showSnackBar(_localeService.get('login_successful'), isError: false);
        
        // Pop back to previous screen with success
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('${_localeService.get('error')}: ${e.toString()}');
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
class _TwoFactorVerificationPage extends StatefulWidget {
  final int userId;
  final List<String> methods;
  final ThemeService themeService;
  final LocaleService localeService;
  final ApiService apiService;
  final AuthService authService;

  const _TwoFactorVerificationPage({
    required this.userId,
    required this.methods,
    required this.themeService,
    required this.localeService,
    required this.apiService,
    required this.authService,
  });

  @override
  State<_TwoFactorVerificationPage> createState() => _TwoFactorVerificationPageState();
}

class _TwoFactorVerificationPageState extends State<_TwoFactorVerificationPage> with SingleTickerProviderStateMixin {
  late String _selectedMethod;
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isSendingOtp = false;
  bool _otpSent = false;
  String? _errorMessage;
  String? _successMessage;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.methods.isNotEmpty ? widget.methods.first : 'email';
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // For TOTP, skip the send OTP step
    if (_selectedMethod == 'totp') {
      _otpSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
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
          _successMessage = widget.localeService.get('2fa_sent_success');
          // Clear success message after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _successMessage = null);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
        } else {
          _errorMessage = result['message'];
        }
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().isEmpty || _otpController.text.trim().length < 6) {
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
        final userData = result['user'];
        final token = result['access_token'];
        await widget.authService.login(userData, token);
        if (mounted) Navigator.pop(context, true);
      } else {
        // Localize common backend error messages
        String errorMsg = result['message'] ?? '';
        if (errorMsg.contains('Invalid OTP') || errorMsg.contains('không đúng')) {
          errorMsg = widget.localeService.get('2fa_invalid_otp');
        } else if (errorMsg.contains('expired') || errorMsg.contains('hết hạn')) {
          errorMsg = widget.localeService.get('2fa_otp_expired');
        } else if (errorMsg.contains('already used') || errorMsg.contains('đã được sử dụng')) {
          errorMsg = widget.localeService.get('2fa_otp_already_used');
        } else if (errorMsg.isEmpty) {
          errorMsg = widget.localeService.get('2fa_invalid_otp');
        }
        
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
          _otpController.clear();
        });
        // Shake animation on error
        _shakeController.forward(from: 0);
        _focusNode.requestFocus();
      }
    }
  }

  void _switchMethod(String method) {
    setState(() {
      _selectedMethod = method;
      _otpSent = method == 'totp';
      _errorMessage = null;
      _successMessage = null;
      _otpController.clear();
    });
    if (method == 'totp') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    }
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'totp': return Icons.app_settings_alt;
      case 'sms': return Icons.sms_outlined;
      default: return Icons.email_outlined;
    }
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'totp': return widget.localeService.get('authenticator_app');
      case 'sms': return 'SMS';
      default: return 'Email';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.themeService;
    final locale = widget.localeService;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.textPrimaryColor, size: 20),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: bottomInset > 0 ? 8 : 40),

                      // Icon
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(_selectedMethod),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.withOpacity(0.15),
                                Colors.blue.withOpacity(0.08),
                              ],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _selectedMethod == 'totp'
                                ? Icons.app_settings_alt_rounded
                                : _selectedMethod == 'sms'
                                    ? Icons.sms_outlined
                                    : Icons.shield_outlined,
                            color: Colors.blue,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        locale.get('2fa_login_title'),
                        style: TextStyle(
                          color: theme.textPrimaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        _otpSent
                            ? _selectedMethod == 'totp'
                                ? locale.get('2fa_enter_totp')
                                : _selectedMethod == 'email'
                                    ? locale.get('2fa_code_sent_email')
                                    : locale.get('2fa_code_sent_sms')
                            : locale.get('2fa_login_subtitle'),
                        style: TextStyle(
                          color: theme.textSecondaryColor,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: bottomInset > 0 ? 20 : 32),

                      // === STEP 1: Method selection (before OTP sent) ===
                      if (!_otpSent) ...[
                        // Method cards
                        if (widget.methods.length > 1) ...[
                          ...widget.methods.map((method) {
                            final isSelected = method == _selectedMethod;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _switchMethod(method),
                                  borderRadius: BorderRadius.circular(14),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.blue.withOpacity(0.1)
                                          : theme.cardColor,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue.withOpacity(0.5)
                                            : theme.cardColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.blue.withOpacity(0.15)
                                                : theme.inputBackground,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            _methodIcon(method),
                                            color: isSelected ? Colors.blue : theme.textSecondaryColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _methodLabel(method),
                                                style: TextStyle(
                                                  color: theme.textPrimaryColor,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                method == 'totp'
                                                    ? locale.get('authenticator_app_desc')
                                                    : method == 'email'
                                                        ? locale.get('email_2fa_desc')
                                                        : locale.get('sms_2fa_desc'),
                                                style: TextStyle(
                                                  color: theme.textSecondaryColor,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        AnimatedOpacity(
                                          opacity: isSelected ? 1 : 0,
                                          duration: const Duration(milliseconds: 200),
                                          child: const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 20),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ] else ...[
                          // Single method info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(_methodIcon(_selectedMethod), color: Colors.blue, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    _methodLabel(_selectedMethod),
                                    style: TextStyle(
                                      color: theme.textPrimaryColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Error
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          _buildErrorBanner(_errorMessage!),
                        ],
                      ],

                      // === STEP 2: OTP Input ===
                      if (_otpSent) ...[
                        // Success banner
                        if (_successMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                                const SizedBox(width: 8),
                                Text(_successMessage!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // OTP Input with shake
                        AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            final progress = _shakeController.value;
                            final shake = _shakeController.isAnimating
                                ? 8 * (1 - progress) * (progress * 6 * 3.14159).clamp(-1, 1)
                                : 0.0;
                            return Transform.translate(offset: Offset(shake, 0), child: child);
                          },
                          child: TextField(
                            controller: _otpController,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            autofocus: true,
                            style: TextStyle(
                              color: theme.textPrimaryColor,
                              fontSize: 28,
                              letterSpacing: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            onChanged: (value) {
                              if (_errorMessage != null) setState(() => _errorMessage = null);
                              if (value.length == 6) _verifyOtp();
                            },
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '000000',
                              hintStyle: TextStyle(
                                color: theme.textSecondaryColor.withOpacity(0.25),
                                fontSize: 28,
                                letterSpacing: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              filled: true,
                              fillColor: theme.cardColor,
                              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Colors.blue, width: 1.5),
                              ),
                            ),
                          ),
                        ),

                        // Loading indicator under input
                        if (_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  locale.get('2fa_verifying'),
                                  style: TextStyle(color: theme.textSecondaryColor, fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                        // Error
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          _buildErrorBanner(_errorMessage!),
                        ],

                        const SizedBox(height: 20),

                        // Resend / switch method
                        if (_selectedMethod != 'totp')
                          TextButton(
                            onPressed: _isSendingOtp ? null : _sendOtp,
                            child: Text(
                              _isSendingOtp ? locale.get('2fa_sending') : locale.get('resend_otp'),
                              style: TextStyle(
                                color: _isSendingOtp ? theme.textSecondaryColor : Colors.blue,
                                fontSize: 14,
                              ),
                            ),
                          ),

                        if (widget.methods.length > 1)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _otpSent = false;
                                _errorMessage = null;
                                _successMessage = null;
                                _otpController.clear();
                              });
                            },
                            child: Text(
                              locale.get('2fa_use_another_method'),
                              style: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom button (only for method selection step or single non-totp method)
              if (!_otpSent) ...[
                Padding(
                  padding: EdgeInsets.only(bottom: bottomInset > 0 ? 8 : 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isSendingOtp || _isLoading)
                          ? null
                          : _selectedMethod == 'totp'
                              ? () {
                                  setState(() { _otpSent = true; _errorMessage = null; });
                                  WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
                                }
                              : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        disabledBackgroundColor: Colors.blue.withOpacity(0.4),
                      ),
                      child: (_isSendingOtp || _isLoading)
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(
                              locale.get('2fa_continue'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red[400], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red[400], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}