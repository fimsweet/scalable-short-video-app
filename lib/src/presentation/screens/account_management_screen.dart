import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/fcm_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/blocked_users_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/activity_history_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/analytics_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/logged_devices_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/phone_management_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/change_password_screen.dart';
import 'package:scalable_short_video_app/src/utils/navigation_utils.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final ApiService _apiService = ApiService();
  final FcmService _fcmService = FcmService();
  
  bool _twoFactorEnabled = false;
  List<String> _twoFactorMethods = [];
  bool _loginAlertsEnabled = false; // Default to false, will be loaded from API
  bool _isLoadingLoginAlerts = true; // Loading state for toggle
  bool _hasPassword = true; // Default to true, will be updated from API
  bool _isLoadingPassword = true;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _checkHasPassword();
    _load2FASettings();
    _loadLoginAlertsStatus();
  }

  Future<void> _loadLoginAlertsStatus() async {
    final enabled = await _fcmService.getLoginAlertsStatus();
    if (mounted) {
      setState(() {
        _loginAlertsEnabled = enabled;
        _isLoadingLoginAlerts = false;
      });
    }
  }

  Future<void> _checkHasPassword() async {
    final token = await _authService.getToken();
    if (token == null) {
      setState(() => _isLoadingPassword = false);
      return;
    }
    
    final result = await _apiService.hasPassword(token);
    print('hasPassword API result: $result');
    if (mounted) {
      setState(() {
        _hasPassword = result['hasPassword'] ?? true;
        _isLoadingPassword = false;
        print('_hasPassword set to: $_hasPassword');
      });
    }
  }

  Future<void> _load2FASettings() async {
    final token = await _authService.getToken();
    if (token == null) return;
    
    final result = await _apiService.get2FASettings(token);
    if (mounted) {
      setState(() {
        _twoFactorEnabled = result['enabled'] ?? false;
        _twoFactorMethods = List<String>.from(result['methods'] ?? []);
      });
    }
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.isLightMode 
          ? const Color(0xFFF5F5F5) 
          : _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: _themeService.iconColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.get('account_management'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // Security Section
            _buildSectionTitle(_localeService.get('security_section')),
            _buildSettingsGroup([
              _isLoadingPassword 
                  ? _buildMenuItem(
                      icon: Icons.lock_outline,
                      iconColor: Colors.orange,
                      title: '...',
                      subtitle: '',
                      onTap: () {},
                      showDivider: true,
                    )
                  : _hasPassword
                      ? _buildMenuItem(
                          icon: Icons.lock_outline,
                          iconColor: Colors.orange,
                          title: _localeService.get('change_password'),
                          subtitle: _localeService.get('change_password_subtitle'),
                          onTap: () => _navigateToChangePassword(),
                          showDivider: true,
                        )
                      : _buildMenuItem(
                          icon: Icons.lock_open,
                          iconColor: Colors.green,
                          title: _localeService.get('set_password'),
                          subtitle: _localeService.get('set_password_subtitle'),
                          onTap: () => _showSetPasswordDialog(),
                          showDivider: true,
                        ),
              _buildSettingSwitch(
                icon: Icons.security,
                iconColor: Colors.blue,
                title: _localeService.get('two_factor_auth'),
                subtitle: _twoFactorEnabled 
                    ? _localeService.get('two_factor_on')
                    : _localeService.get('two_factor_off'),
                value: _twoFactorEnabled,
                onChanged: (value) async {
                  if (value) {
                    // Don't change toggle state here - only change after successful setup
                    _showSetup2FADialog();
                  } else {
                    _showDisable2FADialog();
                  }
                },
                showDivider: true,
              ),
              _buildSettingSwitch(
                icon: Icons.notifications_active_outlined,
                iconColor: Colors.purple,
                title: _localeService.get('login_alerts'),
                subtitle: _localeService.get('login_alerts_desc'),
                value: _loginAlertsEnabled,
                isLoading: _isLoadingLoginAlerts,
                onChanged: _isLoadingLoginAlerts ? null : (value) async {
                  final previousValue = _loginAlertsEnabled;
                  setState(() => _loginAlertsEnabled = value);
                  
                  final success = await _fcmService.toggleLoginAlerts(value);
                  if (success) {
                    _showSnackBar(
                      value ? _localeService.get('enabled') : _localeService.get('disabled'),
                      _themeService.snackBarBackground,
                    );
                  } else {
                    // Revert if failed
                    setState(() => _loginAlertsEnabled = previousValue);
                    _showSnackBar(
                      _localeService.get('error_occurred'),
                      Colors.red,
                    );
                  }
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Account Info Section
            _buildSectionTitle(_localeService.get('account_info')),
            _buildSettingsGroup([
              _buildMenuItem(
                icon: Icons.email_outlined,
                iconColor: Colors.cyan,
                title: _localeService.get('email'),
                subtitle: _authService.user?['email'] ?? _localeService.get('not_set'),
                onTap: () => _showChangeEmailDialog(),
                showDivider: true,
              ),
              _buildMenuItem(
                icon: Icons.phone_outlined,
                iconColor: Colors.teal,
                title: _localeService.get('phone_number'),
                subtitle: _authService.user?['phoneNumber'] ?? _localeService.get('not_linked'),
                onTap: () => _showAddPhoneDialog(),
                showDivider: true,
              ),
              _buildMenuItem(
                icon: Icons.devices_outlined,
                iconColor: Colors.indigo,
                title: _localeService.get('devices'),
                subtitle: _localeService.get('devices_subtitle'),
                onTap: () => _showDevicesDialog(),
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Data & Privacy Section
            _buildSectionTitle(_localeService.get('data_privacy')),
            _buildSettingsGroup([
              _buildMenuItem(
                icon: Icons.analytics_outlined,
                iconColor: Colors.purple,
                title: _localeService.get('analytics'),
                subtitle: _localeService.get('analytics_desc'),
                onTap: () => _showAnalyticsScreen(),
                showDivider: true,
              ),
              _buildMenuItem(
                icon: Icons.history,
                iconColor: Colors.amber,
                title: _localeService.get('activity_history'),
                subtitle: _localeService.get('activity_history_desc'),
                onTap: () => _showActivityHistoryDialog(),
                showDivider: true,
              ),
              _buildMenuItem(
                icon: Icons.block_outlined,
                iconColor: Colors.red[300]!,
                title: _localeService.get('blocked_list'),
                subtitle: _localeService.get('blocked_list_subtitle'),
                onTap: () => _showBlockedAccountsDialog(),
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Danger Zone Section
            _buildSectionTitle(_localeService.get('danger_zone')),
            _buildSettingsGroup([
              _buildMenuItem(
                icon: Icons.logout,
                iconColor: Colors.orange,
                title: _localeService.get('logout'),
                subtitle: _localeService.get('logout_confirm'),
                onTap: () => _showLogoutDialog(),
                showArrow: false,
                showDivider: true,
              ),
              _buildMenuItem(
                icon: Icons.pause_circle_outline,
                iconColor: Colors.deepOrange,
                title: _localeService.get('deactivate_account'),
                subtitle: _localeService.get('deactivate_account_desc'),
                onTap: () => _showDeactivateDialog(),
                showArrow: false,
              ),
            ]),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: _themeService.textSecondaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.white : _themeService.inputBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _themeService.isLightMode
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showArrow = true,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
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
                if (showArrow)
                  Icon(
                    Icons.chevron_right,
                    color: _themeService.textSecondaryColor,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Container(
            margin: const EdgeInsets.only(left: 16),
            height: 0.5,
            color: _themeService.dividerColor,
          ),
      ],
    );
  }

  Widget _buildSettingSwitch({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool showDivider = false,
    bool isLoading = false,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
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
              if (isLoading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _themeService.textSecondaryColor,
                  ),
                )
              else
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: _themeService.switchActiveColor,
                  activeTrackColor: _themeService.switchActiveTrackColor,
                  inactiveThumbColor: _themeService.switchInactiveThumbColor,
                  inactiveTrackColor: _themeService.switchInactiveTrackColor,
                ),
            ],
          ),
        ),
        if (showDivider)
          Container(
            margin: const EdgeInsets.only(left: 16),
            height: 0.5,
            color: _themeService.dividerColor,
          ),
      ],
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: _themeService.snackBarTextColor),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  // Set Password Dialog (for OAuth users who don't have password)
  void _showSetPasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _themeService.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            _localeService.get('set_password'),
            style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _localeService.get('set_password_description'),
                  style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  style: TextStyle(color: _themeService.textPrimaryColor),
                  decoration: InputDecoration(
                    labelText: _localeService.get('new_password'),
                    labelStyle: TextStyle(color: _themeService.textSecondaryColor),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _themeService.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                        color: _themeService.textSecondaryColor,
                      ),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  style: TextStyle(color: _themeService.textPrimaryColor),
                  decoration: InputDecoration(
                    labelText: _localeService.get('confirm_new_password'),
                    labelStyle: TextStyle(color: _themeService.textSecondaryColor),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _themeService.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: _themeService.textSecondaryColor,
                      ),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _localeService.get('password_requirements'),
                  style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_localeService.get('cancel'), style: TextStyle(color: _themeService.textSecondaryColor)),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final newPass = newPasswordController.text;
                final confirmPass = confirmPasswordController.text;

                if (newPass.isEmpty || confirmPass.isEmpty) {
                  _showSnackBar(_localeService.get('fill_all_fields'), Colors.red);
                  return;
                }

                if (newPass != confirmPass) {
                  _showSnackBar(_localeService.get('passwords_not_match'), Colors.red);
                  return;
                }

                if (newPass.length < 8) {
                  _showSnackBar(_localeService.get('password_too_short'), Colors.red);
                  return;
                }

                setDialogState(() => isLoading = true);

                final token = await _authService.getToken();
                if (token == null) {
                  _showSnackBar(_localeService.get('please_login_again'), Colors.red);
                  setDialogState(() => isLoading = false);
                  return;
                }

                final result = await _apiService.setPassword(
                  token: token,
                  newPassword: newPass,
                );

                setDialogState(() => isLoading = false);

                if (result['success'] == true) {
                  Navigator.pop(context);
                  _showSnackBar(_localeService.get('password_set_success'), Colors.green);
                  // Refresh password status
                  _checkHasPassword();
                } else {
                  _showSnackBar(result['message'] ?? _localeService.get('error'), Colors.red);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_localeService.get('confirm')),
            ),
          ],
        ),
      ),
    );
  }

  // ============= 2FA VERIFICATION FOR SENSITIVE ACTIONS =============
  
  /// Shows 2FA verification dialog if 2FA is enabled.
  /// Returns true if 2FA is not enabled or verification is successful.
  /// Returns false if user cancels or verification fails.
  Future<bool> _verify2FAForSensitiveAction(String actionName) async {
    // If 2FA is not enabled, allow action
    if (!_twoFactorEnabled || _twoFactorMethods.isEmpty) {
      return true;
    }
    
    final completer = Completer<bool>();
    
    final user = _authService.user;
    final hasEmail = user != null && user['email'] != null && _twoFactorMethods.contains('email');
    final hasPhone = user != null && user['phoneNumber'] != null && _twoFactorMethods.contains('sms');
    final hasTotp = _twoFactorMethods.contains('totp');
    
    // Build available methods list
    final List<String> availableMethods = [];
    if (hasTotp) availableMethods.add('totp');
    if (hasEmail) availableMethods.add('email');
    if (hasPhone) availableMethods.add('sms');
    
    // If no methods available (edge case), allow action
    if (availableMethods.isEmpty) {
      return true;
    }
    
    // Default to first available method (TOTP preferred)
    String selectedMethod = availableMethods.first;
    bool isSendingOtp = false;
    bool isOtpSent = selectedMethod == 'totp'; // TOTP skips send step
    bool isVerifying = false;
    String otpCode = '';
    String? otpError;
    String? actionError; // Error shown inside the modal
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return PopScope(
            onPopInvokedWithResult: (didPop, result) {
              if (didPop && !completer.isCompleted) {
                completer.complete(false);
              }
            },
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: _themeService.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
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
                              isOtpSent ? Icons.pin : Icons.verified_user,
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _localeService.get('verify_identity'),
                                  style: TextStyle(
                                    color: _themeService.textPrimaryColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  actionName,
                                  style: TextStyle(
                                    color: _themeService.textSecondaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      if (!isOtpSent) ...[
                        // Method selection
                        if (availableMethods.length > 1) ...[
                          Text(
                            _localeService.get('select_2fa_method'),
                            style: TextStyle(
                              color: _themeService.textSecondaryColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: availableMethods.asMap().entries.map((entry) {
                              final index = entry.key;
                              final method = entry.value;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    left: index == 0 ? 0 : 5,
                                    right: index == availableMethods.length - 1 ? 0 : 5,
                                  ),
                                  child: _buildMethodChip(
                                    icon: method == 'email'
                                        ? Icons.email_outlined
                                        : method == 'totp'
                                            ? Icons.app_settings_alt
                                            : Icons.sms_outlined,
                                    label: method == 'email'
                                        ? 'Email'
                                        : method == 'totp'
                                            ? _localeService.get('authenticator_app')
                                            : 'SMS',
                                    isSelected: selectedMethod == method,
                                    onTap: () {
                                      setSheetState(() {
                                        selectedMethod = method;
                                        actionError = null;
                                      });
                                    },
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ] else ...[
                          // Single method display
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _themeService.inputBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selectedMethod == 'email'
                                      ? Icons.email_outlined
                                      : selectedMethod == 'totp'
                                          ? Icons.app_settings_alt
                                          : Icons.sms_outlined,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedMethod == 'email'
                                        ? _localeService.get('send_otp_to_email')
                                        : selectedMethod == 'totp'
                                            ? _localeService.get('authenticator_app')
                                            : _localeService.get('send_otp_via_sms'),
                                    style: TextStyle(color: _themeService.textPrimaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        // Error inside modal
                        if (actionError != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red[400], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    actionError!,
                                    style: TextStyle(color: Colors.red[400], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        // OTP Input
                        Text(
                          selectedMethod == 'email'
                              ? _localeService.get('otp_sent_to_email')
                              : selectedMethod == 'totp'
                                  ? _localeService.get('totp_enter_code')
                                  : _localeService.get('otp_via_sms'),
                          style: TextStyle(
                            color: _themeService.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextField(
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _themeService.textPrimaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                          maxLength: 6,
                          onChanged: (value) {
                            setSheetState(() {
                              otpCode = value;
                              if (otpError != null) otpError = null;
                            });
                          },
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '000000',
                            hintStyle: TextStyle(
                              color: _themeService.textSecondaryColor.withOpacity(0.5),
                              fontSize: 24,
                              letterSpacing: 8,
                            ),
                            filled: true,
                            fillColor: _themeService.inputBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            errorText: otpError,
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
                                if (isOtpSent && selectedMethod != 'totp') {
                                  // Go back to method selection
                                  setSheetState(() {
                                    isOtpSent = false;
                                    otpCode = '';
                                    otpError = null;
                                  });
                                } else {
                                  Navigator.pop(context);
                                  if (!completer.isCompleted) completer.complete(false);
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                (isOtpSent && selectedMethod != 'totp')
                                    ? _localeService.get('back')
                                    : _localeService.get('cancel'),
                                style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: (isSendingOtp || isVerifying || (isOtpSent && otpCode.length != 6))
                                  ? null
                                  : () async {
                                      final token = await _authService.getToken();
                                      if (token == null) {
                                        Navigator.pop(context);
                                        if (!completer.isCompleted) completer.complete(false);
                                        return;
                                      }
                                      
                                      if (!isOtpSent) {
                                        // For TOTP: go directly to code entry
                                        if (selectedMethod == 'totp') {
                                          setSheetState(() {
                                            isOtpSent = true;
                                            actionError = null;
                                          });
                                          return;
                                        }
                                        
                                        // Send OTP for email/sms
                                        setSheetState(() {
                                          isSendingOtp = true;
                                          actionError = null;
                                        });
                                        
                                        final result = await _apiService.send2FASettingsOtp(token, selectedMethod);
                                        
                                        if (result['success'] == true) {
                                          if (result['method'] == 'sms' && result['phoneNumber'] != null) {
                                            setSheetState(() {
                                              isSendingOtp = false;
                                              actionError = _localeService.get('sms_otp_not_implemented');
                                            });
                                          } else {
                                            setSheetState(() {
                                              isOtpSent = true;
                                              isSendingOtp = false;
                                            });
                                          }
                                        } else {
                                          setSheetState(() {
                                            isSendingOtp = false;
                                            actionError = result['message'] ?? _localeService.get('error');
                                          });
                                        }
                                      } else {
                                        // Verify OTP / TOTP
                                        setSheetState(() => isVerifying = true);
                                        
                                        final result = await _apiService.verify2FASettings(
                                          token,
                                          otpCode,
                                          selectedMethod,
                                          true, // Keep 2FA enabled
                                          _twoFactorMethods, // Keep existing methods
                                        );
                                        
                                        if (result['success'] == true) {
                                          Navigator.pop(context);
                                          if (!completer.isCompleted) completer.complete(true);
                                        } else {
                                          setSheetState(() {
                                            isVerifying = false;
                                            otpError = result['message'] ?? _localeService.get('otp_incorrect');
                                          });
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (isOtpSent && otpCode.length != 6) ? Colors.grey : Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: (isSendingOtp || isVerifying)
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text(
                                      isOtpSent 
                                          ? _localeService.get('verify')
                                          : selectedMethod == 'totp'
                                              ? _localeService.get('next')
                                              : _localeService.get('send_otp'),
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
  
  Widget _buildMethodChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.15) : _themeService.inputBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.blue : _themeService.textSecondaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : _themeService.textPrimaryColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Change Password — verify 2FA first, then navigate to full screen
  void _navigateToChangePassword() async {
    final verified = await _verify2FAForSensitiveAction(_localeService.get('change_password_2fa_reason'));
    if (!verified) return;
    if (!mounted) return;
    NavigationUtils.slideToScreen(context, const ChangePasswordScreen());
  }

  // Legacy change password dialog (kept for reference)
  void _showChangePasswordDialog() async {
    // Verify 2FA if enabled before allowing password change
    final verified = await _verify2FAForSensitiveAction(_localeService.get('change_password_2fa_reason'));
    if (!verified) return;
    
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _themeService.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            _localeService.get('change_password'),
            style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  style: TextStyle(color: _themeService.textPrimaryColor),
                  decoration: InputDecoration(
                    labelText: _localeService.get('current_password'),
                    labelStyle: TextStyle(color: _themeService.textSecondaryColor),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _themeService.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent ? Icons.visibility_off : Icons.visibility,
                        color: _themeService.textSecondaryColor,
                      ),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  style: TextStyle(color: _themeService.textPrimaryColor),
                  decoration: InputDecoration(
                    labelText: _localeService.get('new_password'),
                    labelStyle: TextStyle(color: _themeService.textSecondaryColor),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _themeService.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                        color: _themeService.textSecondaryColor,
                      ),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  style: TextStyle(color: _themeService.textPrimaryColor),
                  decoration: InputDecoration(
                    labelText: _localeService.get('confirm_new_password'),
                    labelStyle: TextStyle(color: _themeService.textSecondaryColor),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _themeService.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: _themeService.textSecondaryColor,
                      ),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _localeService.get('password_requirements'),
                  style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text(_localeService.get('cancel'), style: TextStyle(color: _themeService.textSecondaryColor)),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                // Validate
                if (currentPasswordController.text.isEmpty ||
                    newPasswordController.text.isEmpty ||
                    confirmPasswordController.text.isEmpty) {
                  _showSnackBar(_localeService.get('fill_all_fields'), Colors.orange);
                  return;
                }

                if (newPasswordController.text.length < 8) {
                  _showSnackBar(_localeService.get('password_too_short'), Colors.orange);
                  return;
                }

                if (newPasswordController.text != confirmPasswordController.text) {
                  _showSnackBar(_localeService.get('password_mismatch'), Colors.orange);
                  return;
                }

                setDialogState(() => isLoading = true);

                try {
                  final token = await _authService.getToken();
                  if (token == null) {
                    Navigator.pop(context);
                    _showSnackBar(_localeService.get('session_expired'), Colors.red);
                    return;
                  }

                  final result = await ApiService().changePassword(
                    token: token,
                    currentPassword: currentPasswordController.text,
                    newPassword: newPasswordController.text,
                  );

                  Navigator.pop(context);
                  
                  if (result['success'] == true) {
                    _showSnackBar(_localeService.get('password_change_success'), Colors.green);
                  } else {
                    _showSnackBar(result['message'] ?? _localeService.get('password_change_failed'), Colors.red);
                  }
                } catch (e) {
                  Navigator.pop(context);
                  _showSnackBar('${_localeService.get('error')}: $e', Colors.red);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_localeService.get('confirm'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Setup 2FA Dialog - TikTok style with multiple method selection
  void _showSetup2FADialog() {
    // Get current user's available methods
    final user = _authService.user;
    final hasEmail = user != null && user['email'] != null;
    final hasPhone = user != null && user['phoneNumber'] != null;
    
    // Track selected methods
    List<String> selectedMethods = List.from(_twoFactorMethods);
    bool isSaving = false;
    bool isOtpStep = false;
    String otpCode = '';
    String? selectedOtpMethod; // Method used for OTP verification
    bool isSendingOtp = false;
    String? otpError;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: _themeService.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
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
                            isOtpStep ? Icons.pin : Icons.security,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOtpStep 
                                    ? _localeService.get('confirm_enable_2fa')
                                    : _localeService.get('two_factor_auth'),
                                style: TextStyle(
                                  color: _themeService.textPrimaryColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isOtpStep
                                    ? _localeService.get('enter_otp_to_enable')
                                    : _localeService.get('select_2fa_method'),
                                style: TextStyle(
                                  color: _themeService.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    if (!isOtpStep) ...[
                      // Email option
                      _build2FAMethodTile(
                        icon: Icons.email_outlined,
                        title: 'Email',
                        subtitle: hasEmail 
                            ? _localeService.get('email_2fa_desc')
                            : _localeService.get('link_email_first'),
                        isEnabled: hasEmail,
                        isSelected: selectedMethods.contains('email'),
                        onChanged: hasEmail ? (value) {
                          setSheetState(() {
                            if (value) {
                              selectedMethods.add('email');
                            } else {
                              selectedMethods.remove('email');
                            }
                          });
                        } : null,
                      ),
                      const SizedBox(height: 12),
                      
                      // SMS option
                      _build2FAMethodTile(
                        icon: Icons.sms_outlined,
                        title: 'SMS',
                        subtitle: hasPhone 
                            ? _localeService.get('sms_2fa_desc')
                            : _localeService.get('link_phone_first'),
                        isEnabled: hasPhone,
                        isSelected: selectedMethods.contains('sms'),
                        onChanged: hasPhone ? (value) {
                          setSheetState(() {
                            if (value) {
                              selectedMethods.add('sms');
                            } else {
                              selectedMethods.remove('sms');
                            }
                          });
                        } : null,
                      ),
                      const SizedBox(height: 12),
                      
                      // Authenticator App option (TOTP)
                      _build2FAMethodTile(
                        icon: Icons.app_settings_alt,
                        title: _localeService.get('authenticator_app'),
                        subtitle: _localeService.get('authenticator_app_desc'),
                        isEnabled: true,
                        isSelected: selectedMethods.contains('totp'),
                        onChanged: (value) {
                          if (value) {
                            // Start TOTP setup flow
                            Navigator.pop(context);
                            _showTotpSetupDialog(selectedMethods);
                          } else {
                            setSheetState(() {
                              selectedMethods.remove('totp');
                            });
                          }
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Note
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[400], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _localeService.get('2fa_note'),
                                style: TextStyle(color: Colors.orange[400], fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // OTP Input Step
                      Text(
                        selectedOtpMethod == 'email'
                            ? _localeService.get('otp_sent_to_email')
                            : _localeService.get('otp_via_sms'),
                        style: TextStyle(
                          color: _themeService.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // OTP Input
                      TextField(
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        maxLength: 6,
                        onChanged: (value) {
                          setSheetState(() {
                            otpCode = value;
                            if (otpError != null) otpError = null;
                          });
                        },
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          hintStyle: TextStyle(
                            color: _themeService.textSecondaryColor.withOpacity(0.5),
                            fontSize: 24,
                            letterSpacing: 8,
                          ),
                          filled: true,
                          fillColor: _themeService.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorText: otpError,
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
                              if (isOtpStep) {
                                // Go back to method selection
                                setSheetState(() {
                                  isOtpStep = false;
                                  otpCode = '';
                                  otpError = null;
                                });
                              } else {
                                // Just close dialog - state was never changed
                                Navigator.pop(context);
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              isOtpStep ? _localeService.get('back') : _localeService.get('cancel'),
                              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (isSaving || isSendingOtp || (isOtpStep ? otpCode.length != 6 : selectedMethods.isEmpty))
                                ? null
                                : () async {
                                    final token = await _authService.getToken();
                                    if (token == null) {
                                      Navigator.pop(context);
                                      return;
                                    }
                                    
                                    if (!isOtpStep) {
                                      // Step 1: Send OTP
                                      setSheetState(() => isSendingOtp = true);
                                      
                                      // Choose method for OTP - prefer email if available
                                      String otpMethod = hasEmail ? 'email' : 'sms';
                                      
                                      final result = await _apiService.send2FASettingsOtp(token, otpMethod);
                                      
                                      if (result['success'] == true) {
                                        if (result['method'] == 'sms' && result['phoneNumber'] != null) {
                                          // SMS - need Firebase verification
                                          Navigator.pop(context);
                                          _showPhoneOtpFor2FAEnable(
                                            result['phoneNumber'],
                                            selectedMethods,
                                          );
                                        } else {
                                          // Email OTP sent
                                          setSheetState(() {
                                            isOtpStep = true;
                                            selectedOtpMethod = 'email';
                                            isSendingOtp = false;
                                          });
                                        }
                                      } else {
                                        setSheetState(() => isSendingOtp = false);
                                        _showSnackBar(
                                          result['message'] ?? _localeService.get('error'),
                                          Colors.red,
                                        );
                                      }
                                    } else {
                                      // Step 2: Verify OTP and enable 2FA
                                      setSheetState(() => isSaving = true);
                                      
                                      final result = await _apiService.verify2FASettings(
                                        token,
                                        otpCode,
                                        selectedOtpMethod!,
                                        true,
                                        selectedMethods,
                                      );
                                      
                                      if (mounted) {
                                        if (result['success'] == true) {
                                          Navigator.pop(context);
                                          setState(() {
                                            _twoFactorEnabled = true;
                                            _twoFactorMethods = selectedMethods;
                                          });
                                          _showSnackBar(
                                            _localeService.get('2fa_enabled_success'),
                                            Colors.green,
                                          );
                                        } else {
                                          setSheetState(() {
                                            isSaving = false;
                                            otpError = result['message'] ?? _localeService.get('otp_incorrect');
                                          });
                                        }
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (isOtpStep ? otpCode.length != 6 : selectedMethods.isEmpty) 
                                  ? Colors.grey 
                                  : Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: (isSaving || isSendingOtp)
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    isOtpStep 
                                        ? _localeService.get('verify')
                                        : _localeService.get('enable_2fa'),
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
        },
      ),
    );
  }

  // Show phone OTP dialog for 2FA enable (Firebase SMS)
  void _showPhoneOtpFor2FAEnable(String phoneNumber, List<String> methods) {
    // TODO: Implement Firebase SMS verification for 2FA enable
    // Similar to the login 2FA flow
    _showSnackBar(
      _localeService.get('sms_otp_not_implemented'),
      Colors.orange,
    );
    // State was never changed, no need to reset
  }

  // Show TOTP (Google Authenticator) setup dialog
  void _showTotpSetupDialog(List<String> existingMethods) {
    bool isLoading = true;
    bool isVerifying = false;
    String? qrCodeUrl;
    String? secret;
    String? otpauthUrl;
    String? error;
    String totpCode = '';
    int currentStep = 0; // 0: loading/QR, 1: enter code

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Fetch TOTP setup data on first build
          if (isLoading && qrCodeUrl == null && error == null) {
            _authService.getToken().then((token) async {
              if (token == null) {
                if (mounted) Navigator.pop(context);
                return;
              }
              final result = await _apiService.setupTotp(token);
              if (mounted) {
                setSheetState(() {
                  isLoading = false;
                  if (result['success'] == true) {
                    qrCodeUrl = result['qrCodeUrl'] as String?;
                    secret = result['secret'] as String?;
                    otpauthUrl = result['otpauthUrl'] as String?;
                  } else {
                    error = result['message'] ?? _localeService.get('totp_setup_failed');
                  }
                });
              }
            });
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: _themeService.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
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
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            currentStep == 0 ? Icons.qr_code : Icons.pin,
                            color: Colors.green,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _localeService.get('totp_setup_title'),
                                style: TextStyle(
                                  color: _themeService.textPrimaryColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                currentStep == 0
                                    ? _localeService.get('totp_scan_qr')
                                    : _localeService.get('totp_enter_code'),
                                style: TextStyle(
                                  color: _themeService.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (error != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                error!,
                                style: TextStyle(color: Colors.red[400], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (currentStep == 0) ...[
                      // Step 1: Show QR Code
                      Text(
                        _localeService.get('totp_scan_instruction'),
                        style: TextStyle(
                          color: _themeService.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // QR Code display
                      if (qrCodeUrl != null)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Builder(
                              builder: (context) {
                                // Parse data:image/png;base64,... format
                                final base64Str = qrCodeUrl!.split(',').last;
                                final Uint8List bytes = base64Decode(base64Str);
                                return Image.memory(
                                  bytes,
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.contain,
                                );
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Manual entry secret
                      if (secret != null) ...[
                        Text(
                          _localeService.get('totp_manual_entry'),
                          style: TextStyle(
                            color: _themeService.textSecondaryColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: secret!));
                            _showSnackBar(
                              _localeService.get('totp_copied_secret'),
                              Colors.green,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _themeService.inputBackground,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[700]!),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    secret!,
                                    style: TextStyle(
                                      color: _themeService.textPrimaryColor,
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.copy,
                                  color: _themeService.textSecondaryColor,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      // Step 2: Enter verification code
                      TextField(
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        maxLength: 6,
                        onChanged: (value) {
                          setSheetState(() {
                            totpCode = value;
                            if (error != null) error = null;
                          });
                        },
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          hintStyle: TextStyle(
                            color: _themeService.textSecondaryColor.withOpacity(0.5),
                            fontSize: 24,
                            letterSpacing: 8,
                          ),
                          filled: true,
                          fillColor: _themeService.inputBackground,
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
                              if (currentStep == 1) {
                                setSheetState(() {
                                  currentStep = 0;
                                  totpCode = '';
                                  error = null;
                                });
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              currentStep == 1 ? _localeService.get('back') : _localeService.get('cancel'),
                              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (isVerifying || (currentStep == 1 && totpCode.length != 6) || error != null && currentStep == 0)
                                ? null
                                : () async {
                                    if (currentStep == 0) {
                                      // Go to code entry step
                                      setSheetState(() => currentStep = 1);
                                    } else {
                                      // Verify TOTP code
                                      setSheetState(() => isVerifying = true);

                                      final token = await _authService.getToken();
                                      if (token == null) {
                                        if (mounted) Navigator.pop(context);
                                        return;
                                      }

                                      final result = await _apiService.verifyTotpSetup(token, totpCode, secret!);

                                      if (mounted) {
                                        if (result['success'] == true) {
                                          Navigator.pop(context);
                                          setState(() {
                                            _twoFactorEnabled = true;
                                            final methods = (result['methods'] as List?)?.cast<String>() ?? [...existingMethods, 'totp'];
                                            _twoFactorMethods = methods;
                                          });
                                          _showSnackBar(
                                            _localeService.get('totp_setup_success'),
                                            Colors.green,
                                          );
                                        } else {
                                          setSheetState(() {
                                            isVerifying = false;
                                            error = result['message'] ?? _localeService.get('totp_invalid_code');
                                          });
                                        }
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (currentStep == 1 && totpCode.length != 6) ? Colors.grey : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: isVerifying
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    currentStep == 0
                                        ? _localeService.get('next')
                                        : _localeService.get('totp_verify_button'),
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
        },
      ),
    );
  }

  // Show dialog to disable 2FA with OTP verification
  void _showDisable2FADialog() {
    final user = _authService.user;
    final hasEmail = user != null && user['email'] != null;
    
    bool isSendingOtp = false;
    bool isOtpStep = false;
    bool isVerifying = false;
    String otpCode = '';
    String? otpError;
    String? selectedMethod;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: _themeService.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
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
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isOtpStep ? Icons.pin : Icons.security_outlined,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _localeService.get('confirm_disable_2fa'),
                                style: TextStyle(
                                  color: _themeService.textPrimaryColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                isOtpStep
                                    ? _localeService.get('enter_otp_to_disable')
                                    : _localeService.get('disable_2fa_warning'),
                                style: TextStyle(
                                  color: _themeService.textSecondaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    if (isOtpStep) ...[
                      // OTP Input
                      TextField(
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        maxLength: 6,
                        onChanged: (value) {
                          setSheetState(() {
                            otpCode = value;
                            if (otpError != null) otpError = null;
                          });
                        },
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          hintStyle: TextStyle(
                            color: _themeService.textSecondaryColor.withOpacity(0.5),
                            fontSize: 24,
                            letterSpacing: 8,
                          ),
                          filled: true,
                          fillColor: _themeService.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          errorText: otpError,
                        ),
                      ),
                    ] else ...[
                      // Warning message
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.red[400], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _localeService.get('disable_2fa_consequence'),
                                style: TextStyle(color: Colors.red[400], fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              _localeService.get('cancel'),
                              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (isSendingOtp || isVerifying || (isOtpStep && otpCode.length != 6))
                                ? null
                                : () async {
                                    final token = await _authService.getToken();
                                    if (token == null) {
                                      Navigator.pop(context);
                                      return;
                                    }
                                    
                                    if (!isOtpStep) {
                                      // Send OTP
                                      setSheetState(() => isSendingOtp = true);
                                      
                                      // Choose method for OTP
                                      String otpMethod = hasEmail ? 'email' : 'sms';
                                      
                                      final result = await _apiService.send2FASettingsOtp(token, otpMethod);
                                      
                                      if (result['success'] == true) {
                                        if (result['method'] == 'sms' && result['phoneNumber'] != null) {
                                          // SMS - need Firebase verification
                                          Navigator.pop(context);
                                          _showSnackBar(
                                            _localeService.get('sms_otp_not_implemented'),
                                            Colors.orange,
                                          );
                                        } else {
                                          setSheetState(() {
                                            isOtpStep = true;
                                            selectedMethod = 'email';
                                            isSendingOtp = false;
                                          });
                                        }
                                      } else {
                                        setSheetState(() => isSendingOtp = false);
                                        _showSnackBar(
                                          result['message'] ?? _localeService.get('error'),
                                          Colors.red,
                                        );
                                      }
                                    } else {
                                      // Verify OTP and disable 2FA
                                      setSheetState(() => isVerifying = true);
                                      
                                      final result = await _apiService.verify2FASettings(
                                        token,
                                        otpCode,
                                        selectedMethod!,
                                        false, // Disable 2FA
                                        [], // Empty methods
                                      );
                                      
                                      if (mounted) {
                                        if (result['success'] == true) {
                                          Navigator.pop(context);
                                          setState(() {
                                            _twoFactorEnabled = false;
                                            _twoFactorMethods = [];
                                          });
                                          _showSnackBar(
                                            _localeService.get('2fa_disabled_success'),
                                            Colors.green,
                                          );
                                        } else {
                                          setSheetState(() {
                                            isVerifying = false;
                                            otpError = result['message'] ?? _localeService.get('otp_incorrect');
                                          });
                                        }
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: (isSendingOtp || isVerifying)
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    isOtpStep 
                                        ? _localeService.get('verify')
                                        : _localeService.get('disable_2fa'),
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
        },
      ),
    );
  }

  Widget _build2FAMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required bool isSelected,
    ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _themeService.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey[700]!,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isEnabled ? Colors.blue : Colors.grey).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isEnabled ? Colors.blue : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isEnabled ? _themeService.textPrimaryColor : Colors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isEnabled ? _themeService.textSecondaryColor : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isSelected,
            onChanged: onChanged,
            activeColor: _themeService.switchActiveColor,
            activeTrackColor: _themeService.switchActiveTrackColor,
            inactiveThumbColor: _themeService.switchInactiveThumbColor,
            inactiveTrackColor: _themeService.switchInactiveTrackColor,
          ),
        ],
      ),
    );
  }

  // Other dialogs
  void _showChangeEmailDialog() {
    final currentEmail = _authService.user?['email'] as String?;
    _showEmailBottomSheet(currentEmail);
  }

  void _showEmailBottomSheet(String? currentEmail) {
    final emailController = TextEditingController(text: currentEmail ?? '');
    final otpController = TextEditingController();
    int currentStep = 0; // 0: email, 1: OTP
    bool isLoading = false;
    String? errorMessage;
    final isEditing = currentEmail != null && currentEmail.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: _themeService.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: _themeService.textSecondaryColor.withAlpha(100),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    
                    // Step indicator
                    Row(
                      children: [
                        _buildEmailStepIndicator(0, currentStep, _localeService.get('email')),
                        _buildEmailStepLine(currentStep >= 1),
                        _buildEmailStepIndicator(1, currentStep, 'OTP'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Title based on step
                    Text(
                      currentStep == 0 
                          ? (isEditing ? _localeService.get('change_email') : _localeService.get('link_email'))
                          : _localeService.get('verify_email'),
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentStep == 0 
                          ? _localeService.get('enter_email_to_link')
                          : _localeService.get('enter_otp_sent_to_email'),
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Step 0: Email input
                    if (currentStep == 0) ...[
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofocus: true,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'email@example.com',
                          hintStyle: TextStyle(
                            color: _themeService.textSecondaryColor.withAlpha(128),
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: _themeService.textSecondaryColor,
                          ),
                          filled: true,
                          fillColor: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[850],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                    
                    // Step 1: OTP input
                    if (currentStep == 1) ...[
                      // Show email being verified
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[850],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              color: _themeService.textSecondaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                emailController.text,
                                style: TextStyle(
                                  color: _themeService.textPrimaryColor,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // OTP input
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 24,
                          letterSpacing: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: '000000',
                          hintStyle: TextStyle(
                            color: _themeService.textSecondaryColor.withAlpha(100),
                            letterSpacing: 8,
                          ),
                          filled: true,
                          fillColor: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[850],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                    
                    // Error message
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Buttons
                    Row(
                      children: [
                        // Back/Cancel button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              if (currentStep > 0) {
                                setSheetState(() {
                                  currentStep--;
                                  errorMessage = null;
                                  otpController.clear();
                                });
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _themeService.textSecondaryColor,
                              side: BorderSide(color: _themeService.dividerColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              currentStep > 0 ? _localeService.get('back') : _localeService.get('cancel'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Next/Submit button
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    if (currentStep == 0) {
                                      // Step 0: Send OTP
                                      final email = emailController.text.trim();
                                      if (email.isEmpty || !email.contains('@')) {
                                        setSheetState(() => errorMessage = _localeService.get('invalid_email'));
                                        return;
                                      }
                                      
                                      setSheetState(() {
                                        isLoading = true;
                                        errorMessage = null;
                                      });
                                      
                                      final token = await _authService.getToken();
                                      final result = await _apiService.sendLinkEmailOtp(token!, email);
                                      
                                      if (result['success']) {
                                        setSheetState(() {
                                          currentStep = 1;
                                          isLoading = false;
                                        });
                                      } else {
                                        setSheetState(() {
                                          errorMessage = result['message'] ?? _localeService.get('send_otp_failed');
                                          isLoading = false;
                                        });
                                      }
                                    } else if (currentStep == 1) {
                                      // Step 1: Verify OTP
                                      final otp = otpController.text.trim();
                                      if (otp.length != 6) {
                                        setSheetState(() => errorMessage = _localeService.get('invalid_otp'));
                                        return;
                                      }
                                      
                                      setSheetState(() {
                                        isLoading = true;
                                        errorMessage = null;
                                      });
                                      
                                      final token = await _authService.getToken();
                                      final result = await _apiService.verifyAndLinkEmail(
                                        token!,
                                        emailController.text.trim(),
                                        otp,
                                      );
                                      
                                      if (result['success']) {
                                        Navigator.pop(context);
                                        setState(() {}); // Refresh screen
                                        _showSnackBar(
                                          isEditing 
                                              ? _localeService.get('email_changed_success')
                                              : _localeService.get('email_linked_success'),
                                          Colors.green,
                                        );
                                      } else {
                                        setSheetState(() {
                                          errorMessage = result['message'] ?? _localeService.get('verify_otp_failed');
                                          isLoading = false;
                                        });
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    currentStep == 0 
                                        ? _localeService.get('send_otp')
                                        : _localeService.get('complete'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
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
          );
        },
      ),
    );
  }

  Widget _buildEmailStepIndicator(int step, int currentStep, String label) {
    final isActive = step <= currentStep;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? Colors.cyan : _themeService.dividerColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isActive && step < currentStep
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : _themeService.textSecondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? _themeService.textPrimaryColor : _themeService.textSecondaryColor,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailStepLine(bool isActive) {
    return Container(
      height: 2,
      width: 40,
      margin: const EdgeInsets.only(bottom: 18),
      color: isActive ? Colors.cyan : _themeService.dividerColor,
    );
  }

  void _showAddPhoneDialog() {
    NavigationUtils.slideToScreen(
      context,
      const PhoneManagementScreen(),
    );
  }

  void _showDevicesDialog() {
    NavigationUtils.slideToScreen(
      context,
      const LoggedDevicesScreen(),
    );
  }

  void _showAnalyticsScreen() {
    NavigationUtils.slideToScreen(
      context,
      const AnalyticsScreen(),
    );
  }

  void _showActivityHistoryDialog() {
    NavigationUtils.slideToScreen(
      context,
      const ActivityHistoryScreen(),
    );
  }

  void _showBlockedAccountsDialog() {
    NavigationUtils.slideToScreen(
      context,
      const BlockedUsersScreen(),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.get('logout'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _localeService.get('logout_confirm'),
          style: TextStyle(color: _themeService.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localeService.get('cancel'), style: TextStyle(color: _themeService.textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement logout
              _showSnackBar(_localeService.get('success'), _themeService.snackBarBackground);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_localeService.get('logout')),
          ),
        ],
      ),
    );
  }

  void _showDeactivateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeactivateAccountSheet(
        themeService: _themeService,
        localeService: _localeService,
        apiService: _apiService,
        authService: _authService,
        onSuccess: () {
          // Log out after deactivation
          _authService.logout();
          Navigator.of(context).popUntil((route) => route.isFirst);
          _showSnackBar(_localeService.get('deactivate_success'), Colors.deepOrange);
        },
        onError: (message) {
          _showSnackBar(message, Colors.red);
        },
      ),
    );
  }
}

// Deactivate Account Bottom Sheet Widget
class _DeactivateAccountSheet extends StatefulWidget {
  final ThemeService themeService;
  final LocaleService localeService;
  final ApiService apiService;
  final AuthService authService;
  final VoidCallback onSuccess;
  final Function(String) onError;

  const _DeactivateAccountSheet({
    required this.themeService,
    required this.localeService,
    required this.apiService,
    required this.authService,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_DeactivateAccountSheet> createState() => _DeactivateAccountSheetState();
}

class _DeactivateAccountSheetState extends State<_DeactivateAccountSheet> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deactivateAccount() async {
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

      final result = await widget.apiService.deactivateAccount(
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
                      color: Colors.deepOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.pause_circle_outline, color: Colors.deepOrange, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.localeService.get('deactivate_account_title'),
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
              
              // Warning content
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.localeService.get('deactivate_account_warning'),
                      style: TextStyle(
                        color: widget.themeService.textPrimaryColor,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.deepOrange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.localeService.get('deactivate_duration'),
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Password field
              Text(
                widget.localeService.get('enter_password_to_deactivate'),
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
                    borderSide: const BorderSide(color: Colors.deepOrange),
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
                      onPressed: _isLoading ? null : _deactivateAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
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
                              widget.localeService.get('deactivate_account'),
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
