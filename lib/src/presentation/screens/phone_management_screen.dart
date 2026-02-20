import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/locale_service.dart';
import '../widgets/app_snackbar.dart';

class PhoneManagementScreen extends StatefulWidget {
  final String? currentPhone;
  
  const PhoneManagementScreen({super.key, this.currentPhone});

  @override
  State<PhoneManagementScreen> createState() => _PhoneManagementScreenState();
}

class _PhoneManagementScreenState extends State<PhoneManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;

  String? _currentPhone;
  bool _isLoading = true;
  bool _isPhoneVisible = false;
  bool _twoFactorEnabled = false;
  List<String> _twoFactorMethods = [];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentPhone = widget.currentPhone;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final token = await _authService.getToken();
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final results = await Future.wait([
        _apiService.getAccountInfo(token),
        _apiService.get2FASettings(token),
      ]);

      final accountResult = results[0] as Map<String, dynamic>;
      final twoFAResult = results[1] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          if (accountResult['success'] == true && accountResult['data'] != null) {
            _currentPhone = accountResult['data']['phoneNumber'];
          }
          _twoFactorEnabled = twoFAResult['enabled'] ?? false;
          _twoFactorMethods = List<String>.from(twoFAResult['methods'] ?? []);
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _fadeController.forward();
      }
    }
  }

  bool get _hasPhone => _currentPhone != null && _currentPhone!.isNotEmpty;

  String _maskPhone(String phone) {
    String normalized = phone;
    if (normalized.startsWith('0')) {
      normalized = '+84${normalized.substring(1)}';
    }
    if (!normalized.startsWith('+')) {
      normalized = '+84$normalized';
    }
    if (normalized.length >= 9) {
      final lastDigits = normalized.substring(normalized.length - 3);
      return '+84 *** *** $lastDigits';
    }
    return '****';
  }

  Future<bool> _verify2FAIfNeeded() async {
    if (!_twoFactorEnabled || _twoFactorMethods.isEmpty) return true;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TwoFactorVerifySheet(
        themeService: _themeService,
        localeService: _localeService,
        apiService: _apiService,
        authService: _authService,
        methods: _twoFactorMethods,
      ),
    );

    return result == true;
  }

  void _onLinkPhone() {
    _showLinkPhoneSheet(isChange: false);
  }

  Future<void> _onChangePhone() async {
    final verified = await _verify2FAIfNeeded();
    if (!verified) return;
    if (!mounted) return;
    _showLinkPhoneSheet(isChange: true);
  }

  Future<void> _onUnlinkPhone() async {
    final verified = await _verify2FAIfNeeded();
    if (!verified) return;
    if (!mounted) return;
    _showUnlinkSheet();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = _themeService.isLightMode;
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: _themeService.textPrimaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.get('phone_management'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _themeService.textSecondaryColor,
              ),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildPhoneCard(isLight),
                    const SizedBox(height: 24),
                    if (_hasPhone) ...[
                      _buildActionSection(isLight),
                    ] else ...[
                      _buildLinkPrompt(isLight),
                    ],
                    const SizedBox(height: 28),
                    _buildInfoSection(isLight),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPhoneCard(bool isLight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _themeService.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: _hasPhone
              ? Border.all(
                  color: Colors.teal.withValues(alpha: isLight ? 0.2 : 0.15),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: _hasPhone
                    ? LinearGradient(
                        colors: [
                          Colors.teal.withValues(alpha: 0.15),
                          Colors.teal.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : LinearGradient(
                        colors: [
                          Colors.grey.withValues(alpha: 0.15),
                          Colors.grey.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _hasPhone ? Icons.phone_android_rounded : Icons.phone_disabled_rounded,
                color: _hasPhone ? Colors.teal : _themeService.textSecondaryColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _hasPhone
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _hasPhone ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    size: 14,
                    color: _hasPhone ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _hasPhone
                        ? _localeService.get('verified')
                        : _localeService.get('not_linked'),
                    style: TextStyle(
                      color: _hasPhone ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_hasPhone)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isPhoneVisible
                        ? _formatPhone(_currentPhone!)
                        : _maskPhone(_currentPhone!),
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _isPhoneVisible = !_isPhoneVisible),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _themeService.inputBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _isPhoneVisible
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 18,
                        color: _themeService.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                _localeService.isVietnamese
                    ? 'Chưa có số điện thoại liên kết'
                    : 'No phone number linked',
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkPrompt(bool isLight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(
            _localeService.get('link_phone_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onLinkPhone,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _localeService.get('link_phone'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection(bool isLight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              _localeService.isVietnamese ? 'Tùy chọn' : 'Options',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _themeService.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildActionItem(
                  icon: Icons.swap_horiz_rounded,
                  iconColor: Colors.blue,
                  title: _localeService.get('change_phone'),
                  subtitle: _localeService.get('change_phone_desc'),
                  onTap: _onChangePhone,
                  showBorder: true,
                ),
                _buildActionItem(
                  icon: Icons.link_off_rounded,
                  iconColor: Colors.red,
                  title: _localeService.get('unlink_phone'),
                  subtitle: _localeService.get('unlink_phone_desc'),
                  onTap: _onUnlinkPhone,
                  isDestructive: true,
                ),
              ],
            ),
          ),
          if (_twoFactorEnabled) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(Icons.shield_rounded, size: 14, color: Colors.blue.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _localeService.isVietnamese
                          ? 'Các thao tác trên yêu cầu xác thực 2 yếu tố'
                          : 'These actions require two-factor authentication',
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool showBorder = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: showBorder
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : const BorderRadius.vertical(bottom: Radius.circular(16)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: showBorder
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _themeService.dividerColor,
                      width: 0.5,
                    ),
                  ),
                )
              : null,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDestructive
                            ? Colors.red
                            : _themeService.textPrimaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _themeService.textSecondaryColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(bool isLight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLight
              ? Colors.blue.withValues(alpha: 0.04)
              : Colors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.blue.withValues(alpha: isLight ? 0.12 : 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Text(
                  _localeService.get('phone_benefits_title'),
                  style: TextStyle(
                    color: _themeService.textPrimaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBenefitRow(Icons.flash_on_rounded, Colors.amber,
                _localeService.get('phone_benefit_1')),
            _buildBenefitRow(Icons.sms_rounded, Colors.green,
                _localeService.get('phone_benefit_2')),
            _buildBenefitRow(Icons.shield_rounded, Colors.blue,
                _localeService.get('phone_benefit_3')),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPhone(String phone) {
    String normalized = phone;
    if (normalized.startsWith('0')) {
      normalized = '+84${normalized.substring(1)}';
    }
    if (!normalized.startsWith('+')) {
      normalized = '+84$normalized';
    }
    if (normalized.length >= 10) {
      return '${normalized.substring(0, 4)} ${normalized.substring(4, 7)} ${normalized.substring(7)}';
    }
    return normalized;
  }

  void _showLinkPhoneSheet({bool isChange = false}) {
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
        isChange: isChange,
        onSuccess: (phone) {
          setState(() => _currentPhone = phone);
          _authService.updatePhoneNumber(phone);
          AppSnackBar.showSuccess(context, _localeService.get('phone_linked_success'));
        },
      ),
    );
  }

  void _showUnlinkSheet() {
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
          _authService.updatePhoneNumber(null);
          AppSnackBar.showSuccess(context, _localeService.get('unlink_phone_success'));
        },
      ),
    );
  }
}

// 2FA Verification Sheet
class _TwoFactorVerifySheet extends StatefulWidget {
  final ThemeService themeService;
  final LocaleService localeService;
  final ApiService apiService;
  final AuthService authService;
  final List<String> methods;

  const _TwoFactorVerifySheet({
    required this.themeService,
    required this.localeService,
    required this.apiService,
    required this.authService,
    required this.methods,
  });

  @override
  State<_TwoFactorVerifySheet> createState() => _TwoFactorVerifySheetState();
}

class _TwoFactorVerifySheetState extends State<_TwoFactorVerifySheet> {
  final _otpController = TextEditingController();
  late String _selectedMethod;
  bool _isLoading = false;
  bool _isSending = false;
  bool _otpSent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.methods.contains('totp')) {
      _selectedMethod = 'totp';
      _otpSent = true;
    } else if (widget.methods.contains('email')) {
      _selectedMethod = 'email';
    } else {
      _selectedMethod = widget.methods.first;
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_selectedMethod == 'totp') {
      setState(() => _otpSent = true);
      return;
    }
    setState(() { _isSending = true; _error = null; });
    try {
      final token = await widget.authService.getToken();
      if (token == null) return;
      final result = await widget.apiService.send2FASettingsOtp(token, _selectedMethod);
      if (mounted) {
        setState(() {
          _isSending = false;
          if (result['success'] == true) { _otpSent = true; }
          else { _error = result['message'] ?? widget.localeService.get('error'); }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isSending = false; _error = widget.localeService.get('error'); });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) {
      setState(() => _error = widget.localeService.get('invalid_otp'));
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await widget.authService.getToken();
      if (token == null) return;
      final result = await widget.apiService.verify2FASettings(
        token,
        _otpController.text,
        _selectedMethod,
        true,
        widget.methods,
      );
      if (mounted) {
        if (result['success'] == true) {
          Navigator.pop(context, true);
        } else {
          setState(() { _isLoading = false; _error = result['message'] ?? widget.localeService.get('2fa_invalid_otp'); });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = widget.localeService.get('error'); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: widget.themeService.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: widget.themeService.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_rounded, color: Colors.blue, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.localeService.isVietnamese
                                ? 'Xác thực 2 yếu tố'
                                : 'Two-Factor Verification',
                            style: TextStyle(
                              color: widget.themeService.textPrimaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.localeService.isVietnamese
                                ? 'Xác minh danh tính để tiếp tục'
                                : 'Verify your identity to continue',
                            style: TextStyle(
                              color: widget.themeService.textSecondaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!_otpSent && _selectedMethod != 'totp') ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isSending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              widget.localeService.isVietnamese ? 'Gửi mã xác thực' : 'Send verification code',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                    ),
                  ),
                ] else ...[
                  Text(
                    _selectedMethod == 'totp'
                        ? (widget.localeService.isVietnamese ? 'Nhập mã từ ứng dụng xác thực' : 'Enter code from authenticator app')
                        : (widget.localeService.isVietnamese ? 'Nhập mã xác thực đã gửi' : 'Enter the verification code sent'),
                    style: TextStyle(color: widget.themeService.textSecondaryColor, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.themeService.textPrimaryColor,
                      fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8,
                    ),
                    decoration: InputDecoration(
                      hintText: '• • • • • •',
                      hintStyle: TextStyle(color: widget.themeService.textSecondaryColor, fontSize: 24, letterSpacing: 8),
                      counterText: '',
                      filled: true,
                      fillColor: widget.themeService.inputBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue)),
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(widget.localeService.get('cancel'),
                              style: TextStyle(color: widget.themeService.textSecondaryColor)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(widget.localeService.get('verify'),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
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
  final bool isChange;

  const _LinkPhoneSheet({
    required this.themeService,
    required this.localeService,
    required this.apiService,
    required this.authService,
    required this.firebaseAuth,
    required this.onSuccess,
    this.isChange = false,
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
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: widget.themeService.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.phone_android_rounded, color: Colors.teal, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _codeSent
                                ? widget.localeService.get('enter_otp')
                                : widget.isChange
                                    ? (widget.localeService.isVietnamese ? 'Thay đổi số điện thoại' : 'Change Phone Number')
                                    : widget.localeService.get('link_phone'),
                            style: TextStyle(
                              color: widget.themeService.textPrimaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _codeSent
                                ? '${widget.localeService.get("otp_sent_to")} ${_formatPhoneNumber(_phoneController.text)}'
                                : widget.localeService.get('enter_phone_number'),
                            style: TextStyle(
                              color: widget.themeService.textSecondaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!_codeSent) ...[
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      color: widget.themeService.textPrimaryColor,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: '0912 345 678',
                      hintStyle: TextStyle(color: widget.themeService.textSecondaryColor),
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🇻🇳', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text('+84',
                                style: TextStyle(
                                    color: widget.themeService.textPrimaryColor,
                                    fontWeight: FontWeight.w600)),
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
                        borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                      ),
                      errorText: _errorMessage,
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.themeService.textPrimaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                    ),
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
                        borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                      ),
                      errorText: _errorMessage,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _sendOtp,
                      child: Text(
                        widget.localeService.get('resend_otp'),
                        style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          widget.localeService.get('cancel'),
                          style: TextStyle(
                              color: widget.themeService.textSecondaryColor,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (_codeSent ? _verifyOtp : _sendOtp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _codeSent
                                    ? widget.localeService.get('verify')
                                    : widget.localeService.get('send_otp'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
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

  const _UnlinkPhoneSheet({
    required this.themeService,
    required this.localeService,
    required this.apiService,
    required this.authService,
    required this.currentPhone,
    required this.onSuccess,
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
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: widget.themeService.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.link_off_rounded, color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.localeService.get('unlink_phone'),
                            style: TextStyle(
                              color: widget.themeService.textPrimaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.currentPhone,
                            style: TextStyle(
                              color: widget.themeService.textSecondaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.localeService.get('unlink_phone_warning'),
                              style: TextStyle(
                                color: widget.themeService.textPrimaryColor,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.localeService.get('unlink_phone_note'),
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.localeService.get('enter_password_to_confirm'),
                  style: TextStyle(
                    color: widget.themeService.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
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
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    ),
                    errorText: _errorMessage,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: widget.themeService.textSecondaryColor,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          widget.localeService.get('cancel'),
                          style: TextStyle(
                              color: widget.themeService.textSecondaryColor,
                              fontWeight: FontWeight.w500),
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
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                widget.localeService.get('unlink'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
