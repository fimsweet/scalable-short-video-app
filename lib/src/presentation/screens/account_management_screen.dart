import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

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
  
  bool _twoFactorEnabled = false;
  List<String> _twoFactorMethods = [];
  bool _biometricEnabled = false;
  bool _loginAlertsEnabled = true;
  bool _hasPassword = true; // Default to true, will be updated from API
  bool _isLoadingPassword = true;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _checkHasPassword();
    _load2FASettings();
  }

  Future<void> _checkHasPassword() async {
    final token = await _authService.getToken();
    if (token == null) {
      setState(() => _isLoadingPassword = false);
      return;
    }
    
    final result = await _apiService.hasPassword(token);
    if (mounted) {
      setState(() {
        _hasPassword = result['hasPassword'] ?? true;
        _isLoadingPassword = false;
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
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _themeService.iconColor),
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
          children: [
            const SizedBox(height: 16),
            
            // Security Section
            _buildSectionTitle(_localeService.get('security_section')),
            _isLoadingPassword 
                ? _buildMenuItem(
                    icon: Icons.lock_outline,
                    iconColor: Colors.orange,
                    title: '...',
                    subtitle: '',
                    onTap: () {},
                  )
                : _hasPassword
                    ? _buildMenuItem(
                        icon: Icons.lock_outline,
                        iconColor: Colors.orange,
                        title: _localeService.get('change_password'),
                        subtitle: _localeService.get('change_password_subtitle'),
                        onTap: () => _showChangePasswordDialog(),
                      )
                    : _buildMenuItem(
                        icon: Icons.lock_open,
                        iconColor: Colors.green,
                        title: _localeService.get('set_password'),
                        subtitle: _localeService.get('set_password_subtitle'),
                        onTap: () => _showSetPasswordDialog(),
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
                  setState(() => _twoFactorEnabled = true);
                  _showSetup2FADialog();
                } else {
                  // Show confirmation dialog with OTP verification to disable 2FA
                  _showDisable2FADialog();
                }
              },
            ),
            _buildSettingSwitch(
              icon: Icons.notifications_active_outlined,
              iconColor: Colors.purple,
              title: _localeService.get('login_alert'),
              subtitle: _localeService.get('login_alert_desc'),
              value: _loginAlertsEnabled,
              onChanged: (value) {
                setState(() => _loginAlertsEnabled = value);
                _showSnackBar(
                  value ? _localeService.get('enabled') : _localeService.get('disabled'),
                  _themeService.snackBarBackground,
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Account Info Section
            _buildSectionTitle(_localeService.get('account_info')),
            _buildMenuItem(
              icon: Icons.email_outlined,
              iconColor: Colors.cyan,
              title: _localeService.get('email'),
              subtitle: _authService.user?['email'] ?? _localeService.get('not_set'),
              onTap: () => _showChangeEmailDialog(),
            ),
            _buildMenuItem(
              icon: Icons.phone_outlined,
              iconColor: Colors.teal,
              title: _localeService.get('phone_number'),
              subtitle: _localeService.get('not_linked'),
              onTap: () => _showAddPhoneDialog(),
            ),
            _buildMenuItem(
              icon: Icons.devices_outlined,
              iconColor: Colors.indigo,
              title: _localeService.get('devices'),
              subtitle: _localeService.get('devices_subtitle'),
              onTap: () => _showDevicesDialog(),
            ),
            
            const SizedBox(height: 24),
            
            // Data & Privacy Section
            _buildSectionTitle(_localeService.get('data_privacy')),
            _buildMenuItem(
              icon: Icons.download_outlined,
              iconColor: Colors.blue,
              title: _localeService.get('download_data'),
              subtitle: _localeService.get('download_data_desc'),
              onTap: () => _showDownloadDataDialog(),
            ),
            _buildMenuItem(
              icon: Icons.history,
              iconColor: Colors.amber,
              title: _localeService.get('activity_history'),
              subtitle: _localeService.get('activity_history_desc'),
              onTap: () => _showActivityHistoryDialog(),
            ),
            _buildMenuItem(
              icon: Icons.block_outlined,
              iconColor: Colors.red[300]!,
              title: _localeService.get('blocked_list'),
              subtitle: _localeService.get('blocked_list_subtitle'),
              onTap: () => _showBlockedAccountsDialog(),
            ),
            
            const SizedBox(height: 24),
            
            // Danger Zone Section
            _buildSectionTitle(_localeService.get('danger_zone')),
            _buildMenuItem(
              icon: Icons.logout,
              iconColor: Colors.orange,
              title: _localeService.get('logout'),
              subtitle: _localeService.get('logout_confirm'),
              onTap: () => _showLogoutDialog(),
              showArrow: false,
            ),
            _buildMenuItem(
              icon: Icons.pause_circle_outline,
              iconColor: Colors.deepOrange,
              title: _localeService.get('deactivate_account'),
              subtitle: _localeService.get('deactivate_account_desc'),
              onTap: () => _showDeactivateDialog(),
              showArrow: false,
            ),
            _buildMenuItem(
              icon: Icons.delete_forever_outlined,
              iconColor: Colors.red,
              title: _localeService.get('delete_account'),
              subtitle: _localeService.get('delete_account_desc'),
              onTap: () => _showDeleteAccountDialog(),
              showArrow: false,
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _themeService.sectionTitleBackground,
      child: Text(
        title,
        style: TextStyle(
          color: _themeService.textSecondaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
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
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            color: _themeService.inputBackground,
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
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      children: [
        Container(
          color: _themeService.inputBackground,
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
        Container(
          margin: const EdgeInsets.only(left: 16),
          height: 0.5,
          color: _themeService.dividerColor,
        ),
      ],
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // Change Password Dialog
  void _showChangePasswordDialog() {
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
                          otpCode = value;
                          if (otpError != null) {
                            setSheetState(() => otpError = null);
                          }
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
                                setState(() => _twoFactorEnabled = false);
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
    setState(() => _twoFactorEnabled = false);
  }

  // Show dialog to disable 2FA with OTP verification
  void _showDisable2FADialog() {
    final user = _authService.user;
    final hasEmail = user != null && user['email'] != null;
    final hasPhone = user != null && user['phoneNumber'] != null;
    
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
                          otpCode = value;
                          if (otpError != null) {
                            setSheetState(() => otpError = null);
                          }
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
    _showSnackBar(_localeService.get('feature_developing'), _themeService.snackBarBackground);
  }

  void _showAddPhoneDialog() {
    _showSnackBar(_localeService.get('feature_developing'), _themeService.snackBarBackground);
  }

  void _showDevicesDialog() {
    _showSnackBar(_localeService.get('feature_developing'), _themeService.snackBarBackground);
  }

  void _showDownloadDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.get('download_data'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _localeService.get('download_data_desc'),
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
              _showSnackBar(_localeService.get('success'), Colors.green);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_localeService.get('request')),
          ),
        ],
      ),
    );
  }

  void _showActivityHistoryDialog() {
    _showSnackBar(_localeService.get('feature_developing'), _themeService.snackBarBackground);
  }

  void _showBlockedAccountsDialog() {
    _showSnackBar(_localeService.get('feature_developing'), _themeService.snackBarBackground);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.get('deactivate_account'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          _localeService.get('deactivate_account_desc'),
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
              _showSnackBar(_localeService.get('success'), Colors.deepOrange);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_localeService.get('deactivate_account')),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(
              _localeService.get('delete_account'),
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _localeService.get('action_cannot_undo'),
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _localeService.get('delete_account_warning'),
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localeService.get('cancel'), style: TextStyle(color: _themeService.textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showConfirmDeleteDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_localeService.get('delete_account')),
          ),
        ],
      ),
    );
  }

  void _showConfirmDeleteDialog() {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.get('confirm'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _localeService.get('please_enter_password'),
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: _themeService.textPrimaryColor),
              decoration: InputDecoration(
                labelText: _localeService.get('password'),
                labelStyle: TextStyle(color: _themeService.textSecondaryColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: _themeService.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.red),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localeService.get('cancel'), style: TextStyle(color: _themeService.textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement account deletion
              _showSnackBar(_localeService.get('success'), Colors.red);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_localeService.get('delete_permanently')),
          ),
        ],
      ),
    );
  }
}
