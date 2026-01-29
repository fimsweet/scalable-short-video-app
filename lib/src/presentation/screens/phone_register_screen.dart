import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:scalable_short_video_app/src/services/firebase_phone_auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class PhoneRegisterScreen extends StatefulWidget {
  final bool isRegistration; // true = from register screen, false = from login screen
  
  const PhoneRegisterScreen({
    super.key,
    this.isRegistration = false,
  });

  @override
  State<PhoneRegisterScreen> createState() => _PhoneRegisterScreenState();
}

class _PhoneRegisterScreenState extends State<PhoneRegisterScreen> 
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  
  final _phoneAuthService = FirebasePhoneAuthService();
  final _apiService = ApiService();
  final _authService = AuthService();
  final _themeService = ThemeService();
  final _localeService = LocaleService();
  
  // Flow states
  bool _isLoading = false;
  String? _errorMessage;
  String _phoneNumber = '';
  bool _isPhoneRegistered = false; // true = login flow, false = register flow
  bool _showOtpScreen = false;
  bool _showBirthdayScreen = false;
  bool _showUsernameScreen = false;
  
  // Birthday picker state
  late DateTime _selectedBirthday;
  late int _selectedDay;
  late int _selectedMonth;
  late int _selectedYear;
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;
  
  // Animation
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _phoneAuthService.addListener(_onAuthStateChanged);
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    
    _animController.forward();
    
    // Initialize birthday to 18 years ago (default)
    final now = DateTime.now();
    _selectedBirthday = DateTime(now.year - 18, now.month, now.day);
    _selectedDay = _selectedBirthday.day;
    _selectedMonth = _selectedBirthday.month;
    _selectedYear = _selectedBirthday.year;
    
    _dayController = FixedExtentScrollController(initialItem: _selectedDay - 1);
    _monthController = FixedExtentScrollController(initialItem: _selectedMonth - 1);
    _yearController = FixedExtentScrollController(initialItem: _getYearIndex(_selectedYear));
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    _usernameController.dispose();
    for (var c in _otpControllers) { c.dispose(); }
    for (var f in _otpFocusNodes) { f.dispose(); }
    _phoneAuthService.removeListener(_onAuthStateChanged);
    _phoneAuthService.reset();
    _animController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }
  
  void _onAuthStateChanged() {
    if (mounted) {
      setState(() {
        _isLoading = _phoneAuthService.isLoading;
        if (_phoneAuthService.errorMessage != null) {
          _errorMessage = _phoneAuthService.errorMessage;
        }
      });
    }
  }
  
  // Birthday helper methods
  int _getYearIndex(int year) {
    final currentYear = DateTime.now().year;
    return currentYear - 13 - year;
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  bool _isValidAge() {
    final now = DateTime.now();
    final age = now.year - _selectedYear - 
        ((now.month < _selectedMonth || 
          (now.month == _selectedMonth && now.day < _selectedDay)) ? 1 : 0);
    return age >= 13;
  }

  String _getAgeText() {
    final now = DateTime.now();
    final age = now.year - _selectedYear - 
        ((now.month < _selectedMonth || 
          (now.month == _selectedMonth && now.day < _selectedDay)) ? 1 : 0);
    
    if (age < 13) {
      return _localeService.get('age_requirement');
    }
    return _localeService.get('your_birthday_wont_be_shown');
  }
  
  String _formatPhoneNumber(String input) {
    String digits = input.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.startsWith('84')) {
      digits = digits.substring(2);
    }
    return '+84$digits';
  }
  
  Future<void> _checkPhoneAndSendOtp() async {
    final input = _phoneController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage = _localeService.get('please_enter_phone'));
      return;
    }
    
    _phoneNumber = _formatPhoneNumber(input);
    
    if (!RegExp(r'^\+84[0-9]{9,10}$').hasMatch(_phoneNumber)) {
      setState(() => _errorMessage = _localeService.get('invalid_phone'));
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Step 1: Check if phone is registered
      final checkResult = await _apiService.checkPhone(_phoneNumber);
      _isPhoneRegistered = checkResult['available'] == false;
      
      // Step 2: Handle based on registration status and flow type
      if (_isPhoneRegistered) {
        if (widget.isRegistration) {
          // Registration flow but phone already exists - show error
          setState(() => _isLoading = false);
          _showPhoneAlreadyRegisteredDialog();
        } else {
          // Login flow - proceed to OTP for login
          final success = await _phoneAuthService.sendOtp(_phoneNumber);
          if (success && mounted) {
            _animateToOtpScreen();
          }
        }
      } else {
        // Phone not registered
        if (widget.isRegistration) {
          // Registration flow - proceed to OTP for registration
          final success = await _phoneAuthService.sendOtp(_phoneNumber);
          if (success && mounted) {
            _animateToOtpScreen();
          }
        } else {
          // Login flow but phone not registered - show dialog to register
          final success = await _phoneAuthService.sendOtp(_phoneNumber);
          if (success && mounted) {
            setState(() => _isLoading = false);
            _showPhoneNotRegisteredDialog();
          }
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  void _showPhoneNotRegisteredDialog() {
    showDialog(
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
              // Icon
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: Colors.orange,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                _localeService.get('phone_not_registered'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _themeService.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Phone number display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _themeService.isLightMode 
                      ? Colors.grey[100] 
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇻🇳', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      _phoneNumber,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _themeService.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                _localeService.get('phone_not_registered_description'),
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
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _phoneAuthService.reset();
                      },
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
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _animateToOtpScreen();
                      },
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

  void _showPhoneAlreadyRegisteredDialog() {
    showDialog(
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
              // Icon
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                _localeService.get('phone_already_registered'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _themeService.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Phone number display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _themeService.isLightMode 
                      ? Colors.grey[100] 
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇻🇳', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      _phoneNumber,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: _themeService.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                _localeService.get('phone_already_registered_description'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _themeService.textSecondaryColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              
              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Go back to registration screen
                  },
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
                    _localeService.get('understood'),
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
  
  void _animateToOtpScreen() {
    _animController.reset();
    setState(() {
      _showOtpScreen = true;
      _isLoading = false;
    });
    _animController.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _otpFocusNodes[0].requestFocus();
      }
    });
  }
  
  void _animateToBirthdayScreen() {
    _animController.reset();
    setState(() {
      _showOtpScreen = false;
      _showBirthdayScreen = true;
    });
    _animController.forward();
  }
  
  void _animateToUsernameScreen() {
    _animController.reset();
    setState(() {
      _showBirthdayScreen = false;
      _showUsernameScreen = true;
    });
    _animController.forward();
  }
  
  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    
    if (otp.length != 6) {
      setState(() => _errorMessage = _localeService.get('enter_6_digit_otp'));
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    final idToken = await _phoneAuthService.verifyOtp(otp);
    
    if (idToken != null && mounted) {
      if (_isPhoneRegistered) {
        // Login with phone
        await _loginWithPhone(idToken);
      } else {
        // New user - go to birthday step first (like Google OAuth)
        _animateToBirthdayScreen();
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _loginWithPhone(String idToken) async {
    try {
      final result = await _apiService.loginWithPhone(idToken);
      
      if (result['success'] == true) {
        final userData = result['data']['user'];
        final token = result['data']['access_token'];
        await _authService.login(userData, token);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_localeService.get('login_success')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? _localeService.get('login_failed');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  Future<void> _completeRegistration() async {
    final username = _usernameController.text.trim();
    
    if (username.isEmpty) {
      setState(() => _errorMessage = _localeService.get('please_enter_username'));
      return;
    }
    
    if (username.length < 3) {
      setState(() => _errorMessage = _localeService.get('username_min_length'));
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final idToken = await _phoneAuthService.getIdToken();
      if (idToken == null) {
        setState(() {
          _errorMessage = _localeService.get('session_expired');
          _isLoading = false;
          _showOtpScreen = false;
          _showBirthdayScreen = false;
          _showUsernameScreen = false;
        });
        return;
      }
      
      // Format birthday as YYYY-MM-DD
      final dateOfBirth = '${_selectedYear.toString().padLeft(4, '0')}-'
          '${_selectedMonth.toString().padLeft(2, '0')}-'
          '${_selectedDay.toString().padLeft(2, '0')}';
      
      final result = await _apiService.registerWithPhone(
        firebaseIdToken: idToken,
        username: username,
        dateOfBirth: dateOfBirth,
        language: _localeService.currentLocale,
      );
      
      if (result['success'] == true) {
        final userData = result['data']['user'];
        final token = result['data']['access_token'];
        await _authService.login(userData, token);
        
        if (mounted) {
          // Navigate to select interests screen for onboarding (no snackbar)
          Navigator.of(context).pushReplacementNamed('/select-interests');
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? _localeService.get('register_failed');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  void _onOtpChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length == 6) {
      _verifyOtp();
    }
  }
  
  void _onOtpKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent && 
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpControllers[index].text.isEmpty &&
        index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }
  
  void _clearOtp() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _otpFocusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.isRegistration 
        ? _localeService.get('phone_register')
        : _localeService.get('phone_login');
    if (_showOtpScreen) {
      title = _isPhoneRegistered 
          ? _localeService.get('verify_login')
          : _localeService.get('verify_register');
    } else if (_showBirthdayScreen) {
      title = _localeService.get('whats_your_birthday');
    } else if (_showUsernameScreen) {
      title = _localeService.get('create_account');
    }
    
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: _themeService.iconColor, size: 28),
          onPressed: () {
            if (_showUsernameScreen) {
              _animController.reset();
              setState(() {
                _showUsernameScreen = false;
                _showBirthdayScreen = true;
              });
              _animController.forward();
            } else if (_showBirthdayScreen) {
              _animController.reset();
              setState(() {
                _showBirthdayScreen = false;
                _showOtpScreen = true;
              });
              _animController.forward();
            } else if (_showOtpScreen) {
              setState(() {
                _showOtpScreen = false;
                _clearOtp();
              });
              _phoneAuthService.reset();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          title,
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current screen content
                if (!_showOtpScreen && !_showBirthdayScreen && !_showUsernameScreen) _buildPhoneStep(),
                if (_showOtpScreen) _buildOtpStep(),
                if (_showBirthdayScreen) _buildBirthdayStep(),
                if (_showUsernameScreen) _buildUsernameStep(),
                
                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.1),
          ),
          child: const Icon(
            Icons.phone_android,
            color: Colors.red,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        
        Text(
          _localeService.get('enter_phone_number'),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _themeService.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _localeService.get('phone_otp_description'),
          style: TextStyle(
            fontSize: 15,
            color: _themeService.textSecondaryColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        
        // Phone input
        Container(
          decoration: BoxDecoration(
            color: _themeService.inputBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _themeService.dividerColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: _themeService.dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🇻🇳', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      '+84',
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: _themeService.textPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: '901234567',
                    hintStyle: TextStyle(
                      color: _themeService.textSecondaryColor.withOpacity(0.5),
                      fontSize: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        
        // Send OTP button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _checkPhoneAndSendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              disabledBackgroundColor: Colors.red.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  _localeService.get('send_otp'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isPhoneRegistered 
                ? Colors.green.withOpacity(0.1) 
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isPhoneRegistered ? Icons.login : Icons.person_add,
                size: 16,
                color: _isPhoneRegistered ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 6),
              Text(
                _isPhoneRegistered 
                    ? _localeService.get('logging_in')
                    : _localeService.get('registering'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isPhoneRegistered ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        Text(
          _localeService.get('enter_otp'),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _themeService.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              '${_localeService.get('otp_sent_to')} ',
              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 15),
            ),
            Text(
              _phoneNumber,
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        
        // OTP input boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) => _buildOtpBox(index)),
        ),
        const SizedBox(height: 30),
        
        // Resend OTP
        Center(
          child: TextButton.icon(
            onPressed: _isLoading ? null : () async {
              _clearOtp();
              await _phoneAuthService.sendOtp(_phoneNumber);
            },
            icon: Icon(Icons.refresh, size: 18, color: _themeService.textSecondaryColor),
            label: Text(
              _localeService.get('resend_otp'),
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // Verify button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              disabledBackgroundColor: Colors.red.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  _isPhoneRegistered 
                      ? _localeService.get('login') 
                      : _localeService.get('continue'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 50,
      height: 60,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) => _onOtpKeyDown(index, event),
        child: TextField(
          controller: _otpControllers[index],
          focusNode: _otpFocusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _themeService.textPrimaryColor,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: _themeService.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _themeService.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _themeService.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) => _onOtpChanged(index, value),
        ),
      ),
    );
  }
  
  Widget _buildBirthdayStep() {
    final currentYear = DateTime.now().year;
    
    // Vietnamese month names
    final monthNames = [
      'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4', 'Tháng 5', 'Tháng 6',
      'Tháng 7', 'Tháng 8', 'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12'
    ];
    
    final englishMonthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    final isVietnamese = _localeService.currentLocale == 'vi';
    final displayMonths = isVietnamese ? monthNames : englishMonthNames;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                _localeService.get('phone_verified'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        Text(
          _localeService.get('whats_your_birthday'),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _themeService.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _getAgeText(),
          style: TextStyle(
            fontSize: 14,
            color: _isValidAge() 
                ? _themeService.textSecondaryColor
                : Colors.red,
          ),
        ),
        const SizedBox(height: 30),
        
        // Birthday picker wheels
        SizedBox(
          height: 200,
          child: Row(
            children: [
              // Month picker
              Expanded(
                flex: 3,
                child: _buildPickerWheel(
                  controller: _monthController,
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    return Center(
                      child: Text(
                        displayMonths[index],
                        style: TextStyle(
                          fontSize: 18,
                          color: _selectedMonth == index + 1
                              ? _themeService.textPrimaryColor
                              : _themeService.textSecondaryColor.withOpacity(0.5),
                          fontWeight: _selectedMonth == index + 1
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _selectedMonth = index + 1;
                      final daysInMonth = _getDaysInMonth(_selectedYear, _selectedMonth);
                      if (_selectedDay > daysInMonth) {
                        _selectedDay = daysInMonth;
                        _dayController.jumpToItem(_selectedDay - 1);
                      }
                    });
                  },
                ),
              ),
              
              // Day picker
              Expanded(
                flex: 2,
                child: _buildPickerWheel(
                  controller: _dayController,
                  itemCount: _getDaysInMonth(_selectedYear, _selectedMonth),
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    return Center(
                      child: Text(
                        day.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 18,
                          color: _selectedDay == day
                              ? _themeService.textPrimaryColor
                              : _themeService.textSecondaryColor.withOpacity(0.5),
                          fontWeight: _selectedDay == day
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _selectedDay = index + 1;
                    });
                  },
                ),
              ),
              
              // Year picker
              Expanded(
                flex: 2,
                child: _buildPickerWheel(
                  controller: _yearController,
                  itemCount: currentYear - 13 - 1920 + 1,
                  itemBuilder: (context, index) {
                    final year = currentYear - 13 - index;
                    return Center(
                      child: Text(
                        year.toString(),
                        style: TextStyle(
                          fontSize: 18,
                          color: _selectedYear == year
                              ? _themeService.textPrimaryColor
                              : _themeService.textSecondaryColor.withOpacity(0.5),
                          fontWeight: _selectedYear == year
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _selectedYear = currentYear - 13 - index;
                      final daysInMonth = _getDaysInMonth(_selectedYear, _selectedMonth);
                      if (_selectedDay > daysInMonth) {
                        _selectedDay = daysInMonth;
                        _dayController.jumpToItem(_selectedDay - 1);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        
        // Next button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isValidAge() ? _animateToUsernameScreen : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isValidAge() ? Colors.red : Colors.grey,
              disabledBackgroundColor: Colors.grey.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            child: Text(
              _localeService.get('next'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPickerWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required void Function(int) onSelectedItemChanged,
  }) {
    final isDarkMode = !_themeService.isLightMode;
    
    return Stack(
      children: [
        // Selection indicator
        Center(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                ),
                bottom: BorderSide(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
            ),
          ),
        ),
        // Picker
        CupertinoPicker.builder(
          scrollController: controller,
          itemExtent: 40,
          onSelectedItemChanged: onSelectedItemChanged,
          childCount: itemCount,
          itemBuilder: itemBuilder,
          selectionOverlay: null,
          backgroundColor: Colors.transparent,
        ),
      ],
    );
  }
  
  Widget _buildUsernameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 16, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                _localeService.get('phone_verified'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        Text(
          _localeService.get('choose_username'),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _themeService.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _localeService.get('username_description'),
          style: TextStyle(
            fontSize: 15,
            color: _themeService.textSecondaryColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        
        // Username input
        TextField(
          controller: _usernameController,
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 18,
          ),
          decoration: InputDecoration(
            hintText: _localeService.get('username'),
            hintStyle: TextStyle(
              color: _themeService.textSecondaryColor.withOpacity(0.5),
              fontSize: 18,
            ),
            prefixIcon: Icon(Icons.person_outline, color: _themeService.iconColor, size: 24),
            filled: true,
            fillColor: _themeService.inputBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _themeService.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _themeService.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
        ),
        const SizedBox(height: 40),
        
        // Complete button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _completeRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              disabledBackgroundColor: Colors.red.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  _localeService.get('create_account'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ),
      ],
    );
  }
}
