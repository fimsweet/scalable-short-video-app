import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/phone_register_screen.dart';
import 'birthday_picker_screen.dart';
import 'email_register_screen.dart';

/// TikTok-style registration method selection screen
/// Step 1: Choose registration method (Email, Google, Facebook, Apple)
class RegistrationMethodScreen extends StatefulWidget {
  /// Pre-filled OAuth data when user tries to login with unregistered account
  final Map<String, dynamic>? prefilledOAuthData;
  
  const RegistrationMethodScreen({
    super.key,
    this.prefilledOAuthData,
  });

  @override
  State<RegistrationMethodScreen> createState() => _RegistrationMethodScreenState();
}

class _RegistrationMethodScreenState extends State<RegistrationMethodScreen> {
  final _themeService = ThemeService();
  final _localeService = LocaleService();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onServiceChanged);
    _localeService.addListener(_onServiceChanged);
    
    // If we have prefilled OAuth data, navigate directly to birthday screen
    if (widget.prefilledOAuthData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateWithPrefilledData();
      });
    }
  }
  
  void _navigateWithPrefilledData() {
    if (widget.prefilledOAuthData != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BirthdayPickerScreen(
            registrationMethod: widget.prefilledOAuthData!['provider'] ?? 'google',
            oauthData: widget.prefilledOAuthData,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onServiceChanged);
    _localeService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
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
            Icons.chevron_left,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        systemOverlayStyle: isDarkMode 
            ? SystemUiOverlayStyle.light 
            : SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              
              // Title
              Text(
                _localeService.get('sign_up'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Registration options
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Phone option
                      _buildOptionButton(
                        icon: Icons.phone_outlined,
                        label: _localeService.get('use_phone'),
                        onTap: () => _navigateToPhoneRegister(context),
                        isDarkMode: isDarkMode,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Email option
                      _buildOptionButton(
                        icon: Icons.email_outlined,
                        label: _localeService.get('use_email'),
                        onTap: () => _navigateToEmailRegister(context),
                        isDarkMode: isDarkMode,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Divider with OR text
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _localeService.get('or_continue_with'),
                              style: TextStyle(
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Facebook option
                      _buildSocialButton(
                        icon: Icons.facebook,
                        label: _localeService.get('continue_with_facebook'),
                        iconColor: const Color(0xFF1877F2),
                        onTap: () => _handleFacebookSignIn(context),
                        isDarkMode: isDarkMode,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Apple option
                      _buildSocialButton(
                        icon: Icons.apple,
                        label: _localeService.get('continue_with_apple'),
                        iconColor: isDarkMode ? Colors.white : Colors.black,
                        onTap: () => _handleAppleSignIn(context),
                        isDarkMode: isDarkMode,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Google option
                      _buildSocialButton(
                        iconWidget: Image.asset(
                          'assets/icons/google_icon.png',
                          width: 24,
                          height: 24,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.g_mobiledata,
                              size: 28,
                              color: Color(0xFF4285F4),
                            );
                          },
                        ),
                        label: _localeService.get('continue_with_google'),
                        onTap: () => _handleGoogleSignIn(context),
                        isDarkMode: isDarkMode,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Terms of service
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _localeService.get('terms_agreement'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bottom login link
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _localeService.get('already_have_account'),
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        _localeService.get('login'),
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDarkMode ? Colors.white : Colors.black,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    IconData? icon,
    Widget? iconWidget,
    required String label,
    Color? iconColor,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              if (iconWidget != null)
                iconWidget
              else if (icon != null)
                Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _navigateToBirthday(BuildContext context, String method) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BirthdayPickerScreen(
          registrationMethod: method,
        ),
      ),
    );
  }

  void _navigateToEmailRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmailRegisterScreen(),
      ),
    );
  }

  void _navigateToPhoneRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PhoneRegisterScreen(isRegistration: true),
      ),
    );
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Step 1: Sign in with Google to get ID token
      final googleResult = await _authService.signInWithGoogle();
      
      if (googleResult.cancelled) {
        setState(() => _isLoading = false);
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
        setState(() => _isLoading = false);
        return;
      }
      
      // Step 2: Send ID token to backend
      final backendResult = await _authService.googleAuthWithBackend(googleResult.idToken!);
      
      if (!mounted) return;
      
      // Step 3: Check if user needs to complete registration
      // Backend returns 'isNewUser' field
      if (backendResult['isNewUser'] == true) {
        // User not found - need to complete registration
        // Use googleUser from backend response
        final googleUser = backendResult['googleUser'] as Map<String, dynamic>?;
        
        // Navigate to birthday picker with Google user data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BirthdayPickerScreen(
              registrationMethod: 'google',
              oauthData: {
                'provider': 'google',
                'providerId': googleUser?['providerId'] ?? googleResult.providerId,
                'email': googleUser?['email'] ?? googleResult.email,
                'displayName': googleUser?['fullName'] ?? googleResult.displayName,
                'photoUrl': googleUser?['avatar'] ?? googleResult.photoUrl,
              },
            ),
          ),
        );
      } else {
        // User exists - login directly
        final userData = backendResult['user'];
        final token = backendResult['access_token'];
        
        await _authService.login(userData, token);
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.get('login_successful')),
            backgroundColor: Colors.green,
          ),
        );
        
        // Pop back to login/home
        Navigator.of(context).popUntil((route) => route.isFirst);
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
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleFacebookSignIn(BuildContext context) {
    // TODO: Implement Facebook Sign-In
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Facebook Sign-In coming soon')),
    );
  }

  void _handleAppleSignIn(BuildContext context) {
    // TODO: Implement Apple Sign-In
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Apple Sign-In coming soon')),
    );
  }
}
