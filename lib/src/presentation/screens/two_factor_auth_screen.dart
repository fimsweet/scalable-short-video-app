import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/firebase_phone_auth_service.dart';

/// Full-screen 2FA management screen (TikTok-style).
/// - When 2FA is OFF: shows method checkboxes + "Enable" button
/// - When 2FA is ON: shows methods with status, tap to manage each
class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen> {
  final _auth = AuthService();
  final _theme = ThemeService();
  final _api = ApiService();
  final _locale = LocaleService();

  bool _isLoading = true;
  bool _twoFactorEnabled = false;
  List<String> _methods = [];

  // User info
  bool _hasEmail = false;
  bool _hasPhone = false;
  String? _userEmail;
  String? _userPhone;

  // Enable flow state
  bool _isEnableFlow = false;
  List<String> _methodsToSetup = [];
  int _setupIndex = 0;

  // TOTP setup state
  int _totpStep = 0; // 0=QR, 1=enter code
  bool _totpLoading = true;
  String? _totpQrUrl;
  String? _totpSecret;
  String _totpCode = '';
  bool _totpCopied = false;
  bool _totpVerifying = false;
  String? _totpError;

  // SMS setup state
  bool _smsSending = false;
  bool _smsSent = false;
  String _smsCode = '';
  bool _smsVerifying = false;
  String? _smsError;

  // Email setup state
  bool _emailSending = false;
  bool _emailSent = false;
  String _emailCode = '';
  bool _emailVerifying = false;
  String? _emailError;

  // Disable/verify flow state
  bool _isVerifyFlow = false;
  String? _verifyForMethod; // which method we're verifying to toggle
  bool _verifyToEnable = false; // true = enable new method, false = disable existing
  String? _verifyUsingMethod; // which active method we use to verify identity
  bool _verifySendingOtp = false;
  bool _verifyOtpSent = false;
  String _verifyCode = '';
  bool _verifyingOtp = false;
  String? _verifyError;

  // Selection state when 2FA is off
  final Set<String> _selectedMethods = {};

  @override
  void initState() {
    super.initState();
    _theme.addListener(_refresh);
    _locale.addListener(_refresh);
    _loadData();
  }

