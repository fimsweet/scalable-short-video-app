import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/blocked_users_screen.dart';

class ChatOptionsScreen extends StatefulWidget {
  final String recipientId;
  final String recipientUsername;
  final String? recipientAvatar;

  const ChatOptionsScreen({
    super.key,
    required this.recipientId,
    required this.recipientUsername,
    this.recipientAvatar,
  });

  @override
  State<ChatOptionsScreen> createState() => _ChatOptionsScreenState();
}

class _ChatOptionsScreenState extends State<ChatOptionsScreen> {
  final MessageService _messageService = MessageService();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  
  bool _isMuted = false;
  bool _isPinned = false;
  bool _isBlocked = false;
  bool _isLoading = true;

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
      final settings = await _messageService.getConversationSettings(widget.recipientId);
      
      // Check blocked status
      final currentUser = await _authService.getCurrentUser();
      bool isBlocked = false;
      if (currentUser != null) {
        isBlocked = await _apiService.isUserBlocked(currentUser['id'].toString(), widget.recipientId);
      }
      
      if (mounted) {
        setState(() {
          _isMuted = settings['isMuted'] ?? false;
          _isPinned = settings['isPinned'] ?? false;
          _isBlocked = isBlocked;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 18)),
            ),
          ],
        ),
        content: Text(message, style: TextStyle(color: _themeService.textSecondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFFE84C3D))),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(_localeService.get('error'), style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 18)),
          ],
        ),
        content: Text(message, style: TextStyle(color: _themeService.textSecondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localeService.get('ok'), style: const TextStyle(color: Color(0xFFE84C3D))),
          ),
        ],
      ),
    );
  }

  void _viewProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: int.parse(widget.recipientId)),
      ),
    );
  }

  Future<void> _toggleMuteNotification(bool value) async {
    setState(() => _isMuted = value);
    
    try {
      await _messageService.updateConversationSettings(
        widget.recipientId,
        isMuted: value,
      );
      // No dialog - toggle already shows the state
    } catch (e) {
      // Revert on error
      setState(() => _isMuted = !value);
      _showErrorDialog(_localeService.get('settings_update_failed'));
    }
  }

  Future<void> _togglePinConversation(bool value) async {
    setState(() => _isPinned = value);
    
    try {
      await _messageService.updateConversationSettings(
        widget.recipientId,
        isPinned: value,
      );
      // No dialog - toggle already shows the state
    } catch (e) {
      // Revert on error
      setState(() => _isPinned = !value);
      _showErrorDialog(_localeService.get('settings_update_failed'));
    }
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_localeService.get('block_user'), style: TextStyle(color: _themeService.textPrimaryColor)),
        content: Text(
          _localeService.isVietnamese
              ? 'Bạn có chắc muốn chặn ${widget.recipientUsername}?\n\nHọ sẽ không thể:\n• Gửi tin nhắn cho bạn\n• Xem trang cá nhân của bạn\n• Tìm thấy bạn trong tìm kiếm'
              : 'Are you sure you want to block ${widget.recipientUsername}?\n\nThey will not be able to:\n• Send you messages\n• View your profile\n• Find you in search',
          style: TextStyle(color: _themeService.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localeService.get('cancel'), style: TextStyle(color: _themeService.textSecondaryColor)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _performBlockUser();
            },
            child: Text(_localeService.get('block'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performBlockUser() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      final currentUserId = currentUser?['id']?.toString();
      await _apiService.blockUser(widget.recipientId, currentUserId: currentUserId);
      
      if (mounted) {
        setState(() {
          _isBlocked = true;
        });
        
        // Navigate back to chat screen directly after blocking
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(_localeService.get('block_failed'));
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
          icon: Icon(Icons.arrow_back_ios_new, color: _themeService.iconColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.get('chat_options'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeService.textPrimaryColor))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // Profile header
                  _buildProfileHeader(),
                  
                  const SizedBox(height: 32),
                  
                  // Settings section
                  _buildSettingsSection(),
                  
                  const SizedBox(height: 16),
                  
                  // Danger zone
                  _buildDangerSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        // Avatar
        CircleAvatar(
          radius: 50,
          backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
          backgroundImage: widget.recipientAvatar != null
              ? NetworkImage(widget.recipientAvatar!)
              : null,
          child: widget.recipientAvatar == null
              ? Icon(Icons.person, color: _themeService.textSecondaryColor, size: 50)
              : null,
        ),
        const SizedBox(height: 16),
        
        // Username
        Text(
          widget.recipientUsername,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _themeService.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        
        // View profile button
        GestureDetector(
          onTap: _viewProfile,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _localeService.get('view_profile'),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildOptionItem(
            icon: Icons.notifications_off_outlined,
            label: _localeService.get('mute_notifications'),
            subtitle: _isMuted ? _localeService.get('muted') : _localeService.get('unmuted'),
            hasSwitch: true,
            switchValue: _isMuted,
            onSwitchChanged: _toggleMuteNotification,
          ),
          Divider(color: _themeService.dividerColor, height: 1, indent: 56),
          _buildOptionItem(
            icon: Icons.push_pin_outlined,
            label: _localeService.get('pin_conversation'),
            subtitle: _isPinned ? _localeService.get('pinned') : _localeService.get('not_pinned'),
            hasSwitch: true,
            switchValue: _isPinned,
            onSwitchChanged: _togglePinConversation,
          ),
        ],
      ),
    );
  }

  Widget _buildDangerSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (_isBlocked)
            _buildOptionItem(
              icon: Icons.lock_open,
              label: _localeService.get('unblock'),
              subtitle: _localeService.get('allow_contact'),
              textColor: Colors.green,
              iconColor: Colors.green,
              onTap: _unblockUser,
            )
          else
            _buildOptionItem(
              icon: Icons.block,
              label: _localeService.get('block'),
              subtitle: _localeService.get('block_user_desc'),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: _blockUser,
            ),
          Divider(color: _themeService.dividerColor, height: 1, indent: 56),
          _buildOptionItem(
            icon: Icons.list,
            label: _localeService.get('blocked_list'),
            subtitle: _localeService.get('blocked_list_subtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
              ).then((_) => _loadSettings());
            },
          ),
        ],
      ),
    );
  }

  void _unblockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_localeService.get('unblock_user'), style: TextStyle(color: _themeService.textPrimaryColor)),
        content: Text(
          _localeService.isVietnamese
              ? 'Bạn có chắc muốn bỏ chặn ${widget.recipientUsername}?\n\nHọ sẽ có thể gửi tin nhắn cho bạn.'
              : 'Are you sure you want to unblock ${widget.recipientUsername}?\n\nThey will be able to send you messages.',
          style: TextStyle(color: _themeService.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_localeService.get('cancel'), style: TextStyle(color: _themeService.textSecondaryColor)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performUnblockUser();
            },
            child: Text(_localeService.get('unblock'), style: const TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _performUnblockUser() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      final currentUserId = currentUser?['id']?.toString();
      final success = await _apiService.unblockUser(widget.recipientId, currentUserId: currentUserId);
      
      if (success && mounted) {
        setState(() {
          _isBlocked = false;
        });
        
        _showSuccessDialog(
          title: _localeService.get('unblocked_success'),
          message: _localeService.isVietnamese
              ? 'Bạn đã bỏ chặn ${widget.recipientUsername}. Họ có thể gửi tin nhắn cho bạn.'
              : 'You unblocked ${widget.recipientUsername}. They can send you messages now.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(_localeService.get('unblock_failed'));
      }
    }
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    String? subtitle,
    bool hasSwitch = false,
    bool switchValue = false,
    ValueChanged<bool>? onSwitchChanged,
    VoidCallback? onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    final defaultTextColor = textColor ?? _themeService.textPrimaryColor;
    final defaultIconColor = iconColor ?? _themeService.textPrimaryColor;
    
    return InkWell(
      onTap: hasSwitch ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (iconColor ?? _themeService.textSecondaryColor).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: defaultIconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      color: defaultTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: _themeService.textSecondaryColor,
                      ),
                    ),
                ],
              ),
            ),
            if (hasSwitch)
              Switch(
                value: switchValue,
                onChanged: onSwitchChanged,
                activeColor: _themeService.switchActiveColor,
                activeTrackColor: _themeService.switchActiveTrackColor,
                inactiveThumbColor: _themeService.switchInactiveThumbColor,
                inactiveTrackColor: _themeService.switchInactiveTrackColor,
              )
            else
              Icon(Icons.chevron_right, color: _themeService.textSecondaryColor),
          ],
        ),
      ),
    );
  }
}
