import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import '../../services/theme_service.dart';
import '../../services/locale_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final _apiService = ApiService();
  final _themeService = ThemeService();
  final _localeService = LocaleService();
  
  bool _isLoading = false;
  bool _codeSent = false;
  bool _codeVerified = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _resendCountdown = 0;
  
  // Toggle between email and phone
  bool _usePhone = false;
  String? _verificationId; // For Firebase phone auth
  
  // Error messages for inline display
  String? _emailError;
  String? _phoneError;
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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

  void _startResendCountdown() {
    setState(() => _resendCountdown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      return _resendCountdown > 0;
    });
  }

  bool _isPasswordStrong(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _emailError = null;
      _phoneError = null;
    });

    try {
      if (_usePhone) {
        // Phone password reset flow - first check if phone exists with email/password registration
        final phone = ApiService.parsePhoneToE164(_phoneController.text.trim());
        final checkResult = await _apiService.checkPhoneForPasswordReset(phone);
        
        if (checkResult['success'] != true) {
          setState(() {
            _isLoading = false;
            _phoneError = checkResult['message'] ?? _localeService.get('phone_not_found');
          });
          return;
        }
        
        // Use Firebase to send OTP
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (PhoneAuthCredential credential) {
            // Auto-verification (rare)
          },
          verificationFailed: (FirebaseAuthException e) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _phoneError = e.message ?? _localeService.get('verification_failed');
              });
            }
          },
          codeSent: (String verId, int? resendToken) {
            _verificationId = verId;
            if (mounted) {
              setState(() {
                _codeSent = true;
                _isLoading = false;
              });
              _startResendCountdown();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_localeService.get('reset_code_sent')),
                  backgroundColor: ThemeService.successColor,
                ),
              );
            }
          },
          codeAutoRetrievalTimeout: (String verId) {
            _verificationId = verId;
          },
        );
      } else {
        // Email password reset flow
        final result = await _apiService.forgotPassword(_emailController.text.trim());
        
        if (mounted) {
          if (result['success'] == true) {
            setState(() {
              _codeSent = true;
              _isLoading = false;
              _emailError = null;
            });
            _startResendCountdown();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_localeService.get('reset_code_sent')),
                backgroundColor: ThemeService.successColor,
              ),
            );
          } else {
            setState(() {
              _isLoading = false;
              _emailError = result['message'] ?? _localeService.get('error');
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_usePhone) {
            _phoneError = '${_localeService.get('error')}: $e';
          } else {
            _emailError = '${_localeService.get('error')}: $e';
          }
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) {
      setState(() {
        _otpError = _localeService.get('invalid_code');
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    try {
      if (_usePhone) {
        // For phone, we just verify locally then proceed to password step
        // The actual verification will happen when resetting password
        if (_verificationId != null) {
          try {
            // Validate the OTP format (6 digits)
            final smsCode = _codeController.text;
            if (smsCode.length == 6 && RegExp(r'^\d{6}$').hasMatch(smsCode)) {
              // Store the verification info for later use when resetting password
              setState(() {
                _codeVerified = true;
                _isLoading = false;
                _otpError = null;
              });
            } else {
              setState(() {
                _isLoading = false;
                _otpError = _localeService.get('invalid_code');
              });
            }
          } catch (e) {
            setState(() {
              _isLoading = false;
              _otpError = _localeService.get('invalid_code');
            });
          }
        } else {
          setState(() {
            _isLoading = false;
            _otpError = _localeService.get('verification_failed');
          });
        }
      } else {
        // Email OTP verification
        final result = await _apiService.verifyOtp(
          email: _emailController.text.trim(),
          otp: _codeController.text,
        );

        if (mounted) {
          if (result['success'] == true) {
            setState(() {
              _codeVerified = true;
              _isLoading = false;
              _otpError = null;
            });
          } else {
            setState(() {
              _isLoading = false;
              _otpError = result['message'] ?? _localeService.get('invalid_code');
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _otpError = '${_localeService.get('error')}: $e';
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localeService.get('passwords_not_match')),
          backgroundColor: ThemeService.errorColor,
        ),
      );
      return;
    }

    if (!_isPasswordStrong(_newPasswordController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localeService.get('password_requirements')),
          backgroundColor: ThemeService.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> result;
      
      if (_usePhone) {
        // Reset password with phone number - need Firebase ID token
        final phone = ApiService.parsePhoneToE164(_phoneController.text.trim());
        
        // Create credential and sign in to get ID token
        if (_verificationId == null) {
          throw Exception(_localeService.get('verification_failed'));
        }
        
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _codeController.text,
        );
        
        // Sign in to get the ID token
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        final idToken = await userCredential.user?.getIdToken();
        
        if (idToken == null) {
          throw Exception(_localeService.get('verification_failed'));
        }
        
        result = await _apiService.resetPasswordWithPhone(
          phone: phone,
          firebaseIdToken: idToken,
          newPassword: _newPasswordController.text,
        );
        
        // Sign out from Firebase after resetting password
        await FirebaseAuth.instance.signOut();
      } else {
        // Reset password with email
        result = await _apiService.resetPassword(
          email: _emailController.text.trim(),
          otp: _codeController.text,
          newPassword: _newPasswordController.text,
        );
      }
      
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_localeService.get('password_reset_success')),
              backgroundColor: ThemeService.successColor,
            ),
          );
          Navigator.pop(context);
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? _localeService.get('error')),
              backgroundColor: ThemeService.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_localeService.get('error')}: $e'),
            backgroundColor: ThemeService.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        title: Text(
          _localeService.get('forgot_password'),
          style: TextStyle(color: _themeService.textPrimaryColor),
        ),
        iconTheme: IconThemeData(color: _themeService.iconColor),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header illustration
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: ThemeService.accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset,
                        size: 60,
                        color: ThemeService.accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Description text
                  Text(
                    _getStepDescription(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Step 1: Email input
                  if (!_codeSent) ...[
                    _buildEmailStep(),
                  ]
                  // Step 2: Code verification
                  else if (!_codeVerified) ...[
                    _buildCodeVerificationStep(),
                  ]
                  // Step 3: New password
                  else ...[
                    _buildNewPasswordStep(),
                  ],
                  
                  const SizedBox(height: 40),
                  
                  // Language toggle button at bottom
                  Center(
                    child: _buildLanguageToggleButton(),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStepDescription() {
    if (!_codeSent) {
      return _localeService.get('forgot_password_description');
    } else if (!_codeVerified) {
      return _localeService.get('enter_verification_code_desc');
    } else {
      return _localeService.get('create_new_password_desc');
    }
  }

  Widget _buildEmailStep() {
    return Column(
      children: [
        // Toggle between Email and Phone
        Container(
          decoration: BoxDecoration(
            color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[800],
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _usePhone = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_usePhone ? ThemeService.accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      'Email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: !_usePhone ? Colors.white : _themeService.textSecondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _usePhone = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _usePhone ? ThemeService.accentColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Text(
                      _localeService.get('phone_number'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _usePhone ? Colors.white : _themeService.textSecondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Email input
        if (!_usePhone)
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: _themeService.textPrimaryColor),
            decoration: _buildInputDecoration(
              hint: _localeService.get('email'),
              prefixIcon: Icons.email_outlined,
            ).copyWith(
              errorText: _emailError,
              errorStyle: const TextStyle(color: ThemeService.errorColor),
            ),
            onChanged: (_) {
              if (_emailError != null) {
                setState(() => _emailError = null);
              }
            },
            validator: (value) {
              if (!_usePhone) {
                if (value == null || value.isEmpty) {
                  return _localeService.get('please_enter_email');
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return _localeService.get('invalid_email');
                }
              }
              return null;
            },
          ),
        
        // Phone input
        if (_usePhone)
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: _themeService.textPrimaryColor),
            decoration: _buildInputDecoration(
              hint: '0912 345 678',
              prefixIcon: Icons.phone_outlined,
            ).copyWith(
              errorText: _phoneError,
              errorStyle: const TextStyle(color: ThemeService.errorColor),
              helperText: _localeService.get('phone_format_hint'),
              helperStyle: TextStyle(color: _themeService.textSecondaryColor),
            ),
            onChanged: (_) {
              if (_phoneError != null) {
                setState(() => _phoneError = null);
              }
            },
            validator: (value) {
              if (_usePhone) {
                if (value == null || value.isEmpty) {
                  return _localeService.get('please_enter_phone');
                }
                final cleaned = value.replaceAll(RegExp(r'[\s-]'), '');
                if (cleaned.length < 9) {
                  return _localeService.get('invalid_phone');
                }
              }
              return null;
            },
          ),
        
        const SizedBox(height: 24),
        _buildPrimaryButton(
          text: _localeService.get('send_code'),
          onPressed: _sendCode,
        ),
      ],
    );
  }

  Widget _buildCodeVerificationStep() {
    final displayValue = _usePhone 
        ? ApiService.formatPhoneForDisplay(ApiService.parsePhoneToE164(_phoneController.text.trim()))
        : _emailController.text;
    final displayIcon = _usePhone ? Icons.phone_outlined : Icons.email_outlined;
    
    return Column(
      children: [
        // Email/Phone display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(displayIcon, color: _themeService.textSecondaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayValue,
                  style: TextStyle(color: _themeService.textPrimaryColor),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _codeSent = false),
                child: Text(
                  _localeService.get('change'),
                  style: const TextStyle(color: ThemeService.accentColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Code input
        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: _buildInputDecoration(
            hint: '------',
          ).copyWith(
            counterText: '',
            errorText: _otpError,
            errorStyle: const TextStyle(color: ThemeService.errorColor),
          ),
          onChanged: (_) {
            // Clear error when user starts typing
            if (_otpError != null) {
              setState(() => _otpError = null);
            }
          },
        ),
        const SizedBox(height: 16),
        
        // Resend button
        TextButton(
          onPressed: _resendCountdown > 0 ? null : _sendCode,
          child: Text(
            _resendCountdown > 0
                ? '${_localeService.get('resend_code')} (${_resendCountdown}s)'
                : _localeService.get('resend_code'),
            style: TextStyle(
              color: _resendCountdown > 0 
                  ? _themeService.textSecondaryColor 
                  : ThemeService.accentColor,
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        _buildPrimaryButton(
          text: _localeService.get('verify'),
          onPressed: _verifyCode,
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      children: [
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscurePassword,
          style: TextStyle(color: _themeService.textPrimaryColor),
          decoration: _buildInputDecoration(
            hint: _localeService.get('new_password'),
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: _themeService.textSecondaryColor,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
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
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: TextStyle(color: _themeService.textPrimaryColor),
          decoration: _buildInputDecoration(
            hint: _localeService.get('confirm_new_password'),
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                color: _themeService.textSecondaryColor,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return _localeService.get('please_enter_password');
            }
            if (value != _newPasswordController.text) {
              return _localeService.get('passwords_not_match');
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        
        _buildPrimaryButton(
          text: _localeService.get('reset_password'),
          onPressed: _resetPassword,
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
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
      errorMaxLines: 3,
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeService.accentColor,
          disabledBackgroundColor: ThemeService.accentColor.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
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
}
