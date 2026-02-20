import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/notification_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/app_snackbar.dart';
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
  final FollowService _followService = FollowService();

  // Tab controller
  late TabController _tabController;

  // Notifications tab state
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _userCache = {};
  final Map<String, double> _swipeOffsets = {};

  // Follow requests tab state
  List<Map<String, dynamic>> _followRequests = [];
  bool _isLoadingRequests = true;
  bool _hasMoreRequests = false;
  int _requestOffset = 0;
  final int _requestLimit = 20;
  int _pendingRequestCount = 0;
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadNotifications();
    _loadFollowRequests();
    _loadPendingCount();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPendingCount() async {
    if (!_authService.isLoggedIn || _authService.user == null) return;
    try {
      final userId = _authService.user!['id'] as int;
      final count = await _followService.getPendingRequestCount(userId);
      if (mounted) {
        setState(() => _pendingRequestCount = count);
      }
    } catch (e) {
      print('Error loading pending count: $e');
    }
  }

  Future<void> _loadFollowRequests({bool loadMore = false}) async {
    if (!_authService.isLoggedIn || _authService.user == null) return;

    if (!loadMore) {
      setState(() => _isLoadingRequests = true);
      _requestOffset = 0;
    }

    try {
      final userId = _authService.user!['id'] as int;
      final result = await _followService.getPendingRequests(
        userId,
        limit: _requestLimit,
        offset: _requestOffset,
      );

      if (mounted) {
        setState(() {
          if (loadMore) {
            _followRequests.addAll(List<Map<String, dynamic>>.from(result['data'] ?? []));
          } else {
            _followRequests = List<Map<String, dynamic>>.from(result['data'] ?? []);
          }
          _hasMoreRequests = result['hasMore'] ?? false;
          _pendingRequestCount = result['total'] ?? _followRequests.length;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      print('Error loading follow requests: $e');
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
    }
  }

  Future<void> _approveRequest(int followerId) async {
    if (_processingIds.contains(followerId)) return;
    
    final userId = _authService.user!['id'] as int;
    setState(() => _processingIds.add(followerId));

    final success = await _followService.approveFollowRequest(followerId, userId);

    if (mounted) {
      setState(() {
        _processingIds.remove(followerId);
        if (success) {
          _followRequests.removeWhere((r) => r['userId'] == followerId);
          _pendingRequestCount = (_pendingRequestCount - 1).clamp(0, 999999);
        }
      });

      if (success) {
        AppSnackBar.showSuccess(
          context,
          _localeService.isVietnamese 
              ? 'Đã chấp nhận yêu cầu theo dõi' 
              : 'Follow request accepted',
        );
      }
    }
  }

  Future<void> _rejectRequest(int followerId) async {
    if (_processingIds.contains(followerId)) return;
    
    final userId = _authService.user!['id'] as int;
    setState(() => _processingIds.add(followerId));

    final success = await _followService.rejectFollowRequest(followerId, userId);

    if (mounted) {
      setState(() {
        _processingIds.remove(followerId);
        if (success) {
          _followRequests.removeWhere((r) => r['userId'] == followerId);
          _pendingRequestCount = (_pendingRequestCount - 1).clamp(0, 999999);
        }
      });
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
      print('Error fetching user info: $e');
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
      case 'follow_request':
      case 'follow_request_accepted':
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
      if (video != null && video['isHidden'] != true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(
              videos: [video],
              initialIndex: 0,
            ),
          ),
        );
      } else if (mounted) {
        AppSnackBar.showError(
          context,
          _localeService.isVietnamese 
              ? 'Video không khả dụng hoặc đã bị xóa' 
              : 'Video is unavailable or has been deleted',
        );
      }
    } catch (e) {
      print('Error navigating to video: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          _localeService.isVietnamese 
              ? 'Không thể tải video' 
              : 'Unable to load video',
        );
      }
    }
  }

  Future<void> _navigateToVideoWithComments(String videoId) async {
    try {
      final video = await _videoService.getVideoById(videoId);
      if (video != null && video['isHidden'] != true && mounted) {
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
      } else if (mounted) {
        AppSnackBar.showError(
          context,
          _localeService.isVietnamese 
              ? 'Video không khả dụng hoặc đã bị xóa' 
              : 'Video is unavailable or has been deleted',
        );
      }
    } catch (e) {
      print('Error navigating to video with comments: $e');
      if (mounted) {
        AppSnackBar.showError(
          context,
          _localeService.isVietnamese 
              ? 'Không thể tải video' 
              : 'Unable to load video',
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
        AppSnackBar.showSuccess(
          context,
          _localeService.isVietnamese 
              ? 'Đã xóa thông báo' 
              : 'Notification deleted',
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
      case 'follow_request_accepted':
        return Icons.person_add_rounded;
      case 'follow_request':
        return Icons.person_add_alt_1_rounded;
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
      case 'follow_request_accepted':
        return const Color(0xFF0095F6); // Instagram blue
      case 'follow_request':
        return const Color(0xFFFF9500); // Orange
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
      case 'follow_request':
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(text: username, style: boldStyle),
              TextSpan(
                text: _localeService.isVietnamese 
                    ? ' đã gửi yêu cầu theo dõi bạn' 
                    : ' sent you a follow request',
                style: normalStyle,
              ),
            ],
          ),
        );
      case 'follow_request_accepted':
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(text: username, style: boldStyle),
              TextSpan(
                text: _localeService.isVietnamese 
                    ? ' đã chấp nhận yêu cầu theo dõi của bạn' 
                    : ' accepted your follow request',
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
                          ? const Color(0xFFF5F5F5) 
                          : const Color(0xFF2A2A2A)),
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
                            backgroundImage: userInfo['avatar'] != null && userInfo['avatar'].toString().isNotEmpty
                                ? (userInfo['avatar'] != null && _apiService.getAvatarUrl(userInfo['avatar']).isNotEmpty ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar'])) : null)
                                : null,
                            child: userInfo['avatar'] == null || userInfo['avatar'].toString().isEmpty
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
                    
                    // Action button for follow / follow_request_accepted
                    if (type == 'follow' || type == 'follow_request_accepted')
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        child: _buildFollowButton(notification),
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
          _localeService.get('notifications'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_tabController.index == 0 && _notifications.any((n) => !(n['isRead'] ?? false)))
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _themeService.dividerColor.withOpacity(0.15),
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              onTap: (_) => setState(() {}),
              indicatorColor: _themeService.textPrimaryColor,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: _themeService.textPrimaryColor,
              unselectedLabelColor: _themeService.textSecondaryColor,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
              dividerColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: [
                Tab(text: _localeService.isVietnamese ? 'Hoạt động' : 'Activity'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _localeService.isVietnamese ? 'Yêu cầu theo dõi' : 'Follow Requests',
                      ),
                      if (_pendingRequestCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _pendingRequestCount > 99 ? '99+' : _pendingRequestCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsTab(),
          _buildFollowRequestsTab(),
        ],
      ),
    );
  }

  // ==================== NOTIFICATIONS TAB ====================

  Widget _buildNotificationsTab() {
    final groupedNotifications = _groupNotificationsByTime();
    final groupOrder = ['today', 'yesterday', 'this_week', 'this_month', 'older'];

    if (_isLoading) {
      return Center(
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
      );
    }

    if (_notifications.isEmpty) {
      return Center(
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
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: ThemeService.accentColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: groupOrder.fold<int>(0, (count, key) {
          final group = groupedNotifications[key]!;
          if (group.isEmpty) return count;
          return count + 1 + group.length;
        }),
        itemBuilder: (context, index) {
          int currentIndex = 0;
          
          for (var key in groupOrder) {
            final group = groupedNotifications[key]!;
            if (group.isEmpty) continue;
            
            if (index == currentIndex) {
              return _buildGroupHeader(_getGroupTitle(key));
            }
            currentIndex++;
            
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
    );
  }

  // ==================== FOLLOW REQUESTS TAB ====================

  Widget _buildFollowRequestsTab() {
    if (_isLoadingRequests) {
      return Center(
        child: CircularProgressIndicator(
          color: _themeService.textPrimaryColor,
        ),
      );
    }

    if (_followRequests.isEmpty) {
      return Center(
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
                Icons.person_add_disabled_outlined, 
                size: 60, 
                color: _themeService.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _localeService.isVietnamese 
                  ? 'Không có yêu cầu theo dõi nào' 
                  : 'No follow requests',
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
                    ? 'Khi ai đó gửi yêu cầu theo dõi, bạn sẽ thấy ở đây' 
                    : 'When someone sends you a follow request, you\'ll see it here',
                style: TextStyle(
                  color: _themeService.textSecondaryColor, 
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            _hasMoreRequests &&
            !_isLoadingRequests) {
          _requestOffset += _requestLimit;
          _loadFollowRequests(loadMore: true);
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadFollowRequests();
        },
        color: const Color(0xFFFF2D55),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _followRequests.length,
          itemBuilder: (context, index) {
            final request = _followRequests[index];
            return _buildFollowRequestItem(request);
          },
        ),
      ),
    );
  }

  Widget _buildFollowRequestItem(Map<String, dynamic> request) {
    final userId = request['userId'] as int;
    final username = request['username'] ?? 'user';
    final fullName = request['fullName'] as String?;
    final avatar = request['avatar'] as String?;
    final isProcessing = _processingIds.contains(userId);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: userId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
              backgroundImage: avatar != null && avatar.isNotEmpty && _apiService.getAvatarUrl(avatar).isNotEmpty
                  ? NetworkImage(_apiService.getAvatarUrl(avatar))
                  : null,
              child: avatar == null || avatar.isEmpty || _apiService.getAvatarUrl(avatar).isEmpty
                  ? Icon(Icons.person, color: _themeService.textSecondaryColor, size: 24)
                  : null,
            ),
            const SizedBox(width: 14),
            
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (fullName != null && fullName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      fullName,
                      style: TextStyle(
                        color: _themeService.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Approve / Reject buttons
            if (isProcessing)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _approveRequest(userId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2D55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _localeService.isVietnamese ? 'Chấp nhận' : 'Accept',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _rejectRequest(userId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _localeService.isVietnamese ? 'Từ chối' : 'Reject',
                        style: TextStyle(
                          color: _themeService.textPrimaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
