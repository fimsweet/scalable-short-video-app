import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/in_app_notification_service.dart';

class InAppNotificationSettingsScreen extends StatefulWidget {
  const InAppNotificationSettingsScreen({super.key});

  @override
  State<InAppNotificationSettingsScreen> createState() =>
      _InAppNotificationSettingsScreenState();
}

class _InAppNotificationSettingsScreenState
    extends State<InAppNotificationSettingsScreen> {
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  bool _isLoading = true;

  // Master toggle for all in-app notifications
  bool _inAppEnabled = true;

  // In-app notification preferences
  bool _inAppLikes = true;
  bool _inAppComments = true;
  bool _inAppNewFollowers = true;
  bool _inAppMentions = true;
  bool _inAppProfileViews = true;
  bool _inAppMessages = true;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadSettings();
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

  Future<void> _loadSettings() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final result = await _apiService.getUserSettings(token);
      if (result['success'] == true && result['settings'] != null) {
        final s = result['settings'];
        setState(() {
          _inAppLikes = s['inAppLikes'] ?? true;
          _inAppComments = s['inAppComments'] ?? true;
          _inAppNewFollowers = s['inAppNewFollowers'] ?? true;
          _inAppMentions = s['inAppMentions'] ?? true;
          _inAppProfileViews = s['inAppProfileViews'] ?? true;
          _inAppMessages = s['inAppMessages'] ?? true;
          // Master toggle is ON if any individual setting is ON
          _inAppEnabled = _inAppLikes || _inAppComments ||
              _inAppNewFollowers || _inAppMentions || _inAppMessages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      await _apiService.updateUserSettings(token, {key: value});
      // Invalidate cached preferences so the service picks up the change
      InAppNotificationService().invalidatePreferences();
    } catch (e) {
      debugPrint('Error updating in-app setting: $e');
    }
  }

  /// Batch-update multiple settings in a single API call (avoids race conditions)
  Future<void> _updateMultipleSettings(Map<String, dynamic> settings) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      await _apiService.updateUserSettings(token, settings);
      InAppNotificationService().invalidatePreferences();
    } catch (e) {
      debugPrint('Error updating in-app settings: $e');
    }
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
          icon: Icon(Icons.arrow_back, color: _themeService.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.get('in_app_notifications'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: ThemeService.accentColor))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Master toggle
                  _buildSettingsGroup([
                    _buildToggleItem(
                      title: _localeService.get('in_app_notifications_enabled'),
                      value: _inAppEnabled,
                      onChanged: (v) {
                        setState(() {
                          _inAppEnabled = v;
                          _inAppLikes = v;
                          _inAppComments = v;
                          _inAppNewFollowers = v;
                          _inAppMentions = v;
                          _inAppMessages = v;
                        });
                        // Batch update all settings in a single API call
                        _updateMultipleSettings({
                          'inAppLikes': v,
                          'inAppComments': v,
                          'inAppNewFollowers': v,
                          'inAppMentions': v,
                          'inAppMessages': v,
                        });
                      },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Interactions section
                  _buildSectionTitle(_localeService.get('interactions')),
                  _buildSettingsGroup([
                    _buildToggleItem(
                      title: _localeService.get('in_app_likes'),
                      value: _inAppLikes,
                      enabled: _inAppEnabled,
                      onChanged: (v) {
                        setState(() => _inAppLikes = v);
                        _updateSetting('inAppLikes', v);
                      },
                      showDivider: true,
                    ),
                    _buildToggleItem(
                      title: _localeService.get('in_app_comments'),
                      value: _inAppComments,
                      enabled: _inAppEnabled,
                      onChanged: (v) {
                        setState(() => _inAppComments = v);
                        _updateSetting('inAppComments', v);
                      },
                      showDivider: true,
                    ),
                    _buildToggleItem(
                      title: _localeService.get('in_app_new_followers'),
                      value: _inAppNewFollowers,
                      enabled: _inAppEnabled,
                      onChanged: (v) {
                        setState(() => _inAppNewFollowers = v);
                        _updateSetting('inAppNewFollowers', v);
                      },
                      showDivider: true,
                    ),
                    _buildToggleItem(
                      title: _localeService.get('in_app_mentions'),
                      value: _inAppMentions,
                      enabled: _inAppEnabled,
                      onChanged: (v) {
                        setState(() => _inAppMentions = v);
                        _updateSetting('inAppMentions', v);
                      },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Messages section
                  _buildSectionTitle(_localeService.get('messages_section')),
                  _buildSettingsGroup([
                    _buildToggleItem(
                      title: _localeService.get('in_app_messages'),
                      value: _inAppMessages,
                      enabled: _inAppEnabled,
                      onChanged: (v) {
                        setState(() => _inAppMessages = v);
                        _updateSetting('inAppMessages', v);
                      },
                    ),
                  ]),

                  const SizedBox(height: 32),
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
        child: Column(children: children),
      ),
    );
  }

  Widget _buildToggleItem({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool showDivider = false,
    bool enabled = true,
  }) {
    final isActive = enabled && value;
    return Column(
      children: [
        Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Container(
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
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: _themeService.textSecondaryColor,
                            fontSize: 13,
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: enabled ? onChanged : null,
                  activeColor: _themeService.switchActiveColor,
                  activeTrackColor: _themeService.switchActiveTrackColor,
                  inactiveThumbColor: _themeService.switchInactiveThumbColor,
                  inactiveTrackColor: _themeService.switchInactiveTrackColor,
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
}
