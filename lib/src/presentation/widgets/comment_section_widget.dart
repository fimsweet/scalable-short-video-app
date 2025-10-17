import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/comment_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';

class CommentSectionWidget extends StatefulWidget {
  final ScrollController controller;
  final String videoId;
  final VoidCallback? onCommentAdded;
  final VoidCallback? onCommentDeleted;

  const CommentSectionWidget({
    super.key,
    required this.controller,
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
  final TextEditingController _textController = TextEditingController();
  
  List<dynamic> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _replyingTo;
  String? _replyingToUsername;
  String? _replyingToCommentId;
  
  // Track expanded state for comments
  final Set<String> _expandedCommentIds = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
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
          const SnackBar(content: Text('Vui lòng đăng nhập để bình luận')),
        );
      }
      return;
    }

    setState(() => _isSending = true);

    try {
      final userId = _authService.user!['id'].toString();
      final content = _textController.text.trim();
      final replyToCommentId = _replyingToCommentId; // Store before clearing

      final newComment = await _commentService.createComment(
        widget.videoId,
        userId,
        content,
        parentId: replyToCommentId,
      );

      if (newComment != null && mounted) {
        _textController.clear();
        
        // If this was a reply, add the parent comment to expanded set
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
          SnackBar(content: Text('Lỗi gửi bình luận: $e')),
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
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _replyingToUsername = null;
      _replyingToCommentId = null;
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

      if (diff.inDays > 0) return '${diff.inDays}d';
      if (diff.inHours > 0) return '${diff.inHours}h';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m';
      return 'now';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bình luận',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          // Comments list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'Chưa có bình luận nào.\nHãy là người đầu tiên!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: widget.controller,
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _CommentItem(
                            comment: comment,
                            apiService: _apiService,
                            authService: _authService,
                            commentService: _commentService,
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
          const Divider(height: 1, color: Colors.grey),
          // Reply indicator
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[850],
              child: Row(
                children: [
                  Text(
                    'Trả lời @$_replyingTo',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: _cancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // Comment input
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Thêm bình luận...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[900],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      enabled: !_isSending,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, color: Colors.blue),
                    onPressed: _isSending ? null : _sendComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

class _CommentItem extends StatefulWidget {
  final dynamic comment;
  final ApiService apiService;
  final AuthService authService;
  final CommentService commentService;
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

class _CommentItemState extends State<_CommentItem> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _showReplies = false;
  List<dynamic> _replies = [];
  bool _loadingReplies = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.comment['likeCount'] ?? 0;
    _showReplies = widget.isInitiallyExpanded;
    _checkLikeStatus();
    
    // Auto-load replies if initially expanded
    if (_showReplies) {
      _loadReplies(keepExpanded: true);
    }
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
      
      // Notify parent about expanded state change
      widget.onExpandedChanged(widget.comment['id'].toString(), keepExpanded);
    }
  }

  void _showOptions() {
    final isOwnComment = widget.authService.user != null && 
                         widget.authService.user!['id'].toString() == widget.comment['userId'].toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnComment)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Xóa bình luận', style: TextStyle(color: Colors.red)),
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
              leading: const Icon(Icons.flag, color: Colors.white),
              title: const Text('Báo cáo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
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
          color: isPinned ? Colors.yellow.withOpacity(0.1) : Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pinned indicator
              if (isPinned)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.push_pin, size: 14, color: Colors.yellow[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Được ghim bởi tác giả',
                        style: TextStyle(
                          color: Colors.yellow[700],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[700],
                      backgroundImage: userInfo['avatar'] != null && userInfo['avatar'].toString().isNotEmpty
                          ? NetworkImage(widget.apiService.getAvatarUrl(userInfo['avatar']))
                          : null,
                      child: userInfo['avatar'] == null || userInfo['avatar'].toString().isEmpty
                          ? const Icon(Icons.person, size: 18, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Username + time
                          Row(
                            children: [
                              Text(
                                userInfo['username'] ?? 'user',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.formatDate(widget.comment['createdAt']),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          
                          Text(
                            widget.comment['content'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Action buttons
                          Row(
                            children: <Widget>[
                              InkWell(
                                onTap: () => widget.onReply(
                                  widget.comment['id'].toString(),
                                  userInfo['username'] ?? 'user',
                                ),
                                child: Text(
                                  'Trả lời',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (replyCount > 0) ...[
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[600],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    if (_showReplies) {
                                      setState(() => _showReplies = false);
                                      widget.onExpandedChanged(widget.comment['id'].toString(), false);
                                    } else {
                                      _loadReplies();
                                    }
                                  },
                                  child: Text(
                                    _showReplies 
                                        ? 'Ẩn $replyCount phản hồi' 
                                        : 'Xem $replyCount phản hồi',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Like + More buttons in same row (TikTok style)
                    Row(
                      children: [
                        // Like button with count
                        GestureDetector(
                          onTap: _toggleLike,
                          child: Row(
                            children: [
                              AnimatedScale(
                                scale: _isLiked ? 1.2 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  _isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: _isLiked ? Colors.red : Colors.grey[400],
                                  size: 18,
                                ),
                              ),
                              if (_likeCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  widget.formatCount(_likeCount),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // More options button
                        IconButton(
                          icon: Icon(Icons.more_horiz, color: Colors.grey[400], size: 20),
                          onPressed: _showOptions,
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Replies section with recursive rendering
              if (_showReplies && _replies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 50),
                  child: Column(
                    children: _replies.map((reply) {
                      return _ReplyItem(
                        key: ValueKey(reply['id']),
                        reply: reply,
                        apiService: widget.apiService,
                        authService: widget.authService,
                        commentService: widget.commentService,
                        formatDate: widget.formatDate,
                        formatCount: widget.formatCount,
                        onReply: widget.onReply,
                        onDelete: () async {
                          await _loadReplies(keepExpanded: true);
                          widget.onDelete();
                        },
                        level: 1, // Add level tracking
                      );
                    }).toList(),
                  ),
                ),
              
              if (_showReplies && _loadingReplies)
                const Padding(
                  padding: EdgeInsets.only(left: 50, top: 8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Reply item with nested reply support
class _ReplyItem extends StatefulWidget {
  final dynamic reply;
  final ApiService apiService;
  final AuthService authService;
  final CommentService commentService;
  final String Function(String?) formatDate;
  final String Function(int) formatCount;
  final Function(String, String) onReply;
  final VoidCallback onDelete;
  final int level; // Track nesting level

  const _ReplyItem({
    super.key,
    required this.reply,
    required this.apiService,
    required this.authService,
    required this.commentService,
    required this.formatDate,
    required this.formatCount,
    required this.onReply,
    required this.onDelete,
    this.level = 1,
  });

  @override
  State<_ReplyItem> createState() => _ReplyItemState();
}

class _ReplyItemState extends State<_ReplyItem> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _showNestedReplies = false; // Track nested replies visibility
  List<dynamic> _nestedReplies = [];

  @override
  void initState() {
    super.initState();
    _likeCount = widget.reply['likeCount'] ?? 0;
    _checkLikeStatus();
    // Check if reply has nested replies from backend response
    if (widget.reply['replies'] != null && widget.reply['replies'] is List) {
      _nestedReplies = widget.reply['replies'];
    }
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
      backgroundColor: Colors.grey[900],
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnComment)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Xóa bình luận', style: TextStyle(color: Colors.red)),
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
              leading: const Icon(Icons.flag, color: Colors.white),
              title: const Text('Báo cáo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNestedReplies = _nestedReplies.isNotEmpty;
    
    return FutureBuilder<Map<String, dynamic>?>(
      future: widget.apiService.getUserById(widget.reply['userId'].toString()),
      builder: (context, snapshot) {
        final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vertical line connecting to parent
                  Container(
                    width: 2,
                    height: 24,
                    margin: const EdgeInsets.only(right: 10, top: 18),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.grey[700],
                    backgroundImage: userInfo['avatar'] != null && userInfo['avatar'].toString().isNotEmpty
                        ? NetworkImage(widget.apiService.getAvatarUrl(userInfo['avatar']))
                        : null,
                    child: userInfo['avatar'] == null || userInfo['avatar'].toString().isEmpty
                        ? const Icon(Icons.person, size: 14, color: Colors.white)
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
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.formatDate(widget.reply['createdAt']),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        
                        Text(
                          widget.reply['content'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        
                        // Action buttons row
                        Row(
                          children: [
                            InkWell(
                              onTap: () => widget.onReply(
                                widget.reply['id'].toString(),
                                userInfo['username'] ?? 'user',
                              ),
                              child: Text(
                                'Trả lời',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            
                            // Show nested replies toggle if they exist
                            if (hasNestedReplies) ...[
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[600],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _showNestedReplies = !_showNestedReplies;
                                  });
                                },
                                child: Text(
                                  _showNestedReplies 
                                      ? 'Ẩn ${_nestedReplies.length} phản hồi' 
                                      : 'Xem ${_nestedReplies.length} phản hồi',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(
                          children: [
                            AnimatedScale(
                              scale: _isLiked ? 1.2 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                _isLiked ? Icons.favorite : Icons.favorite_border,
                                color: _isLiked ? Colors.red : Colors.grey[400],
                                size: 16,
                              ),
                            ),
                            if (_likeCount > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                widget.formatCount(_likeCount),
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // More options button
                      IconButton(
                        icon: Icon(Icons.more_horiz, color: Colors.grey[400], size: 18),
                        onPressed: _showOptions,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Render nested replies recursively
            if (_showNestedReplies && _nestedReplies.isNotEmpty && widget.level < 5) // Limit nesting depth
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Column(
                  children: _nestedReplies.map((nestedReply) {
                    return _ReplyItem(
                      key: ValueKey(nestedReply['id']),
                      reply: nestedReply,
                      apiService: widget.apiService,
                      authService: widget.authService,
                      commentService: widget.commentService,
                      formatDate: widget.formatDate,
                      formatCount: widget.formatCount,
                      onReply: widget.onReply,
                      onDelete: widget.onDelete,
                      level: widget.level + 1, // Increment nesting level
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}