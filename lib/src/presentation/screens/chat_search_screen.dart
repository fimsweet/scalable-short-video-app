import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class ChatSearchScreen extends StatefulWidget {
  final String recipientId;
  final String recipientUsername;
  final String? recipientAvatar;
  final Function(String messageId)? onMessageTap;

  const ChatSearchScreen({
    super.key,
    required this.recipientId,
    required this.recipientUsername,
    this.recipientAvatar,
    this.onMessageTap,
  });

  @override
  State<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends State<ChatSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final MessageService _messageService = MessageService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounceTimer;

  String get _currentUserId => _authService.user?['id']?.toString() ?? '';
  String? get _currentUserAvatar => _authService.user?['avatar']?.toString();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _searchController.addListener(_onSearchChanged);
    
    // Auto focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }
    
    // Debounce search for 500ms
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    
    setState(() => _isSearching = true);
    
    try {
      final results = await _messageService.searchMessages(widget.recipientId, query);
      
      if (mounted) {
        setState(() {
          _searchResults = results.map((m) => Map<String, dynamic>.from(m)).toList();
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      print('Error searching messages: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
          _hasSearched = true;
        });
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      final timeStr = DateFormat('HH:mm').format(date);
      
      if (diff.inDays == 0) {
        // Today - show just time
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

  String _highlightQuery(String text, String query) {
    return text;
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
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: _themeService.inputBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            style: TextStyle(
              color: _themeService.textPrimaryColor,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: _localeService.isVietnamese 
                  ? 'Tìm kiếm tin nhắn...' 
                  : 'Search messages...',
              hintStyle: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: _themeService.textSecondaryColor,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        color: _themeService.textSecondaryColor,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _focusNode.requestFocus();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => _performSearch(value.trim()),
          ),
        ),
        titleSpacing: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(
          color: Colors.blue,
        ),
      );
    }
    
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: _themeService.textSecondaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.isVietnamese 
                  ? 'Tìm kiếm trong cuộc trò chuyện' 
                  : 'Search in conversation',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
    
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: _themeService.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.isVietnamese 
                  ? 'Không tìm thấy kết quả' 
                  : 'No results found',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _localeService.isVietnamese 
                  ? 'Thử từ khóa khác' 
                  : 'Try a different keyword',
              style: TextStyle(
                color: _themeService.textSecondaryColor.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    final query = _searchController.text.trim().toLowerCase();
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final message = _searchResults[index];
        final isMyMessage = message['senderId']?.toString() == _currentUserId;
        final content = message['content']?.toString() ?? '';
        
        // Get avatar URL for the message sender
        final avatarUrl = isMyMessage 
            ? (_currentUserAvatar != null ? _apiService.getAvatarUrl(_currentUserAvatar!) : null)
            : (widget.recipientAvatar != null ? _apiService.getAvatarUrl(widget.recipientAvatar!) : null);
        
        return InkWell(
          onTap: () {
            final messageId = message['id']?.toString() ?? '';
            print('DEBUG: Search result tapped: $messageId');
            // Call callback
            widget.onMessageTap?.call(messageId);
            // Pop with result
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
                // Avatar instead of icon
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
                            _formatDate(message['createdAt']?.toString()),
                            style: TextStyle(
                              color: _themeService.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildHighlightedText(content, query),
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
        );
      },
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _themeService.textSecondaryColor,
          fontSize: 14,
        ),
      );
    }
    
    final lowerText = text.toLowerCase();
    final queryIndex = lowerText.indexOf(query);
    
    if (queryIndex == -1) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _themeService.textSecondaryColor,
          fontSize: 14,
        ),
      );
    }
    
    final before = text.substring(0, queryIndex);
    final match = text.substring(queryIndex, queryIndex + query.length);
    final after = text.substring(queryIndex + query.length);
    
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          color: _themeService.textSecondaryColor,
          fontSize: 14,
        ),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.blue.withOpacity(0.1),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }
}
