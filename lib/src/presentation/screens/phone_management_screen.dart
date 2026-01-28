import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/locale_service.dart';

class PhoneManagementScreen extends StatefulWidget {
  final String? currentPhone;
  
  const PhoneManagementScreen({super.key, this.currentPhone});

  @override
  State<PhoneManagementScreen> createState() => _PhoneManagementScreenState();
}

class _PhoneManagementScreenState extends State<PhoneManagementScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;

  String? _currentPhone;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentPhone = widget.currentPhone;
    _loadPhoneInfo();
  }

  Future<void> _loadPhoneInfo() async {
    final token = await _authService.getToken();
    if (token == null) return;

    try {
      final result = await _apiService.getAccountInfo(token);
      if (result['success'] == true && result['data'] != null) {
        setState(() {
          _currentPhone = result['data']['phoneNumber'];
        });
      }
    } catch (e) {
      print('Error loading phone info: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _themeService.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.get('phone_management'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current phone status
            _buildPhoneStatusCard(),
            
            const SizedBox(height: 24),
            
            // Actions
            if (_currentPhone != null && _currentPhone!.isNotEmpty)
              _buildUnlinkSection()
            else
              _buildLinkSection(),
            
            const SizedBox(height: 32),
            
            // Info section
            _buildInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStatusCard() {
    final hasPhone = _currentPhone != null && _currentPhone!.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _themeService.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: hasPhone 
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.phone_android,
              color: hasPhone ? Colors.green : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _localeService.get('phone_number'),
                  style: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPhone ? _formatPhone(_currentPhone!) : _localeService.get('not_linked'),
                  style: TextStyle(
                    color: _themeService.textPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasPhone) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _localeService.get('verified'),
                        style: const TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _localeService.get('link_phone_title'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _localeService.get('link_phone_desc'),
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _showLinkPhoneSheet,
            icon: const Icon(Icons.add),
            label: Text(_localeService.get('link_phone')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnlinkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Change phone button
        _buildActionTile(
          icon: Icons.swap_horiz,
          iconColor: Colors.blue,
          title: _localeService.get('change_phone'),
          subtitle: _localeService.get('change_phone_desc'),
          onTap: _showLinkPhoneSheet,
        ),
        
        const SizedBox(height: 12),
        
        // Unlink phone button
        _buildActionTile(
          icon: Icons.link_off,
          iconColor: Colors.red,
          title: _localeService.get('unlink_phone'),
          subtitle: _localeService.get('unlink_phone_desc'),
          onTap: _showUnlinkDialog,
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _themeService.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.red : _themeService.textPrimaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _themeService.textSecondaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                _localeService.get('phone_benefits_title'),
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(_localeService.get('phone_benefit_1')),
          _buildBenefitItem(_localeService.get('phone_benefit_2')),
          _buildBenefitItem(_localeService.get('phone_benefit_3')),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLinkPhoneSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LinkPhoneSheet(
        themeService: _themeService,
        localeService: _localeService,
        apiService: _apiService,
        authService: _authService,
        firebaseAuth: _firebaseAuth,
        onSuccess: (phone) {
          setState(() => _currentPhone = phone);
          _showSnackBar(_localeService.get('phone_linked_success'), Colors.green);
        },
        onError: (message) {
          _showSnackBar(message, Colors.red);
        },
      ),
    );
  }

  void _showUnlinkDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UnlinkPhoneSheet(
        themeService: _themeService,
        localeService: _localeService,
        apiService: _apiService,
        authService: _authService,
        currentPhone: _currentPhone!,
        onSuccess: () {
          setState(() => _currentPhone = null);
          _showSnackBar(_localeService.get('phone_unlinked_success'), Colors.green);
        },
        onError: (message) {
          _showSnackBar(message, Colors.red);
        },
      ),
    );
  }

  String _formatPhone(String phone) {
    if (phone.length >= 10) {
      return '${phone.substring(0, 4)} ${phone.substring(4, 7)} ${phone.substring(7)}';
    }
    return phone;
  }
}

// Link Phone Bottom Sheet
class _LinkPhoneSheet extends StatefulWidget {
  final ThemeService themeService;
  final LocaleService localeService;
  final ApiService apiService;
  final AuthService authService;
  final firebase_auth.FirebaseAuth firebaseAuth;
  final Function(String) onSuccess;
  final Function(String) onError;

  const _LinkPhoneSheet({
    required this.themeService,
    required this.localeService,
    required this.apiService,
    required this.authService,
    required this.firebaseAuth,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_LinkPhoneSheet> createState() => _LinkPhoneSheetState();
}

class _LinkPhoneSheetState extends State<_LinkPhoneSheet> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  String? _errorMessage;
  int? _resendToken;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    // Remove spaces and leading zeros
    phone = phone.replaceAll(' ', '').replaceAll('-', '');
    
    // Add country code if not present
    if (phone.startsWith('0')) {
      phone = '+84${phone.substring(1)}';
    } else if (!phone.startsWith('+')) {
      phone = '+84$phone';
    }
    
    return phone;
  }

  Future<void> _sendOtp() async {
    final phone = _formatPhoneNumber(_phoneController.text.trim());
    
    if (phone.length < 10) {
      setState(() => _errorMessage = widget.localeService.get('invalid_phone'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if phone is available
      final token = await widget.authService.getToken();
      if (token != null) {
        final checkResult = await widget.apiService.checkPhoneForLink(
          token: token,
          phone: phone,
        );
        
        if (checkResult['available'] != true) {
          setState(() {
            _isLoading = false;
            _errorMessage = checkResult['message'] ?? widget.localeService.get('phone_already_used');
          });
          return;
        }
      }

      // Send OTP via Firebase
      await widget.firebaseAuth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (firebase_auth.PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          await _linkWithCredential(credential);
        },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _errorMessage = e.message ?? widget.localeService.get('verification_failed');
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _codeSent = true;
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = widget.localeService.get('error');
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() => _errorMessage = widget.localeService.get('invalid_otp'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text,
      );
      
      await _linkWithCredential(credential);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = widget.localeService.get('invalid_otp');
      });
    }
  }

  Future<void> _linkWithCredential(firebase_auth.PhoneAuthCredential credential) async {
    try {
      // Sign in with Firebase to get the ID token
      final userCredential = await widget.firebaseAuth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      
      if (idToken == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = widget.localeService.get('verification_failed');
        });
        return;
      }

      // Link phone to account via backend
      final token = await widget.authService.getToken();
      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = widget.localeService.get('please_login_again');
        });
        return;
      }

      final result = await widget.apiService.linkPhone(
        token: token,
        firebaseIdToken: idToken,
      );

      if (result['success'] == true) {
        Navigator.pop(context);
        widget.onSuccess(result['phone'] ?? _formatPhoneNumber(_phoneController.text));
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['message'] ?? widget.localeService.get('error');
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = widget.localeService.get('error');
      });
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
      child: SingleChildScrollView(
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
                    color: widget.themeService.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.phone, color: Colors.teal, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _codeSent 
                          ? widget.localeService.get('enter_otp')
                          : widget.localeService.get('link_phone'),
                      style: TextStyle(
                        color: widget.themeService.textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (!_codeSent) ...[
                // Phone input
                Text(
                  widget.localeService.get('enter_phone_number'),
                  style: TextStyle(
                    color: widget.themeService.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: widget.themeService.textPrimaryColor),
                  decoration: InputDecoration(
                    hintText: '0912 345 678',
                    hintStyle: TextStyle(color: widget.themeService.textSecondaryColor),
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🇻🇳', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text('+84', style: TextStyle(color: widget.themeService.textPrimaryColor)),
                        ],
                      ),
                    ),
                    filled: true,
                    fillColor: widget.themeService.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.teal),
                    ),
                    errorText: _errorMessage,
                  ),
                ),
              ] else ...[
                // OTP input
                Text(
                  '${widget.localeService.get("otp_sent_to")} ${_formatPhoneNumber(_phoneController.text)}',
                  style: TextStyle(
                    color: widget.themeService.textSecondaryColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: TextStyle(
                    color: widget.themeService.textPrimaryColor,
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '• • • • • •',
                    hintStyle: TextStyle(
                      color: widget.themeService.textSecondaryColor,
                      fontSize: 24,
                      letterSpacing: 8,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: widget.themeService.inputBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.teal),
                    ),
                    errorText: _errorMessage,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    child: Text(
                      widget.localeService.get('resend_otp'),
                      style: const TextStyle(color: Colors.teal),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : (_codeSent ? _verifyOtp : _sendOtp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _codeSent 
                              ? widget.localeService.get('verify')
                              : widget.localeService.get('send_otp'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Unlink Phone Bottom Sheet
class _UnlinkPhoneSheet extends StatefulWidget {
  final ThemeService themeService;
  final LocaleService localeService;
  final ApiService apiService;
  final AuthService authService;
  final String currentPhone;
  final VoidCallback onSuccess;
  final Function(String) onError;

  const _UnlinkPhoneSheet({
    required this.themeService,
    required this.localeService,
    required this.apiService,
    required this.authService,
    required this.currentPhone,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_UnlinkPhoneSheet> createState() => _UnlinkPhoneSheetState();
}

class _UnlinkPhoneSheetState extends State<_UnlinkPhoneSheet> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlinkPhone() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = widget.localeService.get('please_enter_password'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await widget.authService.getToken();
      if (token == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = widget.localeService.get('please_login_again');
        });
        return;
      }

      final result = await widget.apiService.unlinkPhone(
        token: token,
        password: _passwordController.text,
      );

      if (result['success'] == true) {
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['message'] ?? widget.localeService.get('error');
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = widget.localeService.get('error');
      });
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
      child: SingleChildScrollView(
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
                    color: widget.themeService.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.link_off, color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.localeService.get('unlink_phone'),
                      style: TextStyle(
                        color: widget.themeService.textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Warning
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.localeService.get("unlink_phone_warning")} ${widget.currentPhone}',
                      style: TextStyle(
                        color: widget.themeService.textPrimaryColor,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.localeService.get('unlink_phone_note'),
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Password field
              Text(
                widget.localeService.get('enter_password_to_confirm'),
                style: TextStyle(
                  color: widget.themeService.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(color: widget.themeService.textPrimaryColor),
                decoration: InputDecoration(
                  hintText: widget.localeService.get('password'),
                  hintStyle: TextStyle(color: widget.themeService.textSecondaryColor),
                  filled: true,
                  fillColor: widget.themeService.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  errorText: _errorMessage,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: widget.themeService.textSecondaryColor,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        widget.localeService.get('cancel'),
                        style: TextStyle(color: widget.themeService.textSecondaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _unlinkPhone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              widget.localeService.get('unlink'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
