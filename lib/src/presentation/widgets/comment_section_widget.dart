import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/comment_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';

class CommentSectionWidget extends StatefulWidget {
  final ScrollController controller;
  final String videoId;
  final VoidCallback? onCommentAdded;

  const CommentSectionWidget({
    super.key,
    required this.controller,
    required this.videoId,
    this.onCommentAdded,
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
        setState(() {
          _isLoading = false;
        });
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
      );

      if (newComment != null && mounted) {
        _textController.clear();
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
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
                  '${_comments.length} bình luận',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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
                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _apiService.getUserById(comment['userId'].toString()),
                            builder: (context, snapshot) {
                              final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
                              
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: userInfo['avatar'] != null && userInfo['avatar'].toString().isNotEmpty
                                      ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                                      : null,
                                  child: userInfo['avatar'] == null || userInfo['avatar'].toString().isEmpty
                                      ? const Icon(Icons.person, size: 20)
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      userInfo['username'] ?? 'user',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(comment['createdAt']),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(comment['content'] ?? ''),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          // Comment input
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Thêm bình luận...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    color: Colors.blue,
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
