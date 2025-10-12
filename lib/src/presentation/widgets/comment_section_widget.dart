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
      print('❌ Error loading comments: $e');
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

      final newComment = await _commentService.createComment(
        widget.videoId,
        userId,
        content,
        parentId: _replyingToCommentId,
      );

      if (newComment != null && mounted) {
        _textController.clear();
        _cancelReply();
        await _loadComments();
        widget.onCommentAdded?.call();
      }
    } catch (e) {
      print('❌ Error sending comment: $e');
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

  const _CommentItem({
    required this.comment,
    required this.apiService,
    required this.authService,
    required this.commentService,
    required this.formatDate,
    required this.formatCount,
    required this.onReply,
    required this.onDelete,
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
    _checkLikeStatus();
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

  Future<void> _loadReplies() async {
    setState(() => _loadingReplies = true);
    final replies = await widget.commentService.getReplies(widget.comment['id'].toString());
    if (mounted) {
      setState(() {
        _replies = replies;
        _showReplies = true;
        _loadingReplies = false;
      });
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

    return FutureBuilder<Map<String, dynamic>?>(
      future: widget.apiService.getUserById(widget.comment['userId'].toString()),
      builder: (context, snapshot) {
        final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[700],
                    backgroundImage: userInfo['avatar'] != null && userInfo['avatar'].toString().isNotEmpty
                        ? NetworkImage(widget.apiService.getAvatarUrl(userInfo['avatar']))
                        : null,
                    child: userInfo['avatar'] == null || userInfo['avatar'].toString().isEmpty
                        ? const Icon(Icons.person, size: 16, color: Colors.white)
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
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.formatDate(widget.comment['createdAt']),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.comment['content'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            InkWell(
                              onTap: () => widget.onReply(
                                widget.comment['id'].toString(),
                                userInfo['username'] ?? 'user',
                              ),
                              child: Text(
                                'Trả lời',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (replyCount > 0) ...[
                              const SizedBox(width: 16),
                              InkWell(
                                onTap: _showReplies ? null : _loadReplies,
                                child: Text(
                                  _showReplies ? 'Ẩn $replyCount phản hồi' : 'Xem $replyCount phản hồi',
                                  style: TextStyle(
                                    color: Colors.grey[500],
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
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Colors.red : Colors.grey[600],
                          size: 18,
                        ),
                        onPressed: _toggleLike,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      if (_likeCount > 0)
                        Text(
                          widget.formatCount(_likeCount),
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 18),
                    onPressed: _showOptions,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(left: 8),
                  ),
                ],
              ),
            ),
            if (_showReplies && _replies.isNotEmpty)
              ...(_replies.map((reply) => Padding(
                    padding: const EdgeInsets.only(left: 60),
                    child: _ReplyItem(
                      reply: reply,
                      apiService: widget.apiService,
                      authService: widget.authService,
                      commentService: widget.commentService,
                      formatDate: widget.formatDate,
                      formatCount: widget.formatCount,
                      onDelete: widget.onDelete,
                    ),
                  ))),
          ],
        );
      },
    );
  }
}

class _ReplyItem extends StatefulWidget {
  final dynamic reply;
  final ApiService apiService;
  final AuthService authService;
  final CommentService commentService;
  final String Function(String?) formatDate;
  final String Function(int) formatCount;
  final VoidCallback onDelete;

  const _ReplyItem({
    required this.reply,
    required this.apiService,
    required this.authService,
    required this.commentService,
    required this.formatDate,
    required this.formatCount,
    required this.onDelete,
  });

  @override
  State<_ReplyItem> createState() => _ReplyItemState();
}

class _ReplyItemState extends State<_ReplyItem> {
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.reply['likeCount'] ?? 0;
    _checkLikeStatus();
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: widget.apiService.getUserById(widget.reply['userId'].toString()),
      builder: (context, snapshot) {
        final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.formatDate(widget.reply['createdAt']),
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.reply['content'] ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.grey[600],
                      size: 16,
                    ),
                    onPressed: _toggleLike,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  if (_likeCount > 0)
                    Text(
                      widget.formatCount(_likeCount),
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
