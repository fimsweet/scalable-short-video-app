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
  
  bool _twoFactorEnabled = false;
  bool _biometricEnabled = false;
  bool _loginAlertsEnabled = true;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
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
            _buildMenuItem(
              icon: Icons.lock_outline,
              iconColor: Colors.orange,
              title: _localeService.get('change_password'),
              subtitle: _localeService.get('change_password_subtitle'),
              onTap: () => _showChangePasswordDialog(),
            ),
            _buildSettingSwitch(
              icon: Icons.security,
              iconColor: Colors.blue,
              title: _localeService.get('two_factor_auth'),
              subtitle: _twoFactorEnabled 
                  ? _localeService.get('two_factor_on')
                  : _localeService.get('two_factor_off'),
              value: _twoFactorEnabled,
              onChanged: (value) {
                setState(() {
                  _twoFactorEnabled = value;
                });
                if (value) {
                  _showSetup2FADialog();
                } else {
                  _showSnackBar(_localeService.get('disabled'), _themeService.snackBarBackground);
                }
              },
            ),
            _buildSettingSwitch(
              icon: Icons.fingerprint,
              iconColor: Colors.green,
              title: _localeService.get('biometric_login'),
              subtitle: _localeService.get('biometric_desc'),
              value: _biometricEnabled,
              onChanged: (value) {
                setState(() => _biometricEnabled = value);
                _showSnackBar(
                  value ? _localeService.get('enabled') : _localeService.get('disabled'),
                  _themeService.snackBarBackground,
                );
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
                activeColor: Colors.blue,
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

  // Setup 2FA Dialog
  void _showSetup2FADialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Text(
              'Xác thực hai yếu tố',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _localeService.get('select_2fa_method'),
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 16),
            _build2FAOption(
              icon: Icons.sms_outlined,
              title: 'SMS',
              subtitle: _localeService.get('sms_subtitle'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(_localeService.get('2fa_sms_enabled'), Colors.green);
              },
            ),
            const SizedBox(height: 12),
            _build2FAOption(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: _localeService.get('email_subtitle'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(_localeService.get('2fa_email_enabled'), Colors.green);
              },
            ),
            const SizedBox(height: 12),
            _build2FAOption(
              icon: Icons.apps,
              title: _localeService.get('authenticator_app'),
              subtitle: 'Google Authenticator, Authy',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(_localeService.get('2fa_app_enabled'), Colors.green);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _twoFactorEnabled = false);
              Navigator.pop(context);
            },
            child: Text('Hủy', style: TextStyle(color: Colors.grey[400])),
          ),
        ],
      ),
    );
  }

  Widget _build2FAOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600]),
          ],
        ),
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