  @override
  void dispose() {
    _theme.removeListener(_refresh);
    _locale.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    final token = await _auth.getToken();
    if (token == null) return;

    final result = await _api.get2FASettings(token);
    final user = _auth.user;

    if (mounted) {
      setState(() {
        _twoFactorEnabled = result['enabled'] ?? false;
        _methods = List<String>.from(result['methods'] ?? []);
        _hasEmail = user != null &&
            user['email'] != null &&
            !user['email'].toString().endsWith('@phone.user');
        _hasPhone = user != null && user['phoneNumber'] != null;
        _userEmail = _hasEmail ? user!['email'] as String : null;
        _userPhone = _hasPhone ? user!['phoneNumber'] as String : null;
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.isLightMode
          ? const Color(0xFFF5F5F5)
          : _theme.backgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isEnableFlow
              ? _buildEnableFlow()
              : _isVerifyFlow
                  ? _buildVerifyFlow()
                  : _buildOverview(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isSetup = _isEnableFlow || _isVerifyFlow;
    return AppBar(
      backgroundColor: _theme.isLightMode
          ? Colors.white
          : _theme.backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          isSetup ? Icons.close : Icons.chevron_left,
          color: _theme.iconColor,
          size: 28,
        ),
        onPressed: () {
          if (_isEnableFlow) {
            setState(() => _resetEnableFlow());
          } else if (_isVerifyFlow) {
            setState(() => _resetVerifyFlow());
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: isSetup
          ? null
          : null, // No title — TikTok style uses header in body
      centerTitle: true,
    );
  }

  // ========== OVERVIEW ==========

  Widget _buildOverview() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                Text(
                  _twoFactorEnabled
                      ? _locale.get('2fa_screen_title_on')
                      : _locale.get('2fa_screen_title_off'),
                  style: TextStyle(
                    color: _theme.textPrimaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _locale.get('2fa_screen_subtitle'),
                  style: TextStyle(
                    color: _theme.textSecondaryColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!_twoFactorEnabled) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      _locale.get('2fa_learn_more'),
                      style: TextStyle(
                        color: ThemeService.accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),

          if (_twoFactorEnabled) _buildMethodsListOn() else _buildMethodsListOff(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ---------- 2FA OFF: Checkbox selection ----------

  Widget _buildMethodsListOff() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _locale.get('2fa_choose_methods'),
            style: TextStyle(
              color: _theme.textSecondaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Method cards
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _theme.isLightMode ? Colors.white : _theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _theme.isLightMode
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))]
                : null,
          ),
          child: Column(
            children: [
              _buildMethodCheckbox(
                icon: Icons.smartphone_outlined,
                title: _locale.get('2fa_method_phone'),
                subtitle: _hasPhone
                    ? _locale.get('sms_2fa_desc')
                    : _locale.get('link_phone_first'),
                enabled: _hasPhone,
                checked: _selectedMethods.contains('sms'),
                onChanged: _hasPhone
                    ? (v) => setState(() {
                          if (v) _selectedMethods.add('sms');
                          else _selectedMethods.remove('sms');
                        })
                    : null,
                showDivider: true,
              ),
              _buildMethodCheckbox(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: _hasEmail
                    ? '${_locale.get('email_2fa_desc')}\n${_maskEmail(_userEmail ?? '')}'
                    : _locale.get('link_email_first'),
                enabled: _hasEmail,
                checked: _selectedMethods.contains('email'),
                onChanged: _hasEmail
                    ? (v) => setState(() {
                          if (v) _selectedMethods.add('email');
                          else _selectedMethods.remove('email');
                        })
                    : null,
                showDivider: true,
              ),
              _buildMethodCheckbox(
                icon: Icons.shield_outlined,
                title: _locale.get('authenticator_app'),
                subtitle: _locale.get('authenticator_app_desc'),
                enabled: true,
                checked: _selectedMethods.contains('totp'),
                onChanged: (v) => setState(() {
                  if (v) _selectedMethods.add('totp');
                  else _selectedMethods.remove('totp');
                }),
                showDivider: false,
              ),
            ],
          ),
        ),

        // Enable button — TikTok-style
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
          child: AnimatedOpacity(
            opacity: _selectedMethods.isEmpty ? 0.45 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _selectedMethods.isEmpty ? null : _startEnableFlow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeService.accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ThemeService.accentColor,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _locale.get('2fa_btn_enable'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodCheckbox({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required bool checked,
    required ValueChanged<bool>? onChanged,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: enabled ? () => onChanged?.call(!checked) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: enabled
                      ? _theme.textSecondaryColor
                      : _theme.textSecondaryColor.withOpacity(0.4),
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: enabled
                              ? _theme.textPrimaryColor
                              : _theme.textSecondaryColor.withOpacity(0.5),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: enabled
                              ? _theme.textSecondaryColor
                              : _theme.textSecondaryColor.withOpacity(0.4),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildCheckbox(checked, enabled, onChanged),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 54,
            color: _theme.dividerColor,
          ),
      ],
    );
  }

  Widget _buildCheckbox(bool checked, bool enabled, ValueChanged<bool>? onChanged) {
    return GestureDetector(
      onTap: enabled ? () => onChanged?.call(!checked) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: checked
              ? ThemeService.accentColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: checked
                ? ThemeService.accentColor
                : enabled
                    ? _theme.textSecondaryColor.withOpacity(0.4)
                    : _theme.textSecondaryColor.withOpacity(0.2),
            width: checked ? 0 : 2,
          ),
        ),
        child: AnimatedScale(
          scale: checked ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: const Icon(Icons.check, size: 18, color: Colors.white),
        ),
      ),
    );
  }

  // ---------- 2FA ON: Method status list ----------

  Widget _buildMethodsListOn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _locale.get('2fa_verification_methods'),
            style: TextStyle(
              color: _theme.textSecondaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _theme.isLightMode ? Colors.white : _theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _theme.isLightMode
                ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))]
                : null,
          ),
          child: Column(
            children: [
              // SMS
              _buildMethodStatusTile(
                icon: Icons.smartphone_outlined,
                title: _locale.get('2fa_method_phone'),
                subtitle: _methods.contains('sms') && _userPhone != null
                    ? '${_locale.get('sms_2fa_desc')} ${_maskPhone(_userPhone!)}.'
                    : _hasPhone
                        ? _locale.get('sms_2fa_desc')
                        : _locale.get('link_phone_first'),
                method: 'sms',
                isActive: _methods.contains('sms'),
                canToggle: _hasPhone,
                showDivider: true,
              ),
              // Email
              _buildMethodStatusTile(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: _methods.contains('email') && _userEmail != null
                    ? '${_locale.get('email_2fa_desc')} ${_maskEmail(_userEmail!)}.'
                    : _hasEmail
                        ? _locale.get('email_2fa_desc')
                        : _locale.get('link_email_first'),
                method: 'email',
                isActive: _methods.contains('email'),
                canToggle: _hasEmail,
                showDivider: true,
              ),
              // TOTP
              _buildMethodStatusTile(
                icon: Icons.shield_outlined,
                title: _locale.get('authenticator_app'),
                subtitle: _methods.contains('totp')
                    ? _locale.get('2fa_totp_active_desc')
                    : _locale.get('authenticator_app_desc'),
                method: 'totp',
                isActive: _methods.contains('totp'),
                canToggle: true,
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMethodStatusTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String method,
    required bool isActive,
    required bool canToggle,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: canToggle ? () => _onMethodTap(method, isActive) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: canToggle
                      ? _theme.textSecondaryColor
                      : _theme.textSecondaryColor.withOpacity(0.4),
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: canToggle
                              ? _theme.textPrimaryColor
                              : _theme.textSecondaryColor.withOpacity(0.5),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: canToggle
                              ? _theme.textSecondaryColor
                              : _theme.textSecondaryColor.withOpacity(0.4),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      isActive ? _locale.get('2fa_on') : _locale.get('2fa_off'),
                      style: TextStyle(
                        color: isActive
                            ? _theme.textSecondaryColor
                            : _theme.textSecondaryColor.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                    if (canToggle) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        color: _theme.textSecondaryColor.withOpacity(0.5),
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 54, color: _theme.dividerColor),
      ],
    );
  }

  // ========== ENABLE FLOW (2FA OFF → ON) ==========

  void _startEnableFlow() {
    // Order: totp first, then sms, then email
    final order = <String>[];
    if (_selectedMethods.contains('totp')) order.add('totp');
    if (_selectedMethods.contains('sms')) order.add('sms');
    if (_selectedMethods.contains('email')) order.add('email');

    setState(() {
      _isEnableFlow = true;
      _methodsToSetup = order;
      _setupIndex = 0;
      _initSetupForMethod(order[0]);
    });
  }

  void _initSetupForMethod(String method) {
    if (method == 'totp') {
      _totpStep = 0;
      _totpLoading = true;
      _totpQrUrl = null;
      _totpSecret = null;
      _totpCode = '';
      _totpCopied = false;
      _totpVerifying = false;
      _totpError = null;
      _fetchTotpSetup();
    } else if (method == 'sms') {
      _smsSending = true;
      _smsSent = false;
      _smsCode = '';
      _smsVerifying = false;
      _smsError = null;
      _sendSmsForSetup();
    } else if (method == 'email') {
      _emailSending = true;
      _emailSent = false;
      _emailCode = '';
      _emailVerifying = false;
      _emailError = null;
      _sendEmailForSetup();
    }
  }

  Widget _buildEnableFlow() {
    final method = _methodsToSetup[_setupIndex];
    final totalSteps = _methodsToSetup.length;

    return Column(
      children: [
        // Progress bar
        _buildProgressBar(_setupIndex, totalSteps),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: method == 'totp'
                ? _buildTotpSetup()
                : method == 'sms'
                    ? _buildSmsSetup()
                    : _buildEmailSetup(),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(int current, int total) {
    return Container(
      height: 3,
      color: _theme.isLightMode
          ? Colors.grey[200]
          : Colors.grey[800],
      child: Row(
        children: List.generate(total, (i) {
          return Expanded(
            child: Container(
              color: i <= current
                  ? ThemeService.accentColor
                  : Colors.transparent,
            ),
          );
        }),
      ),
    );
  }

  // ---------- TOTP Setup ----------

  Future<void> _fetchTotpSetup() async {
    final token = await _auth.getToken();
    if (token == null) return;

    final result = await _api.setupTotp(token);
    if (mounted) {
      setState(() {
        _totpLoading = false;
        if (result['success'] == true) {
          _totpQrUrl = result['qrCodeUrl'] as String?;
          _totpSecret = result['secret'] as String?;
        } else {
          _totpError = result['message'] ?? _locale.get('totp_setup_failed');
        }
      });
    }
  }

  Widget _buildTotpSetup() {
    if (_totpLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_totpError != null && _totpStep == 0 && _totpQrUrl == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_totpError!, style: TextStyle(color: Colors.red[400], fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (_totpStep == 0) return _buildTotpQrStep();
    return _buildTotpCodeStep();
  }

  Widget _buildTotpQrStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Text(
          _locale.get('authenticator_app'),
          style: TextStyle(
            color: _theme.textPrimaryColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),

        // QR code
        if (_totpQrUrl != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Builder(builder: (context) {
              final base64Str = _totpQrUrl!.split(',').last;
              final bytes = base64Decode(base64Str);
              return Image.memory(bytes, width: 180, height: 180, fit: BoxFit.contain);
            }),
          ),
        const SizedBox(height: 16),

        // Secret
        if (_totpSecret != null) ...[
          Text(
            _totpSecret!,
            style: TextStyle(
              color: _theme.textPrimaryColor,
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _totpSecret!));
              setState(() => _totpCopied = true);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() => _totpCopied = false);
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: _theme.dividerColor),
              ),
            ),
            child: Text(
              _totpCopied
                  ? _locale.get('totp_copied_secret')
                  : _locale.get('2fa_copy_key'),
              style: TextStyle(
                color: _totpCopied ? const Color(0xFF4CAF50) : _theme.textPrimaryColor,
                fontSize: 14,
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Instructions
        _buildInstructionList([
          _locale.get('2fa_totp_step1'),
          _locale.get('2fa_totp_step2'),
          _locale.get('2fa_totp_step3'),
          _locale.get('2fa_totp_step4'),
        ]),

        const SizedBox(height: 32),

        // Next button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => setState(() => _totpStep = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeService.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              elevation: 0,
            ),
            child: Text(
              _locale.get('2fa_btn_next'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTotpCodeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          _locale.get('authenticator_app'),
          style: TextStyle(
            color: _theme.textPrimaryColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _locale.get('totp_enter_code'),
          style: TextStyle(color: _theme.textSecondaryColor, fontSize: 14),
        ),
        const SizedBox(height: 24),

        _buildOtpInput(
          value: _totpCode,
          error: _totpError,
          onChanged: (v) => setState(() {
            _totpCode = v;
            _totpError = null;
          }),
        ),

        const SizedBox(height: 32),

        AnimatedOpacity(
          opacity: _totpCode.length != 6 ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _totpVerifying || _totpCode.length != 6
                  ? null
                  : _verifyTotpSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeService.accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ThemeService.accentColor,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
              child: _totpVerifying
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(
                      _locale.get('2fa_btn_next'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _verifyTotpSetup() async {
    setState(() => _totpVerifying = true);
    final token = await _auth.getToken();
    if (token == null) return;

    final result = await _api.verifyTotpSetup(token, _totpCode, _totpSecret!);
    if (!mounted) return;

    if (result['success'] == true) {
      final methods = (result['methods'] as List?)?.cast<String>() ?? [..._methods, 'totp'];
      _methods = methods;
      _twoFactorEnabled = true;
      _advanceSetup();
    } else {
      setState(() {
        _totpVerifying = false;
        _totpError = result['message'] ?? _locale.get('totp_invalid_code');
      });
    }
  }

  // ---------- SMS Setup ----------

  Future<void> _sendSmsForSetup() async {
    final token = await _auth.getToken();
    if (token == null) return;

    final result = await _api.send2FASettingsOtp(token, 'sms');
    if (!mounted) return;

    if (result['success'] == true && result['phoneNumber'] != null) {
      final phoneAuth = FirebasePhoneAuthService();
      final sent = await phoneAuth.sendOtp(result['phoneNumber']);
      if (mounted) {
        setState(() {
          _smsSending = false;
          _smsSent = sent;
          if (!sent) {
            _smsError = phoneAuth.errorMessage ??
                (_locale.isVietnamese
                    ? 'Không thể gửi SMS. Vui lòng thử lại.'
                    : 'Failed to send SMS. Please try again.');
          }
        });
      }
    } else {
      setState(() {
        _smsSending = false;
        _smsError = result['message'] ?? _locale.get('error');
      });
    }
  }

  Widget _buildSmsSetup() {
    if (_smsSending) {
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _locale.isVietnamese
                    ? 'Đang gửi mã xác thực SMS...'
                    : 'Sending SMS verification code...',
                style: TextStyle(color: _theme.textSecondaryColor),
              ),
            ],
          ),
        ),
      );
    }

    if (!_smsSent) {
      return _buildSendError(
        error: _smsError,
        onRetry: () => setState(() {
          _smsSending = true;
          _smsError = null;
          _sendSmsForSetup();
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          _locale.get('2fa_method_phone'),
          style: TextStyle(
            color: _theme.textPrimaryColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _locale.isVietnamese
              ? 'Nhập mã OTP đã gửi đến ${_maskPhone(_userPhone ?? '')}'
              : 'Enter OTP sent to ${_maskPhone(_userPhone ?? '')}',
          style: TextStyle(color: _theme.textSecondaryColor, fontSize: 14),
        ),
        const SizedBox(height: 24),

        _buildOtpInput(
          value: _smsCode,
          error: _smsError,
          onChanged: (v) => setState(() {
            _smsCode = v;
            _smsError = null;
          }),
        ),

        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _smsSending ? null : () {
              setState(() {
                _smsSending = true;
                _smsError = null;
              });
              _sendSmsForSetup();
            },
            child: Text(
              _locale.get('resend_otp'),
              style: TextStyle(color: ThemeService.accentColor, fontSize: 14),
            ),
          ),
        ),

        const SizedBox(height: 24),

        AnimatedOpacity(
          opacity: _smsCode.length != 6 ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _smsVerifying || _smsCode.length != 6
                  ? null
                  : _verifySmsSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeService.accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ThemeService.accentColor,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
              child: _smsVerifying
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(
                      _locale.get('2fa_btn_next'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _verifySmsSetup() async {
    setState(() => _smsVerifying = true);

    final phoneAuth = FirebasePhoneAuthService();
    final idToken = await phoneAuth.verifyOtp(_smsCode);
    if (idToken == null) {
      if (mounted) {
        setState(() {
          _smsVerifying = false;
          _smsError = phoneAuth.errorMessage ?? _locale.get('otp_incorrect');
        });
      }
      return;
    }

    final token = await _auth.getToken();
    if (token == null) return;

    final newMethods = [..._methods];
    if (!newMethods.contains('sms')) newMethods.add('sms');

    final result = await _api.verify2FASettings(token, 'firebase_verified', 'sms', true, newMethods);
    if (!mounted) return;

    if (result['success'] == true) {
      _methods = newMethods;
      _twoFactorEnabled = true;
      phoneAuth.reset();
      _advanceSetup();
    } else {
      setState(() {
        _smsVerifying = false;
        _smsError = result['message'] ?? _locale.get('error');
      });
    }
  }

  // ---------- Email Setup ----------

  Future<void> _sendEmailForSetup() async {
    final token = await _auth.getToken();
    if (token == null) return;

    final result = await _api.send2FASettingsOtp(token, 'email');
    if (mounted) {
      setState(() {
        _emailSending = false;
        if (result['success'] == true) {
          _emailSent = true;
        } else {
          _emailError = result['message'] ?? _locale.get('error');
        }
      });
    }
  }

  Widget _buildEmailSetup() {
    if (_emailSending) {
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _locale.isVietnamese
                    ? 'Đang gửi mã xác thực email...'
                    : 'Sending email verification code...',
                style: TextStyle(color: _theme.textSecondaryColor),
              ),
            ],
          ),
        ),
      );
    }

    if (!_emailSent) {
      return _buildSendError(
        error: _emailError,
        onRetry: () => setState(() {
          _emailSending = true;
          _emailError = null;
          _sendEmailForSetup();
        }),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Email',
          style: TextStyle(
            color: _theme.textPrimaryColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _locale.isVietnamese
              ? 'Nhập mã OTP đã gửi đến ${_maskEmail(_userEmail ?? '')}'
              : 'Enter OTP sent to ${_maskEmail(_userEmail ?? '')}',
          style: TextStyle(color: _theme.textSecondaryColor, fontSize: 14),
        ),
        const SizedBox(height: 24),

        _buildOtpInput(
          value: _emailCode,
          error: _emailError,
          onChanged: (v) => setState(() {
            _emailCode = v;
            _emailError = null;
          }),
        ),

        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _emailSending ? null : () {
              setState(() {
                _emailSending = true;
                _emailError = null;
              });
              _sendEmailForSetup();
            },
            child: Text(
              _locale.get('resend_otp'),
              style: TextStyle(color: ThemeService.accentColor, fontSize: 14),
            ),
          ),
        ),

        const SizedBox(height: 24),

        AnimatedOpacity(
          opacity: _emailCode.length != 6 ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _emailVerifying || _emailCode.length != 6
                  ? null
                  : _verifyEmailSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeService.accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ThemeService.accentColor,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
              child: _emailVerifying
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(
                      _locale.get('2fa_btn_next'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _verifyEmailSetup() async {
    setState(() => _emailVerifying = true);
    final token = await _auth.getToken();
    if (token == null) return;

    final newMethods = [..._methods];
    if (!newMethods.contains('email')) newMethods.add('email');

    final result = await _api.verify2FASettings(token, _emailCode, 'email', true, newMethods);
    if (!mounted) return;

    if (result['success'] == true) {
      _methods = newMethods;
      _twoFactorEnabled = true;
      _advanceSetup();
    } else {
      setState(() {
        _emailVerifying = false;
        _emailError = result['message'] ?? _locale.get('otp_incorrect');
      });
    }
  }

  // ---------- Setup flow navigation ----------

  void _advanceSetup() {
    if (_setupIndex + 1 < _methodsToSetup.length) {
      setState(() {
        _setupIndex++;
        _initSetupForMethod(_methodsToSetup[_setupIndex]);
      });
    } else {
      // All methods set up — complete
      setState(() {
        _resetEnableFlow();
      });
      _showSnackBar(_locale.get('2fa_enabled_success'), const Color(0xFF4CAF50));
    }
  }

  void _resetEnableFlow() {
    _isEnableFlow = false;
    _methodsToSetup = [];
    _setupIndex = 0;
    _selectedMethods.clear();
    _totpCode = '';
    _smsCode = '';
    _emailCode = '';
  }

  // ========== VERIFY FLOW (toggle individual method when 2FA ON) ==========

  void _onMethodTap(String method, bool isCurrentlyActive) {
    if (isCurrentlyActive) {
      // Disable this method — verify using THE SAME method
      final otherMethods = _methods.where((m) => m != method).toList();
      if (otherMethods.isEmpty) {
        // Last method — disabling will turn off 2FA entirely
        _showDisableLastMethodDialog(method);
        return;
      }
      // Verify with the method being disabled (e.g., disable TOTP → enter TOTP code)
      _startVerifyFlow(method, false, method);
    } else {
      // Enable this method
      if (method == 'totp') {
        // TOTP needs special setup flow with QR code
        setState(() {
          _isEnableFlow = true;
          _methodsToSetup = ['totp'];
          _setupIndex = 0;
          _initSetupForMethod('totp');
        });
      } else {
        // SMS or Email — verify the method itself to enable it
        setState(() {
          _isEnableFlow = true;
          _methodsToSetup = [method];
          _setupIndex = 0;
          _initSetupForMethod(method);
        });
      }
    }
  }

  void _showDisableLastMethodDialog(String method) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
              const SizedBox(height: 12),
              Text(
                _locale.get('2fa_disable_last_title'),
                style: TextStyle(
                  color: _theme.textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _locale.get('2fa_disable_last_desc'),
                style: TextStyle(color: _theme.textSecondaryColor, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        _locale.get('cancel'),
                        style: TextStyle(color: _theme.textSecondaryColor, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _startVerifyFlow(method, false, method);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        elevation: 0,
                      ),
                      child: Text(
                        _locale.get('disable_2fa'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  void _startVerifyFlow(String forMethod, bool enable, String usingMethod) {
    setState(() {
      _isVerifyFlow = true;
      _verifyForMethod = forMethod;
      _verifyToEnable = enable;
      _verifyUsingMethod = usingMethod;
      _verifySendingOtp = usingMethod != 'totp';
      _verifyOtpSent = usingMethod == 'totp';
      _verifyCode = '';
      _verifyingOtp = false;
      _verifyError = null;
    });

    if (usingMethod == 'email') _sendVerifyOtp('email');
    else if (usingMethod == 'sms') _sendVerifySms();
  }

  Future<void> _sendVerifyOtp(String method) async {
    final token = await _auth.getToken();
    if (token == null) return;

    final result = await _api.send2FASettingsOtp(token, method);
    if (mounted) {
      setState(() {
        _verifySendingOtp = false;
        if (result['success'] == true) {
          _verifyOtpSent = true;
        } else {
          _verifyError = result['message'] ?? _locale.get('error');
        }
      });
    }
  }

  Future<void> _sendVerifySms() async {
    final token = await _auth.getToken();
    if (token == null) return;

    final result = await _api.send2FASettingsOtp(token, 'sms');
    if (!mounted) return;

    if (result['success'] == true && result['phoneNumber'] != null) {
      final phoneAuth = FirebasePhoneAuthService();
      final sent = await phoneAuth.sendOtp(result['phoneNumber']);
      if (mounted) {
        setState(() {
          _verifySendingOtp = false;
          _verifyOtpSent = sent;
          if (!sent) {
            _verifyError = phoneAuth.errorMessage ?? _locale.get('error');
          }
        });
      }
    } else {
      setState(() {
        _verifySendingOtp = false;
        _verifyError = result['message'] ?? _locale.get('error');
      });
    }
  }

  Widget _buildVerifyFlow() {
    final method = _verifyUsingMethod ?? 'email';

    return Column(
      children: [
        _buildProgressBar(0, 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _verifySendingOtp
                ? Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _locale.isVietnamese
                                ? 'Đang gửi mã xác thực...'
                                : 'Sending verification code...',
                            style: TextStyle(color: _theme.textSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                  )
                : !_verifyOtpSent
                    ? _buildSendError(
                        error: _verifyError,
                        onRetry: () {
                          setState(() {
                            _verifySendingOtp = true;
                            _verifyError = null;
                          });
                          if (method == 'sms') _sendVerifySms();
                          else _sendVerifyOtp(method);
                        },
                      )
                    : _buildVerifyOtpEntry(method),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyOtpEntry(String method) {
    final title = method == 'totp'
        ? _locale.get('authenticator_app')
        : method == 'sms'
            ? _locale.get('2fa_method_phone')
            : 'Email';
    final subtitle = method == 'totp'
        ? _locale.get('totp_enter_code')
        : method == 'sms'
            ? (_locale.isVietnamese
                ? 'Nhập mã OTP đã gửi đến ${_maskPhone(_userPhone ?? '')}'
                : 'Enter OTP sent to ${_maskPhone(_userPhone ?? '')}')
            : (_locale.isVietnamese
                ? 'Nhập mã OTP đã gửi đến ${_maskEmail(_userEmail ?? '')}'
                : 'Enter OTP sent to ${_maskEmail(_userEmail ?? '')}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          title,
          style: TextStyle(
            color: _theme.textPrimaryColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: _theme.textSecondaryColor, fontSize: 14)),
        const SizedBox(height: 24),

        _buildOtpInput(
          value: _verifyCode,
          error: _verifyError,
          onChanged: (v) => setState(() {
            _verifyCode = v;
            _verifyError = null;
          }),
        ),

        if (method != 'totp') ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _verifySendingOtp
                  ? null
                  : () {
                      setState(() {
                        _verifySendingOtp = true;
                        _verifyError = null;
                      });
                      if (method == 'sms') _sendVerifySms();
                      else _sendVerifyOtp(method);
                    },
              child: Text(
                _locale.get('resend_otp'),
                style: TextStyle(color: ThemeService.accentColor, fontSize: 14),
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        AnimatedOpacity(
          opacity: _verifyCode.length != 6 ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _verifyingOtp || _verifyCode.length != 6
                  ? null
                  : _doVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeService.accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: ThemeService.accentColor,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                elevation: 0,
              ),
              child: _verifyingOtp
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(
                      _locale.get('verify'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _doVerify() async {
    setState(() => _verifyingOtp = true);
    final method = _verifyUsingMethod!;

    // For SMS: verify with Firebase first
    String otpToSend = _verifyCode;
    if (method == 'sms') {
      final phoneAuth = FirebasePhoneAuthService();
      final idToken = await phoneAuth.verifyOtp(_verifyCode);
      if (idToken == null) {
        if (mounted) {
          setState(() {
            _verifyingOtp = false;
            _verifyError = phoneAuth.errorMessage ?? _locale.get('otp_incorrect');
          });
        }
        return;
      }
      otpToSend = 'firebase_verified';
      phoneAuth.reset();
    }

    final token = await _auth.getToken();
    if (token == null) return;

    // Calculate new methods list
    List<String> newMethods;
    if (_verifyToEnable) {
      newMethods = [..._methods];
      if (!newMethods.contains(_verifyForMethod!)) {
        newMethods.add(_verifyForMethod!);
      }
    } else {
      newMethods = _methods.where((m) => m != _verifyForMethod!).toList();
    }

    final enabled = newMethods.isNotEmpty;

    final result = await _api.verify2FASettings(
      token, otpToSend, method, enabled, newMethods,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _methods = newMethods;
        _twoFactorEnabled = enabled;
        _resetVerifyFlow();
      });
      if (_verifyToEnable) {
        _showSnackBar(
          _locale.get('2fa_method_enabled_success'),
          const Color(0xFF4CAF50),
        );
      } else if (!enabled) {
        _showSnackBar(_locale.get('2fa_disabled_success'), const Color(0xFF4CAF50));
      } else {
        _showSnackBar(
          _locale.get('2fa_method_disabled_success'),
          const Color(0xFF4CAF50),
        );
      }
    } else {
      setState(() {
        _verifyingOtp = false;
        _verifyError = result['message'] ?? _locale.get('otp_incorrect');
      });
    }
  }

  void _resetVerifyFlow() {
    _isVerifyFlow = false;
    _verifyForMethod = null;
    _verifyToEnable = false;
    _verifyUsingMethod = null;
    _verifyCode = '';
    _verifyError = null;
  }

  // ========== Shared UI helpers ==========

  Widget _buildOtpInput({
    required String value,
    required String? error,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      autofocus: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        color: _theme.textPrimaryColor,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 10,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        counterText: '',
        hintText: '000000',
        hintStyle: TextStyle(
          color: _theme.textSecondaryColor.withOpacity(0.3),
          fontSize: 28,
          letterSpacing: 10,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: _theme.isLightMode
            ? Colors.grey[100]
            : _theme.inputBackground,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorText: error,
        errorStyle: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildSendError({String? error, required VoidCallback onRetry}) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              error ?? _locale.get('error'),
              style: TextStyle(color: Colors.red[400], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeService.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              child: Text(_locale.isVietnamese ? 'Thử lại' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionList(List<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.asMap().entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${e.key + 1}.  ',
                style: TextStyle(
                  color: _theme.textPrimaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: Text(
                  e.value,
                  style: TextStyle(
                    color: _theme.textPrimaryColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ========== Utility ==========

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final masked = name.length > 2
        ? '${name.substring(0, 1)}${'*' * (name.length - 2)}${name.substring(name.length - 1)}'
        : name;
    return '$masked@${parts[1]}';
  }

  String _maskPhone(String phone) {
    if (phone.length < 6) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }
}

// ============================================================
// Reusable 2FA verification bottom sheet for sensitive actions
// ============================================================

/// Shows a 2FA verification bottom sheet.
/// Returns true if verified, false if cancelled.
Future<bool> show2FAVerificationSheet({
  required BuildContext context,
  required String actionName,
  required List<String> methods,
}) async {
  final theme = ThemeService();
  final locale = LocaleService();
  final auth = AuthService();
  final api = ApiService();

  final user = auth.user;
  final hasEmail = user != null &&
      user['email'] != null &&
      !user['email'].toString().endsWith('@phone.user') &&
      methods.contains('email');
  final hasPhone = user != null &&
      user['phoneNumber'] != null &&
      methods.contains('sms');
  final hasTotp = methods.contains('totp');

  final List<String> available = [];
  if (hasTotp) available.add('totp');
  if (hasEmail) available.add('email');
  if (hasPhone) available.add('sms');
  if (available.isEmpty) return true;

  final completer = Completer<bool>();
  String selectedMethod = available.first;
  bool isSending = false;
  bool otpSent = selectedMethod == 'totp';
  bool isVerifying = false;
  String code = '';
  String? error;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop && !completer.isCompleted) completer.complete(false);
          },
          child: Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
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
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            otpSent ? Icons.pin : Icons.verified_user,
                            color: Colors.blue, size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                locale.get('verify_identity'),
                                style: TextStyle(
                                  color: theme.textPrimaryColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                actionName,
                                style: TextStyle(
                                  color: theme.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (!otpSent) ...[
                      // Method selection
                      if (available.length > 1) ...[
                        Text(
                          locale.get('select_2fa_method'),
                          style: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        ...available.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MethodSelectTile(
                            theme: theme,
                            locale: locale,
                            method: m,
                            isSelected: selectedMethod == m,
                            onTap: () => setState(() {
                              selectedMethod = m;
                              error = null;
                            }),
                          ),
                        )),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.inputBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _method2Icon(selectedMethod),
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _method2Label(selectedMethod, locale),
                                  style: TextStyle(color: theme.textPrimaryColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red[400], size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: TextStyle(color: Colors.red[400], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      // OTP entry
                      Text(
                        selectedMethod == 'email'
                            ? locale.get('otp_sent_to_email')
                            : selectedMethod == 'totp'
                                ? locale.get('totp_enter_code')
                                : locale.get('otp_via_sms'),
                        style: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(
                          color: theme.textPrimaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        onChanged: (v) => setState(() {
                          code = v;
                          error = null;
                        }),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          hintStyle: TextStyle(
                            color: theme.textSecondaryColor.withOpacity(0.3),
                            fontSize: 24, letterSpacing: 8,
                          ),
                          filled: true,
                          fillColor: theme.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorText: error,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              if (otpSent && selectedMethod != 'totp') {
                                setState(() {
                                  otpSent = false;
                                  code = '';
                                  error = null;
                                });
                              } else {
                                Navigator.pop(ctx);
                                if (!completer.isCompleted) completer.complete(false);
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              (otpSent && selectedMethod != 'totp')
                                  ? locale.get('back')
                                  : locale.get('cancel'),
                              style: TextStyle(color: theme.textSecondaryColor, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (isSending || isVerifying || (otpSent && code.length != 6))
                                ? null
                                : () async {
                                    final token = await auth.getToken();
                                    if (token == null) {
                                      Navigator.pop(ctx);
                                      if (!completer.isCompleted) completer.complete(false);
                                      return;
                                    }

                                    if (!otpSent) {
                                      if (selectedMethod == 'totp') {
                                        setState(() { otpSent = true; error = null; });
                                        return;
                                      }

                                      setState(() { isSending = true; error = null; });

                                      if (selectedMethod == 'sms') {
                                        final result = await api.send2FASettingsOtp(token, 'sms');
                                        if (result['success'] == true && result['phoneNumber'] != null) {
                                          final phoneAuth = FirebasePhoneAuthService();
                                          final sent = await phoneAuth.sendOtp(result['phoneNumber']);
                                          if (sent) {
                                            setState(() { otpSent = true; isSending = false; });
                                          } else {
                                            setState(() {
                                              isSending = false;
                                              error = phoneAuth.errorMessage ?? locale.get('error');
                                            });
                                          }
                                        } else {
                                          setState(() {
                                            isSending = false;
                                            error = result['message'] ?? locale.get('error');
                                          });
                                        }
                                      } else {
                                        final result = await api.send2FASettingsOtp(token, selectedMethod);
                                        if (result['success'] == true) {
                                          setState(() { otpSent = true; isSending = false; });
                                        } else {
                                          setState(() {
                                            isSending = false;
                                            error = result['message'] ?? locale.get('error');
                                          });
                                        }
                                      }
                                    } else {
                                      // Verify
                                      setState(() => isVerifying = true);

                                      String otp = code;
                                      if (selectedMethod == 'sms') {
                                        final phoneAuth = FirebasePhoneAuthService();
                                        final idToken = await phoneAuth.verifyOtp(code);
                                        if (idToken == null) {
                                          setState(() {
                                            isVerifying = false;
                                            error = phoneAuth.errorMessage ?? locale.get('otp_incorrect');
                                          });
                                          return;
                                        }
                                        otp = 'firebase_verified';
                                        phoneAuth.reset();
                                      }

                                      final result = await api.verify2FASettings(
                                        token, otp, selectedMethod, true, methods,
                                      );

                                      if (result['success'] == true) {
                                        if (!completer.isCompleted) completer.complete(true);
                                        Navigator.pop(ctx);
                                      } else {
                                        setState(() {
                                          isVerifying = false;
                                          error = result['message'] ?? locale.get('otp_incorrect');
                                        });
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (otpSent && code.length != 6) ? Colors.grey : Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: (isSending || isVerifying)
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(
                                    otpSent
                                        ? locale.get('verify')
                                        : selectedMethod == 'totp'
                                            ? locale.get('next')
                                            : locale.get('send_otp'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  return completer.future;
}

IconData _method2Icon(String method) {
  switch (method) {
    case 'totp': return Icons.shield_outlined;
    case 'email': return Icons.email_outlined;
    case 'sms': return Icons.sms_outlined;
    default: return Icons.security;
  }
}

String _method2Label(String method, LocaleService locale) {
  switch (method) {
    case 'totp': return locale.get('authenticator_app');
    case 'email': return 'Email';
    case 'sms': return locale.get('2fa_method_phone');
    default: return method;
  }
}

class _MethodSelectTile extends StatelessWidget {
  final ThemeService theme;
  final LocaleService locale;
  final String method;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodSelectTile({
    required this.theme,
    required this.locale,
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.1)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.blue.withOpacity(0.5)
                : theme.dividerColor,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.15)
                    : theme.inputBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _method2Icon(method),
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
                    _method2Label(method, locale),
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
    );
  }
}
