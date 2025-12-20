import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/notification_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ThemeService _themeService = ThemeService();

  List<dynamic> _notifications = [];
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _loadNotifications();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadNotifications() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _authService.user!['id'].toString();
      final notifications = await _notificationService.getNotifications(userId);

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final userInfo = await _apiService.getUserById(userId);
      if (userInfo != null) {
        _userCache[userId] = userInfo;
        return userInfo;
      }
    } catch (e) {
      print('❌ Error fetching user info: $e');
    }

    return {'username': 'user', 'avatar': null};
  }

  Future<void> _handleNotificationTap(dynamic notification) async {
    final userId = _authService.user!['id'].toString();
    
    // Mark as read
    if (!(notification['isRead'] ?? false)) {
      await _notificationService.markAsRead(notification['id'], userId);
      _loadNotifications(); // Refresh
    }

    // Navigate based on type
    // TODO: Add navigation logic
  }

  Future<void> _markAllAsRead() async {
    final userId = _authService.user!['id'].toString();
    await _notificationService.markAllAsRead(userId);
    _loadNotifications();
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add;
      case 'comment':
        return Icons.comment;
      case 'like':
        return Icons.favorite;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'follow':
        return Colors.blue;
      case 'comment':
        return Colors.green;
      case 'like':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getNotificationMessage(dynamic notification, String username) {
    switch (notification['type']) {
      case 'follow':
        return '$username bắt đầu theo dõi bạn';
      case 'comment':
        final message = notification['message']?.toString() ?? '';
        final preview = message.length > 50 ? '${message.substring(0, 50)}...' : message;
        return '$username đã bình luận: $preview';
      case 'like':
        return '$username đã thích video của bạn';
      default:
        return 'Thông báo mới từ $username';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        title: Text('Thông báo', style: TextStyle(color: _themeService.textPrimaryColor)),
        iconTheme: IconThemeData(color: _themeService.iconColor),
        actions: [
          if (_notifications.any((n) => !(n['isRead'] ?? false)))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text(
                'Đọc tất cả',
                style: TextStyle(color: Colors.blue),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeService.textPrimaryColor))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 80, color: _themeService.textSecondaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có thông báo nào',
                        style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Các thông báo của bạn sẽ hiển thị ở đây',
                        style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final isRead = notification['isRead'] ?? false;
                      final type = notification['type']?.toString() ?? '';
                      final senderId = notification['senderId']?.toString() ?? '';

                      return FutureBuilder<Map<String, dynamic>>(
                        future: _getUserInfo(senderId),
                        builder: (context, snapshot) {
                          final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
                          
                          return InkWell(
                            onTap: () => _handleNotificationTap(notification),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.transparent : Colors.blue.withOpacity(0.1),
                                border: Border(
                                  bottom: BorderSide(color: _themeService.dividerColor, width: 1),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar with notification icon badge
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
                                        backgroundImage: userInfo['avatar'] != null
                                            ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                                            : null,
                                        child: userInfo['avatar'] == null
                                            ? Icon(Icons.person, color: _themeService.textPrimaryColor)
                                            : null,
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: _getNotificationColor(type),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: _themeService.backgroundColor, width: 2),
                                          ),
                                          child: Icon(
                                            _getNotificationIcon(type),
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getNotificationMessage(notification, userInfo['username'] ?? 'user'),
                                          style: TextStyle(
                                            color: _themeService.textPrimaryColor,
                                            fontSize: 14,
                                            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          timeago.format(
                                            DateTime.parse(notification['createdAt']),
                                            locale: 'vi',
                                          ),
                                          style: TextStyle(
                                            color: _themeService.textSecondaryColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Unread indicator
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
