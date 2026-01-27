import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/notification_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final VideoService _videoService = VideoService();

  List<dynamic> _notifications = [];
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _userCache = {};
  
  // Animation controllers for swipe
  final Map<String, double> _swipeOffsets = {};

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadNotifications();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onLocaleChanged() {
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

  // Group notifications by time period (Instagram style)
  Map<String, List<dynamic>> _groupNotificationsByTime() {
    final Map<String, List<dynamic>> groups = {
      'today': [],
      'yesterday': [],
      'this_week': [],
      'this_month': [],
      'older': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthAgo = today.subtract(const Duration(days: 30));

    for (var notification in _notifications) {
      final createdAt = DateTime.parse(notification['createdAt']);
      final notificationDate = DateTime(createdAt.year, createdAt.month, createdAt.day);

      if (notificationDate.isAtSameMomentAs(today) || notificationDate.isAfter(today)) {
        groups['today']!.add(notification);
      } else if (notificationDate.isAtSameMomentAs(yesterday)) {
        groups['yesterday']!.add(notification);
      } else if (notificationDate.isAfter(weekAgo)) {
        groups['this_week']!.add(notification);
      } else if (notificationDate.isAfter(monthAgo)) {
        groups['this_month']!.add(notification);
      } else {
        groups['older']!.add(notification);
      }
    }

    return groups;
  }

  String _getGroupTitle(String key) {
    switch (key) {
      case 'today':
        return _localeService.isVietnamese ? 'Hôm nay' : 'Today';
      case 'yesterday':
        return _localeService.isVietnamese ? 'Hôm qua' : 'Yesterday';
      case 'this_week':
        return _localeService.isVietnamese ? '7 ngày qua' : 'This Week';
      case 'this_month':
        return _localeService.isVietnamese ? '30 ngày qua' : 'This Month';
      case 'older':
        return _localeService.isVietnamese ? 'Cũ hơn' : 'Older';
      default:
        return '';
    }
  }

  Future<void> _handleNotificationTap(dynamic notification) async {
    final userId = _authService.user!['id'].toString();
    
    // Mark as read
    if (!(notification['isRead'] ?? false)) {
      await _notificationService.markAsRead(notification['id'], userId);
      _loadNotifications();
    }

    // Navigate based on type
    final type = notification['type']?.toString() ?? '';
    final videoId = notification['videoId']?.toString();
    final senderId = notification['senderId']?.toString();

    if (!mounted) return;

    switch (type) {
      case 'comment':
        // Navigate to video and open comments
        if (videoId != null) {
          await _navigateToVideoWithComments(videoId);
        }
        break;
      case 'like':
        // Navigate to video
        if (videoId != null) {
          await _navigateToVideo(videoId);
        }
        break;
      case 'follow':
        // Navigate to user profile
        if (senderId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(userId: int.parse(senderId)),
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  Future<void> _navigateToVideo(String videoId) async {
    try {
      final video = await _videoService.getVideoById(videoId);
      if (video != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(
              videos: [video],
              initialIndex: 0,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error navigating to video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.isVietnamese 
                ? 'Không thể tải video' 
                : 'Unable to load video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToVideoWithComments(String videoId) async {
    try {
      final video = await _videoService.getVideoById(videoId);
      if (video != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(
              videos: [video],
              initialIndex: 0,
              openCommentsOnLoad: true,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error navigating to video with comments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.isVietnamese 
                ? 'Không thể tải video' 
                : 'Unable to load video'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final userId = _authService.user!['id'].toString();
    
    final success = await _notificationService.deleteNotification(notificationId, userId);
    if (success) {
      setState(() {
        _notifications.removeWhere((n) => n['id'].toString() == notificationId);
        _swipeOffsets.remove(notificationId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.isVietnamese 
                ? 'Đã xóa thông báo' 
                : 'Notification deleted'),
            backgroundColor: ThemeService.accentColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final userId = _authService.user!['id'].toString();
    await _notificationService.markAllAsRead(userId);
    _loadNotifications();
  }

  void _showNotificationOptions(dynamic notification, Map<String, dynamic> userInfo) {
    final notificationId = notification['id'].toString();
    final isRead = notification['isRead'] ?? false;
    final userId = _authService.user!['id'].toString();
    final senderId = notification['senderId']?.toString();

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
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _themeService.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Options
              _buildOptionItem(
                icon: isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined,
                title: isRead 
                    ? (_localeService.isVietnamese ? 'Đánh dấu chưa đọc' : 'Mark as unread')
                    : (_localeService.isVietnamese ? 'Đánh dấu đã đọc' : 'Mark as read'),
                onTap: () async {
                  Navigator.pop(context);
                  if (!isRead) {
                    await _notificationService.markAsRead(notificationId, userId);
                    _loadNotifications();
                  }
                },
              ),
              
              if (senderId != null)
                _buildOptionItem(
                  icon: Icons.person_outline,
                  title: _localeService.isVietnamese 
                      ? 'Xem trang cá nhân ${userInfo['username']}' 
                      : 'View ${userInfo['username']}\'s profile',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: int.parse(senderId)),
                      ),
                    );
                  },
                ),
              
              _buildOptionItem(
                icon: Icons.delete_outline,
                title: _localeService.isVietnamese ? 'Xóa thông báo này' : 'Delete this notification',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _deleteNotification(notificationId);
                },
              ),
              
              const SizedBox(height: 8),
              
              // Cancel button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: _themeService.isLightMode 
                        ? Colors.grey[100] 
                        : Colors.grey[900],
                  ),
                  child: Text(
                    _localeService.isVietnamese ? 'Hủy' : 'Cancel',
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color ?? _themeService.iconColor, size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: color ?? _themeService.textPrimaryColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'like':
        return Icons.favorite_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'follow':
        return const Color(0xFF0095F6); // Instagram blue
      case 'comment':
        return const Color(0xFF00C853); // Green
      case 'like':
        return const Color(0xFFFF2D55); // Red/Pink
      default:
        return Colors.grey;
    }
  }

  Widget _buildNotificationMessage(dynamic notification, String username) {
    final type = notification['type']?.toString() ?? '';
    final TextStyle boldStyle = TextStyle(
      color: _themeService.textPrimaryColor,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final TextStyle normalStyle = TextStyle(
      color: _themeService.textPrimaryColor,
      fontSize: 14,
      fontWeight: FontWeight.normal,
    );

    switch (type) {
      case 'follow':
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(text: username, style: boldStyle),
              TextSpan(
                text: _localeService.isVietnamese 
                    ? ' bắt đầu theo dõi bạn' 
                    : ' started following you',
                style: normalStyle,
              ),
            ],
          ),
        );
      case 'comment':
        final message = notification['message']?.toString() ?? '';
        final preview = message.length > 40 ? '${message.substring(0, 40)}...' : message;
        return RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(text: username, style: boldStyle),
              TextSpan(
                text: ' ${_localeService.get('commented')}: ',
                style: normalStyle,
              ),
              TextSpan(
                text: preview,
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      case 'like':
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(text: username, style: boldStyle),
              TextSpan(
                text: _localeService.isVietnamese 
                    ? ' đã thích video của bạn' 
                    : ' liked your video',
                style: normalStyle,
              ),
            ],
          ),
        );
      default:
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(text: username, style: boldStyle),
              TextSpan(
                text: _localeService.isVietnamese 
                    ? ' đã tương tác với bạn' 
                    : ' interacted with you',
                style: normalStyle,
              ),
            ],
          ),
        );
    }
  }

  Widget _buildNotificationItem(dynamic notification, Map<String, dynamic> userInfo) {
    final isRead = notification['isRead'] ?? false;
    final type = notification['type']?.toString() ?? '';
    final notificationId = notification['id'].toString();
    final swipeOffset = _swipeOffsets[notificationId] ?? 0.0;
    
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          final newOffset = (swipeOffset + details.delta.dx).clamp(-80.0, 0.0);
          _swipeOffsets[notificationId] = newOffset;
        });
      },
      onHorizontalDragEnd: (details) {
        setState(() {
          if (swipeOffset < -40) {
            _swipeOffsets[notificationId] = -80.0;
          } else {
            _swipeOffsets[notificationId] = 0.0;
          }
        });
      },
      child: Stack(
        children: [
          // Background actions (delete button)
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // More options button
                GestureDetector(
                  onTap: () {
                    setState(() => _swipeOffsets[notificationId] = 0.0);
                    _showNotificationOptions(notification, userInfo);
                  },
                  child: Container(
                    width: 40,
                    color: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[700],
                    child: const Center(
                      child: Icon(Icons.more_horiz, color: Colors.white, size: 22),
                    ),
                  ),
                ),
                // Delete button
                GestureDetector(
                  onTap: () => _deleteNotification(notificationId),
                  child: Container(
                    width: 40,
                    color: const Color(0xFFFF3B30),
                    child: const Center(
                      child: Icon(Icons.delete_outline, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Notification content
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(swipeOffset, 0, 0),
            child: InkWell(
              onTap: () {
                if (swipeOffset < 0) {
                  setState(() => _swipeOffsets[notificationId] = 0.0);
                } else {
                  _handleNotificationTap(notification);
                }
              },
              onLongPress: () => _showNotificationOptions(notification, userInfo),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isRead 
                      ? _themeService.backgroundColor 
                      : (_themeService.isLightMode 
                          ? const Color(0xFFF0F8FF) 
                          : const Color(0xFF1A2A3A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar with notification type badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isRead 
                                  ? Colors.transparent 
                                  : _getNotificationColor(type).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: _themeService.isLightMode 
                                ? Colors.grey[200] 
                                : Colors.grey[800],
                            backgroundImage: userInfo['avatar'] != null
                                ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                                : null,
                            child: userInfo['avatar'] == null
                                ? Icon(Icons.person, 
                                    color: _themeService.textSecondaryColor, 
                                    size: 26)
                                : null,
                          ),
                        ),
                        // Notification type badge
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: _getNotificationColor(type),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _themeService.backgroundColor, 
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _getNotificationColor(type).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _getNotificationIcon(type),
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildNotificationMessage(
                            notification, 
                            userInfo['username'] ?? 'user',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeago.format(
                              DateTime.parse(notification['createdAt']),
                              locale: _localeService.isVietnamese ? 'vi' : 'en',
                            ),
                            style: TextStyle(
                              color: _themeService.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Action button or indicator
                    if (type == 'follow')
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: _buildFollowButton(notification),
                      )
                    else if (!isRead)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(left: 8, top: 4),
                        decoration: BoxDecoration(
                          color: _getNotificationColor(type),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _getNotificationColor(type).withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton(dynamic notification) {
    // You can implement follow back logic here
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0095F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _localeService.isVietnamese ? 'Theo dõi' : 'Follow',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        title,
        style: TextStyle(
          color: _themeService.textPrimaryColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedNotifications = _groupNotificationsByTime();
    final groupOrder = ['today', 'yesterday', 'this_week', 'this_month', 'older'];
    
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
          _localeService.get('notifications'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_notifications.any((n) => !(n['isRead'] ?? false)))
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                _localeService.isVietnamese ? 'Đọc tất cả' : 'Read all',
                style: const TextStyle(
                  color: Color(0xFF0095F6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: ThemeService.accentColor,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _localeService.isVietnamese 
                        ? 'Đang tải thông báo...' 
                        : 'Loading notifications...',
                    style: TextStyle(color: _themeService.textSecondaryColor),
                  ),
                ],
              ),
            )
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _themeService.isLightMode 
                              ? Colors.grey[100] 
                              : Colors.grey[900],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_off_outlined, 
                          size: 60, 
                          color: _themeService.textSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _localeService.get('no_notifications'),
                        style: TextStyle(
                          color: _themeService.textPrimaryColor, 
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          _localeService.isVietnamese 
                              ? 'Khi có người tương tác với bạn, thông báo sẽ xuất hiện ở đây' 
                              : 'When someone interacts with you, you\'ll see it here',
                          style: TextStyle(
                            color: _themeService.textSecondaryColor, 
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: ThemeService.accentColor,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: groupOrder.fold<int>(0, (count, key) {
                      final group = groupedNotifications[key]!;
                      if (group.isEmpty) return count;
                      return count + 1 + group.length; // header + items
                    }),
                    itemBuilder: (context, index) {
                      int currentIndex = 0;
                      
                      for (var key in groupOrder) {
                        final group = groupedNotifications[key]!;
                        if (group.isEmpty) continue;
                        
                        // Header
                        if (index == currentIndex) {
                          return _buildGroupHeader(_getGroupTitle(key));
                        }
                        currentIndex++;
                        
                        // Items
                        for (int i = 0; i < group.length; i++) {
                          if (index == currentIndex) {
                            final notification = group[i];
                            final senderId = notification['senderId']?.toString() ?? '';
                            
                            return FutureBuilder<Map<String, dynamic>>(
                              future: _getUserInfo(senderId),
                              builder: (context, snapshot) {
                                final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
                                return _buildNotificationItem(notification, userInfo);
                              },
                            );
                          }
                          currentIndex++;
                        }
                      }
                      
                      return const SizedBox.shrink();
                    },
                  ),
                ),
    );
  }
}
