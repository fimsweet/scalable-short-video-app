import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/push_notification_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/in_app_notification_settings_screen.dart';
import 'package:scalable_short_video_app/src/utils/navigation_utils.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  bool _pushEnabled = false;
  bool _systemPermissionGranted = false;
  bool _isLoading = true;

  // Push notification preferences
  bool _pushLikes = true;
  bool _pushComments = true;
  bool _pushNewFollowers = true;
  bool _pushProfileViews = true;
  bool _pushMentions = true;
  bool _pushMessages = true;

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
      // Check system permission
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      final sysGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      final token = await _authService.getToken();
      if (token == null) return;

      final result = await _apiService.getUserSettings(token);
      if (result['success'] == true && result['settings'] != null) {
        final s = result['settings'];
        setState(() {
          _systemPermissionGranted = sysGranted;
          _pushEnabled = sysGranted && (s['pushNotifications'] ?? false);
          _pushLikes = s['pushLikes'] ?? true;
          _pushComments = s['pushComments'] ?? true;
          _pushNewFollowers = s['pushNewFollowers'] ?? true;
          _pushProfileViews = s['pushProfileViews'] ?? true;
          _pushMentions = s['pushMentions'] ?? true;
          _pushMessages = s['pushMessages'] ?? true;
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
    } catch (e) {
      debugPrint('Error updating setting: $e');
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
          _localeService.isVietnamese ? 'Thông báo' : 'Notifications',
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
              child: CircularProgressIndicator(
                color: ThemeService.accentColor,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Push notification row with chevron
                  _buildSettingsGroup([
                    _buildNavigationItem(
                      title: _localeService.get('push_notification_settings'),
                      subtitle: _pushEnabled
                          ? (_localeService.isVietnamese ? 'Bật' : 'On')
                          : (_localeService.get('push_off')),
                      onTap: () async {
                        await NavigationUtils.slideToScreen(
                          context,
                          const PushNotificationSettingsScreen(),
                        );
                        // Reload settings when coming back
                        _loadSettings();
                      },
                      showDivider: true,
                    ),

                    // In-app notifications row
                    _buildNavigationItem(
                      title: _localeService.get('in_app_notifications'),
                      onTap: () async {
                        await NavigationUtils.slideToScreen(
                          context,
                          const InAppNotificationSettingsScreen(),
                        );
                        _loadSettings();
                      },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Interactions section - shown with push state awareness
                  _buildSectionTitle(_localeService.get('interactions')),
                  _buildSettingsGroup([
                    _buildToggleItem(
                      title: _localeService.get('push_likes'),
                      value: _pushLikes,
                      enabled: _pushEnabled,
                      onChanged: (v) {
                        setState(() => _pushLikes = v);
                        _updateSetting('pushLikes', v);
                      },
                      showDivider: true,
                    ),
                    _buildToggleItem(
                      title: _localeService.get('push_comments'),
                      value: _pushComments,
                      enabled: _pushEnabled,
                      onChanged: (v) {
                        setState(() => _pushComments = v);
                        _updateSetting('pushComments', v);
                      },
                      showDivider: true,
                    ),
                    _buildToggleItem(
                      title: _localeService.get('push_new_followers'),
                      value: _pushNewFollowers,
                      enabled: _pushEnabled,
                      onChanged: (v) {
                        setState(() => _pushNewFollowers = v);
                        _updateSetting('pushNewFollowers', v);
                      },
                      showDivider: true,
                    ),
                    _buildToggleItem(
                      title: _localeService.get('push_profile_views'),
                      value: _pushProfileViews,
                      enabled: _pushEnabled,
                      onChanged: (v) {
                        setState(() => _pushProfileViews = v);
                        _updateSetting('pushProfileViews', v);
                      },
                      showDivider: true,
                    ),
                    _buildToggleItem(
                      title: _localeService.get('push_mentions'),
                      value: _pushMentions,
                      enabled: _pushEnabled,
                      onChanged: (v) {
                        setState(() => _pushMentions = v);
                        _updateSetting('pushMentions', v);
                      },
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Messages section
                  _buildSectionTitle(_localeService.get('messages_section')),
                  _buildSettingsGroup([
                    _buildToggleItem(
                      title: _localeService.get('push_messages'),
                      value: _pushMessages,
                      enabled: _pushEnabled,
                      onChanged: (v) {
                        setState(() => _pushMessages = v);
                        _updateSetting('pushMessages', v);
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

  Widget _buildNavigationItem({
    required String title,
    String? subtitle,
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
                          fontWeight: FontWeight.w500,
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
                        ),
                      ],
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

  Widget _buildToggleItem({
    required String title,
    String? subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    bool showDivider = false,
  }) {
    final effectiveOpacity = enabled ? 1.0 : 0.4;

    return Column(
      children: [
        AnimatedOpacity(
          opacity: effectiveOpacity,
          duration: const Duration(milliseconds: 200),
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
                CupertinoSwitch(
                  value: enabled ? value : false,
                  onChanged: enabled ? onChanged : null,
                  activeTrackColor: _themeService.switchActiveTrackColor,
                  thumbColor: Colors.white,
                  trackColor: _themeService.switchInactiveTrackColor,
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
