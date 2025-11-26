import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

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

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  Timer? _typingTimer;

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
    // Connect to WebSocket
    if (_currentUserId.isNotEmpty) {
      _messageService.connect(_currentUserId);
    }

    // Listen for new messages
    _newMessageSubscription = _messageService.newMessageStream.listen((message) {
      if (message['senderId'] == widget.recipientId ||
          message['recipientId'] == widget.recipientId) {
        setState(() {
          _messages.insert(0, message);
        });
        _scrollToBottom();

        // Mark as read
        _messageService.markAsRead(_conversationId);
      }
    });

    // Listen for sent message confirmation
    _messageSentSubscription = _messageService.messageSentStream.listen((message) {
      // Message already added optimistically, update if needed
      final index = _messages.indexWhere((m) =>
          m['content'] == message['content'] &&
          m['senderId'] == _currentUserId &&
          m['id'] == null);

      if (index != -1) {
        setState(() {
          _messages[index] = message;
        });
      }
    });

    // Listen for typing indicator
    _typingSubscription = _messageService.userTypingStream.listen((data) {
      if (data['userId'] == widget.recipientId) {
        setState(() {
          _otherUserTyping = data['isTyping'] ?? false;
        });
      }
    });

    // Load existing messages
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      final messages = await _messageService.getMessages(
        _currentUserId,
        widget.recipientId,
      );

      if (mounted) {
        setState(() {
          _messages = messages.map((m) => Map<String, dynamic>.from(m)).toList();
          _isLoading = false;
        });

        // Mark as read
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

    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _messageService.sendTypingIndicator(widget.recipientId, false);
      }
    });

    setState(() {});
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty || _currentUserId.isEmpty) return;

    // Add message optimistically
    final tempMessage = {
      'id': null,
      'senderId': _currentUserId,
      'recipientId': widget.recipientId,
      'content': content,
      'createdAt': DateTime.now().toIso8601String(),
      'isRead': false,
    };

    setState(() {
      _messages.insert(0, tempMessage);
    });

    // Send via WebSocket
    _messageService.sendMessage(widget.recipientId, content);

    _messageController.clear();
    _isTyping = false;
    _messageService.sendTypingIndicator(widget.recipientId, false);

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0, // Since list is reversed
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
            // Avatar
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
            // User info
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
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
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
                const SnackBar(
                  content: Text('Tính năng gọi điện đang phát triển'),
                  backgroundColor: Colors.grey,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng video call đang phát triển'),
                  backgroundColor: Colors.grey,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Divider
          Container(height: 0.5, color: Colors.grey[900]),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.grey[800],
                              backgroundImage: widget.recipientAvatar != null
                                  ? NetworkImage(widget.recipientAvatar!)
                                  : null,
                              child: widget.recipientAvatar == null
                                  ? const Icon(Icons.person, color: Colors.white, size: 40)
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.recipientUsername,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Bắt đầu cuộc trò chuyện',
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true, // Show newest at bottom
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message['senderId'] == _currentUserId;
                          final showAvatar = !isMe &&
                              (index == _messages.length - 1 ||
                                  _messages[index + 1]['senderId'] == _currentUserId);

                          return _MessageBubble(
                            message: message['content'] ?? '',
                            isMe: isMe,
                            time: _formatTime(message['createdAt']),
                            showAvatar: showAvatar,
                            recipientAvatar: widget.recipientAvatar,
                            isRead: message['isRead'] ?? false,
                          );
                        },
                      ),
          ),

          // Input area
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: bottomInset > 0 ? 8 : bottomPadding + 8,
            ),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(color: Colors.grey[900]!, width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Camera button
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Text input
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          // Emoji button
                          GestureDetector(
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                Icons.emoji_emotions_outlined,
                                color: Colors.grey[500],
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send or other actions
                  if (_messageController.text.trim().isNotEmpty)
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.mic_none_rounded, color: Colors.grey[400], size: 28),
                        const SizedBox(width: 12),
                        Icon(Icons.image_outlined, color: Colors.grey[400], size: 28),
                        const SizedBox(width: 12),
                        Icon(Icons.favorite_border_rounded, color: Colors.grey[400], size: 28),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
}

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
    setState(() {
      _showTime = !_showTime;
    });
    
    if (_showTime) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        bottom: 2,
        left: widget.isMe ? 60 : 0,
        right: widget.isMe ? 0 : 60,
      ),
      child: Column(
        crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message row with avatar and bubble
          Row(
            mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar for other user
              if (!widget.isMe)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: widget.showAvatar
                      ? CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: widget.recipientAvatar != null
                              ? NetworkImage(widget.recipientAvatar!)
                              : null,
                          child: widget.recipientAvatar == null
                              ? const Icon(Icons.person, color: Colors.white, size: 14)
                              : null,
                        )
                      : const SizedBox(width: 28),
                ),

              // Message bubble - tap to show time
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
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Animated time display - full width, aligned to right edge
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _heightAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 4, right: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            widget.time,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
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
