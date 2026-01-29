import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

/// TikTok-style Email Registration Screen
/// Combines Birthday -> Username -> Email/Password in one screen like phone registration
class EmailRegisterScreen extends StatefulWidget {
  const EmailRegisterScreen({super.key});

  @override
  State<EmailRegisterScreen> createState() => _EmailRegisterScreenState();
}

class _EmailRegisterScreenState extends State<EmailRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _apiService = ApiService();
  final _authService = AuthService();
  final _themeService = ThemeService();
  final _localeService = LocaleService();

  // Flow states
  bool _isLoading = false;
  String? _errorMessage;
  bool _showBirthdayScreen = true;
  bool _showUsernameScreen = false;
  bool _showEmailPasswordScreen = false;
  
  // Password visibility
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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

  // Password requirements
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  
  // Username check
  bool _isUsernameAvailable = false;
  bool _hasCheckedUsername = false;

  @override
  void initState() {
    super.initState();

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
    
    // Password listener
    _passwordController.addListener(_validatePasswordRequirements);
    
    // Username listener
    _usernameController.addListener(() {
      setState(() {
        _hasCheckedUsername = false;
        _isUsernameAvailable = false;
      });
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
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
    final age = now.year -
        _selectedYear -
        ((now.month < _selectedMonth ||
                (now.month == _selectedMonth && now.day < _selectedDay))
            ? 1
            : 0);
    return age >= 13;
  }

  String _getAgeText() {
    final now = DateTime.now();
    final age = now.year -
        _selectedYear -
        ((now.month < _selectedMonth ||
                (now.month == _selectedMonth && now.day < _selectedDay))
            ? 1
            : 0);

    if (age < 13) {
      return _localeService.get('age_requirement');
    }
    return _localeService.get('your_birthday_wont_be_shown');
  }

  void _animateToUsernameScreen() {
    _animController.reset();
    setState(() {
      _showBirthdayScreen = false;
      _showUsernameScreen = true;
      _errorMessage = null;
    });
    _animController.forward();
  }

  void _animateToEmailPasswordScreen() {
    _animController.reset();
    setState(() {
      _showUsernameScreen = false;
      _showEmailPasswordScreen = true;
      _errorMessage = null;
    });
    _animController.forward();
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
  
  Future<void> _checkUsernameAvailability() async {
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

  Future<void> _completeRegistration() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final username = _usernameController.text.trim();

    // Validate email
    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = _localeService.get('invalid_email'));
      return;
    }
    
    // Validate password strength
    if (!_isPasswordStrong()) {
      setState(() => _errorMessage = _localeService.get('password_too_weak'));
      return;
    }
    
    // Validate password match
    if (password != confirmPassword) {
      setState(() => _errorMessage = _localeService.get('passwords_dont_match'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Format birthday as YYYY-MM-DD
      final dateOfBirth = DateTime(_selectedYear, _selectedMonth, _selectedDay);

      final result = await _authService.emailRegister(
        email: email,
        password: password,
        username: username,
        dateOfBirth: dateOfBirth,
      );

      if (result['success'] == true || result['user'] != null) {
        final userData = result['user'];
        final token = result['access_token'];
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
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = _localeService.get('email_register');
    if (_showBirthdayScreen) {
      title = _localeService.get('whats_your_birthday');
    } else if (_showUsernameScreen) {
      title = _localeService.get('create_account');
    } else if (_showEmailPasswordScreen) {
      title = _localeService.get('enter_email_password');
    }

    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: _themeService.iconColor, size: 28),
          onPressed: () {
            if (_showEmailPasswordScreen) {
              _animController.reset();
              setState(() {
                _showEmailPasswordScreen = false;
                _showUsernameScreen = true;
                _errorMessage = null;
              });
              _animController.forward();
            } else if (_showUsernameScreen) {
              _animController.reset();
              setState(() {
                _showUsernameScreen = false;
                _showBirthdayScreen = true;
                _errorMessage = null;
              });
              _animController.forward();
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
                if (_showBirthdayScreen) _buildBirthdayStep(),
                if (_showUsernameScreen) _buildUsernameStep(),
                if (_showEmailPasswordScreen) _buildEmailPasswordStep(),

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
        // Header icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withOpacity(0.1),
          ),
          child: const Icon(
            Icons.email_outlined,
            color: Colors.red,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),

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
                _localeService.get('birthday_confirmed'),
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
        Container(
          decoration: BoxDecoration(
            color: _themeService.inputBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hasCheckedUsername 
                  ? (_isUsernameAvailable ? Colors.green : Colors.red)
                  : _themeService.dividerColor,
              width: _hasCheckedUsername ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
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
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  ),
                ),
              ),
              // Status indicator
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                  ),
                )
              else if (_hasCheckedUsername && _isUsernameAvailable)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 24),
                )
              else if (_hasCheckedUsername && !_isUsernameAvailable)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(Icons.cancel, color: Colors.red, size: 24),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Check availability button
        if (!_hasCheckedUsername || !_isUsernameAvailable)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _checkUsernameAvailability,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _localeService.get('check_availability'),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        
        const SizedBox(height: 40),

        // Next button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: (_hasCheckedUsername && _isUsernameAvailable && !_isLoading) 
                ? _animateToEmailPasswordScreen 
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              disabledBackgroundColor: Colors.red.withOpacity(0.4),
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

  Widget _buildEmailPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicators
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '@${_usernameController.text.trim()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Text(
          _localeService.get('enter_email_password'),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _themeService.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _localeService.get('email_password_description'),
          style: TextStyle(
            fontSize: 15,
            color: _themeService.textSecondaryColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),

        // Email input
        _buildInputField(
          controller: _emailController,
          hint: 'example@email.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // Password input
        _buildInputField(
          controller: _passwordController,
          hint: _localeService.get('enter_password'),
          icon: Icons.lock_outline,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: _themeService.iconColor,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 12),
        
        // Password requirements
        _buildPasswordRequirements(),
        const SizedBox(height: 16),

        // Confirm password input
        _buildInputField(
          controller: _confirmPasswordController,
          hint: _localeService.get('enter_confirm_password'),
          icon: Icons.lock_outline,
          obscureText: _obscureConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: _themeService.iconColor,
            ),
            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
        ),
        const SizedBox(height: 40),

        // Register button
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

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _themeService.inputBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _themeService.dividerColor,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: TextStyle(
          color: _themeService.textPrimaryColor,
          fontSize: 18,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: _themeService.textSecondaryColor.withOpacity(0.5),
            fontSize: 18,
          ),
          prefixIcon: Icon(icon, color: _themeService.iconColor, size: 24),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    final isDarkMode = !_themeService.isLightMode;
    
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
