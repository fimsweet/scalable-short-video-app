import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadBlockedUsers();
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

  Future<void> _loadBlockedUsers() async {
    try {
      final currentUser = await _authService.getCurrentUser();
      if (currentUser != null) {
        final users = await _apiService.getBlockedUsers(currentUser['id'].toString());
        if (mounted) {
          setState(() {
            _blockedUsers = users;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading blocked users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _unblockUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.get('unblock_user'),
          style: TextStyle(color: _themeService.textPrimaryColor),
        ),
        content: Text(
          _localeService.isVietnamese
              ? 'Bạn có chắc muốn bỏ chặn ${user['username']}?\n\nHọ sẽ có thể gửi tin nhắn cho bạn.'
              : 'Are you sure you want to unblock ${user['username']}?\n\nThey will be able to send you messages.',
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
              await _performUnblock(user);
            },
            child: Text(_localeService.get('unblock'), style: const TextStyle(color: Color(0xFFE84C3D))),
          ),
        ],
      ),
    );
  }

  Future<void> _performUnblock(Map<String, dynamic> user) async {
    try {
      final currentUser = await _authService.getCurrentUser();
      final currentUserId = currentUser?['id']?.toString();
      final success = await _apiService.unblockUser(user['id'].toString(), currentUserId: currentUserId);
      
      if (success && mounted) {
        setState(() {
          _blockedUsers.removeWhere((u) => u['id'] == user['id']);
        });
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _themeService.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Text(
                  _localeService.get('unblocked_success'),
                  style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              '${_localeService.get('unblocked_user_success')} ${user['username']}',
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_localeService.get('ok'), style: const TextStyle(color: Color(0xFFE84C3D))),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _themeService.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.error, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Text(
                  _localeService.get('error'),
                  style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              _localeService.get('unblock_failed'),
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_localeService.get('ok'), style: const TextStyle(color: Color(0xFFE84C3D))),
              ),
            ],
          ),
        );
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
          icon: Icon(Icons.chevron_left, color: _themeService.iconColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.get('blocked_list'),
          style: TextStyle(color: _themeService.textPrimaryColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeService.textPrimaryColor))
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : _buildBlockedList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 80, color: _themeService.textSecondaryColor),
          const SizedBox(height: 16),
          Text(
            _localeService.get('no_blocked_users'),
            style: TextStyle(
              fontSize: 16,
              color: _themeService.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _localeService.get('blocked_users_hint'),
            style: TextStyle(
              fontSize: 14,
              color: _themeService.textSecondaryColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _blockedUsers.length,
      itemBuilder: (context, index) {
        final user = _blockedUsers[index];
        return _buildBlockedUserItem(user);
      },
    );
  }

  Widget _buildBlockedUserItem(Map<String, dynamic> user) {
    final avatarUrl = user['avatarUrl'] as String?;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Icon(Icons.person, color: _themeService.textSecondaryColor, size: 24)
              : null,
        ),
        title: Text(
          user['username'] ?? 'Unknown',
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          _localeService.get('blocked'),
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 13,
          ),
        ),
        trailing: TextButton(
          onPressed: () => _unblockUser(user),
          style: TextButton.styleFrom(
            backgroundColor: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[800],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(
            _localeService.get('unblock'),
            style: const TextStyle(
              color: Color(0xFFE84C3D),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
