import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final ApiService _apiService = ApiService();

  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FocusNode _currentFocus = FocusNode();
  final FocusNode _newFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  // Validation state
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _newPasswordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _validatePassword() {
    final password = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _passwordsMatch = password.isNotEmpty && password == confirm;
    });
  }

  bool get _isFormValid =>
      _currentPasswordController.text.isNotEmpty &&
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _passwordsMatch;

  Future<void> _changePassword() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      final token = await _authService.getToken();
      if (token == null) {
        _showSnackBar(
          _localeService.isVietnamese ? 'Phiên đăng nhập hết hạn' : 'Session expired',
          Colors.red,
        );
        return;
      }

      final result = await _apiService.changePassword(
        token: token,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _showSnackBar(
          _localeService.isVietnamese ? 'Đổi mật khẩu thành công' : 'Password changed successfully',
          Colors.green,
        );
        Navigator.pop(context);
      } else {
        final msg = result['message'] ?? '';
        String displayMsg;
        if (msg.toString().toLowerCase().contains('incorrect') ||
            msg.toString().toLowerCase().contains('sai')) {
          displayMsg = _localeService.isVietnamese
              ? 'Mật khẩu hiện tại không đúng'
              : 'Current password is incorrect';
        } else {
          displayMsg = _localeService.isVietnamese
              ? 'Đổi mật khẩu thất bại'
              : 'Failed to change password';
        }
        _showSnackBar(displayMsg, Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          _localeService.isVietnamese ? 'Có lỗi xảy ra' : 'An error occurred',
          Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
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
          _localeService.isVietnamese ? 'Đổi mật khẩu' : 'Change Password',
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header icon
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, color: Colors.orange, size: 36),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _localeService.isVietnamese
                    ? 'Hãy đặt mật khẩu mạnh để bảo vệ tài khoản'
                    : 'Set a strong password to protect your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Current password
            _buildLabel(_localeService.isVietnamese ? 'Mật khẩu hiện tại' : 'Current Password'),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _currentPasswordController,
              focusNode: _currentFocus,
              obscure: _obscureCurrent,
              onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
              hint: _localeService.isVietnamese ? 'Nhập mật khẩu hiện tại' : 'Enter current password',
              onSubmitted: (_) => FocusScope.of(context).requestFocus(_newFocus),
            ),
            const SizedBox(height: 20),

            // New password
            _buildLabel(_localeService.isVietnamese ? 'Mật khẩu mới' : 'New Password'),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _newPasswordController,
              focusNode: _newFocus,
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              hint: _localeService.isVietnamese ? 'Nhập mật khẩu mới' : 'Enter new password',
              onSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmFocus),
            ),
            const SizedBox(height: 20),

            // Confirm password
            _buildLabel(_localeService.isVietnamese ? 'Xác nhận mật khẩu mới' : 'Confirm New Password'),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _confirmPasswordController,
              focusNode: _confirmFocus,
              obscure: _obscureConfirm,
              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
              hint: _localeService.isVietnamese ? 'Nhập lại mật khẩu mới' : 'Re-enter new password',
              onSubmitted: (_) => _isFormValid ? _changePassword() : null,
            ),
            const SizedBox(height: 20),

            // Password requirements checklist
            _buildRequirementsCard(),
            const SizedBox(height: 28),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isFormValid && !_isLoading ? _changePassword : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFormValid
                      ? ThemeService.accentColor
                      : (_themeService.isLightMode ? Colors.grey[300] : Colors.grey[700]),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: _themeService.isLightMode ? Colors.grey[500] : Colors.grey[400],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        _localeService.isVietnamese ? 'Đổi mật khẩu' : 'Change Password',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _themeService.textPrimaryColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool obscure,
    required VoidCallback onToggle,
    required String hint,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.white : _themeService.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _themeService.isLightMode
              ? const Color(0xFFDDDDDD)
              : Colors.transparent,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscure,
        onSubmitted: onSubmitted,
        style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: _themeService.textSecondaryColor.withOpacity(0.5),
            fontSize: 15,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _themeService.textSecondaryColor,
              size: 20,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.white : _themeService.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _themeService.isLightMode
              ? const Color(0xFFDDDDDD)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _localeService.isVietnamese ? 'Yêu cầu mật khẩu' : 'Password requirements',
            style: TextStyle(
              color: _themeService.textPrimaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirement(
            _localeService.isVietnamese ? 'Ít nhất 8 ký tự' : 'At least 8 characters',
            _hasMinLength,
          ),
          const SizedBox(height: 8),
          _buildRequirement(
            _localeService.isVietnamese ? 'Có chữ hoa (A-Z)' : 'Has uppercase letter (A-Z)',
            _hasUppercase,
          ),
          const SizedBox(height: 8),
          _buildRequirement(
            _localeService.isVietnamese ? 'Có chữ thường (a-z)' : 'Has lowercase letter (a-z)',
            _hasLowercase,
          ),
          const SizedBox(height: 8),
          _buildRequirement(
            _localeService.isVietnamese ? 'Có số (0-9)' : 'Has number (0-9)',
            _hasNumber,
          ),
          const SizedBox(height: 8),
          _buildRequirement(
            _localeService.isVietnamese ? 'Mật khẩu xác nhận trùng khớp' : 'Passwords match',
            _passwordsMatch,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 18,
          color: met ? ThemeService.successColor : _themeService.textSecondaryColor.withOpacity(0.4),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: met ? _themeService.textPrimaryColor : _themeService.textSecondaryColor,
              fontSize: 13,
              fontWeight: met ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
