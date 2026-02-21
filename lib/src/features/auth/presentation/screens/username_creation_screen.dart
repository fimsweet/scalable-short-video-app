import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/phone_register_screen.dart';
import 'email_password_screen.dart';

/// TikTok-style username creation screen
/// Step 3: Create username (biệt danh)
class UsernameCreationScreen extends StatefulWidget {
  final String registrationMethod; // 'email', 'phone', 'google', 'facebook', 'apple'
  final DateTime dateOfBirth;
  final Map<String, dynamic>? oauthData; // OAuth data containing provider, providerId, email, displayName, photoUrl

  const UsernameCreationScreen({
    super.key,
    required this.registrationMethod,
    required this.dateOfBirth,
    this.oauthData,
  });

  @override
  State<UsernameCreationScreen> createState() => _UsernameCreationScreenState();
}

class _UsernameCreationScreenState extends State<UsernameCreationScreen> {
  final _themeService = ThemeService();
  final _localeService = LocaleService();
  final _authService = AuthService();
  final _apiService = ApiService();
  final TextEditingController _usernameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _isUsernameAvailable = false;
  bool _hasCheckedUsername = false;

  static const int minLength = 3;
  static const int maxLength = 30;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onServiceChanged);
    _localeService.addListener(_onServiceChanged);
    _usernameController.addListener(_onUsernameChanged);
    
    // Auto-generate username from OAuth name if available
    final displayName = widget.oauthData?['displayName'] as String?;
    if (displayName != null) {
      final suggested = _generateSuggestedUsername(displayName);
      _usernameController.text = suggested;
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onServiceChanged);
    _localeService.removeListener(_onServiceChanged);
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  String _generateSuggestedUsername(String fullName) {
    // Remove accents and special characters
    String username = fullName.toLowerCase()
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll(RegExp(r'[đ]'), 'd')
        .replaceAll(RegExp(r'[^a-z0-9_.]'), '')
        .replaceAll(RegExp(r'\s+'), '');
    
    // Add random suffix
    final suffix = DateTime.now().millisecondsSinceEpoch % 10000;
    username = '${username}_$suffix';
    
    return username.substring(0, username.length > maxLength ? maxLength : username.length);
  }

  void _onUsernameChanged() {
    setState(() {
      _hasCheckedUsername = false;
      _isUsernameAvailable = false;
      _errorMessage = null;
    });
  }

  String? _validateUsername(String value) {
    if (value.isEmpty) {
      return _localeService.get('username_required');
    }
    if (value.length < minLength) {
      return _localeService.get('username_too_short')
          .replaceAll('{min}', minLength.toString());
    }
    if (value.length > maxLength) {
      return _localeService.get('username_too_long')
          .replaceAll('{max}', maxLength.toString());
    }
    // Only allow letters, numbers, underscores, and dots
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value)) {
      return _localeService.get('username_invalid_chars');
    }
    // Cannot start with a number
    if (RegExp(r'^[0-9]').hasMatch(value)) {
      return _localeService.get('username_cannot_start_with_number');
    }
    return null;
  }

  Future<void> _checkUsernameAvailability() async {
    final username = _usernameController.text.trim();
    
    final validationError = _validateUsername(username);
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
        _hasCheckedUsername = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Call API to check username availability
      final result = await _apiService.checkUsernameAvailability(username);
      
      final isAvailable = result['success'] == true && result['available'] == true;
      
      setState(() {
        _isUsernameAvailable = isAvailable;
        _hasCheckedUsername = true;
        if (!isAvailable) {
          _errorMessage = _localeService.get('username_taken');
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = _localeService.get('error_checking_username');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _canProceed() {
    final username = _usernameController.text.trim();
    return username.length >= minLength && 
           username.length <= maxLength &&
           _validateUsername(username) == null &&
           !_isLoading;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = !_themeService.isLightMode;
    final accentColor = ThemeService.accentColor;
    
    final username = _usernameController.text;
    final charCount = username.length;

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
                _localeService.get('create_username'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                _localeService.get('username_can_change_later'),
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Username input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _errorMessage != null
                            ? Colors.red
                            : (_isUsernameAvailable && _hasCheckedUsername
                                ? Colors.green
                                : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!)),
                        width: _hasCheckedUsername ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _usernameController,
                            focusNode: _focusNode,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: _localeService.get('username'),
                              hintStyle: TextStyle(
                                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            maxLength: maxLength,
                            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          ),
                        ),
                        // Character count
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Text(
                            '$charCount/$maxLength',
                            style: TextStyle(
                              fontSize: 12,
                              color: charCount > maxLength
                                  ? Colors.red
                                  : (isDarkMode ? Colors.grey[500] : Colors.grey[400]),
                            ),
                          ),
                        ),
                        // Status indicator
                        if (_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              ),
                            ),
                          )
                        else if (_hasCheckedUsername && _isUsernameAvailable)
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24,
                            ),
                          )
                        else if (_hasCheckedUsername && !_isUsernameAvailable)
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(
                              Icons.cancel,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Error or hint message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        _localeService.get('username_hint'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Show success message if username was checked and available
              if (_hasCheckedUsername && _isUsernameAvailable)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _localeService.get('username_available'),
                        style: const TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              
              const Spacer(),
              
              // Next button (auto-checks availability then navigates)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ElevatedButton(
                  onPressed: _canProceed() ? _onNextWithCheck : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed() ? accentColor : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _localeService.get('next'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Auto-check availability then navigate if valid
  Future<void> _onNextWithCheck() async {
    final username = _usernameController.text.trim();
    
    // Validate format first
    final validationError = _validateUsername(username);
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }
    
    // Check availability via API
    await _checkUsernameAvailability();
    
    // Only proceed if available
    if (_hasCheckedUsername && _isUsernameAvailable) {
      _onNextPressed();
    }
  }

  void _onNextPressed() {
    final username = _usernameController.text.trim();
    
    if (widget.registrationMethod == 'email') {
      // Go to email/password screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmailPasswordScreen(
            username: username,
            dateOfBirth: widget.dateOfBirth,
          ),
        ),
      );
    } else if (widget.registrationMethod == 'phone') {
      // Go to phone registration screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PhoneRegisterScreen(isRegistration: true),
        ),
      );
    } else {
      // OAuth registration - complete directly
      _completeOAuthRegistration(username);
    }
  }

  Future<void> _completeOAuthRegistration(String username) async {
    if (widget.oauthData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localeService.get('error')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.completeOAuthRegistration(
        provider: widget.oauthData!['provider'] ?? widget.registrationMethod,
        providerId: widget.oauthData!['providerId'] ?? '',
        email: widget.oauthData!['email'] ?? '',
        username: username,
        dateOfBirth: widget.dateOfBirth,
        fullName: widget.oauthData!['displayName'],
        avatar: widget.oauthData!['photoUrl'],
      );

      if (!mounted) return;

      // Login with the new user
      final userData = result['user'];
      final token = result['access_token'];
      await _authService.login(userData, token);

      // Navigate to select interests screen for onboarding (no snackbar)
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/select-interests',
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_localeService.get('registration_failed')}: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
