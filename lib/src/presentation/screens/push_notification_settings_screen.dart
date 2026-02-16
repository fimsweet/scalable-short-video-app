import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/fcm_service.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/app_snackbar.dart';

class PushNotificationSettingsScreen extends StatefulWidget {
  const PushNotificationSettingsScreen({super.key});

  @override
  State<PushNotificationSettingsScreen> createState() =>
      _PushNotificationSettingsScreenState();
}

class _PushNotificationSettingsScreenState
    extends State<PushNotificationSettingsScreen> with WidgetsBindingObserver {
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final FcmService _fcmService = FcmService();

  bool _pushEnabled = false;
  bool _systemPermissionGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check system permission when returning from settings
      _onResumeCheckPermission();
    }
  }

  Future<void> _onResumeCheckPermission() async {
    final wasGranted = _systemPermissionGranted;
    await _checkSystemPermission();

    // If user just granted permission from system settings, auto-enable push
    if (!wasGranted && _systemPermissionGranted && !_pushEnabled) {
      await _togglePushNotifications(true);
    }

    // If user just revoked permission from system settings, auto-disable push
    if (wasGranted && !_systemPermissionGranted && _pushEnabled) {
      setState(() => _pushEnabled = false);
      try {
        final token = await _authService.getToken();
        if (token != null) {
          await _apiService.updateUserSettings(token, {'pushNotifications': false});
        }
      } catch (e) {
        debugPrint('Error syncing push off: $e');
      }
    }
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkSystemPermission() async {
    final settings =
        await FirebaseMessaging.instance.getNotificationSettings();
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (mounted) {
      setState(() => _systemPermissionGranted = granted);
    }
  }

  Future<void> _loadSettings() async {
    try {
      await _checkSystemPermission();
      final token = await _authService.getToken();
      if (token == null) return;

      final result = await _apiService.getUserSettings(token);
      if (result['success'] == true && result['settings'] != null) {
        final s = result['settings'];
        setState(() {
          _pushEnabled = s['pushNotifications'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePushNotifications(bool value) async {
    if (value && !_systemPermissionGranted) {
      // System permission not granted — open Android notification settings
      _showSystemPermissionDialog();
      return;
    }

    setState(() => _pushEnabled = value);
    try {
      final token = await _authService.getToken();
      if (token == null) return;
      await _apiService.updateUserSettings(token, {'pushNotifications': value});
      if (value) {
        await _fcmService.registerToken();
      }
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          value
              ? _localeService.get('push_notifications_enabled')
              : _localeService.get('push_notifications_disabled'),
        );
      }
    } catch (e) {
      debugPrint('Error toggling push: $e');
    }
  }

  void _showSystemPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.isVietnamese
              ? 'Cho phép thông báo'
              : 'Allow Notifications',
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          _localeService.isVietnamese
              ? 'Bạn cần bật thông báo trong cài đặt hệ thống để nhận thông báo đẩy.'
              : 'You need to enable notifications in system settings to receive push notifications.',
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _localeService.isVietnamese ? 'Để sau' : 'Later',
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Open Android system notification settings for this app
              _fcmService.openNotificationSettings();
            },
            child: Text(
              _localeService.isVietnamese ? 'Mở cài đặt' : 'Open Settings',
              style: const TextStyle(color: Color(0xFFFF2D55)),
            ),
          ),
        ],
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
          icon: Icon(Icons.arrow_back, color: _themeService.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.get('push_notification_settings'),
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

                  // Master push toggle
                  _buildSettingsGroup([
                    _buildToggleItem(
                      title: _localeService.get('push_notification_settings'),
                      subtitle: _localeService
                          .get('push_notification_settings_desc'),
                      value: _systemPermissionGranted && _pushEnabled,
                      enabled: true,
                      onChanged: _togglePushNotifications,
                    ),
                  ]),

                  // Hint text about system permission
                  if (!_systemPermissionGranted)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: GestureDetector(
                        onTap: () {
                          _fcmService.openNotificationSettings();
                        },
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 14,
                                color: _themeService.textSecondaryColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _localeService.isVietnamese
                                    ? 'Thông báo hệ thống chưa được bật. Nhấn để mở cài đặt.'
                                    : 'System notifications not enabled. Tap to open settings.',
                                style: TextStyle(
                                  color: _themeService.textSecondaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Info about what push notifications do
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _localeService.isVietnamese
                          ? 'Khi bật, bạn sẽ nhận được thông báo về lượt thích, bình luận, người theo dõi mới và tin nhắn ngay cả khi không sử dụng ứng dụng.'
                          : 'When enabled, you\'ll receive notifications about likes, comments, new followers and messages even when you\'re not using the app.',
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
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
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
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
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: _themeService.switchActiveColor,
            activeTrackColor: _themeService.switchActiveTrackColor,
            inactiveThumbColor: _themeService.switchInactiveThumbColor,
            inactiveTrackColor: _themeService.switchInactiveTrackColor,
          ),
        ],
      ),
    );
  }
}
