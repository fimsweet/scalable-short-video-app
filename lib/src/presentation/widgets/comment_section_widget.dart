import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/comment_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/login_screen.dart';

// Theme colors - matching TikTok/Instagram style
class CommentTheme {
  static const Color primaryRed = Color(0xFFFF2D55);
  static const Color likeRed = Color(0xFFFF2D55);
  static const Color background = Color(0xFF121212);
  static const Color cardBackground = Color(0xFF1E1E1E);
  static const Color inputBackground = Color(0xFF2A2A2A);
  static const Color divider = Color(0xFF2A2A2A);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8E8E8E);
  static const Color accent = Color(0xFF0095F6);
}

class CommentSectionWidget extends StatefulWidget {
  final String videoId;
  final VoidCallback? onCommentAdded;
  final VoidCallback? onCommentDeleted;

  const CommentSectionWidget({
    super.key,
    required this.videoId,
    this.onCommentAdded,
    this.onCommentDeleted,
  });

  @override
  State<CommentSectionWidget> createState() => _CommentSectionWidgetState();
}

class _CommentSectionWidgetState extends State<CommentSectionWidget> {
  final CommentService _commentService = CommentService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _replyingTo;
  String? _replyingToUsername;
  String? _replyingToCommentId;
  
  final Set<String> _expandedCommentIds = {};

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _loadComments();
    _textController.addListener(() {
      setState(() {});
    });
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

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final comments = await _commentService.getCommentsByVideo(widget.videoId);
      
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendComment() async {
    if (_textController.text.trim().isEmpty) return;
    
    if (!_authService.isLoggedIn || _authService.user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Vui lòng đăng nhập để bình luận'),
            backgroundColor: CommentTheme.cardBackground,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    setState(() => _isSending = true);

    try {
      final userId = _authService.user!['id'].toString();
      final content = _textController.text.trim();
      final replyToCommentId = _replyingToCommentId;

      final newComment = await _commentService.createComment(
        widget.videoId,
        userId,
        content,
        parentId: replyToCommentId,
      );

      if (newComment != null && mounted) {
        _textController.clear();
        
        if (replyToCommentId != null) {
          _expandedCommentIds.add(replyToCommentId);
        }
        
        _cancelReply();
        await _loadComments();
        widget.onCommentAdded?.call();
      }
    } catch (e) {
      print('Error sending comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi bình luận: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _startReply(String commentId, String username) {
    setState(() {
      _replyingTo = username;
      _replyingToUsername = username;
      _replyingToCommentId = commentId;
      _textController.text = '@$username ';
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyingToUsername = null;
      _replyingToCommentId = null;
      _textController.clear();
    });
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 7) return '${diff.inDays ~/ 7}w';
      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'now';
    } catch (e) {
      return '';
    }
  }

  void _navigateToLogin() {
    Navigator.pop(context); // Close comment sheet first
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    ).then((result) {
      if (result == true) {
        // User logged in successfully, could show the comment sheet again
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    final sheetHeight = screenHeight * 0.65;
    final isLoggedIn = _authService.isLoggedIn;
    
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: _themeService.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity! > 500) {
                  Navigator.pop(context);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _themeService.textSecondaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_comments.length} bình luận',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _themeService.textPrimaryColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _themeService.inputBackground,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: _themeService.textPrimaryColor,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Container(height: 0.5, color: _themeService.dividerColor),
            
            // Comments list
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: _themeService.textPrimaryColor,
                        strokeWidth: 2,
                      ),
                    )
                  : _comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 56,
                                color: _themeService.textSecondaryColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _localeService.get('no_comments'),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Hãy là người đầu tiên bình luận!',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          physics: const ClampingScrollPhysics(),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            return _CommentItem(
                              comment: comment,
                              apiService: _apiService,
                              authService: _authService,
                              commentService: _commentService,
                              themeService: _themeService,
                              localeService: _localeService,
                              formatDate: _formatDate,
                              formatCount: _formatCount,
                              onReply: _startReply,
                              onDelete: () async {
                                await _loadComments();
                                widget.onCommentDeleted?.call();
                              },
                              isInitiallyExpanded: _expandedCommentIds.contains(comment['id'].toString()),
                              onExpandedChanged: (commentId, isExpanded) {
                                if (isExpanded) {
                                  _expandedCommentIds.add(commentId);
                                } else {
                                  _expandedCommentIds.remove(commentId);
                                }
                              },
                            );
                          },
                        ),
            ),
            
            // Reply indicator (only show when logged in)
            if (_replyingTo != null && isLoggedIn)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: CommentTheme.cardBackground,
                  border: Border(
                    top: BorderSide(color: CommentTheme.divider, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: CommentTheme.primaryRed,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_localeService.get('replying_to')} @$_replyingTo',
                        style: const TextStyle(
                          color: CommentTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: CommentTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Input section - Different UI for logged in vs logged out
            isLoggedIn 
                ? _buildLoggedInInput(bottomPadding)
                : _buildLoggedOutPrompt(bottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInInput(double bottomPadding) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: bottomPadding + 10,
      ),
      decoration: BoxDecoration(
        color: _themeService.backgroundColor,
        border: Border(
          top: BorderSide(color: _themeService.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _themeService.inputBackground,
            backgroundImage: _authService.avatarUrl != null
                ? NetworkImage(_apiService.getAvatarUrl(_authService.avatarUrl!))
                : null,
            child: _authService.avatarUrl == null
                ? Icon(Icons.person, size: 16, color: _themeService.textSecondaryColor)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 36,
                maxHeight: 100,
              ),
              decoration: BoxDecoration(
                color: _themeService.inputBackground,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: TextStyle(
                  color: _themeService.textPrimaryColor,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: _localeService.get('add_comment'),
                  hintStyle: TextStyle(
                    color: _themeService.textSecondaryColor,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                enabled: !_isSending,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : _sendComment,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _textController.text.trim().isNotEmpty
                    ? CommentTheme.accent
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: _textController.text.trim().isNotEmpty
                            ? Colors.white
                            : CommentTheme.accent,
                        size: 18,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedOutPrompt(double bottomPadding) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: bottomPadding + 14,
      ),
      decoration: BoxDecoration(
        color: CommentTheme.cardBackground,
        border: Border(
          top: BorderSide(color: CommentTheme.divider, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CommentTheme.inputBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.grey[500],
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _navigateToLogin,
              child: Text(
                _localeService.get('need_login_to_comment'),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatefulWidget {
  final dynamic comment;
  final ApiService apiService;
  final AuthService authService;
  final CommentService commentService;
  final ThemeService themeService;
  final LocaleService localeService;
  final String Function(String?) formatDate;
  final String Function(int) formatCount;
  final Function(String, String) onReply;
  final VoidCallback onDelete;
  final bool isInitiallyExpanded;
  final Function(String, bool) onExpandedChanged;

  const _CommentItem({
    required this.comment,
    required this.apiService,
    required this.authService,
    required this.commentService,
    required this.themeService,
    required this.localeService,
    required this.formatDate,
    required this.formatCount,
    required this.onReply,
    required this.onDelete,
    this.isInitiallyExpanded = false,
    required this.onExpandedChanged,
  });

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _showReplies = false;
  List<dynamic> _replies = [];
  bool _loadingReplies = false;
  
  AnimationController? _likeAnimController;
  Animation<double>? _likeScaleAnimation;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.comment['likeCount'] ?? 0;
    _showReplies = widget.isInitiallyExpanded;
    _checkLikeStatus();
    
    _likeAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _likeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _likeAnimController!, curve: Curves.easeInOut));
    
    if (_showReplies) {
      _loadReplies(keepExpanded: true);
    }
  }

  @override
  void dispose() {
    _likeAnimController?.dispose();
    super.dispose();
  }

  Future<void> _checkLikeStatus() async {
    if (widget.authService.isLoggedIn && widget.authService.user != null) {
      final userId = widget.authService.user!['id'].toString();
      final liked = await widget.commentService.isCommentLikedByUser(
        widget.comment['id'].toString(),
        userId,
      );
      if (mounted) {
        setState(() => _isLiked = liked);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (!widget.authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập')),
      );
      return;
    }

    _likeAnimController?.forward(from: 0);

    final userId = widget.authService.user!['id'].toString();
    final result = await widget.commentService.toggleCommentLike(
      widget.comment['id'].toString(),
      userId,
    );

    if (mounted) {
      setState(() {
        _isLiked = result['liked'] ?? false;
        _likeCount = result['likeCount'] ?? 0;
      });
    }
  }

  Future<void> _loadReplies({bool keepExpanded = true}) async {
    setState(() => _loadingReplies = true);
    final replies = await widget.commentService.getReplies(widget.comment['id'].toString());
    if (mounted) {
      setState(() {
        _replies = replies;
        _showReplies = keepExpanded;
        _loadingReplies = false;
      });
      
      widget.onExpandedChanged(widget.comment['id'].toString(), keepExpanded);
    }
  }

  void _showOptions() {
    final isOwnComment = widget.authService.user != null && 
                         widget.authService.user!['id'].toString() == widget.comment['userId'].toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: CommentTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isOwnComment)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                ),
                title: Text(widget.localeService.get('delete_comment'), style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final userId = widget.authService.user!['id'].toString();
                  final deleted = await widget.commentService.deleteComment(
                    widget.comment['id'].toString(),
                    userId,
                  );
                  if (deleted) widget.onDelete();
                },
              ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_outlined, color: Colors.orange),
              ),
              title: const Text('Báo cáo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final replyCount = widget.comment['replyCount'] ?? 0;
    final isPinned = widget.comment['isPinned'] ?? false;

    return FutureBuilder<Map<String, dynamic>?>(
      future: widget.apiService.getUserById(widget.comment['userId'].toString()),
      builder: (context, snapshot) {
        final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 44),
                  child: Row(
                    children: [
                      Icon(Icons.push_pin_rounded, size: 12, color: CommentTheme.primaryRed),
                      const SizedBox(width: 4),
                      Text(
                        'Ghim bởi tác giả',
                        style: TextStyle(
                          color: CommentTheme.primaryRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: CommentTheme.cardBackground,
                    backgroundImage: userInfo['avatar'] != null && userInfo['avatar'].toString().isNotEmpty
                        ? NetworkImage(widget.apiService.getAvatarUrl(userInfo['avatar']))
                        : null,
                    child: userInfo['avatar'] == null || userInfo['avatar'].toString().isEmpty
                        ? const Icon(Icons.person, size: 18, color: Colors.white54)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              userInfo['username'] ?? 'user',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: CommentTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.formatDate(widget.comment['createdAt']),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.comment['content'] ?? '',
                          style: TextStyle(
                            color: widget.themeService.textPrimaryColor,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            GestureDetector(
                              onTap: () => widget.onReply(
                                widget.comment['id'].toString(),
                                userInfo['username'] ?? 'user',
                              ),
                              child: Text(
                                widget.localeService.get('reply'),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (replyCount > 0) ...[
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12),
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.grey[600],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  if (_showReplies) {
                                    setState(() => _showReplies = false);
                                    widget.onExpandedChanged(widget.comment['id'].toString(), false);
                                  } else {
                                    _loadReplies();
                                  }
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      _showReplies ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                      size: 16,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      _showReplies 
                                          ? 'Ẩn phản hồi' 
                                          : 'Xem $replyCount phản hồi',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: _toggleLike,
                        child: _likeScaleAnimation != null
                            ? AnimatedBuilder(
                                animation: _likeScaleAnimation!,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _likeScaleAnimation!.value,
                                    child: Column(
                                      children: [
                                        Icon(
                                          _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                          color: _isLiked ? CommentTheme.likeRed : Colors.grey[600],
                                          size: 20,
                                        ),
                                        if (_likeCount > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              widget.formatCount(_likeCount),
                                              style: TextStyle(
                                                color: _isLiked ? CommentTheme.likeRed : Colors.grey[600],
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              )
                            : Column(
                                children: [
                                  Icon(
                                    _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: _isLiked ? CommentTheme.likeRed : Colors.grey[600],
                                    size: 20,
                                  ),
                                  if (_likeCount > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        widget.formatCount(_likeCount),
                                        style: TextStyle(
                                          color: _isLiked ? CommentTheme.likeRed : Colors.grey[600],
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _showOptions,
                        child: Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              if (_showReplies && _replies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 48, top: 4),
                  child: Column(
                    children: _replies.map((reply) {
                      return _ReplyItem(
                        key: ValueKey(reply['id']),
                        reply: reply,
                        apiService: widget.apiService,
                        authService: widget.authService,
                        commentService: widget.commentService,
                        themeService: widget.themeService,
                        localeService: widget.localeService,
                        formatDate: widget.formatDate,
                        formatCount: widget.formatCount,
                        onReply: widget.onReply,
                        onDelete: () async {
                          await _loadReplies(keepExpanded: true);
                          widget.onDelete();
                        },
                      );
                    }).toList(),
                  ),
                ),
              
              if (_showReplies && _loadingReplies)
                Padding(
                  padding: const EdgeInsets.only(left: 48, top: 8),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CommentTheme.primaryRed,
                    ),
                  ),
                ),
            ],
          ),
        );
      }, // Đã thêm dấu ) bị thiếu ở đây
    );
  }
}

class _ReplyItem extends StatefulWidget {
  final dynamic reply;
  final ApiService apiService;
  final AuthService authService;
  final CommentService commentService;
  final ThemeService themeService;
  final LocaleService localeService;
  final String Function(String?) formatDate;
  final String Function(int) formatCount;
  final Function(String, String) onReply;
  final VoidCallback onDelete;

  const _ReplyItem({
    super.key,
    required this.reply,
    required this.apiService,
    required this.authService,
    required this.commentService,
    required this.themeService,
    required this.localeService,
    required this.formatDate,
    required this.formatCount,
    required this.onReply,
    required this.onDelete,
  });

  @override
  State<_ReplyItem> createState() => _ReplyItemState();
}

class _ReplyItemState extends State<_ReplyItem> with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  int _likeCount = 0;
  
  AnimationController? _likeAnimController;
  Animation<double>? _likeScaleAnimation;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.reply['likeCount'] ?? 0;
    _checkLikeStatus();
    
    _likeAnimController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _likeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _likeAnimController!, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _likeAnimController?.dispose();
    super.dispose();
  }

  Future<void> _checkLikeStatus() async {
    if (widget.authService.isLoggedIn && widget.authService.user != null) {
      final userId = widget.authService.user!['id'].toString();
      final liked = await widget.commentService.isCommentLikedByUser(
        widget.reply['id'].toString(),
        userId,
      );
      if (mounted) {
        setState(() => _isLiked = liked);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (!widget.authService.isLoggedIn) return;

    _likeAnimController?.forward(from: 0);

    final userId = widget.authService.user!['id'].toString();
    final result = await widget.commentService.toggleCommentLike(
      widget.reply['id'].toString(),
      userId,
    );

    if (mounted) {
      setState(() {
        _isLiked = result['liked'] ?? false;
        _likeCount = result['likeCount'] ?? 0;
      });
    }
  }

  void _showOptions() {
    final isOwnComment = widget.authService.user != null && 
                         widget.authService.user!['id'].toString() == widget.reply['userId'].toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: CommentTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isOwnComment)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                ),
                title: Text(widget.localeService.get('delete_comment'), style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final userId = widget.authService.user!['id'].toString();
                  final deleted = await widget.commentService.deleteComment(
                    widget.reply['id'].toString(),
                    userId,
                  );
                  if (deleted) widget.onDelete();
                },
              ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_outlined, color: Colors.orange),
              ),
              title: const Text('Báo cáo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: widget.apiService.getUserById(widget.reply['userId'].toString()),
      builder: (context, snapshot) {
        final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
        
        return Container(
          margin: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: CommentTheme.cardBackground,
                backgroundImage: userInfo['avatar'] != null && userInfo['avatar'].toString().isNotEmpty
                    ? NetworkImage(widget.apiService.getAvatarUrl(userInfo['avatar']))
                    : null,
                child: userInfo['avatar'] == null || userInfo['avatar'].toString().isEmpty
                    ? const Icon(Icons.person, size: 14, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 10),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          userInfo['username'] ?? 'user',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: CommentTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.formatDate(widget.reply['createdAt']),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    _buildReplyContent(widget.reply['content'] ?? ''),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => widget.onReply(
                        widget.reply['id'].toString(),
                        userInfo['username'] ?? 'user',
                      ),
                      child: Text(
                        widget.localeService.get('reply'),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: _toggleLike,
                    child: _likeScaleAnimation != null
                        ? AnimatedBuilder(
                            animation: _likeScaleAnimation!,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _likeScaleAnimation!.value,
                                child: Column(
                                  children: [
                                    Icon(
                                      _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: _isLiked ? CommentTheme.likeRed : Colors.grey[600],
                                      size: 20,
                                    ),
                                    if (_likeCount > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          widget.formatCount(_likeCount),
                                          style: TextStyle(
                                            color: _isLiked ? CommentTheme.likeRed : Colors.grey[600],
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          )
                        : Column(
                            children: [
                              Icon(
                                _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: _isLiked ? CommentTheme.likeRed : Colors.grey[600],
                                size: 20,
                              ),
                              if (_likeCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    widget.formatCount(_likeCount),
                                    style: TextStyle(
                                      color: _isLiked ? CommentTheme.likeRed : Colors.grey[600],
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _showOptions,
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }, // Đã thêm dấu ) bị thiếu ở đây
    );
  }

  Widget _buildReplyContent(String content) {
    final mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(content);
    
    if (matches.isEmpty) {
      return Text(
        content,
        style: TextStyle(
          color: widget.themeService.textPrimaryColor,
          fontSize: 13,
          height: 1.3,
        ),
      );
    }

    List<TextSpan> spans = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: TextStyle(color: widget.themeService.textPrimaryColor),
        ));
      }
      
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: CommentTheme.accent,
          fontWeight: FontWeight.w600,
        ),
      ));
      
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: TextStyle(color: widget.themeService.textPrimaryColor),
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(fontSize: 13, height: 1.3),
      ),
    );
  }
}