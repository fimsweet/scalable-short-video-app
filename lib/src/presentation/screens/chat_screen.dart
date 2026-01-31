import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_options_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';

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
  final LocaleService _localeService = LocaleService();
  
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
  StreamSubscription? _onlineStatusSubscription;

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
  
  // Chat customization: theme color and nickname
  Color? _chatThemeColor; // Custom theme color for chat bubbles
  String? _recipientNickname; // Custom nickname for recipient
  
  // Translation state management
  final Map<String, bool> _translatingMessages = {}; // messageId -> isTranslating
  final Map<String, String> _translatedMessages = {}; // messageId -> translated text
  
  // Pinned message at top of chat
  Map<String, dynamic>? _pinnedMessage;
  
  // Online status
  bool _recipientIsOnline = false;
  String _recipientStatusText = 'Offline';
  Timer? _onlineStatusTimer;
  Timer? _heartbeatTimer;

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
    _localeService.addListener(_onLocaleChanged);
    _selectedImagesList = [];
    _imagePreviewCacheMap = {};
    _imagePicker = ImagePicker();
    _initChat();
    _messageController.addListener(_onTextChanged);
    
    // Start online status polling and heartbeat
    _startOnlineStatusPolling();
    _startHeartbeat();
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

  // Start polling for recipient's online status
  void _startOnlineStatusPolling() {
    // Fetch immediately via REST as initial value
    _fetchOnlineStatus();
    
    // Subscribe to realtime online status updates via WebSocket
    _subscribeOnlineStatus();
  }
  
  void _subscribeOnlineStatus() {
    // Subscribe to online status stream for recipient
    _messageService.subscribeOnlineStatus(widget.recipientId);
    
    // Listen to online status updates
    _onlineStatusSubscription = _messageService.onlineStatusStream.listen((data) {
      final userId = data['userId']?.toString();
      if (userId == widget.recipientId && mounted) {
        final isOnline = data['isOnline'] == true;
        setState(() {
          _recipientIsOnline = isOnline;
          _recipientStatusText = isOnline ? 'Online' : 'Offline';
        });
      }
    });
  }

  Future<void> _fetchOnlineStatus() async {
    try {
      final status = await _apiService.getOnlineStatus(widget.recipientId);
      if (mounted) {
        setState(() {
          _recipientIsOnline = status['isOnline'] == true;
          _recipientStatusText = status['statusText'] ?? 'Offline';
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  // Send heartbeat to update my online status
  void _startHeartbeat() {
    if (_currentUserId.isEmpty) return;
    
    // Send immediately
    _apiService.sendHeartbeat(_currentUserId);
    
    // Then send every 60 seconds
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _apiService.sendHeartbeat(_currentUserId);
    });
  }

  void _initChat() async {
    if (_currentUserId.isNotEmpty) {
      _messageService.connect(_currentUserId);
      
      // Check if user is blocked
      _checkBlockedStatus();
      
      // Load conversation settings (theme color, nickname)
      _loadConversationSettings();
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
      print('Error loading messages: $e');
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

  Future<void> _loadConversationSettings() async {
    try {
      final settings = await _messageService.getConversationSettings(
        widget.recipientId,
      );
      
      if (mounted) {
        setState(() {
          // Parse theme color - could be hex or color id (pink, blue, etc.)
          final themeColorValue = settings['themeColor'] as String?;
          if (themeColorValue != null && themeColorValue.isNotEmpty) {
            _chatThemeColor = _parseThemeColor(themeColorValue);
          }
          
          // Set nickname
          _recipientNickname = settings['nickname'] as String?;
        });
      }
      
      // Load pinned messages and set the latest one
      _loadPinnedMessage();
    } catch (e) {
      print('Error loading conversation settings: $e');
    }
  }

  Future<void> _loadPinnedMessage() async {
    try {
      final pinnedMessages = await _messageService.getPinnedMessages(widget.recipientId);
      if (mounted && pinnedMessages.isNotEmpty) {
        setState(() {
          // Get the most recent pinned message
          _pinnedMessage = Map<String, dynamic>.from(pinnedMessages.first);
        });
      }
    } catch (e) {
      print('Error loading pinned message: $e');
    }
  }

  Color? _parseThemeColor(String colorValue) {
    // Map of color IDs to actual colors
    const colorMap = {
      'default': Colors.blue,
      'pink': Colors.pink,
      'purple': Colors.purple,
      'green': Colors.green,
      'orange': Colors.orange,
      'red': Colors.red,
      'teal': Colors.teal,
      'indigo': Colors.indigo,
    };
    
    // First check if it's a color ID
    if (colorMap.containsKey(colorValue)) {
      return colorMap[colorValue];
    }
    
    // Otherwise try to parse as hex
    return _parseHexColor(colorValue);
  }

  Color? _parseHexColor(String hexString) {
    try {
      // Remove # if present
      final hex = hexString.replaceFirst('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (e) {
      print('Error parsing hex color: $e');
    }
    return null;
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
        
        // Capture reply data before clearing
        final replyData = _replyToMessage != null ? {
          'id': _replyToMessage!['id'],
          'content': _replyToMessage!['content'],
          'senderId': _replyToMessage!['senderId'],
        } : null;
        
        final tempMessage = {
          'id': null,
          'tempId': tempId,
          'senderId': _currentUserId,
          'recipientId': widget.recipientId,
          'content': textToSend,
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
          'status': 'sending',
          // Include reply info in temp message for UI display
          if (replyData != null) ...{
            'replyToId': replyData['id'],
            'replyToContent': replyData['content'],
            'replyToSenderId': replyData['senderId'],
          },
        };

        // Clear reply state immediately
        if (mounted) {
          setState(() {
            _messages.insert(0, tempMessage);
            _replyToMessage = null;
          });
        }

        await _messageService.sendMessage(
          recipientId: widget.recipientId,
          content: textToSend,
          replyTo: replyData,
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
      print('Error sending message: $e');
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
    _onlineStatusTimer?.cancel();
    _heartbeatTimer?.cancel();
    _newMessageSubscription?.cancel();
    _messageSentSubscription?.cancel();
    _typingSubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    // Unsubscribe from online status updates
    _messageService.unsubscribeOnlineStatus(widget.recipientId);
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
        return _localeService.isVietnamese ? 'Hôm qua, $timeStr' : 'Yesterday, $timeStr';
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
      print('Error opening shared video: $e');
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
            print('Error loading image preview: $e');
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
      print('Error picking image: $e');
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

  void _showMessageOptions(Map<String, dynamic> message, {Offset? tapPosition, Size? bubbleSize, bool isMe = false}) {
    final messageId = message['id']?.toString();
    final content = message['content']?.toString() ?? '';
    final isDeletedForEveryone = message['isDeletedForEveryone'] == true;
    
    // Don't show options for temp messages (no id yet) or deleted messages
    if (messageId == null) return;
    if (isDeletedForEveryone) return;
    
    // Show Messenger-style overlay
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.5),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _MessageOptionsOverlay(
            message: message,
            content: content,
            currentUserId: _currentUserId,
            themeService: _themeService,
            localeService: _localeService,
            messageService: _messageService,
            chatThemeColor: _chatThemeColor,
            tapPosition: tapPosition,
            bubbleSize: bubbleSize,
            isMe: isMe,
            onReply: () {
              Navigator.pop(context);
              // Set reply state
              _setReplyTo(message);
            },
            onCopy: () {
              Navigator.pop(context);
              _copyToClipboard(content);
            },
            onTranslate: () async {
              Navigator.pop(context);
              await _translateMessage(message);
            },
            onForward: () {
              Navigator.pop(context);
              _forwardMessage(message);
            },
            onPin: () async {
              Navigator.pop(context);
              final isPinned = message['pinnedBy'] != null;
              await _togglePinMessage(messageId, isPinned);
            },
            onRemind: () {
              Navigator.pop(context);
              _showReminderDialog(message);
            },
            onReport: () {
              Navigator.pop(context);
              _reportMessage(message);
            },
            onDeleteForMe: () async {
              Navigator.pop(context);
              await _deleteMessageForMe(messageId);
            },
            onDeleteForEveryone: () async {
              Navigator.pop(context);
              await _deleteMessageForEveryone(messageId);
            },
            animation: animation,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child; // Animation handled inside overlay
        },
      ),
    );
  }

  // Reply to a message
  Map<String, dynamic>? _replyToMessage;
  
  void _setReplyTo(Map<String, dynamic> message) {
    setState(() {
      _replyToMessage = message;
    });
    _focusNode.requestFocus();
  }

  void _clearReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  // Show user options modal when avatar is tapped (like Messenger)
  void _showUserOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _themeService.isLightMode ? Colors.white : const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User info header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.recipientUsername,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _themeService.textPrimaryColor,
                ),
              ),
            ),
            Divider(height: 1, color: _themeService.dividerColor),
            // View profile option
            ListTile(
              onTap: () {
                Navigator.pop(context);
                _navigateToProfile();
              },
              title: Text(
                _localeService.isVietnamese ? 'Xem trang cá nhân' : 'View Profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _chatThemeColor ?? Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Divider(height: 1, color: _themeService.dividerColor),
            // Block option
            ListTile(
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmDialog();
              },
              title: Text(
                _localeService.isVietnamese ? 'Chặn' : 'Block',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Divider(height: 1, color: _themeService.dividerColor),
            // Cancel
            ListTile(
              onTap: () => Navigator.pop(context),
              title: Text(
                _localeService.isVietnamese ? 'Huỷ' : 'Cancel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 16,
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile() {
    final userId = int.tryParse(widget.recipientId);
    if (userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: userId),
      ),
    );
  }

  void _showBlockConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.isLightMode ? Colors.white : const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.isVietnamese ? 'Chặn người dùng?' : 'Block User?',
          style: TextStyle(color: _themeService.textPrimaryColor),
        ),
        content: Text(
          _localeService.isVietnamese 
              ? 'Bạn có chắc muốn chặn ${widget.recipientUsername}? Họ sẽ không thể gửi tin nhắn cho bạn.'
              : 'Are you sure you want to block ${widget.recipientUsername}? They won\'t be able to message you.',
          style: TextStyle(color: _themeService.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _localeService.isVietnamese ? 'Huỷ' : 'Cancel',
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser();
            },
            child: Text(
              _localeService.isVietnamese ? 'Chặn' : 'Block',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    try {
      await _apiService.blockUser(widget.recipientId, currentUserId: _currentUserId);
      if (mounted) {
        setState(() {
          _isUserBlocked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _localeService.isVietnamese 
                  ? 'Đã chặn ${widget.recipientUsername}' 
                  : 'Blocked ${widget.recipientUsername}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _localeService.isVietnamese ? 'Không thể chặn người dùng' : 'Failed to block user',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Copy text to clipboard
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_localeService.isVietnamese ? 'Đã sao chép' : 'Copied'),
        duration: const Duration(seconds: 1),
        backgroundColor: _chatThemeColor ?? Colors.blue,
      ),
    );
  }

  // Translate message - now shows inline translation below bubble
  Future<void> _translateMessage(Map<String, dynamic> message) async {
    final messageId = message['id']?.toString() ?? '';
    final content = message['content']?.toString() ?? '';
    if (content.isEmpty || content.startsWith('[') || messageId.isEmpty) return;

    // Set translating state
    setState(() {
      _translatingMessages[messageId] = true;
      _translatedMessages.remove(messageId); // Clear any previous translation
    });

    try {
      final targetLang = _localeService.isVietnamese ? 'vi' : 'en';
      final result = await _messageService.translateMessage(content, targetLang);
      
      if (!mounted) return;
      
      if (result['success'] == true && result['translatedText'] != null) {
        final translated = result['translatedText'] as String;
        setState(() {
          _translatingMessages[messageId] = false;
          _translatedMessages[messageId] = translated;
        });
      } else {
        setState(() {
          _translatingMessages[messageId] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Translation failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _translatingMessages[messageId] = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_localeService.isVietnamese ? 'Lỗi dịch tin nhắn' : 'Translation error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Forward message (placeholder)
  void _forwardMessage(Map<String, dynamic> message) {
    // TODO: Implement forward to other conversations
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_localeService.isVietnamese ? 'Tính năng đang phát triển' : 'Coming soon'),
        backgroundColor: _chatThemeColor ?? Colors.blue,
      ),
    );
  }

  // Show reminder dialog (placeholder)
  void _showReminderDialog(Map<String, dynamic> message) {
    // TODO: Implement reminder feature
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_localeService.isVietnamese ? 'Tính năng đang phát triển' : 'Coming soon'),
        backgroundColor: _chatThemeColor ?? Colors.blue,
      ),
    );
  }

  // Report message (placeholder)
  void _reportMessage(Map<String, dynamic> message) {
    // TODO: Implement report feature
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_localeService.isVietnamese ? 'Đã báo cáo tin nhắn' : 'Message reported'),
        backgroundColor: _chatThemeColor ?? Colors.blue,
      ),
    );
  }

  Future<void> _deleteMessageForMe(String messageId) async {
    try {
      final result = await _messageService.deleteForMe(messageId);
      
      if (result['success'] == true && mounted) {
        setState(() {
          // Remove the message from local list
          _messages.removeWhere((m) => m['id']?.toString() == messageId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _localeService.isVietnamese ? 'Đã gỡ tin nhắn' : 'Message deleted',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: _chatThemeColor ?? Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Error deleting message for me: $e');
    }
  }

  Future<void> _deleteMessageForEveryone(String messageId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _themeService.isLightMode ? Colors.white : const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _localeService.isVietnamese ? 'Gỡ tin nhắn?' : 'Unsend message?',
          style: TextStyle(color: _themeService.textPrimaryColor),
        ),
        content: Text(
          _localeService.isVietnamese 
              ? 'Tin nhắn này sẽ bị gỡ với tất cả mọi người trong cuộc trò chuyện.'
              : 'This message will be removed for everyone in this conversation.',
          style: TextStyle(color: _themeService.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _localeService.isVietnamese ? 'Huỷ' : 'Cancel',
              style: TextStyle(color: _themeService.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final result = await _messageService.deleteForEveryone(messageId);
      
      if (result['success'] == true && mounted) {
        setState(() {
          // Update the message in local list to show as deleted
          final index = _messages.indexWhere((m) => m['id']?.toString() == messageId);
          if (index != -1) {
            _messages[index] = {
              ..._messages[index],
              'content': '[MESSAGE_DELETED]',
              'isDeletedForEveryone': true,
              'imageUrls': [],
            };
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _localeService.isVietnamese ? 'Đã gỡ tin nhắn với mọi người' : 'Message unsent',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: _chatThemeColor ?? Colors.blue,
          ),
        );
      } else if (result['canUnsend'] == false && mounted) {
        // Time expired
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _localeService.isVietnamese 
                  ? 'Không thể gỡ tin nhắn sau 10 phút'
                  : 'Cannot unsend message after 10 minutes',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error deleting message for everyone: $e');
    }
  }

  Future<void> _togglePinMessage(String messageId, bool isPinned) async {
    try {
      bool success;
      if (isPinned) {
        success = await _messageService.unpinMessage(messageId);
      } else {
        success = await _messageService.pinMessage(messageId);
      }
      
      if (success && mounted) {
        setState(() {
          // Update the message in the list
          final index = _messages.indexWhere((m) => m['id']?.toString() == messageId);
          if (index != -1) {
            if (isPinned) {
              // Unpin - clear the pinned message if it was this one
              _messages[index] = {..._messages[index], 'pinnedBy': null, 'pinnedAt': null};
              if (_pinnedMessage?['id']?.toString() == messageId) {
                _pinnedMessage = null;
              }
            } else {
              // Pin - update message and set as pinned message at top
              _messages[index] = {..._messages[index], 'pinnedBy': _currentUserId, 'pinnedAt': DateTime.now().toIso8601String()};
              _pinnedMessage = _messages[index];
              
              // Scroll to the pinned message
              _scrollToMessageByIndex(index);
            }
          }
        });
        
        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPinned
                  ? (_localeService.isVietnamese ? 'Đã bỏ ghim tin nhắn' : 'Message unpinned')
                  : (_localeService.isVietnamese ? 'Đã ghim tin nhắn' : 'Message pinned'),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: _chatThemeColor ?? Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('Error toggling pin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.isVietnamese ? 'Có lỗi xảy ra' : 'An error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToMessageByIndex(int index) {
    // Since ListView is reversed, we need to scroll to the correct position
    // Each message is approximately 60-80 pixels high, estimate position
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        // Calculate approximate position based on index
        // For reversed list, lower index means more recent (closer to bottom)
        final estimatedItemHeight = 70.0;
        final targetPosition = index * estimatedItemHeight;
        
        _scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _scrollToMessage(String messageId) {
    print('DEBUG: _scrollToMessage called with messageId: $messageId');
    print('DEBUG: Total messages: ${_messages.length}');
    
    // Find the message index
    final index = _messages.indexWhere((m) => m['id']?.toString() == messageId);
    print('DEBUG: Found index: $index');
    
    if (index != -1 && _scrollController.hasClients) {
      // Estimate position - each message is roughly 80-100 pixels
      // Since messages are reversed, we need to calculate from the end
      final estimatedPosition = index * 80.0;
      final maxScroll = _scrollController.position.maxScrollExtent;
      print('DEBUG: Estimated position: $estimatedPosition, max scroll: $maxScroll');
      
      _scrollController.animateTo(
        estimatedPosition.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      print('DEBUG: Cannot scroll - index: $index, hasClients: ${_scrollController.hasClients}');
    }
  }

  void _showPinnedMessagesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PinnedMessagesModal(
        recipientId: widget.recipientId,
        recipientUsername: _recipientNickname ?? widget.recipientUsername,
        recipientAvatar: widget.recipientAvatar,
        themeService: _themeService,
        localeService: _localeService,
        messageService: _messageService,
        apiService: _apiService,
        currentUserId: _currentUserId,
        currentUserAvatar: _authService.user?['avatar']?.toString(),
        onMessageTap: (messageId) {
          Navigator.pop(context);
          final index = _messages.indexWhere((m) => m['id']?.toString() == messageId);
          if (index != -1) {
            _scrollToMessageByIndex(index);
          }
        },
        onPinnedMessagesChanged: () {
          _loadPinnedMessage();
        },
      ),
    );
  }

  Widget _buildPinnedMessageBar() {
    final content = _pinnedMessage?['content']?.toString() ?? '';
    final isImage = content.startsWith('[IMAGE:');
    final displayContent = isImage 
        ? (_localeService.isVietnamese ? '📷 Hình ảnh' : '📷 Photo')
        : content.length > 50 ? '${content.substring(0, 50)}...' : content;
    
    return GestureDetector(
      onTap: _showPinnedMessagesModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: (_chatThemeColor ?? Colors.blue).withOpacity(0.1),
          border: Border(
            bottom: BorderSide(
              color: _themeService.dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.push_pin,
              size: 18,
              color: _chatThemeColor ?? Colors.blue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _localeService.isVietnamese ? 'Tin nhắn đã ghim' : 'Pinned message',
                    style: TextStyle(
                      color: _chatThemeColor ?? Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayContent,
                    style: TextStyle(
                      color: _themeService.textSecondaryColor,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 22,
              color: _themeService.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showChatOptions() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ChatOptionsScreen(
          recipientId: widget.recipientId,
          recipientUsername: widget.recipientUsername,
          recipientAvatar: widget.recipientAvatar,
          onThemeColorChanged: (color) {
            if (mounted) {
              setState(() {
                _chatThemeColor = color;
              });
            }
          },
          onNicknameChanged: (nickname) {
            if (mounted) {
              setState(() {
                _recipientNickname = nickname;
              });
            }
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((result) {
      // Refresh blocked status and conversation settings when returning from options
      _checkBlockedStatus();
      _loadConversationSettings();
      
      // Handle scroll to message from search/pinned
      print('DEBUG: ChatScreen received result from ChatOptions: $result');
      if (result != null && result is Map && result['scrollToMessageId'] != null) {
        print('DEBUG: Scrolling to message: ${result['scrollToMessageId']}');
        _scrollToMessage(result['scrollToMessageId']);
      }
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
          icon: Icon(Icons.chevron_left, color: _themeService.iconColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _showChatOptions,
          behavior: HitTestBehavior.opaque,
          child: Row(
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
                      _recipientNickname ?? widget.recipientUsername,
                      style: TextStyle(
                        color: _themeService.textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_otherUserTyping)
                      Text(
                        _localeService.isVietnamese ? 'Đang nhập...' : 'Typing...',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Row(
                        children: [
                          if (_recipientIsOnline)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _recipientIsOnline 
                                ? (_localeService.isVietnamese ? 'Đang hoạt động' : 'Active now')
                                : _recipientStatusText,
                            style: TextStyle(
                              color: _recipientIsOnline ? Colors.green : _themeService.textSecondaryColor, 
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
          // Pinned message bar
          if (_pinnedMessage != null) _buildPinnedMessageBar(),
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

                            // Check if message is deleted for everyone
                            final isDeletedForEveryone = message['isDeletedForEveryone'] == true || content == '[MESSAGE_DELETED]';
                            if (isDeletedForEveryone) {
                              return _DeletedMessageBubble(
                                isMe: isMe,
                                time: _formatTime(message['createdAt']),
                                showAvatar: showAvatar,
                                recipientAvatar: widget.recipientAvatar,
                                themeService: _themeService,
                                localeService: _localeService,
                              );
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
                                chatThemeColor: _chatThemeColor,
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
                                chatThemeColor: _chatThemeColor,
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
                              chatThemeColor: _chatThemeColor,
                              messageId: message['id']?.toString(),
                              isPinned: message['pinnedBy'] != null,
                              // Reply support
                              replyToId: message['replyToId']?.toString(),
                              replyToContent: message['replyToContent']?.toString(),
                              replyToSenderId: message['replyToSenderId']?.toString(),
                              currentUserId: _currentUserId,
                              recipientName: widget.recipientUsername,
                              localeService: _localeService,
                              onAvatarTap: _showUserOptionsModal,
                              onLongPressWithPosition: (tapPosition, bubbleSize, isMe) {
                                _showMessageOptions(message, tapPosition: tapPosition, bubbleSize: bubbleSize, isMe: isMe);
                              },
                              // Translation support
                              isTranslating: _translatingMessages[message['id']?.toString()] ?? false,
                              translatedText: _translatedMessages[message['id']?.toString()],
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
          _localeService.get('cannot_contact'),
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
            _localeService.get('you_blocked_user'),
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
            child: Text(
              _localeService.get('unblock'),
              style: const TextStyle(
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
          Text(
            _localeService.isVietnamese ? 'Bắt đầu cuộc trò chuyện' : 'Start a conversation',
            style: TextStyle(color: _themeService.textSecondaryColor, fontSize: 14),
          ),
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
                        _localeService.isVietnamese ? 'Thêm' : 'Add',
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
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview bar
        if (_replyToMessage != null)
          _buildReplyPreview(),
        
        Container(
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
                      child: Icon(
                        Icons.image_outlined,
                        color: _themeService.textSecondaryColor,
                        size: 26,
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
                      child: Icon(
                        Icons.image_outlined,
                        color: _themeService.textSecondaryColor,
                        size: 26,
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
                                  ? (_localeService.isVietnamese ? 'Thêm tin nhắn...' : 'Add a message...')
                                  : _localeService.get('type_message'),
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
                      color: canSend ? (_chatThemeColor ?? Colors.blue) : _themeService.textSecondaryColor,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildReplyPreview() {
    final replyContent = _replyToMessage?['content'] ?? '';
    final replySenderId = _replyToMessage?['senderId'] ?? '';
    final isReplyingToSelf = replySenderId == _currentUserId;
    
    // Get preview text
    String previewText = replyContent;
    if (replyContent.startsWith('[IMAGE:')) {
      previewText = _localeService.isVietnamese ? '📷 Hình ảnh' : '📷 Photo';
    } else if (replyContent.startsWith('[STACKED_IMAGE:')) {
      previewText = _localeService.isVietnamese ? '📷 Nhiều hình ảnh' : '📷 Multiple photos';
    } else if (replyContent.startsWith('[VIDEO_SHARE:')) {
      previewText = _localeService.isVietnamese ? '🎬 Video' : '🎬 Video';
    }
    
    // Truncate if too long
    if (previewText.length > 50) {
      previewText = '${previewText.substring(0, 50)}...';
    }
    
    final replyToName = isReplyingToSelf 
        ? (_localeService.isVietnamese ? 'chính mình' : 'yourself')
        : widget.recipientUsername;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _themeService.isLightMode 
            ? Colors.grey[100] 
            : Colors.grey[900],
        border: Border(
          top: BorderSide(color: _themeService.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Colored bar indicator
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: _chatThemeColor ?? Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          // Reply content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _localeService.isVietnamese 
                      ? 'Đang trả lời $replyToName'
                      : 'Replying to $replyToName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _chatThemeColor ?? Colors.blue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: _themeService.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          // Close button
          GestureDetector(
            onTap: _clearReply,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _themeService.isLightMode 
                    ? Colors.grey[300] 
                    : Colors.grey[700],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: _themeService.textPrimaryColor,
              ),
            ),
          ),
        ],
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
  final Color? chatThemeColor; // Custom theme color for my bubbles
  final String? messageId; // For pin/unpin functionality
  final bool isPinned;
  final void Function(Offset tapPosition, Size bubbleSize, bool isMe)? onLongPressWithPosition;
  // Reply to support
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderId;
  final String? currentUserId;
  final String? recipientName;
  final LocaleService localeService;
  final VoidCallback? onAvatarTap; // Callback when avatar is tapped
  // Translation support
  final bool isTranslating;
  final String? translatedText;

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
    this.chatThemeColor,
    this.messageId,
    this.isPinned = false,
    this.onLongPressWithPosition,
    // Reply to support
    this.replyToId,
    this.replyToContent,
    this.replyToSenderId,
    this.currentUserId,
    this.recipientName,
    required this.localeService,
    this.onAvatarTap,
    // Translation support
    this.isTranslating = false,
    this.translatedText,
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

  Widget _buildReplyBubble() {
    final replyContent = widget.replyToContent ?? '';
    final replySenderId = widget.replyToSenderId ?? '';
    
    // Get preview text
    String previewText = replyContent;
    if (replyContent.startsWith('[IMAGE:')) {
      previewText = widget.localeService.isVietnamese ? '📷 Hình ảnh' : '📷 Photo';
    } else if (replyContent.startsWith('[STACKED_IMAGE:')) {
      previewText = widget.localeService.isVietnamese ? '📷 Nhiều hình ảnh' : '📷 Multiple photos';
    } else if (replyContent.startsWith('[VIDEO_SHARE:')) {
      previewText = widget.localeService.isVietnamese ? '🎬 Video đã chia sẻ' : '🎬 Shared video';
    }
    
    // Truncate if too long
    if (previewText.length > 50) {
      previewText = '${previewText.substring(0, 50)}...';
    }
    
    // Determine who sent the reply (current bubble sender)
    final isSenderMe = widget.isMe;
    // Determine who is being replied to
    final isReplyToMe = replySenderId == widget.currentUserId;
    
    // Build the "You replied to..." or "X replied to..." text
    String repliedToText;
    if (isSenderMe) {
      // I sent this reply
      if (isReplyToMe) {
        repliedToText = widget.localeService.isVietnamese 
            ? 'Bạn đã trả lời chính mình' 
            : 'You replied to yourself';
      } else {
        repliedToText = widget.localeService.isVietnamese 
            ? 'Bạn đã trả lời ${widget.recipientName ?? "User"}' 
            : 'You replied to ${widget.recipientName ?? "User"}';
      }
    } else {
      // They sent this reply
      if (isReplyToMe) {
        repliedToText = widget.localeService.isVietnamese 
            ? '${widget.recipientName ?? "User"} đã trả lời bạn' 
            : '${widget.recipientName ?? "User"} replied to you';
      } else {
        repliedToText = widget.localeService.isVietnamese 
            ? '${widget.recipientName ?? "User"} đã trả lời chính mình' 
            : '${widget.recipientName ?? "User"} replied to themselves';
      }
    }
    
    // Messenger-style: Reply bubble connected to main bubble
    return Container(
      margin: const EdgeInsets.only(bottom: 0), // No margin - connected to main bubble
      child: Column(
        crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // "You replied to..." label with icon
          Padding(
            padding: EdgeInsets.only(
              left: widget.isMe ? 0 : 0,
              right: widget.isMe ? 4 : 0,
              bottom: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.reply_rounded,
                  size: 12,
                  color: widget.themeService.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  repliedToText,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.themeService.textSecondaryColor,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          // Reply content bubble - connected style (rounded top, flat bottom to connect with main)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.themeService.isLightMode 
                  ? Colors.grey[200] 
                  : Colors.grey[800],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                // Bottom corners connect to main bubble
                bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
                bottomRight: Radius.circular(widget.isMe ? 4 : 16),
              ),
            ),
            child: Text(
              previewText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: widget.themeService.textPrimaryColor,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Status indicator for _MessageBubble
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
        LocaleService().get('sent'),
        style: TextStyle(color: Colors.grey[600], fontSize: 11),
      );
    }
    
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final isSending = widget.status == 'sending';
    final hasReply = widget.replyToId != null && widget.replyToContent != null;
    
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
                      ? GestureDetector(
                          onTap: widget.onAvatarTap,
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: widget.recipientAvatar != null ? NetworkImage(widget.recipientAvatar!) : null,
                            child: widget.recipientAvatar == null ? const Icon(Icons.person, color: Colors.white, size: 14) : null,
                          ),
                        )
                      : const SizedBox(width: 28),
                ),
              Flexible(
                child: Builder(
                  builder: (context) {
                    final GlobalKey bubbleKey = GlobalKey();
                    return GestureDetector(
                      onTap: _toggleTime,
                      onLongPressStart: (details) {
                        if (widget.onLongPressWithPosition != null) {
                          final RenderBox? box = bubbleKey.currentContext?.findRenderObject() as RenderBox?;
                          final size = box?.size ?? Size.zero;
                          widget.onLongPressWithPosition!(details.globalPosition, size, widget.isMe);
                        }
                      },
                      child: Opacity(
                        opacity: isSending ? 0.7 : 1.0,
                        child: Column(
                          key: bubbleKey,
                          crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Reply preview (if replying to a message) - connected to main bubble
                            if (hasReply) _buildReplyBubble(),
                            
                            // Main message bubble - connects to reply bubble above
                            Stack(
                              children: [
                                Container(
                                  margin: EdgeInsets.only(top: hasReply ? 2 : 0), // Small gap for connected look
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: widget.isMe 
                                        ? (widget.chatThemeColor ?? Colors.blue) 
                                        : (widget.themeService.isLightMode ? Colors.grey[300] : Colors.grey[900]),
                                    borderRadius: BorderRadius.only(
                                      // When has reply, top corners are small to show connection
                                      topLeft: Radius.circular(hasReply ? 4 : 18),
                                      topRight: Radius.circular(hasReply ? 4 : 18),
                                      bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
                                      bottomRight: Radius.circular(widget.isMe ? 4 : 18),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Show translated text if available, otherwise show original
                                      Text(
                                        widget.translatedText ?? widget.message, 
                                        style: TextStyle(
                                          color: widget.isMe ? Colors.white : widget.themeService.textPrimaryColor, 
                                          fontSize: 15, 
                                          height: 1.3,
                                        ),
                                      ),
                                      // Show "Đang dịch..." indicator when translating
                                      if (widget.isTranslating)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: widget.isMe ? Colors.white70 : widget.themeService.textSecondaryColor,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                widget.localeService.isVietnamese ? 'Đang dịch sang tiếng Việt...' : 'Translating to English...',
                                                style: TextStyle(
                                                  color: widget.isMe ? Colors.white70 : widget.themeService.textSecondaryColor,
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      // Show translation indicator if message has been translated
                                      if (widget.translatedText != null && !widget.isTranslating)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.translate,
                                                size: 12,
                                                color: widget.isMe ? Colors.white60 : widget.themeService.textSecondaryColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                widget.localeService.isVietnamese ? 'Đã dịch' : 'Translated',
                                                style: TextStyle(
                                                  color: widget.isMe ? Colors.white60 : widget.themeService.textSecondaryColor,
                                                  fontSize: 10,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Pin indicator
                                if (widget.isPinned)
                                  Positioned(
                                    right: widget.isMe ? 4 : null,
                                    left: widget.isMe ? null : 4,
                                    top: 4,
                                    child: Icon(
                                      Icons.push_pin,
                                      size: 12,
                                      color: widget.isMe ? Colors.white70 : widget.themeService.textSecondaryColor,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
                      _videoExists 
                          ? LocaleService().get('tap_to_view') 
                          : (LocaleService().isVietnamese ? 'Không khả dụng' : 'Not available'),
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
  final Color? chatThemeColor;

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
    this.chatThemeColor,
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
            LocaleService().isVietnamese ? 'Đã xem' : 'Seen',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
          ),
        ],
        if (!widget.isRead) ...[
          const SizedBox(width: 4),
          Text(
            LocaleService().get('sent'),
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
                        color: widget.isMe ? (widget.chatThemeColor ?? Colors.blue) : Colors.grey[900],
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
  final Color? chatThemeColor;

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
    this.chatThemeColor,
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
          Text(LocaleService().get('sent'), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
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
      padding: EdgeInsets.only(top: 12, bottom: 12, left: widget.isMe ? 60 : 0, right: widget.isMe ? 0 : 60),
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

// Pinned Messages Modal - Messenger style with horizontal list
class _PinnedMessagesModal extends StatefulWidget {
  final String recipientId;
  final String recipientUsername;
  final String? recipientAvatar;
  final ThemeService themeService;
  final LocaleService localeService;
  final MessageService messageService;
  final ApiService apiService;
  final String currentUserId;
  final String? currentUserAvatar;
  final Function(String messageId) onMessageTap;
  final VoidCallback onPinnedMessagesChanged;

  const _PinnedMessagesModal({
    required this.recipientId,
    required this.recipientUsername,
    this.recipientAvatar,
    required this.themeService,
    required this.localeService,
    required this.messageService,
    required this.apiService,
    required this.currentUserId,
    this.currentUserAvatar,
    required this.onMessageTap,
    required this.onPinnedMessagesChanged,
  });

  @override
  State<_PinnedMessagesModal> createState() => _PinnedMessagesModalState();
}

class _PinnedMessagesModalState extends State<_PinnedMessagesModal> {
  List<Map<String, dynamic>> _pinnedMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPinnedMessages();
  }

  Future<void> _loadPinnedMessages() async {
    try {
      final messages = await widget.messageService.getPinnedMessages(widget.recipientId);
      if (mounted) {
        setState(() {
          _pinnedMessages = messages.map((m) => Map<String, dynamic>.from(m)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays == 0) {
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      } else if (diff.inDays < 7) {
        return '${date.day} Thg ${date.month}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }

  String? _getAvatarUrl(String? avatar) {
    if (avatar == null || avatar.isEmpty) return null;
    final url = widget.apiService.getAvatarUrl(avatar);
    return url.isNotEmpty ? url : null;
  }

  @override
  Widget build(BuildContext context) {
    // Use simple Container - showModalBottomSheet handles animation & backdrop
    return Container(
      decoration: BoxDecoration(
        color: widget.themeService.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.themeService.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                widget.localeService.isVietnamese ? 'Tin nhắn đã ghim' : 'Pinned Messages',
                style: TextStyle(
                  color: widget.themeService.textPrimaryColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Divider(height: 1, color: widget.themeService.dividerColor),
            // Content
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )
                : _pinnedMessages.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.push_pin_outlined,
                              size: 48,
                              color: widget.themeService.textSecondaryColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.localeService.isVietnamese 
                                  ? 'Chưa có tin nhắn ghim' 
                                  : 'No pinned messages',
                              style: TextStyle(
                                color: widget.themeService.textSecondaryColor,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _pinnedMessages.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 72,
                          color: widget.themeService.dividerColor.withOpacity(0.5),
                        ),
                        itemBuilder: (context, index) {
                          return _buildPinnedMessageRow(_pinnedMessages[index]);
                        },
                      ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedMessageRow(Map<String, dynamic> message) {
    final isMyMessage = message['senderId']?.toString() == widget.currentUserId;
    final content = message['content']?.toString() ?? '';
    final isImage = content.startsWith('[IMAGE:') || content.startsWith('[STACKED_IMAGE:');
    final isSticker = content.startsWith('[STICKER:');
    final isVoice = content.startsWith('[VOICE:');
    
    // Get avatar for the message sender
    final avatarUrl = isMyMessage 
        ? _getAvatarUrl(widget.currentUserAvatar)
        : _getAvatarUrl(widget.recipientAvatar);

    // Get display content
    String displayContent = content;
    if (isImage) {
      displayContent = widget.localeService.isVietnamese ? 'Đã gửi một ảnh' : 'Sent a photo';
    } else if (isSticker) {
      displayContent = widget.localeService.isVietnamese ? 'Đã gửi một sticker' : 'Sent a sticker';
    } else if (isVoice) {
      displayContent = widget.localeService.isVietnamese ? 'Tin nhắn thoại' : 'Voice message';
    }
    
    return InkWell(
      onTap: () => widget.onMessageTap(message['id']?.toString() ?? ''),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar with pin badge
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: widget.themeService.isLightMode 
                      ? Colors.grey[200] 
                      : Colors.grey[800],
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null 
                      ? Icon(Icons.person, size: 24, color: widget.themeService.textSecondaryColor)
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.themeService.cardColor, width: 2),
                    ),
                    child: const Icon(Icons.push_pin, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Message info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMyMessage 
                        ? (widget.localeService.isVietnamese ? 'Bạn' : 'You')
                        : widget.recipientUsername,
                    style: TextStyle(
                      color: widget.themeService.textPrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Message preview
                  Row(
                    children: [
                      if (isImage) ...[
                        Icon(Icons.photo, size: 14, color: widget.themeService.textSecondaryColor),
                        const SizedBox(width: 4),
                      ] else if (isSticker) ...[
                        Icon(Icons.emoji_emotions, size: 14, color: widget.themeService.textSecondaryColor),
                        const SizedBox(width: 4),
                      ] else if (isVoice) ...[
                        Icon(Icons.mic, size: 14, color: widget.themeService.textSecondaryColor),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          displayContent,
                          style: TextStyle(
                            color: widget.themeService.textSecondaryColor,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Date and arrow - vertically aligned on right
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDate(message['createdAt']?.toString()),
                  style: TextStyle(
                    color: widget.themeService.textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  Icons.chevron_right,
                  color: widget.themeService.textSecondaryColor,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Messenger-style message options overlay
class _MessageOptionsOverlay extends StatefulWidget {
  final Map<String, dynamic> message;
  final String content;
  final String currentUserId;
  final ThemeService themeService;
  final LocaleService localeService;
  final MessageService messageService;
  final Color? chatThemeColor;
  final Offset? tapPosition;
  final Size? bubbleSize;
  final bool isMe;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onTranslate;
  final VoidCallback onForward;
  final VoidCallback onPin;
  final VoidCallback onRemind;
  final VoidCallback onReport;
  final VoidCallback onDeleteForMe;
  final VoidCallback onDeleteForEveryone;
  final Animation<double> animation;

  const _MessageOptionsOverlay({
    required this.message,
    required this.content,
    required this.currentUserId,
    required this.themeService,
    required this.localeService,
    required this.messageService,
    this.chatThemeColor,
    this.tapPosition,
    this.bubbleSize,
    this.isMe = false,
    required this.onReply,
    required this.onCopy,
    required this.onTranslate,
    required this.onForward,
    required this.onPin,
    required this.onRemind,
    required this.onReport,
    required this.onDeleteForMe,
    required this.onDeleteForEveryone,
    required this.animation,
  });

  @override
  State<_MessageOptionsOverlay> createState() => _MessageOptionsOverlayState();
}

class _MessageOptionsOverlayState extends State<_MessageOptionsOverlay> {
  bool _showMoreOptions = false;

  bool get _isMyMessage => widget.message['senderId'] == widget.currentUserId;
  bool get _isPinned => widget.message['pinnedBy'] != null;
  bool get _isTextMessage => !widget.content.startsWith('[IMAGE:') && 
                              !widget.content.startsWith('[VIDEO_SHARE:') && 
                              !widget.content.startsWith('[STACKED_IMAGE:') &&
                              !widget.content.startsWith('[STICKER:') &&
                              !widget.content.startsWith('[VOICE:');
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final themeColor = widget.chatThemeColor ?? Colors.blue;
    
    // Menu and bubble dimensions
    const double menuWidth = 220.0;
    const double menuHeight = 180.0;
    const double moreMenuHeight = 280.0;
    const double bubbleMaxWidth = 260.0;
    
    // Calculate menu position
    double menuTop = 0;
    double menuLeft = 0;
    double menuRight = 0;
    double bubbleTop = 0;
    
    final currentMenuHeight = _showMoreOptions ? moreMenuHeight : menuHeight;
    final bubbleHeight = widget.bubbleSize?.height ?? 50;
    final estimatedBubbleHeight = bubbleHeight.clamp(40.0, 80.0);
    final totalHeight = currentMenuHeight + estimatedBubbleHeight + 8;
    
    if (widget.tapPosition != null) {
      // Center the whole group (bubble + menu) vertically
      final centerY = screenSize.height / 2;
      bubbleTop = centerY - totalHeight / 2;
      menuTop = bubbleTop + estimatedBubbleHeight + 8;
      
      // Clamp to screen bounds
      if (bubbleTop < 80) {
        bubbleTop = 80;
        menuTop = bubbleTop + estimatedBubbleHeight + 8;
      }
      if (menuTop + currentMenuHeight > screenSize.height - 50) {
        menuTop = screenSize.height - currentMenuHeight - 50;
        bubbleTop = menuTop - estimatedBubbleHeight - 8;
      }
      
      // Horizontal position based on sender
      if (widget.isMe) {
        menuRight = 16;
      } else {
        menuLeft = 50;
      }
    } else {
      bubbleTop = screenSize.height * 0.3;
      menuTop = bubbleTop + estimatedBubbleHeight + 8;
      menuLeft = (screenSize.width - menuWidth) / 2;
    }
    
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: widget.animation,
        builder: (context, child) {
          // Animation for pulling up effect
          final pullUpAnimation = Tween<double>(
            begin: 30.0,
            end: 0.0,
          ).animate(CurvedAnimation(
            parent: widget.animation,
            curve: Curves.easeOutCubic,
          ));
          
          return Stack(
            children: [
              // Blurred/dimmed background
              Positioned.fill(
                child: Opacity(
                  opacity: widget.animation.value * 0.6,
                  child: Container(color: Colors.black),
                ),
              ),
              
              // Cloned bubble preview - above menu with pull-up animation
              Positioned(
                top: bubbleTop + pullUpAnimation.value,
                left: widget.isMe ? null : menuLeft,
                right: widget.isMe ? menuRight : null,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: widget.animation,
                    curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
                  ),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                      CurvedAnimation(
                        parent: widget.animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isMyMessage 
                            ? themeColor
                            : (widget.themeService.isLightMode ? Colors.grey[200] : Colors.grey[800]),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
                          bottomRight: Radius.circular(widget.isMe ? 4 : 18),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _isTextMessage 
                            ? (widget.content.length > 80 ? '${widget.content.substring(0, 80)}...' : widget.content)
                            : (widget.localeService.isVietnamese ? '📷 Đa phương tiện' : '📷 Media'),
                        style: TextStyle(
                          color: _isMyMessage ? Colors.white : widget.themeService.textPrimaryColor,
                          fontSize: 15,
                          height: 1.3,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Options menu - below bubble
              Positioned(
                top: menuTop,
                left: widget.isMe ? null : menuLeft,
                right: widget.isMe ? menuRight : null,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: widget.animation,
                    curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
                  )),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: widget.animation,
                      curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                        CurvedAnimation(
                          parent: widget.animation,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                      alignment: widget.isMe ? Alignment.topRight : Alignment.topLeft,
                      child: GestureDetector(
                        onTap: () {}, // Prevent closing
                        child: Container(
                          width: menuWidth,
                          decoration: BoxDecoration(
                            color: widget.themeService.isLightMode 
                                ? Colors.white 
                                : const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _showMoreOptions 
                                    ? _buildMoreOptions() 
                                    : _buildMainOptions(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildMainOptions() {
    return [
      // Reply
      _buildOptionItem(
        icon: Icons.reply_rounded,
        label: widget.localeService.isVietnamese ? 'Trả lời' : 'Reply',
        onTap: widget.onReply,
      ),
      // Copy (only for text)
      if (_isTextMessage)
        _buildOptionItem(
          icon: Icons.content_copy_rounded,
          label: widget.localeService.isVietnamese ? 'Sao chép' : 'Copy',
          onTap: widget.onCopy,
        ),
      // Translate (only for text)
      if (_isTextMessage)
        _buildOptionItem(
          icon: Icons.translate_rounded,
          label: widget.localeService.isVietnamese ? 'Dịch' : 'Translate',
          onTap: widget.onTranslate,
        ),
      // More
      _buildOptionItem(
        icon: Icons.more_horiz_rounded,
        label: widget.localeService.isVietnamese ? 'Khác' : 'More',
        onTap: () => setState(() => _showMoreOptions = true),
        showDivider: false,
      ),
    ];
  }

  List<Widget> _buildMoreOptions() {
    return [
      // Forward
      _buildOptionItem(
        icon: Icons.shortcut_rounded,
        label: widget.localeService.isVietnamese ? 'Chuyển tiếp' : 'Forward',
        onTap: widget.onForward,
      ),
      // Report
      _buildOptionItem(
        icon: Icons.report_outlined,
        label: widget.localeService.isVietnamese ? 'Báo cáo' : 'Report',
        onTap: widget.onReport,
      ),
      // Remind
      _buildOptionItem(
        icon: Icons.notifications_none_rounded,
        label: widget.localeService.isVietnamese ? 'Nhắc lại' : 'Remind',
        onTap: widget.onRemind,
      ),
      // Pin/Unpin
      _buildOptionItem(
        icon: _isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
        label: _isPinned 
            ? (widget.localeService.isVietnamese ? 'Bỏ ghim' : 'Unpin')
            : (widget.localeService.isVietnamese ? 'Ghim' : 'Pin'),
        onTap: widget.onPin,
      ),
      // Delete for me
      _buildOptionItem(
        icon: Icons.delete_outline_rounded,
        label: widget.localeService.isVietnamese ? 'Xóa' : 'Delete',
        onTap: widget.onDeleteForMe,
        textColor: Colors.red,
        iconColor: Colors.red,
      ),
      // Back
      _buildOptionItem(
        icon: Icons.arrow_back_rounded,
        label: widget.localeService.isVietnamese ? 'Quay lại' : 'Back',
        onTap: () => setState(() => _showMoreOptions = false),
        showDivider: false,
      ),
    ];
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showDivider = true,
    Color? textColor,
    Color? iconColor,
  }) {
    final defaultColor = widget.themeService.textPrimaryColor;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: showDivider ? BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.themeService.dividerColor.withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ) : null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor ?? defaultColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                icon,
                size: 20,
                color: iconColor ?? widget.themeService.textSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget for displaying deleted messages
class _DeletedMessageBubble extends StatelessWidget {
  final bool isMe;
  final String time;
  final bool showAvatar;
  final String? recipientAvatar;
  final ThemeService themeService;
  final LocaleService localeService;

  const _DeletedMessageBubble({
    required this.isMe,
    required this.time,
    required this.showAvatar,
    this.recipientAvatar,
    required this.themeService,
    required this.localeService,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        bottom: 2,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
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
                      backgroundColor: themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
                      backgroundImage: recipientAvatar != null ? NetworkImage(recipientAvatar!) : null,
                      child: recipientAvatar == null
                          ? Icon(Icons.person, color: themeService.iconColor, size: 14)
                          : null,
                    )
                  : const SizedBox(width: 28),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: themeService.isLightMode
                  ? Colors.grey[200]
                  : Colors.grey[800],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              border: Border.all(
                color: themeService.isLightMode
                    ? Colors.grey[300]!
                    : Colors.grey[700]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block,
                  size: 14,
                  color: themeService.textSecondaryColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    localeService.isVietnamese
                        ? 'Tin nhắn đã bị gỡ'
                        : 'Message was deleted',
                    style: TextStyle(
                      color: themeService.textSecondaryColor,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
