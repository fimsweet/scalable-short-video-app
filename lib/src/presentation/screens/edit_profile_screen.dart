import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/account_management_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  final ThemeService _themeService = ThemeService();
  
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _linkController;
  
  bool _isLoading = false;
  bool _isUploading = false;
  
  // Privacy settings
  bool _isPrivateAccount = false;
  bool _commentsDisabled = false;
  bool _allowSaveVideo = true;
  bool _pushNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _authService.username ?? '');
    _usernameController = TextEditingController(text: _authService.username ?? '');
    _bioController = TextEditingController(text: _authService.bio ?? '');
    _linkController = TextEditingController();
    _themeService.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _linkController.dispose();
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      final token = await _authService.getToken();
      if (token == null) {
        if (mounted) {
          _showSnackBar('Vui lòng đăng nhập lại', Colors.red);
        }
        return;
      }

      final result = await _apiService.uploadAvatar(
        token: token,
        imageFile: kIsWeb ? image : File(image.path),
      );

      if (result['success']) {
        final avatarUrl = result['data']['user']['avatar'];
        await _authService.updateAvatar(avatarUrl);

        if (mounted) {
          setState(() {});
          _showSnackBar('Cập nhật ảnh đại diện thành công!', Colors.green);
        }
      } else {
        if (mounted) {
          _showSnackBar(result['message'] ?? 'Upload thất bại', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        _showSnackBar('Vui lòng đăng nhập lại', Colors.red);
        return;
      }

      // Update bio if changed
      final newBio = _bioController.text.trim();
      if (newBio != _authService.bio) {
        final result = await _apiService.updateProfile(
          token: token,
          bio: newBio,
        );

        if (result['success']) {
          await _authService.updateBio(newBio);
          if (mounted) {
            _showSnackBar('Cập nhật thông tin thành công!', Colors.green);
            Navigator.pop(context, true);
          }
        } else {
          if (mounted) {
            _showSnackBar(result['message'] ?? 'Cập nhật thất bại', Colors.red);
          }
        }
      } else {
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi: $e', Colors.red);
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
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: _themeService.iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Sửa hồ sơ',
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _themeService.textPrimaryColor,
                    ),
                  )
                : Text(
                    'Lưu',
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Avatar section
            Center(
              child: GestureDetector(
                onTap: _pickAndUploadAvatar,
                child: Stack(
                  children: [
                    _buildAvatar(),
                    if (_isUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _themeService.isLightMode ? Colors.white54 : Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _themeService.textPrimaryColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _pickAndUploadAvatar,
              child: const Text(
                'Thay đổi ảnh',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Form fields
            _buildSectionTitle('Thông tin cơ bản'),
            _buildEditField(
              label: 'Tên',
              hint: 'Thêm Tên',
              controller: _nameController,
              showArrow: true,
            ),
            _buildEditField(
              label: 'Tiểu sử',
              hint: 'Thêm tiểu sử',
              controller: _bioController,
              maxLines: 3,
              showArrow: true,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Quyền riêng tư và bảo mật'),
            _buildSettingSwitch(
              title: 'Tài khoản riêng tư',
              subtitle: 'Chỉ người theo dõi mới có thể xem video của bạn',
              value: _isPrivateAccount,
              onChanged: (value) {
                setState(() {
                  _isPrivateAccount = value;
                });
                _showSnackBar(
                  value ? 'Đã bật tài khoản riêng tư' : 'Đã tắt tài khoản riêng tư',
                  _themeService.snackBarBackground,
                );
              },
            ),
            _buildMenuItem(
              title: 'Ai có thể xem video của bạn',
              subtitle: 'Mọi người',
              onTap: () {
                // TODO: Navigate to video privacy settings
              },
            ),
            _buildMenuItem(
              title: 'Ai có thể gửi tin nhắn cho bạn',
              subtitle: 'Bạn bè',
              onTap: () {
                // TODO: Navigate to message privacy settings
              },
            ),
            _buildMenuItem(
              title: 'Ai có thể Duet hoặc Stitch với video của bạn',
              subtitle: 'Mọi người',
              onTap: () {
                // TODO: Navigate to duet/stitch settings
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Tương tác'),
            _buildMenuItem(
              title: 'Quản lý bình luận',
              subtitle: 'Lọc và kiểm duyệt bình luận',
              onTap: () {
                // TODO: Navigate to comment management
              },
            ),
            _buildSettingSwitch(
              title: 'Tắt bình luận',
              subtitle: 'Tắt bình luận cho tất cả video của bạn',
              value: _commentsDisabled,
              onChanged: (value) {
                setState(() {
                  _commentsDisabled = value;
                });
                _showSnackBar(
                  value ? 'Đã tắt bình luận' : 'Đã bật bình luận',
                  _themeService.snackBarBackground,
                );
              },
            ),
            _buildSettingSwitch(
              title: 'Cho phép lưu video',
              subtitle: 'Người khác có thể lưu video của bạn',
              value: _allowSaveVideo,
              onChanged: (value) {
                setState(() {
                  _allowSaveVideo = value;
                });
                _showSnackBar(
                  value ? 'Đã cho phép lưu video' : 'Đã tắt lưu video',
                  _themeService.snackBarBackground,
                );
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Thông báo'),
            _buildMenuItem(
              title: 'Cài đặt thông báo',
              subtitle: 'Quản lý thông báo bạn nhận được',
              onTap: () {
                // TODO: Navigate to notification settings
              },
            ),
            _buildSettingSwitch(
              title: 'Thông báo đẩy',
              subtitle: 'Nhận thông báo về hoạt động mới',
              value: _pushNotificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _pushNotificationsEnabled = value;
                });
                _showSnackBar(
                  value ? 'Đã bật thông báo đẩy' : 'Đã tắt thông báo đẩy',
                  _themeService.snackBarBackground,
                );
              },
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Nội dung và hiển thị'),
            _buildSettingSwitch(
              title: 'Chế độ sáng',
              subtitle: 'Chuyển đổi giữa giao diện sáng và tối',
              value: _themeService.isLightMode,
              onChanged: (value) {
                _themeService.toggleTheme(value);
                _showSnackBar(
                  value ? 'Đã bật chế độ sáng' : 'Đã bật chế độ tối',
                  _themeService.snackBarBackground,
                );
              },
            ),
            _buildMenuItem(
              title: 'Ngôn ngữ',
              subtitle: 'Tiếng Việt',
              onTap: () {
                // TODO: Navigate to language settings
              },
            ),
            _buildMenuItem(
              title: 'Quản lý tài khoản',
              subtitle: 'Bảo mật, mật khẩu, xóa tài khoản',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccountManagementScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = _authService.avatarUrl;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      final fullUrl = _apiService.getAvatarUrl(avatarUrl);
      
      return CircleAvatar(
        radius: 48,
        backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
        child: ClipOval(
          child: Image.network(
            fullUrl,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.person, size: 48, color: _themeService.textPrimaryColor);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 48,
      backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
      child: Icon(Icons.person, size: 48, color: _themeService.textPrimaryColor),
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

  Widget _buildEditField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    bool showArrow = false,
    bool enabled = true,
  }) {
    return Column(
      children: [
        Container(
          color: _themeService.inputBackground,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (label.isNotEmpty)
                SizedBox(
                  width: 100,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  maxLines: maxLines,
                  style: TextStyle(
                    color: enabled ? _themeService.textPrimaryColor : _themeService.textSecondaryColor,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
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
        Container(
          margin: const EdgeInsets.only(left: 16),
          height: 0.5,
          color: _themeService.dividerColor,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            color: _themeService.inputBackground,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _themeService.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
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
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      children: [
        Container(
          color: _themeService.inputBackground,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.blue,
                activeTrackColor: Colors.blue.withOpacity(0.5),
                inactiveThumbColor: _themeService.isLightMode ? Colors.grey[400] : Colors.grey[600],
                inactiveTrackColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
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
}
