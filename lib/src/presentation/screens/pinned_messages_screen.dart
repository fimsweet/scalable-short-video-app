import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:intl/intl.dart';

class PinnedMessagesScreen extends StatefulWidget {
  final String recipientId;
  final String recipientUsername;
  final String? recipientAvatar;
  final Function(String messageId)? onMessageTap;

  const PinnedMessagesScreen({
    super.key,
    required this.recipientId,
    required this.recipientUsername,
    this.recipientAvatar,
    this.onMessageTap,
  });

  @override
  State<PinnedMessagesScreen> createState() => _PinnedMessagesScreenState();
}

class _PinnedMessagesScreenState extends State<PinnedMessagesScreen> {
  final MessageService _messageService = MessageService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _pinnedMessages = [];
  bool _isLoading = true;

  String get _currentUserId => _authService.user?['id']?.toString() ?? '';
  String? get _currentUserAvatar => _authService.user?['avatar']?.toString();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _loadPinnedMessages();
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPinnedMessages() async {
    setState(() => _isLoading = true);
    
    try {
      final messages = await _messageService.getPinnedMessages(widget.recipientId);
      
      if (mounted) {
        setState(() {
          _pinnedMessages = messages.map((m) => Map<String, dynamic>.from(m)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading pinned messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unpinMessage(String messageId) async {
    try {
      final success = await _messageService.unpinMessage(messageId);
      if (success) {
        setState(() {
          _pinnedMessages.removeWhere((m) => m['id'] == messageId);
        });
        _showSnackBar(
          _localeService.isVietnamese ? 'Đã bỏ ghim tin nhắn' : 'Message unpinned',
          Colors.green,
        );
      }
    } catch (e) {
      _showSnackBar(
        _localeService.isVietnamese ? 'Lỗi khi bỏ ghim' : 'Error unpinning',
        Colors.red,
      );
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      final timeStr = DateFormat('HH:mm').format(date);
      
      if (diff.inDays == 0) {
        // Today - show time only
        return timeStr;
      } else if (diff.inDays == 1) {
        // Yesterday - show yesterday + time
        return _localeService.isVietnamese ? 'Hôm qua $timeStr' : 'Yesterday $timeStr';
      } else if (diff.inDays < 7) {
        // Within a week - show day name + time
        final dayName = DateFormat('EEEE', _localeService.isVietnamese ? 'vi' : 'en').format(date);
        return '$dayName $timeStr';
      } else {
        // Older - show full date + time
        return '${DateFormat('dd/MM/yyyy').format(date)} $timeStr';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeService.backgroundColor,
      appBar: AppBar(
        backgroundColor: _themeService.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: _themeService.textPrimaryColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _localeService.isVietnamese ? 'Tin nhắn đã ghim' : 'Pinned Messages',
          style: TextStyle(
            color: _themeService.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.blue,
              ),
            )
          : _pinnedMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.push_pin_outlined,
                        size: 64,
                        color: _themeService.textSecondaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _localeService.isVietnamese 
                            ? 'Chưa có tin nhắn ghim nào' 
                            : 'No pinned messages',
                        style: TextStyle(
                          color: _themeService.textSecondaryColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _localeService.isVietnamese 
                            ? 'Nhấn giữ tin nhắn để ghim' 
                            : 'Long press a message to pin',
                        style: TextStyle(
                          color: _themeService.textSecondaryColor.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _pinnedMessages.length,
                  itemBuilder: (context, index) {
                    final message = _pinnedMessages[index];
                    final isMyMessage = message['senderId']?.toString() == _currentUserId;
                    final hasImages = message['imageUrls'] != null && 
                        (message['imageUrls'] is List ? (message['imageUrls'] as List).isNotEmpty : message['imageUrls'].toString().isNotEmpty);
                    
                    // Get avatar URL for the message sender
                    final avatarUrl = isMyMessage 
                        ? (_currentUserAvatar != null ? _apiService.getAvatarUrl(_currentUserAvatar!) : null)
                        : (widget.recipientAvatar != null ? _apiService.getAvatarUrl(widget.recipientAvatar!) : null);
                    
                    return Dismissible(
                      key: Key(message['id']?.toString() ?? index.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.push_pin_outlined, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: _themeService.cardColor,
                            title: Text(
                              _localeService.isVietnamese ? 'Bỏ ghim?' : 'Unpin?',
                              style: TextStyle(color: _themeService.textPrimaryColor),
                            ),
                            content: Text(
                              _localeService.isVietnamese 
                                  ? 'Bạn có muốn bỏ ghim tin nhắn này?'
                                  : 'Do you want to unpin this message?',
                              style: TextStyle(color: _themeService.textSecondaryColor),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  _localeService.isVietnamese ? 'Hủy' : 'Cancel',
                                  style: TextStyle(color: _themeService.textSecondaryColor),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  _localeService.isVietnamese ? 'Bỏ ghim' : 'Unpin',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        _unpinMessage(message['id']?.toString() ?? '');
                      },
                      child: InkWell(
                        onTap: () {
                          final messageId = message['id']?.toString() ?? '';
                          print('DEBUG: Pinned message tapped: $messageId');
                          // Call callback first
                          widget.onMessageTap?.call(messageId);
                          // Then pop with result
                          Navigator.pop(context, {'scrollToMessageId': messageId});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _themeService.dividerColor,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar with pin badge
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: _themeService.isLightMode 
                                        ? Colors.grey[300] 
                                        : Colors.grey[800],
                                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl == null 
                                        ? Icon(Icons.person, size: 22, color: _themeService.textSecondaryColor)
                                        : null,
                                  ),
                                  // Small pin badge
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.amber,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _themeService.cardColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.push_pin,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Message content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          isMyMessage 
                                              ? (_localeService.isVietnamese ? 'Bạn' : 'You')
                                              : widget.recipientUsername,
                                          style: TextStyle(
                                            color: _themeService.textPrimaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDate(message['pinnedAt']?.toString()),
                                          style: TextStyle(
                                            color: _themeService.textSecondaryColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (hasImages)
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.image,
                                            size: 16,
                                            color: _themeService.textSecondaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _localeService.isVietnamese ? 'Hình ảnh' : 'Image',
                                            style: TextStyle(
                                              color: _themeService.textSecondaryColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        message['content']?.toString() ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _themeService.textSecondaryColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Chevron
                              Icon(
                                Icons.chevron_right,
                                color: _themeService.textSecondaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
