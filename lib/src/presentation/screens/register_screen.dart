import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/locale_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  final _apiService = ApiService();
  final _authService = AuthService();
  final _themeService = ThemeService();
  final _localeService = LocaleService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showAdditionalInfo = false;
  DateTime? _selectedDate;
  String? _selectedGender;
  
  late AnimationController _additionalInfoController;
  late Animation<double> _additionalInfoAnimation;
  
  // New animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    
    _additionalInfoController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _additionalInfoAnimation = CurvedAnimation(
      parent: _additionalInfoController,
      curve: Curves.easeInOut,
    );
    
    // Initialize fade and slide animations
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
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _additionalInfoController.dispose();
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

  void _toggleAdditionalInfo() {
    setState(() {
      _showAdditionalInfo = !_showAdditionalInfo;
      if (_showAdditionalInfo) {
        _additionalInfoController.forward();
      } else {
        _additionalInfoController.reverse();
      }
    });
  }

  bool _isPasswordStrong(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  bool _isUsernameValid(String username) {
    return RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username);
  }

  bool _isPhoneValid(String phone) {
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(phone);
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 13, now.month, now.day);
    final minDate = DateTime(1900);
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? maxDate,
      firstDate: minDate,
      lastDate: maxDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: _themeService.isLightMode
                ? ColorScheme.light(
                    primary: ThemeService.accentColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  )
                : ColorScheme.dark(
                    primary: ThemeService.accentColor,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  ),
            dialogBackgroundColor: _themeService.backgroundColor,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    // Check required birthday (TikTok style)
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localeService.get('please_select_dob')),
          backgroundColor: ThemeService.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _apiService.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim().isNotEmpty 
            ? _fullNameController.text.trim() 
            : null,
        phoneNumber: _phoneController.text.trim().isNotEmpty 
            ? _phoneController.text.trim() 
            : null,
        dateOfBirth: _selectedDate!.toIso8601String().split('T')[0],
        gender: _selectedGender,
        language: _localeService.currentLocale,
      );

      if (result['success']) {
        if (mounted) {
          // Auto-login after successful registration
          final responseData = result['data'];
          if (responseData != null) {
            final userData = responseData['user'];
            final token = responseData['access_token'];
            
            if (userData != null && token != null) {
              // Login the user automatically
              await _authService.login(
                Map<String, dynamic>.from(userData),
                token.toString(),
              );
              print('Auto-login after registration successful');
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_localeService.get('register_success')),
              backgroundColor: ThemeService.successColor,
            ),
          );
          // Navigate to select interests screen for onboarding
          Navigator.of(context).pushReplacementNamed('/select-interests');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? _localeService.get('register_failed')),
              backgroundColor: ThemeService.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_localeService.get('error')}: $e'),
            backgroundColor: ThemeService.errorColor,
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
            _localeService.get('register'),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome text
                      Text(
                        _localeService.isVietnamese ? 'Tạo tài khoản mới' : 'Create new account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _themeService.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _localeService.isVietnamese 
                            ? 'Điền thông tin để bắt đầu' 
                            : 'Fill in your details to get started',
                        style: TextStyle(
                          fontSize: 15,
                          color: _themeService.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Birthday Section (TikTok style - required first)
                      Text(
                        _localeService.get('whats_your_birthday'),
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _localeService.get('birthday_description'),
                        style: TextStyle(
                          color: _themeService.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDatePicker(),
                      const SizedBox(height: 24),

                      // Username Section
                      Text(
                        _localeService.get('create_username'),
                        style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _localeService.get('username_description'),
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _usernameController,
                    hint: _localeService.get('username'),
                    prefixIcon: Icons.alternate_email,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _localeService.get('please_enter_username');
                      }
                      if (value.length < 3) {
                        return _localeService.get('username_min_length');
                      }
                      if (!_isUsernameValid(value)) {
                        return _localeService.get('username_requirements');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Email
                  Text(
                    _localeService.get('email'),
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _emailController,
                    hint: _localeService.get('email_hint'),
                    prefixIcon: Icons.email_outlined,
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
                  const SizedBox(height: 20),

                  // Password
                  Text(
                    _localeService.get('password'),
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _passwordController,
                    hint: _localeService.get('password'),
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: _themeService.textSecondaryColor,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _localeService.get('please_enter_password');
                      }
                      if (!_isPasswordStrong(value)) {
                        return _localeService.get('password_requirements');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: _themeService.textSecondaryColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _localeService.get('password_requirements'),
                          style: TextStyle(
                            color: _themeService.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Confirm Password
                  Text(
                    _localeService.get('confirm_password'),
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    hint: _localeService.get('confirm_password'),
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: _themeService.textSecondaryColor,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _localeService.get('please_enter_password');
                      }
                      if (value != _passwordController.text) {
                        return _localeService.get('passwords_not_match');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Additional Info Toggle (Expandable with smooth animation)
                  _buildAdditionalInfoToggle(),
                  
                  // Animated Additional Info Section
                  SizeTransition(
                    sizeFactor: _additionalInfoAnimation,
                    child: FadeTransition(
                      opacity: _additionalInfoAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          
                          // Full Name
                          _buildTextField(
                            controller: _fullNameController,
                            hint: _localeService.get('full_name'),
                            prefixIcon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),

                          // Phone
                          _buildTextField(
                            controller: _phoneController,
                            hint: _localeService.get('phone_number'),
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                            ],
                            validator: (value) {
                              if (value != null && value.isNotEmpty && !_isPhoneValid(value)) {
                                return _localeService.get('invalid_phone');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Gender Dropdown
                          _buildGenderDropdown(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Register Button (TikTok style)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeService.accentColor,
                        disabledBackgroundColor: ThemeService.accentColor.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _localeService.get('sign_up'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Divider with "or"
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: _themeService.dividerColor,
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _localeService.get('or'),
                          style: TextStyle(
                            color: _themeService.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: _themeService.dividerColor,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Register with Phone button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/phone-register');
                      },
                      icon: Icon(
                        Icons.phone_android_rounded,
                        color: _themeService.textPrimaryColor,
                        size: 22,
                      ),
                      label: Text(
                        _localeService.get('register_with_phone'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: _themeService.textPrimaryColor,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _themeService.dividerColor,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Terms and Privacy
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text.rich(
                        TextSpan(
                          text: _localeService.get('terms_agree_prefix'),
                          style: TextStyle(
                            color: _themeService.textSecondaryColor,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(
                              text: _localeService.get('terms_of_service'),
                              style: const TextStyle(
                                color: ThemeService.accentColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            TextSpan(
                              text: _localeService.get('and'),
                            ),
                            TextSpan(
                              text: _localeService.get('privacy_policy'),
                              style: const TextStyle(
                                color: ThemeService.accentColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: _localeService.get('have_account'),
                            style: TextStyle(color: _themeService.textSecondaryColor),
                          ),
                          TextSpan(
                            text: _localeService.get('login'),
                            style: TextStyle(
                              color: ThemeService.accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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

  Widget _buildAdditionalInfoToggle() {
    return InkWell(
      onTap: _toggleAdditionalInfo,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.person_add_outlined,
              color: _themeService.textSecondaryColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _localeService.get('additional_info'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              _localeService.get('optional'),
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _showAdditionalInfo ? 0.5 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: _themeService.textSecondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _themeService.textSecondaryColor,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool? obscureText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText ?? false,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: TextStyle(color: _themeService.textPrimaryColor),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _themeService.textSecondaryColor),
        prefixIcon: prefixIcon != null 
            ? Icon(prefixIcon, color: _themeService.textSecondaryColor, size: 22)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _themeService.isLightMode ? Colors.grey[300]! : Colors.grey[800]!,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ThemeService.accentColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ThemeService.errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: ThemeService.errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _selectedDate == null
                ? (_themeService.isLightMode ? Colors.grey[300]! : Colors.grey[800]!)
                : ThemeService.accentColor,
            width: _selectedDate == null ? 1 : 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cake_outlined,
              color: _selectedDate != null 
                  ? ThemeService.accentColor 
                  : _themeService.textSecondaryColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDate != null
                    ? DateFormat('MMMM dd, yyyy', _localeService.isVietnamese ? 'vi' : 'en').format(_selectedDate!)
                    : _localeService.get('select_birthday'),
                style: TextStyle(
                  color: _selectedDate != null
                      ? _themeService.textPrimaryColor
                      : _themeService.textSecondaryColor,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              color: _themeService.textSecondaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    final genderOptions = [
      {'value': 'male', 'label': _localeService.get('male')},
      {'value': 'female', 'label': _localeService.get('female')},
      {'value': 'other', 'label': _localeService.get('other')},
      {'value': 'prefer_not_to_say', 'label': _localeService.get('prefer_not_to_say')},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _themeService.isLightMode ? Colors.grey[300]! : Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(
                Icons.wc_outlined,
                color: _themeService.textSecondaryColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                _localeService.get('gender'),
                style: TextStyle(color: _themeService.textSecondaryColor),
              ),
            ],
          ),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: _themeService.textSecondaryColor,
          ),
          dropdownColor: _themeService.isLightMode ? Colors.white : const Color(0xFF2A2A2A),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 16,
          ),
          items: genderOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option['value'],
              child: Text(option['label']!),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedGender = value);
          },
          selectedItemBuilder: (context) {
            return genderOptions.map((option) {
              return Row(
                children: [
                  Icon(
                    Icons.wc_outlined,
                    color: _themeService.textSecondaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    option['label']!,
                    style: TextStyle(color: _themeService.textPrimaryColor),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    final genderOptions = [
      {'value': 'male', 'label': _localeService.get('male')},
      {'value': 'female', 'label': _localeService.get('female')},
      {'value': 'other', 'label': _localeService.get('other')},
      {'value': 'prefer_not_to_say', 'label': _localeService.get('prefer_not_to_say')},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _localeService.get('gender'),
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: genderOptions.map((option) {
            final isSelected = _selectedGender == option['value'];
            return GestureDetector(
              onTap: () => setState(() => _selectedGender = option['value']),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? ThemeService.accentColor.withValues(alpha: 0.15)
                      : _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected 
                        ? ThemeService.accentColor 
                        : _themeService.isLightMode ? Colors.grey[300]! : Colors.grey[800]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Text(
                  option['label']!,
                  style: TextStyle(
                    color: isSelected 
                        ? ThemeService.accentColor 
                        : _themeService.textPrimaryColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }


}


