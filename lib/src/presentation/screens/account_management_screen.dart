import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  final AuthService _authService = AuthService();
  
  bool _twoFactorEnabled = false;
  bool _biometricEnabled = false;
  bool _loginAlertsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Quản lý tài khoản',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // Security Section
            _buildSectionTitle('Bảo mật'),
            _buildMenuItem(
              icon: Icons.lock_outline,
              iconColor: Colors.orange,
              title: 'Đổi mật khẩu',
              subtitle: 'Cập nhật mật khẩu của bạn',
              onTap: () => _showChangePasswordDialog(),
            ),
            _buildSettingSwitch(
              icon: Icons.security,
              iconColor: Colors.blue,
              title: 'Xác thực hai yếu tố',
              subtitle: _twoFactorEnabled 
                  ? 'Đang bật - Bảo vệ tài khoản với xác thực 2 lớp'
                  : 'Tăng cường bảo mật cho tài khoản',
              value: _twoFactorEnabled,
              onChanged: (value) {
                setState(() {
                  _twoFactorEnabled = value;
                });
                if (value) {
                  _showSetup2FADialog();
                } else {
                  _showSnackBar('Đã tắt xác thực hai yếu tố', Colors.grey[700]!);
                }
              },
            ),
            _buildSettingSwitch(
              icon: Icons.fingerprint,
              iconColor: Colors.green,
              title: 'Sinh trắc học',
              subtitle: 'Đăng nhập bằng vân tay hoặc FaceID',
              value: _biometricEnabled,
              onChanged: (value) {
                setState(() => _biometricEnabled = value);
                _showSnackBar(
                  value ? 'Đã bật sinh trắc học' : 'Đã tắt sinh trắc học',
                  Colors.grey[700]!,
                );
              },
            ),
            _buildSettingSwitch(
              icon: Icons.notifications_active_outlined,
              iconColor: Colors.purple,
              title: 'Cảnh báo đăng nhập',
              subtitle: 'Thông báo khi có đăng nhập mới',
              value: _loginAlertsEnabled,
              onChanged: (value) {
                setState(() => _loginAlertsEnabled = value);
                _showSnackBar(
                  value ? 'Đã bật cảnh báo đăng nhập' : 'Đã tắt cảnh báo đăng nhập',
                  Colors.grey[700]!,
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Account Info Section
            _buildSectionTitle('Thông tin tài khoản'),
            _buildMenuItem(
              icon: Icons.email_outlined,
              iconColor: Colors.cyan,
              title: 'Email',
              subtitle: _authService.user?['email'] ?? 'Chưa cài đặt',
              onTap: () => _showChangeEmailDialog(),
            ),
            _buildMenuItem(
              icon: Icons.phone_outlined,
              iconColor: Colors.teal,
              title: 'Số điện thoại',
              subtitle: 'Chưa liên kết',
              onTap: () => _showAddPhoneDialog(),
            ),
            _buildMenuItem(
              icon: Icons.devices_outlined,
              iconColor: Colors.indigo,
              title: 'Thiết bị đã đăng nhập',
              subtitle: 'Quản lý các thiết bị đã đăng nhập',
              onTap: () => _showDevicesDialog(),
            ),
            
            const SizedBox(height: 24),
            
            // Data & Privacy Section
            _buildSectionTitle('Dữ liệu & Quyền riêng tư'),
            _buildMenuItem(
              icon: Icons.download_outlined,
              iconColor: Colors.blue,
              title: 'Tải dữ liệu của bạn',
              subtitle: 'Yêu cầu bản sao dữ liệu tài khoản',
              onTap: () => _showDownloadDataDialog(),
            ),
            _buildMenuItem(
              icon: Icons.history,
              iconColor: Colors.amber,
              title: 'Lịch sử hoạt động',
              subtitle: 'Xem lịch sử đăng nhập và hoạt động',
              onTap: () => _showActivityHistoryDialog(),
            ),
            _buildMenuItem(
              icon: Icons.block_outlined,
              iconColor: Colors.red[300]!,
              title: 'Tài khoản đã chặn',
              subtitle: 'Quản lý danh sách chặn',
              onTap: () => _showBlockedAccountsDialog(),
            ),
            
            const SizedBox(height: 24),
            
            // Danger Zone Section
            _buildSectionTitle('Vùng nguy hiểm'),
            _buildMenuItem(
              icon: Icons.logout,
              iconColor: Colors.orange,
              title: 'Đăng xuất',
              subtitle: 'Đăng xuất khỏi tài khoản này',
              onTap: () => _showLogoutDialog(),
              showArrow: false,
            ),
            _buildMenuItem(
              icon: Icons.pause_circle_outline,
              iconColor: Colors.deepOrange,
              title: 'Vô hiệu hóa tài khoản',
              subtitle: 'Tạm thời ẩn hồ sơ của bạn',
              onTap: () => _showDeactivateDialog(),
              showArrow: false,
            ),
            _buildMenuItem(
              icon: Icons.delete_forever_outlined,
              iconColor: Colors.red,
              title: 'Xóa tài khoản',
              subtitle: 'Xóa vĩnh viễn tài khoản và dữ liệu',
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
      color: Colors.grey[900],
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
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
            color: Colors.black,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showArrow)
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[600],
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 16),
          height: 0.5,
          color: Colors.grey[900],
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
          color: Colors.black,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
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
          color: Colors.grey[900],
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Đổi mật khẩu',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey[500],
                      ),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey[500],
                      ),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    labelStyle: TextStyle(color: Colors.grey[500]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.blue),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey[500],
                      ),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Mật khẩu phải có ít nhất 8 ký tự, bao gồm chữ hoa, chữ thường và số',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy', style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement password change
                Navigator.pop(context);
                _showSnackBar('Đổi mật khẩu thành công', Colors.green);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Xác nhận'),
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
        backgroundColor: Colors.grey[900],
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
              'Chọn phương thức xác thực:',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 16),
            _build2FAOption(
              icon: Icons.sms_outlined,
              title: 'SMS',
              subtitle: 'Nhận mã qua tin nhắn',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Đã bật xác thực qua SMS', Colors.green);
              },
            ),
            const SizedBox(height: 12),
            _build2FAOption(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: 'Nhận mã qua email',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Đã bật xác thực qua Email', Colors.green);
              },
            ),
            const SizedBox(height: 12),
            _build2FAOption(
              icon: Icons.apps,
              title: 'Ứng dụng xác thực',
              subtitle: 'Google Authenticator, Authy',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Đã bật xác thực qua ứng dụng', Colors.green);
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
    _showSnackBar('Tính năng đang phát triển', Colors.grey[700]!);
  }

  void _showAddPhoneDialog() {
    _showSnackBar('Tính năng đang phát triển', Colors.grey[700]!);
  }

  void _showDevicesDialog() {
    _showSnackBar('Tính năng đang phát triển', Colors.grey[700]!);
  }

  void _showDownloadDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Tải dữ liệu của bạn',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Chúng tôi sẽ chuẩn bị một bản sao dữ liệu tài khoản của bạn. Quá trình này có thể mất vài phút đến vài giờ tùy thuộc vào lượng dữ liệu.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Yêu cầu đã được gửi. Bạn sẽ nhận được email khi dữ liệu sẵn sàng.', Colors.green);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Yêu cầu'),
          ),
        ],
      ),
    );
  }

  void _showActivityHistoryDialog() {
    _showSnackBar('Tính năng đang phát triển', Colors.grey[700]!);
  }

  void _showBlockedAccountsDialog() {
    _showSnackBar('Tính năng đang phát triển', Colors.grey[700]!);
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement logout
              _showSnackBar('Đã đăng xuất', Colors.grey[700]!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  void _showDeactivateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Vô hiệu hóa tài khoản',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Hồ sơ của bạn sẽ bị ẩn và bạn có thể kích hoạt lại bất cứ lúc nào bằng cách đăng nhập.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Tài khoản đã được vô hiệu hóa', Colors.deepOrange);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Vô hiệu hóa'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Xóa tài khoản',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hành động này không thể hoàn tác!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Tất cả dữ liệu của bạn sẽ bị xóa vĩnh viễn, bao gồm:\n\n• Video và ảnh\n• Bình luận và thích\n• Tin nhắn\n• Danh sách theo dõi\n• Tất cả hoạt động',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: Colors.grey[400])),
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
            child: const Text('Xóa tài khoản'),
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
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xác nhận xóa tài khoản',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Nhập mật khẩu của bạn để xác nhận:',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                labelStyle: TextStyle(color: Colors.grey[500]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[700]!),
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
            child: Text('Hủy', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement account deletion
              _showSnackBar('Tài khoản đã được xóa', Colors.red);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
  }
}
