import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final MessageService _messageService = MessageService();

  String _whoCanViewVideos = 'everyone';
  String _whoCanSendMessages = 'everyone';
  String _whoCanComment = 'everyone';
  String _whoCanViewFollowingList = 'everyone';
  String _whoCanViewFollowersList = 'everyone';
  String _whoCanViewLikedVideos = 'everyone';
  bool _filterComments = true;

  bool _isLoadingSettings = true;

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
        if (mounted) {
          setState(() {
            _whoCanViewVideos = settings['whoCanViewVideos'] ?? 'everyone';
            _whoCanSendMessages = settings['whoCanSendMessages'] ?? 'everyone';
            _whoCanComment = settings['whoCanComment'] ?? 'everyone';
            _filterComments = settings['filterComments'] ?? true;
            _whoCanViewFollowingList = settings['whoCanViewFollowingList'] ?? 'everyone';
            _whoCanViewFollowersList = settings['whoCanViewFollowersList'] ?? 'everyone';
            _whoCanViewLikedVideos = settings['whoCanViewLikedVideos'] ?? 'everyone';
            _isLoadingSettings = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingSettings = false);
      }
    } catch (e) {
      print('Error loading privacy settings: $e');
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  Future<void> _updatePrivacySetting(String key, dynamic value) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      await _apiService.updateUserSettings(token, {key: value});

      final userId = _authService.userId;
      if (userId != null) {
        if (key == 'whoCanSendMessages') {
          _messageService.notifyPrivacySettingsChanged(
            userId: userId.toString(),
            whoCanSendMessages: value as String,
          );
        }
      }
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
          _localeService.get('privacy_and_safety'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoadingSettings
          ? Center(
              child: CircularProgressIndicator(
                color: _themeService.textSecondaryColor,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Section: Content Visibility
                  _buildSectionTitle(_localeService.isVietnamese ? 'Nội dung' : 'Content'),
                  _buildSettingsGroup([
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
                      title: _localeService.get('who_can_view_liked_videos'),
                      subtitle: _getDisplayText(_whoCanViewLikedVideos),
                      onTap: () => _showPrivacySelectionModal(
                        title: _localeService.get('who_can_view_liked_videos_title'),
                        currentValue: _whoCanViewLikedVideos,
                        options: [
                          {'title': _localeService.get('everyone'), 'value': 'everyone'},
                          {'title': _localeService.get('friends'), 'value': 'friends'},
                          {'title': _localeService.get('only_me'), 'value': 'onlyMe'},
                        ],
                        onSelect: (value) {
                          setState(() => _whoCanViewLikedVideos = value);
                          _updatePrivacySetting('whoCanViewLikedVideos', value);
                          _showSnackBar(_localeService.get('updated'), _themeService.snackBarBackground);
                        },
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),

                  // Section: Social
                  _buildSectionTitle(_localeService.isVietnamese ? 'Xã hội' : 'Social'),
                  _buildSettingsGroup([
                    _buildMenuItem(
                      title: _localeService.get('who_can_view_following_list'),
                      subtitle: _getDisplayText(_whoCanViewFollowingList),
                      onTap: () => _showPrivacySelectionModal(
                        title: _localeService.get('who_can_view_following_list_title'),
                        currentValue: _whoCanViewFollowingList,
                        options: [
                          {'title': _localeService.get('everyone'), 'value': 'everyone'},
                          {'title': _localeService.get('friends'), 'value': 'friends'},
                          {'title': _localeService.get('only_me'), 'value': 'onlyMe'},
                        ],
                        onSelect: (value) {
                          setState(() => _whoCanViewFollowingList = value);
                          _updatePrivacySetting('whoCanViewFollowingList', value);
                          _showSnackBar(_localeService.get('updated'), _themeService.snackBarBackground);
                        },
                      ),
                      showDivider: true,
                    ),
                    _buildMenuItem(
                      title: _localeService.get('who_can_view_followers_list'),
                      subtitle: _getDisplayText(_whoCanViewFollowersList),
                      onTap: () => _showPrivacySelectionModal(
                        title: _localeService.get('who_can_view_followers_list_title'),
                        currentValue: _whoCanViewFollowersList,
                        options: [
                          {'title': _localeService.get('everyone'), 'value': 'everyone'},
                          {'title': _localeService.get('friends'), 'value': 'friends'},
                          {'title': _localeService.get('only_me'), 'value': 'onlyMe'},
                        ],
                        onSelect: (value) {
                          setState(() => _whoCanViewFollowersList = value);
                          _updatePrivacySetting('whoCanViewFollowersList', value);
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

                  // Section: Interaction
                  _buildSectionTitle(_localeService.get('interaction')),
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

                  const SizedBox(height: 100),
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
              CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: _themeService.switchActiveTrackColor,
                thumbColor: Colors.white,
                trackColor: _themeService.switchInactiveTrackColor,
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
