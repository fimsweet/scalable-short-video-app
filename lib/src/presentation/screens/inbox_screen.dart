import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/search_user_screen.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/utils/navigation_utils.dart';
import 'package:timeago/timeago.dart' as timeago;

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final MessageService _messageService = MessageService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  List<Map<String, dynamic>> _conversations = [];
  Map<String, Map<String, dynamic>> _userCache = {};
  Map<String, bool> _onlineStatusCache = {};
  Map<String, String?> _nicknameCache = {};
  bool _isLoading = true;
  
  StreamSubscription? _newMessageSubscription;

  String get _currentUserId => _authService.user?['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadConversations();
    _setupListeners();
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

  void _setupListeners() {
    if (_currentUserId.isNotEmpty) {
      _messageService.connect(_currentUserId);
    }

    _newMessageSubscription = _messageService.newMessageStream.listen((message) {
      _loadConversations();
    });
  }

  Future<void> _loadConversations() async {
    if (_currentUserId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final conversations = await _messageService.getConversations(_currentUserId);

      if (mounted) {
        setState(() {
          _conversations = conversations.map((c) => Map<String, dynamic>.from(c)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading conversations: $e');
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

    return {'username': 'User', 'avatar': null};
  }

  Future<bool> _getOnlineStatus(String userId) async {
    if (_onlineStatusCache.containsKey(userId)) {
      return _onlineStatusCache[userId]!;
    }

    try {
      final status = await _apiService.getOnlineStatus(userId);
      final isOnline = status['isOnline'] == true;
      _onlineStatusCache[userId] = isOnline;
      return isOnline;
    } catch (e) {
      print('❌ Error fetching online status: $e');
      return false;
    }
  }

  Future<String?> _getNickname(String recipientId) async {
    if (_nicknameCache.containsKey(recipientId)) {
      return _nicknameCache[recipientId];
    }

    try {
      final settings = await _messageService.getConversationSettings(recipientId);
      final nickname = settings['nickname'] as String?;
      _nicknameCache[recipientId] = nickname;
      return nickname;
    } catch (e) {
      print('❌ Error fetching nickname: $e');
      return null;
    }
  }

  void _navigateToChat(Map<String, dynamic> conversation) async {
    final otherUserId = conversation['otherUserId']?.toString() ?? '';
    final userInfo = await _getUserInfo(otherUserId);

    if (mounted) {
      NavigationUtils.slideToScreen(
        context,
        ChatScreen(
          recipientId: otherUserId,
          recipientUsername: userInfo['username'] ?? 'User',
          recipientAvatar: userInfo['avatar'] != null 
              ? _apiService.getAvatarUrl(userInfo['avatar']) 
              : null,
        ),
      ).then((_) {
        _loadConversations();
      });
    }
  }

  @override
  void dispose() {
    _newMessageSubscription?.cancel();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return '';
    try {
      DateTime date;
      // Parse ISO string từ server
      // TypeORM với NestJS trả về Date như "2025-01-15T10:30:00.000Z" hoặc "2025-01-15T10:30:00.000"
      if (dateString.endsWith('Z')) {
        // Có 'Z' suffix = UTC, convert sang local
        date = DateTime.parse(dateString).toLocal();
      } else if (dateString.contains('+') || dateString.contains('-') && dateString.lastIndexOf('-') > 7) {
        // Có timezone offset (+07:00 hoặc -05:00), parse bình thường
        date = DateTime.parse(dateString).toLocal();
      } else {
        // Không có timezone info - server trả về local time hoặc UTC không có Z
        // Assume là UTC và convert sang local
        final utcDate = DateTime.parse(dateString);
        date = DateTime.utc(utcDate.year, utcDate.month, utcDate.day, utcDate.hour, utcDate.minute, utcDate.second, utcDate.millisecond).toLocal();
      }
      return timeago.format(date, locale: _localeService.isVietnamese ? 'vi' : 'en');
    } catch (e) {
      print('Error parsing date: $e');
      return '';
    }
  }

  String _formatMessagePreview(String? content, {bool isMe = false, String otherUsername = ''}) {
    if (content == null || content.isEmpty) {
      return '';
    }
    
    if (content.startsWith('[VIDEO_SHARE:') && content.endsWith(']')) {
      return isMe 
          ? (_localeService.isVietnamese ? 'Bạn đã chia sẻ một video' : 'You shared a video')
          : (_localeService.isVietnamese ? '$otherUsername đã chia sẻ một video' : '$otherUsername shared a video');
    }
    
    // Handle stacked images (4+ images)
    if (content.startsWith('[STACKED_IMAGE:') && content.endsWith(']')) {
      final start = content.indexOf(':') + 1;
      final end = content.lastIndexOf(']');
      if (start > 0 && end > start) {
        final urlsString = content.substring(start, end);
        final imageCount = urlsString.split(',').where((url) => url.isNotEmpty).length;
        if (isMe) {
          return _localeService.isVietnamese ? 'Bạn đã gửi $imageCount ảnh' : 'You sent $imageCount photos';
        } else {
          return _localeService.isVietnamese ? '$otherUsername đã gửi $imageCount ảnh' : '$otherUsername sent $imageCount photos';
        }
      }
      return isMe 
          ? (_localeService.isVietnamese ? 'Bạn đã gửi nhiều ảnh' : 'You sent multiple photos')
          : (_localeService.isVietnamese ? '$otherUsername đã gửi nhiều ảnh' : '$otherUsername sent multiple photos');
    }
    
    // Handle single image
    if (content.startsWith('[IMAGE:') && content.endsWith(']')) {
      return isMe 
          ? (_localeService.isVietnamese ? 'Bạn đã gửi một ảnh' : 'You sent a photo')
          : (_localeService.isVietnamese ? '$otherUsername đã gửi một ảnh' : '$otherUsername sent a photo');
    }
    
    // Handle image in text
    if (content.contains('[IMAGE:')) {
      return isMe 
          ? (_localeService.isVietnamese ? 'Bạn đã gửi một ảnh' : 'You sent a photo')
          : (_localeService.isVietnamese ? '$otherUsername đã gửi một ảnh' : '$otherUsername sent a photo');
    }
    
    if (content.startsWith('[STICKER:') && content.endsWith(']')) {
      return isMe 
          ? (_localeService.isVietnamese ? 'Bạn đã gửi một sticker' : 'You sent a sticker')
          : (_localeService.isVietnamese ? '$otherUsername đã gửi một sticker' : '$otherUsername sent a sticker');
    }
    
    if (content.startsWith('[VOICE:') && content.endsWith(']')) {
      return isMe 
          ? (_localeService.isVietnamese ? 'Bạn đã gửi tin nhắn thoại' : 'You sent a voice message')
          : (_localeService.isVietnamese ? '$otherUsername đã gửi tin nhắn thoại' : '$otherUsername sent a voice message');
    }
    
    return isMe ? '${_localeService.get('you')}: $content' : content;
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
          _localeService.get('inbox'),
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1_outlined, color: _themeService.iconColor, size: 24),
            onPressed: () {
              NavigationUtils.slideToScreen(
                context,
                const SearchUserScreen(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                style: TextStyle(color: _themeService.textPrimaryColor),
                decoration: InputDecoration(
                  hintText: _localeService.get('search'),
                  hintStyle: TextStyle(color: _themeService.textSecondaryColor, fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: _themeService.textSecondaryColor, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _themeService.textPrimaryColor))
                : _conversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mail_outline, size: 80, color: _themeService.textSecondaryColor),
                            const SizedBox(height: 16),
                            Text(
                              _localeService.get('no_messages'),
                              style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _localeService.isVietnamese 
                                  ? 'Bắt đầu nhắn tin với bạn bè' 
                                  : 'Start messaging with friends',
                              style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadConversations,
                        child: ListView.builder(
                          itemCount: _conversations.length,
                          itemBuilder: (context, index) {
                            final conversation = _conversations[index];
                            final otherUserId = conversation['otherUserId']?.toString() ?? '';
                            final unreadCount = conversation['unreadCount'] ?? 0;
                            final lastMessageSenderId = conversation['lastMessageSenderId']?.toString() ?? '';
                            final isMe = lastMessageSenderId == _currentUserId;

                            return FutureBuilder<List<dynamic>>(
                              future: Future.wait([
                                _getUserInfo(otherUserId),
                                _getNickname(otherUserId),
                              ]),
                              builder: (context, snapshot) {
                                final userInfo = (snapshot.data?[0] as Map<String, dynamic>?) ?? {'username': 'User', 'avatar': null};
                                final nickname = snapshot.data?[1] as String?;
                                final otherUsername = userInfo['username'] ?? 'User';
                                final displayName = nickname ?? otherUsername;

                                return InkWell(
                                  onTap: () => _navigateToChat(conversation),
                                  highlightColor: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[900],
                                  splashColor: Colors.transparent,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        FutureBuilder<bool>(
                                          future: _getOnlineStatus(otherUserId),
                                          builder: (context, onlineSnapshot) {
                                            final isOnline = onlineSnapshot.data ?? false;
                                            return Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 28,
                                                  backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
                                                  backgroundImage: userInfo['avatar'] != null
                                                      ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                                                      : null,
                                                  child: userInfo['avatar'] == null
                                                      ? Icon(Icons.person, color: _themeService.textPrimaryColor, size: 28)
                                                      : null,
                                                ),
                                                if (isOnline)
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      width: 14,
                                                      height: 14,
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: _themeService.backgroundColor, width: 2),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      displayName,
                                                      style: TextStyle(
                                                        color: _themeService.textPrimaryColor,
                                                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                                                        fontSize: 16,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatTime(conversation['updatedAt']),
                                                    style: TextStyle(
                                                      color: unreadCount > 0 ? Colors.blue : _themeService.textSecondaryColor,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      _formatMessagePreview(
                                                        conversation['lastMessage']?.toString(),
                                                        isMe: isMe,
                                                        otherUsername: otherUsername,
                                                      ),
                                                      style: TextStyle(
                                                        color: unreadCount > 0 ? _themeService.textPrimaryColor : _themeService.textSecondaryColor,
                                                        fontSize: 14,
                                                        fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (unreadCount > 0)
                                                    Container(
                                                      margin: const EdgeInsets.only(left: 8),
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Text(
                                                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
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
          ),
        ],
      ),
    );
  }
}
