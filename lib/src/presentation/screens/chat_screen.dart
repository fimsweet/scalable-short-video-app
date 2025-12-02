import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String recipientId;
  final String recipientUsername;
  final String? recipientAvatar;

  const ChatScreen({
    super.key,
    required this.recipientId,
    required this.recipientUsername,
    this.recipientAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final MessageService _messageService = MessageService();
  final AuthService _authService = AuthService();
  final VideoService _videoService = VideoService();
  final ApiService _apiService = ApiService();

  // Change from ValueNotifier to regular List with setState for messages
  List<Map<String, dynamic>> _messages = [];
  
  bool _isLoading = true;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  Timer? _typingTimer;
  bool _isSending = false;
  
  // Cache for video data to prevent repeated API calls
  final Map<String, Map<String, dynamic>?> _videoCache = {};

  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _messageSentSubscription;
  StreamSubscription? _typingSubscription;

  String get _currentUserId => _authService.user?['id']?.toString() ?? '';
  String get _conversationId {
    final ids = [_currentUserId, widget.recipientId];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  @override
  void initState() {
    super.initState();
    _initChat();
    _messageController.addListener(_onTextChanged);
  }

  void _initChat() async {
    if (_currentUserId.isNotEmpty) {
      _messageService.connect(_currentUserId);
    }

    _newMessageSubscription = _messageService.newMessageStream.listen((message) {
      // Only add messages from the other user (incoming messages)
      // Our sent messages are handled by messageSentStream
      if (message['senderId']?.toString() == widget.recipientId) {
        if (mounted) {
          // Check if message already exists by id
          final messageId = message['id']?.toString();
          final exists = messageId != null && _messages.any((m) => 
            m['id']?.toString() == messageId
          );
          
          if (!exists) {
            setState(() {
              _messages.insert(0, message);
            });
            _scrollToBottom();
          }
        }
        _messageService.markAsRead(_conversationId);
      }
    });

    _messageSentSubscription = _messageService.messageSentStream.listen((message) {
      if (mounted) {
        final messageId = message['id']?.toString();
        final content = message['content']?.toString() ?? '';
        
        // First, check if message with this ID already exists
        if (messageId != null) {
          final existsById = _messages.any((m) => m['id']?.toString() == messageId);
          if (existsById) {
            // Message already exists, skip
            return;
          }
        }
        
        // Find temp message (id == null) with same content from current user
        final tempIndex = _messages.indexWhere((m) =>
            m['id'] == null &&
            m['content']?.toString() == content &&
            m['senderId']?.toString() == _currentUserId);

        if (tempIndex != -1) {
          // Replace temp message with real message
          setState(() {
            _messages[tempIndex] = message;
          });
        }
        // Don't add if temp not found - it means message was already added or doesn't belong here
      }
    });

    _typingSubscription = _messageService.userTypingStream.listen((data) {
      if (data['userId'] == widget.recipientId && mounted) {
        setState(() {
          _otherUserTyping = data['isTyping'] ?? false;
        });
      }
    });

    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final messages = await _messageService.getMessages(
        _currentUserId,
        widget.recipientId,
      );

      if (mounted) {
        // Clear existing messages and load fresh from server
        // This prevents duplicates when returning to the screen
        setState(() {
          _messages = messages.map((m) => Map<String, dynamic>.from(m)).toList();
          _isLoading = false;
        });
        _messageService.markAsRead(_conversationId);
      }
    } catch (e) {
      print('❌ Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      _messageService.sendTypingIndicator(widget.recipientId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _messageService.sendTypingIndicator(widget.recipientId, false);
      }
    });
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _currentUserId.isEmpty) return;
    
    if (_isSending) return;
    _isSending = true;

    final tempMessage = {
      'id': null,
      'senderId': _currentUserId,
      'recipientId': widget.recipientId,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': false,
    };

    if (mounted) {
      setState(() {
        _messages.insert(0, tempMessage);
      });
    }

    _messageController.clear();
    _isTyping = false;
    _messageService.sendTypingIndicator(widget.recipientId, false);

    await _messageService.sendMessage(
      recipientId: widget.recipientId,
      content: content,
    );

    _isSending = false;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _newMessageSubscription?.cancel();
    _messageSentSubscription?.cancel();
    _typingSubscription?.cancel();
    super.dispose();
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  bool _isVideoShare(String content) {
    return content.startsWith('[VIDEO_SHARE:') && content.endsWith(']');
  }

  String? _extractVideoId(String content) {
    if (!_isVideoShare(content)) return null;
    final start = content.indexOf(':') + 1;
    final end = content.indexOf(']');
    if (start > 0 && end > start) {
      return content.substring(start, end);
    }
    return null;
  }

  Future<void> _openSharedVideo(String videoId) async {
    try {
      final video = await _getVideoWithCache(videoId);
      
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video không còn tồn tại')),
        );
      }
    } catch (e) {
      print('❌ Error opening shared video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở video')),
      );
    }
  }

  Future<Map<String, dynamic>?> _getVideoWithCache(String videoId) async {
    if (_videoCache.containsKey(videoId)) {
      return _videoCache[videoId];
    }
    
    final video = await _videoService.getVideoById(videoId);
    _videoCache[videoId] = video;
    return video;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[800],
              backgroundImage: widget.recipientAvatar != null
                  ? NetworkImage(widget.recipientAvatar!)
                  : null,
              child: widget.recipientAvatar == null
                  ? const Icon(Icons.person, color: Colors.white, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientUsername,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_otherUserTyping)
                    const Text(
                      'Đang nhập...',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Đang hoạt động',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng gọi điện đang phát triển'), backgroundColor: Colors.grey),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng video call đang phát triển'), backgroundColor: Colors.grey),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(height: 0.5, color: Colors.grey[900]),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['senderId'] == _currentUserId;
                          final showAvatar = !isMe &&
                              (index == _messages.length - 1 ||
                                  _messages[index + 1]['senderId'] == _currentUserId);
                          final content = message['content']?.toString() ?? '';

                          if (_isVideoShare(content)) {
                            final videoId = _extractVideoId(content);
                            if (videoId != null) {
                              return _buildVideoShareRow(videoId, isMe, showAvatar);
                            }
                          }

                          return _MessageBubble(
                            message: content,
                            isMe: isMe,
                            time: _formatTime(message['createdAt']),
                            showAvatar: showAvatar,
                            recipientAvatar: widget.recipientAvatar,
                            isRead: message['isRead'] ?? false,
                          );
                        },
                      ),
          ),
          _buildInputArea(bottomInset, bottomPadding),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey[800],
            backgroundImage: widget.recipientAvatar != null ? NetworkImage(widget.recipientAvatar!) : null,
            child: widget.recipientAvatar == null ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
          ),
          const SizedBox(height: 16),
          Text(widget.recipientUsername, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Bắt đầu cuộc trò chuyện', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildVideoShareRow(String videoId, bool isMe, bool showAvatar) {
    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: 2, left: isMe ? 60 : 0, right: isMe ? 0 : 60),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: showAvatar
                  ? CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: widget.recipientAvatar != null ? NetworkImage(widget.recipientAvatar!) : null,
                      child: widget.recipientAvatar == null ? const Icon(Icons.person, color: Colors.white, size: 14) : null,
                    )
                  : const SizedBox(width: 28),
            ),
          _VideoShareBubble(
            videoId: videoId,
            isMe: isMe,
            videoService: _videoService,
            apiService: _apiService,
            videoCache: _videoCache,
            onTap: () => _openSharedVideo(videoId),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(double bottomInset, double bottomPadding) {
    return Container(
      padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: bottomInset > 0 ? 8 : bottomPadding + 8),
      decoration: BoxDecoration(color: Colors.black, border: Border(top: BorderSide(color: Colors.grey[900]!, width: 0.5))),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
                decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(20)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Nhắn tin...',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[500], size: 24),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                if (value.text.trim().isNotEmpty) {
                  return GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  );
                }
                return Row(
                  children: [
                    Icon(Icons.mic_none_rounded, color: Colors.grey[400], size: 28),
                    const SizedBox(width: 12),
                    Icon(Icons.image_outlined, color: Colors.grey[400], size: 28),
                    const SizedBox(width: 12),
                    Icon(Icons.favorite_border_rounded, color: Colors.grey[400], size: 28),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Separate StatefulWidget for message bubble with time toggle
class _MessageBubble extends StatefulWidget {
  final String message;
  final bool isMe;
  final String time;
  final bool showAvatar;
  final String? recipientAvatar;
  final bool isRead;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.time,
    this.showAvatar = false,
    this.recipientAvatar,
    this.isRead = false,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> with SingleTickerProviderStateMixin {
  bool _showTime = false;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _heightAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleTime() {
    setState(() => _showTime = !_showTime);
    if (_showTime) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 2, bottom: 2, left: widget.isMe ? 60 : 0, right: widget.isMe ? 0 : 60),
      child: Column(
        crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!widget.isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: widget.showAvatar
                      ? CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: widget.recipientAvatar != null ? NetworkImage(widget.recipientAvatar!) : null,
                          child: widget.recipientAvatar == null ? const Icon(Icons.person, color: Colors.white, size: 14) : null,
                        )
                      : const SizedBox(width: 28),
                ),
              Flexible(
                child: GestureDetector(
                  onTap: _toggleTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.isMe ? Colors.blue : Colors.grey[900],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
                        bottomRight: Radius.circular(widget.isMe ? 4 : 18),
                      ),
                    ),
                    child: Text(widget.message, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3)),
                  ),
                ),
              ),
            ],
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _heightAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          if (!widget.isMe) const SizedBox(width: 36),
                          Text(widget.time, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          if (widget.isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              widget.isRead ? Icons.done_all : Icons.done,
                              size: 14,
                              color: widget.isRead ? Colors.lightBlue : Colors.grey[600],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Separate widget for video share bubble with caching
class _VideoShareBubble extends StatefulWidget {
  final String videoId;
  final bool isMe;
  final VideoService videoService;
  final ApiService apiService;
  final Map<String, Map<String, dynamic>?> videoCache;
  final VoidCallback onTap;

  const _VideoShareBubble({
    required this.videoId,
    required this.isMe,
    required this.videoService,
    required this.apiService,
    required this.videoCache,
    required this.onTap,
  });

  @override
  State<_VideoShareBubble> createState() => _VideoShareBubbleState();
}

class _VideoShareBubbleState extends State<_VideoShareBubble> {
  Map<String, dynamic>? _videoData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    if (widget.videoCache.containsKey(widget.videoId)) {
      setState(() {
        _videoData = widget.videoCache[widget.videoId];
        _isLoading = false;
      });
      return;
    }

    final video = await widget.videoService.getVideoById(widget.videoId);
    widget.videoCache[widget.videoId] = video;
    
    if (mounted) {
      setState(() {
        _videoData = video;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: widget.isMe ? const Color(0xFF0084FF) : Colors.grey[850],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
            bottomRight: Radius.circular(widget.isMe ? 4 : 18),
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 9 / 12,
              child: _isLoading
                  ? Container(
                      color: Colors.black,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                    )
                  : _videoData != null
                      ? _buildVideoContent()
                      : _buildPlaceholder(),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.play_circle_outline_rounded, color: widget.isMe ? Colors.white.withOpacity(0.9) : Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Nhấn để xem', style: TextStyle(color: widget.isMe ? Colors.white.withOpacity(0.9) : Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: widget.isMe ? Colors.white.withOpacity(0.7) : Colors.white54, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    final thumbnailUrl = _videoData!['thumbnailUrl'] != null
        ? widget.videoService.getVideoUrl(_videoData!['thumbnailUrl'])
        : null;
    final username = _videoData!['username']?.toString() ?? 'user';
    final userAvatar = _videoData!['userAvatar']?.toString();
    final avatarUrl = userAvatar != null && userAvatar.isNotEmpty
        ? widget.apiService.getAvatarUrl(userAvatar)
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnailUrl != null)
          Image.network(thumbnailUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())
        else
          _buildPlaceholder(),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.7)],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
          ),
        ),
        Positioned(
          top: 8, left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_filled, color: Colors.white, size: 12),
                SizedBox(width: 2),
                Text('Video', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 8, left: 8, right: 8,
          child: Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: Colors.grey[800],
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null || avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 10) : null,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text('@$username', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_rounded, color: Colors.grey[600], size: 36),
            const SizedBox(height: 8),
            Text('Video', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
