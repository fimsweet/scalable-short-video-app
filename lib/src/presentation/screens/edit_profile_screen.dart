import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_settings_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
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
  
  String _selectedGender = '';
  DateTime? _selectedDateOfBirth;
  bool _isLoading = false;
  bool _isUploading = false;
  
  // Account info
  String? _linkedEmail;
  String? _linkedPhone;
  String? _authProvider;
  
  // Track original values for unsaved changes detection
  String _originalBio = '';
  String _originalGender = '';
  DateTime? _originalDateOfBirth;
  
  // Bio expand/collapse state
  bool _isBioExpanded = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _authService.username ?? '');
    _bioController = TextEditingController(text: _authService.bio ?? '');
    _originalBio = _authService.bio ?? '';
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final token = await _authService.getToken();
    if (token == null) return;
    
    final userData = await _apiService.getUserById((_authService.userId ?? 0).toString());
    if (userData != null && mounted) {
      setState(() {
        _selectedGender = userData['gender'] ?? '';
        _originalGender = _selectedGender;
        if (userData['dateOfBirth'] != null) {
          try {
            _selectedDateOfBirth = DateTime.parse(userData['dateOfBirth']);
            _originalDateOfBirth = _selectedDateOfBirth;
          } catch (e) {
            print('Error parsing date: $e');
          }
        }
      });
    }
    
    // Load account info
    await _loadAccountInfo();
  }

  Future<void> _loadAccountInfo() async {
    final token = await _authService.getToken();
    if (token == null) return;
    
    try {
      final result = await _apiService.getAccountInfo(token);
      if (result['success'] == true && result['data'] != null && mounted) {
        final accountInfo = result['data'] as Map<String, dynamic>;
        setState(() {
          _authProvider = accountInfo['authProvider'] as String?;
          
          // Check if user has a real email (not placeholder)
          final email = accountInfo['email'] as String?;
          if (email != null && !email.contains('@phone.user')) {
            _linkedEmail = email;
          }
          
          // Check if user has a phone number
          final phone = accountInfo['phoneNumber'] as String?;
          if (phone != null && phone.isNotEmpty) {
            _linkedPhone = phone;
          }
        });
        print('📱 Account info loaded: email=$_linkedEmail, phone=$_linkedPhone, provider=$_authProvider');
      }
    } catch (e) {
      print('Error loading account info: $e');
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }
  
  // Check if there are unsaved changes
  bool _hasUnsavedChanges() {
    final currentBio = _bioController.text.trim();
    final bioChanged = currentBio != _originalBio;
    final genderChanged = _selectedGender != _originalGender;
    final dateChanged = _selectedDateOfBirth != _originalDateOfBirth;
    
    return bioChanged || genderChanged || dateChanged;
  }
  
  // Show confirmation dialog when trying to exit with unsaved changes
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges()) {
      return true;
    }
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _localeService.isVietnamese ? 'Thay đổi chưa lưu' : 'Unsaved Changes',
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          _localeService.isVietnamese 
              ? 'Bạn có thay đổi chưa được lưu. Bạn muốn lưu trước khi rời đi không?' 
              : 'You have unsaved changes. Do you want to save before leaving?',
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 15,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // Discard button
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              _localeService.isVietnamese ? 'Bỏ thay đổi' : 'Discard',
              style: TextStyle(
                color: Colors.red,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              _localeService.isVietnamese ? 'Tiếp tục chỉnh sửa' : 'Keep Editing',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Save button
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeService.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _localeService.isVietnamese ? 'Lưu' : 'Save',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    
    if (result == 'save') {
      await _saveProfile();
      return false; // _saveProfile will handle navigation
    } else if (result == 'discard') {
      return true;
    }
    return false; // cancel - stay on page
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
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

  // Helper function to get gender display text based on stored key
  String _getGenderDisplayText(String genderKey) {
    switch (genderKey.toLowerCase()) {
      case 'male':
        return _localeService.get('male');
      case 'female':
        return _localeService.get('female');
      case 'other':
        return _localeService.get('other');
      case 'prefer_not_to_say':
        return _localeService.get('prefer_not_to_say');
      default:
        return genderKey; // fallback to raw value if not recognized
    }
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
              // Store key values (male, female, etc.) not translated text
              _buildGenderOption('male', _localeService.get('male')),
              _buildGenderOption('female', _localeService.get('female')),
              _buildGenderOption('other', _localeService.get('other')),
              _buildGenderOption('prefer_not_to_say', _localeService.get('prefer_not_to_say')),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption(String genderKey, String displayText) {
    return InkWell(
      onTap: () {
        setState(() => _selectedGender = genderKey);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayText,
                style: TextStyle(
                  fontSize: 16,
                  color: _themeService.textPrimaryColor,
                ),
              ),
            ),
            if (_selectedGender.toLowerCase() == genderKey.toLowerCase())
              const Icon(Icons.check, color: Colors.blue, size: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final initialDate = _selectedDateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: _themeService.isLightMode
              ? ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Colors.red,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                )
              : ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: Colors.red,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = pickedDate;
      });
    }
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
      final newGender = _selectedGender;
      final newDateOfBirth = _selectedDateOfBirth != null 
          ? '${_selectedDateOfBirth!.year}-${_selectedDateOfBirth!.month.toString().padLeft(2, '0')}-${_selectedDateOfBirth!.day.toString().padLeft(2, '0')}'
          : null;

      final result = await _apiService.updateProfile(
        token: token,
        bio: newBio.isNotEmpty ? newBio : null,
        gender: newGender.isNotEmpty ? newGender : null,
        dateOfBirth: newDateOfBirth,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _themeService.isLightMode 
            ? const Color(0xFFF5F5F5) 
            : _themeService.backgroundColor,
        appBar: AppBar(
          backgroundColor: _themeService.appBarBackground,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: _themeService.iconColor),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Center(
              child: TextButton(
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
            ),
            
            const SizedBox(height: 24),
            
            // Section: Basic Info
            _buildSectionTitle(_localeService.get('basic_info')),
            _buildSettingsGroup([
              _buildEditField(
                label: _localeService.get('name'),
                hint: _localeService.get('add_name'),
                controller: _nameController,
                enabled: false,
                showDivider: true,
              ),
              _buildCollapsibleBioField(showDivider: false),
            ]),
            
            const SizedBox(height: 24),
            
            // Section: Additional Info
            _buildSectionTitle(_localeService.get('additional_info')),
            _buildSettingsGroup([
              _buildTapField(
                label: _localeService.get('date_of_birth'),
                value: _selectedDateOfBirth != null 
                    ? '${_selectedDateOfBirth!.day.toString().padLeft(2, '0')}/${_selectedDateOfBirth!.month.toString().padLeft(2, '0')}/${_selectedDateOfBirth!.year}'
                    : _localeService.get('select_date_of_birth'),
                onTap: _showDatePicker,
                showDivider: true,
              ),
              _buildTapField(
                label: _localeService.get('gender'),
                value: _selectedGender.isEmpty ? _localeService.get('select_gender') : _getGenderDisplayText(_selectedGender),
                onTap: _showGenderPicker,
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Section: Account Info
            _buildSectionTitle(_localeService.get('account_info')),
            _buildSettingsGroup([
              _buildAccountInfoSection(),
            ]),
            
            const SizedBox(height: 24),
            
            // Link to Settings
            _buildSettingsGroup([
              InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const UserSettingsScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Text(
                    _localeService.get('account_settings'),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ]),
            
            const SizedBox(height: 100),
          ],
        ),
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
        color: _themeService.inputBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: children,
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
    bool showDivider = false,
  }) {
    return Column(
      children: [
        Container(
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
        if (showDivider)
          Container(
            margin: const EdgeInsets.only(left: 16),
            height: 0.5,
            color: _themeService.dividerColor,
          ),
      ],
    );
  }

  Widget _buildCollapsibleBioField({bool showDivider = false}) {
    final hasBio = _bioController.text.trim().isNotEmpty;
    
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isBioExpanded = !_isBioExpanded;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    _localeService.get('bio'),
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    hasBio 
                        ? _localeService.get('tap_to_edit_bio')
                        : _localeService.get('add_bio'),
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedRotation(
                  turns: _isBioExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: _themeService.textSecondaryColor,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Animated expand section
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _isBioExpanded
              ? Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _themeService.isLightMode 
                          ? Colors.grey[100] 
                          : Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _themeService.isLightMode
                            ? Colors.grey[300]!
                            : Colors.grey[700]!,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _bioController,
                      maxLines: 4,
                      maxLength: 150,
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: _localeService.get('add_bio'),
                        hintStyle: TextStyle(
                          color: _themeService.textSecondaryColor.withAlpha(150),
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                        counterStyle: TextStyle(
                          color: _themeService.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {}); // Update preview text
                      },
                    ),
                  ),
                )
              : const SizedBox.shrink(),
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

  Widget _buildTapField({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool showDivider = false,
  }) {
    final isPlaceholder = value == _localeService.get('select_gender');
    
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isPlaceholder 
                          ? _themeService.textSecondaryColor 
                          : _themeService.textPrimaryColor,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: _themeService.textSecondaryColor, size: 20),
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

  Widget _buildAccountInfoSection() {
    final hasEmail = _linkedEmail != null && _linkedEmail!.isNotEmpty;
    final hasPhone = _linkedPhone != null && _linkedPhone!.isNotEmpty;
    
    return Column(
      children: [
        // Email row
        _buildAccountInfoItem(
          icon: Icons.email_outlined,
          label: 'Email',
          value: hasEmail ? _linkedEmail! : null,
          onTap: () => _showEmailBottomSheet(hasEmail ? _linkedEmail : null),
          showDivider: true,
        ),
        
        // Phone row
        _buildAccountInfoItem(
          icon: Icons.phone_outlined,
          label: _localeService.get('phone_number'),
          value: hasPhone ? ApiService.formatPhoneForDisplay(_linkedPhone!) : null,
          onTap: () => _showPhoneBottomSheet(hasPhone ? _linkedPhone : null),
        ),
      ],
    );
  }

  Widget _buildAccountInfoItem({
    required IconData icon,
    required String label,
    String? value,
    required VoidCallback onTap,
    bool showDivider = false,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon, 
                  color: _themeService.textSecondaryColor, 
                  size: 22,
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    hasValue ? value! : _localeService.get('not_linked'),
                    style: TextStyle(
                      color: hasValue 
                          ? _themeService.textPrimaryColor 
                          : Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  hasValue ? Icons.edit_outlined : Icons.add,
                  color: hasValue ? _themeService.textSecondaryColor : Colors.blue,
                  size: 20,
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

  // ===== MODERN BOTTOM SHEET DIALOGS =====

  void _showEmailBottomSheet(String? currentEmail) {
    final emailController = TextEditingController(text: currentEmail ?? '');
    final otpController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    int currentStep = 0; // 0: email, 1: OTP, 2: password (only for phone users adding new email)
    bool isLoading = false;
    String? errorMessage;
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;
    final isEditing = currentEmail != null;
    
    // Determine if password step is needed:
    // - Phone user adding NEW email -> needs password to login via email
    // - Google user changing email -> no password needed (they login via Google)
    // - Anyone editing existing email -> no password needed (keep existing password)
    final needsPasswordStep = _authProvider == 'phone' && !isEditing;
    final totalSteps = needsPasswordStep ? 3 : 2;

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
                    
                    // Step indicator - dynamic based on needsPasswordStep
                    Row(
                      children: [
                        _buildStepIndicator(0, currentStep, _localeService.get('email')),
                        _buildStepLine(currentStep >= 1),
                        _buildStepIndicator(1, currentStep, 'OTP'),
                        if (needsPasswordStep) ...[
                          _buildStepLine(currentStep >= 2),
                          _buildStepIndicator(2, currentStep, _localeService.get('password')),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Title based on step
                    Text(
                      currentStep == 0 
                          ? (isEditing ? _localeService.get('change_email') : _localeService.get('link_email'))
                          : currentStep == 1 
                              ? _localeService.get('verify_email')
                              : _localeService.get('set_password_for_email'),
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
                          : currentStep == 1 
                              ? _localeService.get('enter_otp_sent_to_email')
                              : _localeService.get('set_password_to_login_with_email'),
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
                          filled: true,
                          fillColor: _themeService.inputBackground,
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
                          color: _themeService.inputBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              color: _themeService.textSecondaryColor,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              emailController.text,
                              style: TextStyle(
                                color: _themeService.textPrimaryColor,
                                fontSize: 16,
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
                          fillColor: _themeService.inputBackground,
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
                    
                    // Step 2: Password input (only for phone users adding new email)
                    if (currentStep == 2 && needsPasswordStep) ...[
                      // Show email
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _themeService.inputBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${_localeService.get('email_verified')}: ${emailController.text}',
                                style: TextStyle(
                                  color: _themeService.textPrimaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Password
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        autofocus: true,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: _localeService.get('password'),
                          hintStyle: TextStyle(
                            color: _themeService.textSecondaryColor.withAlpha(128),
                          ),
                          filled: true,
                          fillColor: _themeService.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: _themeService.textSecondaryColor,
                            ),
                            onPressed: () => setSheetState(() => obscurePassword = !obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Confirm password
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: _localeService.get('confirm_password'),
                          hintStyle: TextStyle(
                            color: _themeService.textSecondaryColor.withAlpha(128),
                          ),
                          filled: true,
                          fillColor: _themeService.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: _themeService.textSecondaryColor,
                            ),
                            onPressed: () => setSheetState(() => obscureConfirmPassword = !obscureConfirmPassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _localeService.get('password_min_6_chars'),
                        style: TextStyle(
                          color: _themeService.textSecondaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    
                    // Error message
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      children: [
                        // Back/Cancel button
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              if (currentStep > 0) {
                                setSheetState(() {
                                  currentStep--;
                                  errorMessage = null;
                                });
                              } else {
                                Navigator.pop(context);
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              currentStep > 0 ? _localeService.get('back') : _localeService.get('cancel'),
                              style: TextStyle(
                                color: _themeService.textSecondaryColor,
                                fontSize: 16,
                              ),
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
                                      
                                      if (needsPasswordStep) {
                                        // Move to password step for phone users adding new email
                                        setSheetState(() {
                                          currentStep = 2;
                                          errorMessage = null;
                                        });
                                      } else {
                                        // Complete immediately for Google users or email changes (no password needed)
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
                                          setState(() {
                                            _linkedEmail = emailController.text.trim();
                                          });
                                          _showSnackBar(_localeService.get('email_linked_success'), Colors.green);
                                        } else {
                                          setSheetState(() {
                                            errorMessage = result['message'] ?? _localeService.get('verify_otp_failed');
                                            isLoading = false;
                                          });
                                        }
                                      }
                                    } else if (currentStep == 2) {
                                      // Step 2: Set password and complete linking (phone users only)
                                      final password = passwordController.text;
                                      final confirmPassword = confirmPasswordController.text;
                                      
                                      if (password.length < 6) {
                                        setSheetState(() => errorMessage = _localeService.get('password_too_short'));
                                        return;
                                      }
                                      
                                      if (password != confirmPassword) {
                                        setSheetState(() => errorMessage = _localeService.get('passwords_not_match'));
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
                                        otpController.text.trim(),
                                        password: password,
                                      );
                                      
                                      if (result['success']) {
                                        Navigator.pop(context);
                                        setState(() {
                                          _linkedEmail = emailController.text.trim();
                                        });
                                        _showSnackBar(_localeService.get('email_linked_can_login'), Colors.green);
                                      } else {
                                        setSheetState(() {
                                          errorMessage = result['message'] ?? _localeService.get('verify_otp_failed');
                                          isLoading = false;
                                        });
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
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
                                        : (currentStep == 1 && needsPasswordStep)
                                            ? _localeService.get('next')
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
  
  Widget _buildStepIndicator(int step, int currentStep, String label) {
    final isActive = step <= currentStep;
    final isCurrent = step == currentStep;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : _themeService.inputBackground,
            shape: BoxShape.circle,
            border: isCurrent ? Border.all(color: Colors.blue, width: 2) : null,
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
            fontSize: 10,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStepLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        color: isActive ? Colors.blue : _themeService.inputBackground,
      ),
    );
  }

  void _showPhoneBottomSheet(String? currentPhone) {
    final phoneController = TextEditingController(
      text: currentPhone != null ? ApiService.formatPhoneForDisplay(currentPhone) : '',
    );
    bool isLoading = false;
    String? errorMessage;
    final isEditing = currentPhone != null;

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
                    
                    // Title
                    Text(
                      isEditing 
                          ? _localeService.get('change_phone') 
                          : _localeService.get('link_phone'),
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _localeService.get('enter_phone_to_link'),
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Phone input
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      autofocus: true,
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 16,
                      ),
                      decoration: InputDecoration(
                        hintText: '0912 345 678',
                        hintStyle: TextStyle(
                          color: _themeService.textSecondaryColor.withAlpha(128),
                        ),
                        filled: true,
                        fillColor: _themeService.inputBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        prefixIcon: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🇻🇳 +84',
                                style: TextStyle(
                                  color: _themeService.textPrimaryColor,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                height: 24,
                                color: _themeService.dividerColor,
                              ),
                            ],
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0),
                      ),
                    ),
                    
                    // Error message
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _localeService.get('cancel'),
                              style: TextStyle(
                                color: _themeService.textSecondaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    final phone = phoneController.text.trim();
                                    if (phone.isEmpty) {
                                      setSheetState(() => errorMessage = _localeService.get('enter_phone'));
                                      return;
                                    }
                                    
                                    final e164Phone = ApiService.parsePhoneToE164(phone);
                                    
                                    setSheetState(() {
                                      isLoading = true;
                                      errorMessage = null;
                                    });
                                    
                                    // Step 1: Check if phone is available for linking
                                    final token = await _authService.getToken();
                                    if (token == null) {
                                      setSheetState(() {
                                        errorMessage = _localeService.get('session_expired');
                                        isLoading = false;
                                      });
                                      return;
                                    }
                                    
                                    final checkResult = await _apiService.checkPhoneForLink(token: token, phone: e164Phone);
                                    if (checkResult['available'] != true) {
                                      setSheetState(() {
                                        errorMessage = checkResult['message'] ?? _localeService.get('phone_already_used');
                                        isLoading = false;
                                      });
                                      return;
                                    }
                                    
                                    // Step 2: Phone is available, send OTP via Firebase
                                    await FirebaseAuth.instance.verifyPhoneNumber(
                                      phoneNumber: e164Phone,
                                      verificationCompleted: (PhoneAuthCredential credential) async {},
                                      verificationFailed: (FirebaseAuthException e) {
                                        setSheetState(() {
                                          errorMessage = e.message ?? _localeService.get('verification_failed');
                                          isLoading = false;
                                        });
                                      },
                                      codeSent: (String verId, int? resendToken) {
                                        Navigator.pop(context);
                                        _showPhoneOtpBottomSheet(e164Phone, verId);
                                      },
                                      codeAutoRetrievalTimeout: (String verId) {},
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
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
                                    _localeService.get('send_otp'),
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

  void _showPhoneOtpBottomSheet(String phoneNumber, String verificationId) {
    final otpController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
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
                    
                    // Title
                    Text(
                      _localeService.get('verify_phone'),
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_localeService.get('otp_sent_to')} ${ApiService.formatPhoneForDisplay(phoneNumber)}',
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
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
                        fillColor: _themeService.inputBackground,
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
                    
                    // Error message
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _localeService.get('cancel'),
                              style: TextStyle(
                                color: _themeService.textSecondaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    final otp = otpController.text.trim();
                                    if (otp.length != 6) {
                                      setSheetState(() => errorMessage = _localeService.get('invalid_otp'));
                                      return;
                                    }
                                    
                                    setSheetState(() {
                                      isLoading = true;
                                      errorMessage = null;
                                    });
                                    
                                    try {
                                      final credential = PhoneAuthProvider.credential(
                                        verificationId: verificationId,
                                        smsCode: otp,
                                      );
                                      
                                      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
                                      final firebaseIdToken = await userCredential.user?.getIdToken();
                                      
                                      if (firebaseIdToken == null) {
                                        throw Exception(_localeService.get('verification_failed'));
                                      }
                                      
                                      final token = await _authService.getToken();
                                      final result = await _apiService.linkPhone(token: token!, firebaseIdToken: firebaseIdToken);
                                      
                                      await FirebaseAuth.instance.signOut();
                                      
                                      if (result['success']) {
                                        Navigator.pop(context);
                                        setState(() {
                                          _linkedPhone = phoneNumber;
                                        });
                                        _showSnackBar(_localeService.get('phone_linked_success'), Colors.green);
                                      } else {
                                        setSheetState(() {
                                          errorMessage = result['message'] ?? _localeService.get('link_phone_failed');
                                          isLoading = false;
                                        });
                                      }
                                    } catch (e) {
                                      await FirebaseAuth.instance.signOut();
                                      setSheetState(() {
                                        errorMessage = _localeService.get('verify_otp_failed');
                                        isLoading = false;
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
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
                                    _localeService.get('verify'),
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
}
