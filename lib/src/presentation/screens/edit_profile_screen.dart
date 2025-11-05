import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
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
  
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _linkController;
  
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _authService.username ?? '');
    _usernameController = TextEditingController(text: _authService.username ?? '');
    _bioController = TextEditingController(text: _authService.bio ?? '');
    _linkController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _linkController.dispose();
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sửa hồ sơ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Lưu',
                    style: TextStyle(
                      color: Colors.white,
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
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
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
              hint: 'Thêm tên',
              controller: _nameController,
              showArrow: true,
            ),
            _buildEditField(
              label: 'TikTok ID',
              hint: _usernameController.text,
              controller: _usernameController,
              showArrow: true,
              enabled: false,
            ),
            _buildProfileLink(),
            const SizedBox(height: 24),
            _buildSectionTitle('Tiểu sử'),
            _buildEditField(
              label: '',
              hint: 'Viết mô tả ngắn gọn để cho mọi người biết bạn là ai hoặc tài khoản của bạn tập trung vào chủ đề gì',
              controller: _bioController,
              maxLines: 4,
              showArrow: true,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Liên kết'),
            _buildEditField(
              label: '',
              hint: 'Thêm liên kết',
              controller: _linkController,
              showArrow: true,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Khác'),
            _buildMenuItem(
              title: 'Chương trình gây quỹ',
              subtitle: 'Thêm chương trình gây quỹ...',
              onTap: () {},
            ),
            _buildMenuItem(
              title: 'AI Self',
              subtitle: 'Thêm AI Self',
              onTap: () {},
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Thay đổi thứ tự hiển thị'),
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
        backgroundColor: Colors.grey[800],
        child: ClipOval(
          child: Image.network(
            fullUrl,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.person, size: 48, color: Colors.white);
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
      backgroundColor: Colors.grey[800],
      child: const Icon(Icons.person, size: 48, color: Colors.white),
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
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (label.isNotEmpty)
                SizedBox(
                  width: 100,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
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
                    color: enabled ? Colors.white : Colors.grey[600],
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
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
                  color: Colors.grey[600],
                  size: 24,
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

  Widget _buildProfileLink() {
    return Column(
      children: [
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'tiktok.com/@${_usernameController.text}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.copy,
                  color: Colors.grey[600],
                  size: 20,
                ),
                onPressed: () {
                  _showSnackBar('Đã sao chép liên kết', Colors.grey[700]!);
                },
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
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
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
}
