import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_options_screen.dart';
import 'dart:io';

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
  final ThemeService _themeService = ThemeService();
  
  // Initialize ImagePicker as late to ensure proper initialization
  late final ImagePicker _imagePicker;

  // Change from ValueNotifier to regular List with setState for messages
  List<Map<String, dynamic>> _messages = [];
  
  bool _isLoading = true;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  Timer? _typingTimer;
  bool _isSending = false;
  
  // Cache for video data to prevent repeated API calls
  final Map<String, Map<String, dynamic>?> _videoCache = {};

  // Selected images for attachment - Use nullable and late init
  List<XFile>? _selectedImagesList;
  Map<String, Uint8List>? _imagePreviewCacheMap;

  // Safe getters
  List<XFile> get _selectedImages => _selectedImagesList ??= [];
  Map<String, Uint8List> get _imagePreviewCache => _imagePreviewCacheMap ??= {};

  // Safe getter for checking if images are selected
  bool get _hasSelectedImages {
    try {
      return _selectedImagesList != null && _selectedImagesList!.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Safe getter for selected images count
  int get _selectedImagesCount {
    try {
      return _selectedImagesList?.length ?? 0;
    } catch (e) {
      return 0;
    }
  }

  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _messageSentSubscription;
  StreamSubscription? _typingSubscription;

  String get _currentUserId => _authService.user?['id']?.toString() ?? '';
  String get _conversationId {
    final ids = [_currentUserId, widget.recipientId];
    ids.sort();
    return '${ids[0]}_${ids[1]}';
  }

  bool _showEmojiPicker = false;
  bool _isUserBlocked = false; // Track if I blocked the recipient
  bool _amIBlocked = false; // Track if recipient blocked me
  bool _isCheckingBlockStatus = true; // Track if we're still checking block status

  // Common emojis for quick access - CHANGED TO STATIC CONST
  static const List<String> _commonEmojis = [
    '😀', '😂', '🥰', '😍', '🤩', '😊', '😇', '🙂',
    '😉', '😌', '😋', '🤪', '😜', '🤗', '🤭', '🤫',
    '🤔', '😮', '😯', '😲', '😳', '🥺', '😢', '😭',
    '😤', '😠', '🤬', '😈', '👿', '💀', '☠️', '💩',
    '🤡', '👹', '👺', '👻', '👽', '👾', '🤖', '😺',
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘',
    '👍', '👎', '👊', '✊', '🤛', '🤜', '🤝', '👏',
    '🙌', '👐', '🤲', '🙏', '✌️', '🤞', '🤟', '🤘',
    '👌', '🤌', '🤏', '👈', '👉', '👆', '👇', '☝️',
    '🔥', '💯', '✨', '⭐', '🌟', '💫', '🎉', '🎊',
  ];

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _selectedImagesList = [];
    _imagePreviewCacheMap = {};
    _imagePicker = ImagePicker();
    _initChat();
    _messageController.addListener(_onTextChanged);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initChat() async {
    if (_currentUserId.isNotEmpty) {
      _messageService.connect(_currentUserId);
      
      // Check if user is blocked
      _checkBlockedStatus();
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

  Future<void> _checkBlockedStatus() async {
    try {
      // Check if I blocked the recipient
      final isBlocked = await _apiService.isUserBlocked(_currentUserId, widget.recipientId);
      // Check if recipient blocked me
      final amIBlocked = await _apiService.isUserBlocked(widget.recipientId, _currentUserId);
      
      if (mounted) {
        setState(() {
          _isUserBlocked = isBlocked;
          _amIBlocked = amIBlocked;
          _isCheckingBlockStatus = false;
        });
      }
    } catch (e) {
      print('Error checking blocked status: $e');
      if (mounted) {
        setState(() {
          _isCheckingBlockStatus = false;
        });
      }
    }
  }

  void _onTextChanged() {
    // Rebuild UI to update send button color
    if (mounted) {
      setState(() {});
    }
    
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
    final hasImages = _hasSelectedImages; // Use safe getter
    
    if (content.isEmpty && !hasImages) return;
    if (_currentUserId.isEmpty) return;
    if (_isSending) return;
    
    // If blocked by recipient, don't send (input should already be hidden)
    if (_amIBlocked) return;
    
    _isSending = true;

    final textToSend = content;
    final imagesToSend = List<XFile>.from(_selectedImages);
    
    _messageController.clear();
    _clearSelectedImages();
    _isTyping = false;
    _messageService.sendTypingIndicator(widget.recipientId, false);

    try {
      // Upload images first if any
      List<String> imageUrls = [];
      if (imagesToSend.isNotEmpty) {
        for (var image in imagesToSend) {
          final uploadResult = await _messageService.uploadImage(image);
          if (uploadResult != null && uploadResult.isNotEmpty) {
            imageUrls.add(uploadResult);
          }
        }
      }

      // CASE 1: 4+ images - send as stacked images (single message)
      if (imageUrls.length >= 4) {
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        final imageUrlsStr = imageUrls.join(',');
        final imageContent = '[STACKED_IMAGE:$imageUrlsStr]';
        
        final tempMessage = {
          'id': null,
          'tempId': tempId,
          'senderId': _currentUserId,
          'recipientId': widget.recipientId,
          'content': imageContent,
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'status': 'sending',
        };

        if (mounted) {
          setState(() => _messages.insert(0, tempMessage));
        }

        await _messageService.sendMessage(
          recipientId: widget.recipientId,
          content: imageContent,
        );

        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m['tempId'] == tempId);
            if (index != -1) {
              _messages[index] = {..._messages[index], 'status': 'sent'};
            }
          });
        }
      }
      // CASE 2: 1-3 images - send each image separately
      else if (imageUrls.isNotEmpty) {
        for (int i = 0; i < imageUrls.length; i++) {
          final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_$i';
          final imageContent = '[IMAGE:${imageUrls[i]}]';
          
          final tempMessage = {
            'id': null,
            'tempId': tempId,
            'senderId': _currentUserId,
            'recipientId': widget.recipientId,
            'content': imageContent,
            'createdAt': DateTime.now().toIso8601String(),
            'isRead': false,
            'status': 'sending',
          };

          if (mounted) {
            setState(() => _messages.insert(0, tempMessage));
          }

          await _messageService.sendMessage(
            recipientId: widget.recipientId,
            content: imageContent,
          );

          if (mounted) {
            setState(() {
              final index = _messages.indexWhere((m) => m['tempId'] == tempId);
              if (index != -1) {
                _messages[index] = {..._messages[index], 'status': 'sent'};
              }
            });
          }
        }
      }

      // CASE 3: Send text message separately (if any)
      if (textToSend.isNotEmpty) {
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_text';
        
        final tempMessage = {
          'id': null,
          'tempId': tempId,
          'senderId': _currentUserId,
          'recipientId': widget.recipientId,
          'content': textToSend,
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'status': 'sending',
        };

        if (mounted) {
          setState(() => _messages.insert(0, tempMessage));
        }

        await _messageService.sendMessage(
          recipientId: widget.recipientId,
          content: textToSend,
        );

        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m['tempId'] == tempId);
            if (index != -1) {
              _messages[index] = {..._messages[index], 'status': 'sent'};
            }
          });
        }
      }
    } catch (e) {
      print('❌ Error sending message: $e');
    }

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
    _themeService.removeListener(_onThemeChanged);
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
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(date.year, date.month, date.day);
      final difference = today.difference(messageDate).inDays;
      
      final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      
      // Hôm nay: chỉ hiển thị giờ
      if (difference == 0) {
        return timeStr;
      }
      
      // Hôm qua
      if (difference == 1) {
        return 'Hôm qua, $timeStr';
      }
      
      // Trong tuần này (2-6 ngày trước): hiển thị thứ, giờ
      if (difference < 7) {
        final weekday = _getVietnameseWeekday(date.weekday);
        return '$weekday, $timeStr';
      }
      
      // Trong năm nay: ngày/tháng, giờ
      if (date.year == now.year) {
        return '${date.day} Th${date.month}, $timeStr';
      }
      
      // Năm trước: ngày/tháng/năm, giờ
      return '${date.day} Th${date.month} ${date.year}, $timeStr';
    } catch (e) {
      return '';
    }
  }

  String _getVietnameseWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'T2';
      case 2:
        return 'T3';
      case 3:
        return 'T4';
      case 4:
        return 'T5';
      case 5:
        return 'T6';
      case 6:
        return 'T7';
      case 7:
        return 'CN';
      default:
        return '';
    }
  }

  bool _isVideoShare(String content) {
    return content.startsWith('[VIDEO_SHARE:') && content.endsWith(']');
  }

  // Helper method to check time gap between messages (for avatar grouping like Messenger)
  bool _hasSignificantTimeGap(String? time1, String? time2) {
    if (time1 == null || time2 == null) return true;
    try {
      final date1 = DateTime.parse(time1);
      final date2 = DateTime.parse(time2);
      // If more than 5 minutes apart, consider it a new group
      return date1.difference(date2).abs().inMinutes > 5;
    } catch (e) {
      return false;
    }
  }

  // Check if message is stacked images (4+ images)
  bool _isStackedImages(String content) {
    return content.startsWith('[STACKED_IMAGE:') && content.endsWith(']');
  }

  // Extract stacked image URLs
  List<String> _extractStackedImageUrls(String content) {
    if (!_isStackedImages(content)) return [];
    final start = content.indexOf(':') + 1;
    final end = content.lastIndexOf(']');
    if (start > 0 && end > start) {
      final urlsString = content.substring(start, end);
      return urlsString.split(',').where((url) => url.isNotEmpty).toList();
    }
    return [];
  }

  // Add method to check if message contains images
  bool _hasImageContent(String content) {
    return content.contains('[IMAGE:');
  }

  // Add method to extract image URLs from content
  List<String> _extractImageUrls(String content) {
    final regex = RegExp(r'\[IMAGE:([^\]]+)\]');
    final match = regex.firstMatch(content);
    if (match != null) {
      final urlsString = match.group(1) ?? '';
      return urlsString.split(',').where((url) => url.isNotEmpty).toList();
    }
    return [];
  }

  // Add method to get text content without image tags
  String _getTextWithoutImages(String content) {
    return content.replaceAll(RegExp(r'\n?\[IMAGE:[^\]]+\]'), '').trim();
  }

  // Add method to build full image URL
  String _getFullImageUrl(String imagePath) {
    if (imagePath.startsWith('http')) {
      return imagePath;
    }
    // Use video service base URL for chat images
    return _videoService.getVideoUrl(imagePath);
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

  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty && mounted) {
        final newImages = <XFile>[];
        for (var image in images) {
          try {
            final key = _getImageKey(image);
            if (_imagePreviewCacheMap != null && !_imagePreviewCacheMap!.containsKey(key)) {
              final bytes = await image.readAsBytes();
              _imagePreviewCacheMap![key] = bytes;
            }
            newImages.add(image);
          } catch (e) {
            print('❌ Error loading image preview: $e');
          }
        }
        
        if (newImages.isNotEmpty) {
          setState(() {
            _selectedImagesList ??= [];
            _selectedImagesList!.addAll(newImages);
          });
        }
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn ảnh: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null && mounted) {
        try {
          final bytes = await photo.readAsBytes();
          final key = _getImageKey(photo);
          _imagePreviewCacheMap ??= {};
          _imagePreviewCacheMap![key] = bytes;
          
          setState(() {
            _selectedImagesList ??= [];
            _selectedImagesList!.add(photo);
          });
        } catch (e) {
          print('❌ Error loading photo preview: $e');
        }
      }
    } catch (e) {
      print('❌ Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chụp ảnh: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getImageKey(XFile image) {
    if (image.path.isNotEmpty) {
      return image.path;
    }
    return '${image.name}_${DateTime.now().millisecondsSinceEpoch}';
  }

  void _removeSelectedImage(int index) {
    if (_selectedImagesList == null) return;
    if (index >= 0 && index < _selectedImagesList!.length) {
      setState(() {
        final removed = _selectedImagesList!.removeAt(index);
        final key = _getImageKey(removed);
        _imagePreviewCacheMap?.remove(key);
      });
    }
  }

  void _clearSelectedImages() {
    setState(() {
      _selectedImagesList = [];
      _imagePreviewCacheMap = {};
    });
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      emoji,
    );
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  void _showChatOptions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatOptionsScreen(
          recipientId: widget.recipientId,
          recipientUsername: widget.recipientUsername,
          recipientAvatar: widget.recipientAvatar,
        ),
      ),
    ).then((_) {
      // Refresh blocked status when returning from options
      _checkBlockedStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.appBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _themeService.iconColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
              backgroundImage: widget.recipientAvatar != null
                  ? NetworkImage(widget.recipientAvatar!)
                  : null,
              child: widget.recipientAvatar == null
                  ? Icon(Icons.person, color: _themeService.iconColor, size: 18)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.recipientUsername,
                    style: TextStyle(
                      color: _themeService.textPrimaryColor,
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
                    Text(
                      'Đang hoạt động',
                      style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: _themeService.iconColor),
            onPressed: _showChatOptions,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(height: 0.5, color: _themeService.dividerColor),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _focusNode.unfocus();
                setState(() => _showEmojiPicker = false);
              },
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _themeService.textPrimaryColor))
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
                            final content = message['content']?.toString() ?? '';
                            final status = message['status']?.toString();
                            
                            // Messenger-style avatar logic:
                            // Show avatar if:
                            // 1. It's the last message in a group from this sender (next message is from different sender or doesn't exist)
                            // 2. OR there's a significant time gap (>5 min) from the previous message in the group
                            bool showAvatar = false;
                            if (!isMe) {
                              // Check if next message (older, higher index) is from different sender
                              final isLastInGroup = index == _messages.length - 1 ||
                                  _messages[index + 1]['senderId'] == _currentUserId;
                              
                              // Check if there's a time gap from previous message in same direction
                              bool hasTimeGap = false;
                              if (index < _messages.length - 1 && 
                                  _messages[index + 1]['senderId'] != _currentUserId) {
                                // Previous message is also from recipient, check time gap
                                hasTimeGap = _hasSignificantTimeGap(
                                  message['createdAt']?.toString(),
                                  _messages[index + 1]['createdAt']?.toString(),
                                );
                              }
                              
                              showAvatar = isLastInGroup || hasTimeGap;
                            }
                            
                            // Chỉ hiện status cho tin nhắn cuối cùng của mình (như Messenger)
                            // Do list reverse, tin nhắn mới nhất ở index 0
                            // Tìm xem đây có phải tin nhắn cuối cùng của mình không
                            bool isLastMyMessage = false;
                            if (isMe) {
                              // Kiểm tra xem có tin nhắn nào của mình trước đó (index nhỏ hơn) không
                              isLastMyMessage = true;
                              for (int i = 0; i < index; i++) {
                                if (_messages[i]['senderId'] == _currentUserId) {
                                  isLastMyMessage = false;
                                  break;
                                }
                              }
                            }

                            if (_isVideoShare(content)) {
                              final videoId = _extractVideoId(content);
                              if (videoId != null) {
                                return _buildVideoShareRow(videoId, isMe, showAvatar);
                              }
                            }

                            // Check if message is stacked images (4+ images like Messenger)
                            if (_isStackedImages(content)) {
                              final imageUrls = _extractStackedImageUrls(content);
                              return _StackedImagesBubble(
                                imageUrls: imageUrls,
                                isMe: isMe,
                                time: _formatTime(message['createdAt']),
                                showAvatar: showAvatar,
                                recipientAvatar: widget.recipientAvatar,
                                isRead: message['isRead'] ?? false,
                                status: status,
                                getFullImageUrl: _getFullImageUrl,
                                showStatus: isLastMyMessage,
                              );
                            }

                            // Check if message contains single image
                            if (_hasImageContent(content)) {
                              final imageUrls = _extractImageUrls(content);
                              final textContent = _getTextWithoutImages(content);
                              return _ImageMessageBubble(
                                imageUrls: imageUrls,
                                text: textContent,
                                isMe: isMe,
                                time: _formatTime(message['createdAt']),
                                showAvatar: showAvatar,
                                recipientAvatar: widget.recipientAvatar,
                                isRead: message['isRead'] ?? false,
                                status: status,
                                getFullImageUrl: _getFullImageUrl,
                                showStatus: isLastMyMessage,
                              );
                            }

                            return _MessageBubble(
                              message: content,
                              isMe: isMe,
                              time: _formatTime(message['createdAt']),
                              showAvatar: showAvatar,
                              recipientAvatar: widget.recipientAvatar,
                              isRead: message['isRead'] ?? false,
                              status: status,
                              showStatus: isLastMyMessage,
                              themeService: _themeService,
                            );
                          },
                        ),
            ),
          ),
          // Image attachment preview - use safe getter
          if (_hasSelectedImages && !_isUserBlocked && !_amIBlocked && !_isCheckingBlockStatus) _buildImageAttachmentPreview(),
          // Show blocked message, cannot contact message, or input area
          // Hide input while checking block status to prevent flicker
          if (_isCheckingBlockStatus)
            const SizedBox.shrink() // Don't show anything while checking
          else if (_isUserBlocked)
            _buildBlockedMessage()
          else if (_amIBlocked)
            _buildCannotContactMessage()
          else
            _buildInputArea(bottomInset, bottomPadding),
          if (_showEmojiPicker && !_isUserBlocked && !_amIBlocked && !_isCheckingBlockStatus) _buildEmojiPicker(),
        ],
      ),
    );
  }

  Widget _buildCannotContactMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      color: _themeService.backgroundColor,
      child: Center(
        child: Text(
          'Hiện tại không thể liên lạc với người này',
          style: TextStyle(
            color: _themeService.textSecondaryColor,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      color: _themeService.backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, color: _themeService.textSecondaryColor, size: 18),
          const SizedBox(width: 8),
          Text(
            'Bạn đã chặn người dùng này.',
            style: TextStyle(
              color: _themeService.textSecondaryColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatOptionsScreen(
                    recipientId: widget.recipientId,
                    recipientUsername: widget.recipientUsername,
                    recipientAvatar: widget.recipientAvatar,
                  ),
                ),
              ).then((_) => _checkBlockedStatus());
            },
            child: const Text(
              'Bỏ chặn',
              style: TextStyle(
                color: Color(0xFFE84C3D),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
            backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
            backgroundImage: widget.recipientAvatar != null ? NetworkImage(widget.recipientAvatar!) : null,
            child: widget.recipientAvatar == null ? Icon(Icons.person, color: _themeService.iconColor, size: 40) : null,
          ),
          const SizedBox(height: 16),
          Text(widget.recipientUsername, style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Bắt đầu cuộc trò chuyện', style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 14)),
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
                      backgroundColor: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
                      backgroundImage: widget.recipientAvatar != null ? NetworkImage(widget.recipientAvatar!) : null,
                      child: widget.recipientAvatar == null ? Icon(Icons.person, color: _themeService.iconColor, size: 14) : null,
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

  Widget _buildImageAttachmentPreview() {
    if (!_hasSelectedImages) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
        border: Border(
          top: BorderSide(color: _themeService.dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Add more images button
              GestureDetector(
                onTap: _pickImageFromGallery,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[700]!, width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400], size: 28),
                      const SizedBox(height: 4),
                      Text(
                        'Thêm',
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Selected images
              Expanded(
                child: SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImagesCount,
                    itemBuilder: (context, index) {
                      if (_selectedImagesList == null || index >= _selectedImagesList!.length) {
                        return const SizedBox.shrink();
                      }
                      
                      final image = _selectedImagesList![index];
                      final key = _getImageKey(image);
                      final bytes = _imagePreviewCacheMap?[key];
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[700]!, width: 1),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: bytes != null
                                    ? Image.memory(
                                        bytes,
                                        fit: BoxFit.cover,
                                        width: 72,
                                        height: 72,
                                      )
                                    : Container(
                                        color: Colors.grey[800],
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            // Remove button
                            Positioned(
                              top: -6,
                              right: -6,
                              child: GestureDetector(
                                onTap: () => _removeSelectedImage(index),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[700],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey[900]!, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(double bottomInset, double bottomPadding) {
    final hasText = _messageController.text.trim().isNotEmpty;
    final canSend = hasText || _hasSelectedImages; // Use safe getter
    
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 10,
        bottom: _showEmojiPicker ? 10 : (bottomInset > 0 ? 10 : bottomPadding + 10),
      ),
      decoration: BoxDecoration(
        color: _themeService.backgroundColor,
        border: Border(top: BorderSide(color: _themeService.dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        bottom: !_showEmojiPicker,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Camera/Image picker button
            if (kIsWeb) ...[
              GestureDetector(
                onTap: _pickImageFromGallery,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
              ),
            ] else ...[
              GestureDetector(
                onTap: _pickImageFromGallery,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_rounded,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
              ),
            ],
            
            // Text input field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
                decoration: BoxDecoration(
                  color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        style: TextStyle(color: _themeService.textPrimaryColor, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: _hasSelectedImages  // Use safe getter
                              ? 'Thêm tin nhắn...' 
                              : 'Nhắn tin...',
                          hintStyle: TextStyle(color: _themeService.textSecondaryColor, fontSize: 16),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, 
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        onTap: () {
                          if (_showEmojiPicker) {
                            setState(() => _showEmojiPicker = false);
                          }
                        },
                      ),
                    ),
                    
                    // Emoji button
                    GestureDetector(
                      onTap: _toggleEmojiPicker,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          _showEmojiPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                          color: _showEmojiPicker ? Colors.blue : Colors.grey[500],
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Send button - Messenger/Instagram style (no circle background)
            GestureDetector(
              onTap: _sendMessage, // Always allow tap
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  Icons.send_rounded,
                  color: canSend ? Colors.blue : _themeService.textSecondaryColor,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    VoidCallback? onTap,
    double size = 44,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: size * 0.5,
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: _themeService.isLightMode ? Colors.grey[100] : Colors.grey[900],
        border: Border(top: BorderSide(color: _themeService.dividerColor, width: 0.5)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Biểu tượng cảm xúc',
                  style: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showEmojiPicker = false),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _themeService.textSecondaryColor,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          // Emoji grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: _commonEmojis.length,
              itemBuilder: (context, index) {
                final emoji = _commonEmojis[index];
                return GestureDetector(
                  onTap: () => _insertEmoji(emoji),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              },
            ),
          ),
          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
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
  final String? status;
  final bool showStatus;
  final ThemeService themeService;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.time,
    this.showAvatar = false,
    this.recipientAvatar,
    this.isRead = false,
    this.status,
    this.showStatus = false,
    required this.themeService,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> with SingleTickerProviderStateMixin {
  bool _showTime = false;
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
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

  Widget _buildStatusIndicator() {
    if (!widget.isMe) return const SizedBox.shrink();
    
    final status = widget.status;
    
    if (status == 'sending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Đang gửi',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      );
    }
    
    if (status == 'failed') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 14, color: Colors.red[400]),
          const SizedBox(width: 4),
          Text(
            'Gửi thất bại',
            style: TextStyle(color: Colors.red[400], fontSize: 11),
          ),
        ],
      );
    }
    
    // Đã xem
    if (widget.isRead) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 14, color: Colors.lightBlue),
          const SizedBox(width: 4),
          Text(
            'Đã xem',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      );
    }
    
    // Đã gửi - Only show if showStatus is true (latest message)
    if (widget.showStatus) {
      return Text(
        'Đã gửi',
        style: TextStyle(color: Colors.grey[600], fontSize: 11),
      );
    }
    
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isSending = widget.status == 'sending';
    
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
                  child: Opacity(
                    opacity: isSending ? 0.7 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: widget.isMe ? Colors.blue : (widget.themeService.isLightMode ? Colors.grey[300] : Colors.grey[900]),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
                          bottomRight: Radius.circular(widget.isMe ? 4 : 18),
                        ),
                      ),
                      child: Text(
                        widget.message, 
                        style: TextStyle(
                          color: widget.isMe ? Colors.white : widget.themeService.textPrimaryColor, 
                          fontSize: 15, 
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Status and time row - only show when needed
          if (_showTime || (widget.isMe && widget.showStatus))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isMe) const SizedBox(width: 36),
                  // Time - animated (only visible on tap)
                  if (_showTime)
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _opacityAnimation.value,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.time,
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                              if (widget.isMe && widget.showStatus) const SizedBox(width: 8),
                            ],
                          ),
                        );
                      },
                    ),
                  // Status - always visible for latest message
                  if (widget.isMe && widget.showStatus) _buildStatusIndicator(),
                ],
              ),
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
  bool _videoExists = true; // Track if video exists

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    if (widget.videoCache.containsKey(widget.videoId)) {
      final cached = widget.videoCache[widget.videoId];
      setState(() {
        _videoData = cached;
        _videoExists = cached != null;
        _isLoading = false;
      });
      return;
    }

    final video = await widget.videoService.getVideoById(widget.videoId);
    widget.videoCache[widget.videoId] = video;
    
    if (mounted) {
      setState(() {
        _videoData = video;
        _videoExists = video != null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _videoExists && !_isLoading ? widget.onTap : null,
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
                  : _videoExists && _videoData != null
                      ? _buildVideoContent()
                      : _buildVideoNotAvailable(),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _videoExists ? Icons.play_circle_outline_rounded : Icons.error_outline_rounded,
                    color: widget.isMe ? Colors.white.withOpacity(0.9) : Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _videoExists ? 'Nhấn để xem' : 'Không khả dụng',
                      style: TextStyle(
                        color: widget.isMe ? Colors.white.withOpacity(0.9) : Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_videoExists)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: widget.isMe ? Colors.white.withOpacity(0.7) : Colors.white54,
                      size: 18,
                    ),
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

  Widget _buildVideoNotAvailable() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.videocam_off_rounded,
                color: Colors.grey[500],
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Video không còn\ntồn tại',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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

// Add new widget for image messages
class _ImageMessageBubble extends StatefulWidget {
  final List<String> imageUrls;
  final String text;
  final bool isMe;
  final String time;
  final bool showAvatar;
  final String? recipientAvatar;
  final bool isRead;
  final String? status;
  final String Function(String) getFullImageUrl;
  final bool showStatus;

  const _ImageMessageBubble({
    required this.imageUrls,
    required this.text,
    required this.isMe,
    required this.time,
    this.showAvatar = false,
    this.recipientAvatar,
    this.isRead = false,
    this.status,
    required this.getFullImageUrl,
    this.showStatus = false,
  });

  @override
  State<_ImageMessageBubble> createState() => _ImageMessageBubbleState();
}

class _ImageMessageBubbleState extends State<_ImageMessageBubble> with SingleTickerProviderStateMixin {
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

  Widget _buildStatusIndicator() {
    if (!widget.isMe) return const SizedBox.shrink();
    
    final status = widget.status;
    
    if (status == 'sending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Đang gửi',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      );
    }
    
    if (status == 'failed') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 14, color: Colors.red[400]),
          const SizedBox(width: 4),
          Text(
            'Gửi thất bại',
            style: TextStyle(color: Colors.red[400], fontSize: 11),
          ),
        ],
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          widget.isRead ? Icons.done_all : Icons.done,
          size: 14,
          color: widget.isRead ? Colors.lightBlue : Colors.grey[600],
        ),
        if (widget.isRead) ...[
          const SizedBox(width: 4),
          Text(
            'Đã xem',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
        if (!widget.isRead) ...[
          const SizedBox(width: 4),
          Text(
            'Đã gửi',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ],
    );
  }

  void _openImageViewer(int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => _ImageViewerDialog(
        imageUrls: widget.imageUrls,
        initialIndex: initialIndex,
        getFullImageUrl: widget.getFullImageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSending = widget.status == 'sending';
    final imageCount = widget.imageUrls.length;
    
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
                  child: Opacity(
                    opacity: isSending ? 0.7 : 1.0,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 250),
                      decoration: BoxDecoration(
                        color: widget.isMe ? Colors.blue : Colors.grey[900],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
                          bottomRight: Radius.circular(widget.isMe ? 4 : 18),
                        ),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image grid
                          if (imageCount == 1)
                            GestureDetector(
                              onTap: () => _openImageViewer(0),
                              child: _buildSingleImage(widget.imageUrls[0]),
                            )
                          else
                            _buildImageGrid(),
                          // Text content if any
                          if (widget.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                widget.text,
                                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Status and time row - show when tapped (animated)
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
                      child: Column(
                        crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              if (!widget.isMe) const SizedBox(width: 36),
                              Text(widget.time, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                            ],
                          ),
                          // Show status for my messages when tapped
                          if (widget.isMe && widget.showStatus)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _buildStatusIndicator(),
                            ),
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

  Widget _buildSingleImage(String imageUrl) {
    final fullUrl = widget.getFullImageUrl(imageUrl);
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      width: double.infinity,
      child: Image.network(
        fullUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 150,
            color: Colors.grey[800],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 150,
            color: Colors.grey[800],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, color: Colors.grey[600], size: 40),
                const SizedBox(height: 8),
                Text('Không thể tải ảnh', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageGrid() {
    final imageCount = widget.imageUrls.length;
    
    if (imageCount == 2) {
      return Row(
        children: [
          Expanded(child: _buildGridImage(0, height: 150)),
          const SizedBox(width: 2),
          Expanded(child: _buildGridImage(1, height: 150)),
        ],
      );
    }
    
    if (imageCount == 3) {
      return Column(
        children: [
          _buildGridImage(0, height: 120),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(child: _buildGridImage(1, height: 80)),
              const SizedBox(width: 2),
              Expanded(child: _buildGridImage(2, height: 80)),
            ],
          ),
        ],
      );
    }
    
    // 4+ images
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildGridImage(0, height: 100)),
            const SizedBox(width: 2),
            Expanded(child: _buildGridImage(1, height: 100)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(child: _buildGridImage(2, height: 100)),
            const SizedBox(width: 2),
            Expanded(
              child: imageCount > 4
                  ? _buildGridImageWithOverlay(3, imageCount - 4, height: 100)
                  : _buildGridImage(3, height: 100),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridImage(int index, {required double height}) {
    final fullUrl = widget.getFullImageUrl(widget.imageUrls[index]);
    return GestureDetector(
      onTap: () => _openImageViewer(index),
      child: SizedBox(
        height: height,
        child: Image.network(
          fullUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[800],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[800],
              child: Icon(Icons.broken_image_rounded, color: Colors.grey[600]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridImageWithOverlay(int index, int moreCount, {required double height}) {
    final fullUrl = widget.getFullImageUrl(widget.imageUrls[index]);
    return GestureDetector(
      onTap: () => _openImageViewer(index),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              fullUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.grey[800]);
              },
            ),
            Container(
              color: Colors.black54,
              child: Center(
                child: Text(
                  '+$moreCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Image viewer dialog
class _ImageViewerDialog extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String Function(String) getFullImageUrl;

  const _ImageViewerDialog({
    required this.imageUrls,
    required this.initialIndex,
    required this.getFullImageUrl,
  });

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final hasMultipleImages = widget.imageUrls.length > 1;
    
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          children: [
            // Image PageView with swipe gesture
            GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! < -200) {
                  _goToNext();
                } else if (details.primaryVelocity! > 200) {
                  _goToPrevious();
                }
              },
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final fullUrl = widget.getFullImageUrl(widget.imageUrls[index]);
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.network(
                        fullUrl,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image_rounded, color: Colors.grey[600], size: 64),
                              const SizedBox(height: 16),
                              Text('Không thể tải ảnh', style: TextStyle(color: Colors.grey[600])),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Top bar with close button and counter
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  right: 8,
                  bottom: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    if (hasMultipleImages)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 48), // Balance for close button
                  ],
                ),
              ),
            ),
            
            // Left arrow button
            if (hasMultipleImages && _currentIndex > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildNavigationButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: _goToPrevious,
                  ),
                ),
              ),
            
            // Right arrow button
            if (hasMultipleImages && _currentIndex < widget.imageUrls.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildNavigationButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: _goToNext,
                  ),
                ),
              ),
            
            // Bottom page indicator dots
            if (hasMultipleImages)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.imageUrls.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: index == _currentIndex ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: index == _currentIndex ? Colors.white : Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }
}

// Stacked Images Bubble - Like Messenger for 4+ images
class _StackedImagesBubble extends StatefulWidget {
  final List<String> imageUrls;
  final bool isMe;
  final String time;
  final bool showAvatar;
  final String? recipientAvatar;
  final bool isRead;
  final String? status;
  final String Function(String) getFullImageUrl;
  final bool showStatus;

  const _StackedImagesBubble({
    required this.imageUrls,
    required this.isMe,
    required this.time,
    this.showAvatar = false,
    this.recipientAvatar,
    this.isRead = false,
    this.status,
    required this.getFullImageUrl,
    this.showStatus = false,
  });

  @override
  State<_StackedImagesBubble> createState() => _StackedImagesBubbleState();
}

class _StackedImagesBubbleState extends State<_StackedImagesBubble> with SingleTickerProviderStateMixin {
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

  Widget _buildStatusIndicator() {
    if (!widget.isMe) return const SizedBox.shrink();
    
    final status = widget.status;
    
    if (status == 'sending') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(width: 4),
          Text('Đang gửi...', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      );
    }
    
    if (status == 'failed') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 14),
          const SizedBox(width: 4),
          Text('Gửi thất bại', style: TextStyle(color: Colors.red[400], fontSize: 11)),
        ],
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isRead) ...[
          Icon(Icons.done_all, color: Colors.blue[400], size: 14),
          const SizedBox(width: 4),
          Text('Đã xem', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ] else ...[
          Icon(Icons.done, color: Colors.grey[500], size: 14),
          const SizedBox(width: 4),
          Text('Đã gửi', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ],
    );
  }

  void _openImageViewer(int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => _ImageViewerDialog(
        imageUrls: widget.imageUrls,
        initialIndex: initialIndex,
        getFullImageUrl: widget.getFullImageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSending = widget.status == 'sending';
    final imageCount = widget.imageUrls.length;
    
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
                  onTap: () {
                    _toggleTime();
                    _openImageViewer(0);
                  },
                  child: Opacity(
                    opacity: isSending ? 0.7 : 1.0,
                    child: _buildStackedImages(imageCount),
                  ),
                ),
              ),
            ],
          ),
          // Status and time row - show when tapped (animated)
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
                      child: Column(
                        crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              if (!widget.isMe) const SizedBox(width: 36),
                              Text(widget.time, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                            ],
                          ),
                          // Show status for my messages when tapped
                          if (widget.isMe && widget.showStatus)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _buildStatusIndicator(),
                            ),
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

  Widget _buildStackedImages(int imageCount) {
    // Messenger-style stacked images
    const double mainSize = 140.0;
    const double stackOffset = 8.0;
    const double rotation = 5.0;
    
    // Take first 4 images for display
    final displayImages = widget.imageUrls.take(4).toList();
    final moreCount = imageCount > 4 ? imageCount - 4 : 0;
    
    return SizedBox(
      width: mainSize + stackOffset * 3,
      height: mainSize + stackOffset * 3,
      child: Stack(
        children: [
          // Back images (stacked effect)
          for (int i = displayImages.length - 1; i > 0; i--)
            Positioned(
              left: widget.isMe ? 0 : stackOffset * i,
              right: widget.isMe ? stackOffset * i : 0,
              top: stackOffset * (displayImages.length - 1 - i),
              child: Transform.rotate(
                angle: (widget.isMe ? 1 : -1) * (i * rotation * 0.0174533), // Convert degrees to radians
                child: Container(
                  width: mainSize,
                  height: mainSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      widget.getFullImageUrl(displayImages[i]),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: Colors.grey[800]);
                      },
                    ),
                  ),
                ),
              ),
            ),
          // Front image (main)
          Positioned(
            left: widget.isMe ? 0 : stackOffset * displayImages.length - stackOffset,
            right: widget.isMe ? stackOffset * displayImages.length - stackOffset : 0,
            top: stackOffset * (displayImages.length - 1),
            child: Container(
              width: mainSize,
              height: mainSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      widget.getFullImageUrl(displayImages[0]),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: Icon(Icons.broken_image_rounded, color: Colors.grey[600], size: 40),
                        );
                      },
                    ),
                    // Badge showing image count
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$imageCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Overlay if more than 4 images
                    if (moreCount > 0)
                      Container(
                        color: Colors.black.withOpacity(0.3),
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
}
