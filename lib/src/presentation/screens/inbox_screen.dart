import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_screen.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
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

  List<Map<String, dynamic>> _conversations = [];
  Map<String, Map<String, dynamic>> _userCache = {};
  bool _isLoading = true;
  
  StreamSubscription? _newMessageSubscription;

  String get _currentUserId => _authService.user?['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _setupListeners();
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

  void _navigateToChat(Map<String, dynamic> conversation) async {
    final otherUserId = conversation['otherUserId']?.toString() ?? '';
    final userInfo = await _getUserInfo(otherUserId);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            recipientId: otherUserId,
            recipientUsername: userInfo['username'] ?? 'User',
            recipientAvatar: userInfo['avatar'] != null 
                ? _apiService.getAvatarUrl(userInfo['avatar']) 
                : null,
          ),
        ),
      ).then((_) {
        _loadConversations();
      });
    }
  }

  @override
  void dispose() {
    _newMessageSubscription?.cancel();
    super.dispose();
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return timeago.format(date, locale: 'vi');
    } catch (e) {
      return '';
    }
  }

  String _formatMessagePreview(String? content) {
    if (content == null || content.isEmpty) {
      return '';
    }
    
    if (content.startsWith('[VIDEO_SHARE:') && content.endsWith(']')) {
      return 'Đã chia sẻ một video';
    }
    
    if (content.startsWith('[IMAGE:') && content.endsWith(']')) {
      return 'Đã gửi một hình ảnh';
    }
    
    if (content.startsWith('[STICKER:') && content.endsWith(']')) {
      return 'Đã gửi một sticker';
    }
    
    if (content.startsWith('[VOICE:') && content.endsWith(']')) {
      return 'Đã gửi tin nhắn thoại';
    }
    
    return content;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hộp thư',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.white, size: 24),
            onPressed: () {},
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
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _conversations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mail_outline, size: 80, color: Colors.grey[700]),
                            const SizedBox(height: 16),
                            const Text(
                              'Chưa có tin nhắn',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Bắt đầu nhắn tin với bạn bè',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
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

                            return FutureBuilder<Map<String, dynamic>>(
                              future: _getUserInfo(otherUserId),
                              builder: (context, snapshot) {
                                final userInfo = snapshot.data ?? {'username': 'User', 'avatar': null};

                                return InkWell(
                                  onTap: () => _navigateToChat(conversation),
                                  highlightColor: Colors.grey[900],
                                  splashColor: Colors.transparent,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 28,
                                              backgroundColor: Colors.grey[800],
                                              backgroundImage: userInfo['avatar'] != null
                                                  ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                                                  : null,
                                              child: userInfo['avatar'] == null
                                                  ? const Icon(Icons.person, color: Colors.white, size: 28)
                                                  : null,
                                            ),
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: Colors.black, width: 2),
                                                ),
                                              ),
                                            ),
                                          ],
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
                                                      userInfo['username'] ?? 'User',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                                                        fontSize: 16,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatTime(conversation['updatedAt']),
                                                    style: TextStyle(
                                                      color: unreadCount > 0 ? Colors.blue : Colors.grey[600],
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
                                                      _formatMessagePreview(conversation['lastMessage']?.toString()),
                                                      style: TextStyle(
                                                        color: unreadCount > 0 ? Colors.white : Colors.grey[500],
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
