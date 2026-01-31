import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/account_management_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_profile_screen.dart';
import 'package:scalable_short_video_app/src/utils/navigation_utils.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  // Privacy settings (synced with backend)
  bool _isPrivateAccount = false;
  bool _pushNotificationsEnabled = true;
  
  // New privacy settings from backend
  String _whoCanViewVideos = 'everyone';
  String _whoCanSendMessages = 'everyone';
  String _whoCanComment = 'everyone';
  bool _filterComments = true;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadPrivacySettings();
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

  Future<void> _loadPrivacySettings() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final result = await _apiService.getUserSettings(token);
      
      if (result['success'] == true && result['settings'] != null) {
        final settings = result['settings'];
        setState(() {
          _whoCanViewVideos = settings['whoCanViewVideos'] ?? 'everyone';
          _whoCanSendMessages = settings['whoCanSendMessages'] ?? 'everyone';
          _whoCanComment = settings['whoCanComment'] ?? 'everyone';
          _filterComments = settings['filterComments'] ?? true;
          _isPrivateAccount = settings['accountPrivacy'] == 'private';
          _pushNotificationsEnabled = settings['pushNotifications'] ?? true;
        });
        
        // Load language from backend settings (per account)
        final language = settings['language'] as String?;
        if (language != null) {
          await _localeService.loadFromBackend(language);
        }
      }
    } catch (e) {
      print('Error loading privacy settings: $e');
    }
  }

  Future<void> _updatePrivacySetting(String key, dynamic value) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final result = await _apiService.updateUserSettings(token, {key: value});
      print('Privacy setting updated: $key = $value, result: $result');
    } catch (e) {
      print('Error updating privacy setting: $e');
    }
  }

  String _getDisplayText(String value) {
    switch (value) {
      case 'everyone':
        return _localeService.get('everyone');
      case 'friends':
        return _localeService.get('friends');
      case 'onlyMe':
        return _localeService.get('only_me');
      case 'noOne':
        return _localeService.get('no_one');
      default:
        return _localeService.get('everyone');
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  _localeService.get('language'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _themeService.textPrimaryColor,
                  ),
                ),
              ),
              Divider(height: 1, color: _themeService.dividerColor),
              
              // Vietnamese
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  await _changeLanguage('vi');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tiếng Việt',
                          style: TextStyle(
                            fontSize: 16,
                            color: _themeService.textPrimaryColor,
                          ),
                        ),
                      ),
                      if (_localeService.isVietnamese)
                        const Icon(Icons.check, color: Colors.blue, size: 24),
                    ],
                  ),
                ),
              ),
              
              // English
              InkWell(
                onTap: () async {
                  Navigator.pop(context);
                  await _changeLanguage('en');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'English',
                          style: TextStyle(
                            fontSize: 16,
                            color: _themeService.textPrimaryColor,
                          ),
                        ),
                      ),
                      if (_localeService.isEnglish)
                        const Icon(Icons.check, color: Colors.blue, size: 24),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeLanguage(String locale) async {
    // Update local service
    await _localeService.setLocale(locale);
    
    // Sync to database
    try {
      final token = await _authService.getToken();
      if (token != null) {
        await _apiService.updateUserSettings(token, {'language': locale});
      }
    } catch (e) {
      print('Error syncing language to database: $e');
    }
    
    _showSnackBar(
      locale == 'vi' ? 'Đã chuyển sang Tiếng Việt' : 'Switched to English',
      _themeService.snackBarBackground,
    );
  }

  void _showPrivacySelectionModal({
    required String title,
    required String currentValue,
    required List<Map<String, String>> options,
    required Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _themeService.textPrimaryColor,
                  ),
                ),
              ),
              Divider(height: 1, color: _themeService.dividerColor),
              ...options.map((option) => InkWell(
                onTap: () {
                  Navigator.pop(context);
                  onSelect(option['value']!);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option['title']!,
                          style: TextStyle(
                            fontSize: 16,
                            color: _themeService.textPrimaryColor,
                          ),
                        ),
                      ),
                      if (option['value'] == currentValue)
                        const Icon(Icons.check, color: Colors.blue, size: 24),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 20),
            ],
          ),
        ),
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
          _localeService.get('settings'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // Profile Link Card
            _buildSettingsGroup([
              _buildProfileLink(),
            ]),
            
            const SizedBox(height: 24),
            
            // Section: Account
            _buildSectionTitle(_localeService.get('account')),
            _buildSettingsGroup([
              _buildMenuItem(
                title: _localeService.get('account_management'),
                subtitle: _localeService.get('account_management_subtitle'),
                onTap: () {
                  NavigationUtils.slideToScreen(
                    context,
                    const AccountManagementScreen(),
                  );
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Section: Privacy
            _buildSectionTitle(_localeService.get('privacy')),
            _buildSettingsGroup([
              _buildSettingSwitch(
                title: _localeService.get('private_account'),
                subtitle: _localeService.get('private_account_desc'),
                value: _isPrivateAccount,
                onChanged: (value) {
                  setState(() => _isPrivateAccount = value);
                  _updatePrivacySetting('accountPrivacy', value ? 'private' : 'public');
                  _showSnackBar(
                    value ? _localeService.get('private_account_enabled') : _localeService.get('private_account_disabled'),
                    _themeService.snackBarBackground,
                  );
                },
                showDivider: true,
              ),
              _buildMenuItem(
                title: _localeService.get('who_can_view_videos'),
                subtitle: _getDisplayText(_whoCanViewVideos),
                onTap: () => _showPrivacySelectionModal(
                  title: _localeService.get('who_can_view_videos_title'),
                  currentValue: _whoCanViewVideos,
                  options: [
                    {'title': _localeService.get('everyone'), 'value': 'everyone'},
                    {'title': _localeService.get('friends'), 'value': 'friends'},
                    {'title': _localeService.get('only_me'), 'value': 'onlyMe'},
                  ],
                  onSelect: (value) {
                    setState(() => _whoCanViewVideos = value);
                    _updatePrivacySetting('whoCanViewVideos', value);
                    _showSnackBar(_localeService.get('updated'), _themeService.snackBarBackground);
                  },
                ),
                showDivider: true,
              ),
              _buildMenuItem(
                title: _localeService.get('who_can_send_messages'),
                subtitle: _getDisplayText(_whoCanSendMessages),
                onTap: () => _showPrivacySelectionModal(
                  title: _localeService.get('who_can_send_messages_title'),
                  currentValue: _whoCanSendMessages,
                  options: [
                    {'title': _localeService.get('everyone'), 'value': 'everyone'},
                    {'title': _localeService.get('friends'), 'value': 'friends'},
                    {'title': _localeService.get('no_one'), 'value': 'noOne'},
                  ],
                  onSelect: (value) {
                    setState(() => _whoCanSendMessages = value);
                    _updatePrivacySetting('whoCanSendMessages', value);
                    _showSnackBar(_localeService.get('updated'), _themeService.snackBarBackground);
                  },
                ),
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Section: Comments
            _buildSectionTitle(_localeService.get('comments')),
            _buildSettingsGroup([
              _buildMenuItem(
                title: _localeService.get('who_can_comment'),
                subtitle: _getDisplayText(_whoCanComment),
                onTap: () => _showPrivacySelectionModal(
                  title: _localeService.get('who_can_comment_title'),
                  currentValue: _whoCanComment,
                  options: [
                    {'title': _localeService.get('everyone'), 'value': 'everyone'},
                    {'title': _localeService.get('friends'), 'value': 'friends'},
                    {'title': _localeService.get('no_one'), 'value': 'noOne'},
                  ],
                  onSelect: (value) {
                    setState(() => _whoCanComment = value);
                    _updatePrivacySetting('whoCanComment', value);
                    _showSnackBar(_localeService.get('updated'), _themeService.snackBarBackground);
                  },
                ),
                showDivider: true,
              ),
              _buildSettingSwitch(
                title: _localeService.get('filter_comments'),
                subtitle: _localeService.get('filter_comments_desc'),
                value: _filterComments,
                onChanged: (value) {
                  setState(() => _filterComments = value);
                  _updatePrivacySetting('filterComments', value);
                  _showSnackBar(
                    value ? _localeService.get('filter_comments_enabled') : _localeService.get('filter_comments_disabled'),
                    _themeService.snackBarBackground,
                  );
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Section: Notifications
            _buildSectionTitle(_localeService.get('notifications')),
            _buildSettingsGroup([
              _buildSettingSwitch(
                title: _localeService.get('push_notifications'),
                subtitle: _localeService.get('push_notifications_desc'),
                value: _pushNotificationsEnabled,
                onChanged: (value) {
                  setState(() => _pushNotificationsEnabled = value);
                  _updatePrivacySetting('pushNotifications', value);
                  _showSnackBar(
                    value ? _localeService.get('push_notifications_enabled') : _localeService.get('push_notifications_disabled'),
                    _themeService.snackBarBackground,
                  );
                },
              ),
            ]),
            
            const SizedBox(height: 24),
            
            // Section: Content & Display
            _buildSectionTitle(_localeService.get('content_display')),
            _buildSettingsGroup([
              _buildSettingSwitch(
                title: _localeService.get('light_mode'),
                subtitle: _localeService.get('light_mode_desc'),
                value: _themeService.isLightMode,
                onChanged: (value) async {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  await _themeService.toggleTheme(value);
                  if (mounted) {
                    _showSnackBar(
                      value ? _localeService.get('light_mode_enabled') : _localeService.get('dark_mode_enabled'),
                      _themeService.snackBarBackground,
                    );
                  }
                },
                showDivider: true,
              ),
              _buildMenuItem(
                title: _localeService.get('language'),
                subtitle: _localeService.isVietnamese ? 'Tiếng Việt' : 'English',
                onTap: _showLanguageSelector,
              ),
            ]),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileLink() {
    final avatarUrl = _authService.avatarUrl;
    final username = _authService.username ?? 'Người dùng';
    
    return InkWell(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 28,
              backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[700],
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        _apiService.getAvatarUrl(avatarUrl),
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          size: 28,
                          color: _themeService.textPrimaryColor,
                        ),
                      ),
                    )
                  : Icon(Icons.person, size: 28, color: _themeService.textPrimaryColor),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _themeService.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _localeService.get('edit_profile'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _themeService.textSecondaryColor),
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

  Widget _buildMenuItem({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        Container(
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
}
