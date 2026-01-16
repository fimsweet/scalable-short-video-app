import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_settings_screen.dart';
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
  final LocaleService _localeService = LocaleService();
  
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _websiteController;
  late TextEditingController _locationController;
  
  String _selectedGender = '';
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _authService.username ?? '');
    _bioController = TextEditingController(text: _authService.bio ?? '');
    _websiteController = TextEditingController();
    _locationController = TextEditingController();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    _locationController.dispose();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
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

      setState(() => _isUploading = true);

      final token = await _authService.getToken();
      if (token == null) {
        if (mounted) _showSnackBar(_localeService.get('please_login_again'), Colors.red);
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
          _showSnackBar(_localeService.get('avatar_update_success'), Colors.green);
        }
      } else {
        if (mounted) {
          _showSnackBar(result['message'] ?? _localeService.get('upload_failed'), Colors.red);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('${_localeService.get('error')}: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
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

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _themeService.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _localeService.get('select_gender'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _themeService.textPrimaryColor,
                  ),
                ),
              ),
              Divider(height: 1, color: _themeService.dividerColor),
              _buildGenderOption(_localeService.get('male')),
              _buildGenderOption(_localeService.get('female')),
              _buildGenderOption(_localeService.get('other')),
              _buildGenderOption(_localeService.get('prefer_not_to_say')),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption(String gender) {
    return InkWell(
      onTap: () {
        setState(() => _selectedGender = gender);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                gender,
                style: TextStyle(
                  fontSize: 16,
                  color: _themeService.textPrimaryColor,
                ),
              ),
            ),
            if (_selectedGender == gender)
              const Icon(Icons.check, color: Colors.blue, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    try {
      final token = await _authService.getToken();
      if (token == null) {
        _showSnackBar(_localeService.get('please_login_again'), Colors.red);
        return;
      }

      final newBio = _bioController.text.trim();
      final newWebsite = _websiteController.text.trim();
      final newLocation = _locationController.text.trim();
      final newGender = _selectedGender;

      final result = await _apiService.updateProfile(
        token: token,
        bio: newBio.isNotEmpty ? newBio : null,
        website: newWebsite.isNotEmpty ? newWebsite : null,
        location: newLocation.isNotEmpty ? newLocation : null,
        gender: newGender.isNotEmpty ? newGender : null,
      );

      if (result['success']) {
        await _authService.updateBio(newBio);
        if (mounted) {
          _showSnackBar(_localeService.get('update_success'), Colors.green);
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          _showSnackBar(result['message'] ?? _localeService.get('update_failed'), Colors.red);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar('${_localeService.get('error')}: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          _localeService.get('edit_profile'),
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
                    _localeService.get('save'),
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
              child: Text(
                _localeService.get('change_photo'),
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Section: Thông tin cơ bản
            _buildSectionTitle(_localeService.get('basic_info')),
            _buildEditField(
              label: _localeService.get('name'),
              hint: _localeService.get('add_name'),
              controller: _nameController,
              enabled: false,
            ),
            _buildEditField(
              label: _localeService.get('bio'),
              hint: _localeService.get('add_bio'),
              controller: _bioController,
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            // Section: Thông tin liên hệ
            _buildSectionTitle(_localeService.get('additional_info')),
            _buildEditField(
              label: _localeService.get('website'),
              hint: _localeService.get('add_website'),
              controller: _websiteController,
            ),
            _buildEditField(
              label: _localeService.get('location'),
              hint: _localeService.get('add_location'),
              controller: _locationController,
            ),
            _buildTapField(
              label: _localeService.get('gender'),
              value: _selectedGender.isEmpty ? _localeService.get('select_gender') : _selectedGender,
              onTap: _showGenderPicker,
            ),
            
            const SizedBox(height: 24),
            
            // Link to Settings - simple blue text like Instagram
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserSettingsScreen()),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  _localeService.get('account_settings'),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                  ),
                ),
              ),
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
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
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

  Widget _buildEditField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
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
              SizedBox(
                width: 80,
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

  Widget _buildTapField({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final isPlaceholder = value == _localeService.get('select_gender');
    
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            color: _themeService.inputBackground,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isPlaceholder ? _themeService.textSecondaryColor : _themeService.textPrimaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: _themeService.textSecondaryColor, size: 20),
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
}
