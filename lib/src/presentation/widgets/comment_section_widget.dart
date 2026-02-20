import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:scalable_short_video_app/src/services/comment_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/login_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/app_snackbar.dart';

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
  final bool allowComments;
  final bool autoFocus;
  final String? videoOwnerId; // For user-level comment permission check

  const CommentSectionWidget({
    super.key,
    required this.videoId,
    this.onCommentAdded,
    this.onCommentDeleted,
    this.allowComments = true,
    this.autoFocus = false,
    this.videoOwnerId,
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
  final ImagePicker _imagePicker = ImagePicker();
  
  List<dynamic> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _replyingTo;
  String? _replyingToUsername; // ignore: unused_field
  String? _replyingToCommentId;
  File? _selectedImage;
  bool _filterComments = true; // User's comment filter preference
  bool _isCommentRestricted = false; // User-level whoCanComment restriction
  String? _commentRestrictedReason;
  
  final Set<String> _expandedCommentIds = {};
  
  // Pagination state
  bool _hasMore = true;
  bool _isLoadingMore = false;
  int _currentOffset = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    _scrollController.addListener(_onScroll);
    _loadFilterSetting();
    _checkCommentPermission();
    _loadComments();
    _textController.addListener(() {
      setState(() {});
    });
    
    // Auto focus input if requested
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
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

  Future<void> _loadFilterSetting() async {
    try {
      final token = await AuthService().getToken();
      if (token == null) return;
      final result = await _apiService.getUserSettings(token);
      if (result['success'] == true && result['settings'] != null) {
        if (mounted) {
          setState(() {
            _filterComments = result['settings']['filterComments'] != false;
          });
        }
      }
    } catch (e) {
      // Default to true (filter on)
    }
  }

  Future<void> _checkCommentPermission() async {
    if (widget.videoOwnerId == null) return;
    try {
      final userId = _authService.userId?.toString();
      if (userId == null) return;

      // If user is the video owner, check their own privacy settings
      if (userId == widget.videoOwnerId) {
        final settings = await _apiService.getPrivacySettings(userId);
        final whoCanComment = settings['whoCanComment'] ?? 'everyone';
        if (whoCanComment == 'noOne' || whoCanComment == 'onlyMe') {
          if (mounted) {
            setState(() {
              _isCommentRestricted = true;
              _commentRestrictedReason = _localeService.get('comments_disabled');
            });
          }
        }
        return;
      }

      // For other users, check via privacy permission API
      final result = await _apiService.checkPrivacyPermission(
        userId,
        widget.videoOwnerId!,
        'comment',
      );
      if (mounted && result['allowed'] != true) {
        setState(() {
          _isCommentRestricted = true;
          _commentRestrictedReason = result['reason'] as String?;
        });
      }
    } catch (e) {
      // If check fails, default to restricted for safety
      if (mounted) {
        setState(() {
          _isCommentRestricted = true;
          _commentRestrictedReason = 'Không thể kiểm tra quyền bình luận';
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreComments();
    }
  }

  Future<void> _loadComments() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _currentOffset = 0;
      _hasMore = true;
    });
    
    try {
      final result = await _commentService.getCommentsByVideoWithPagination(
        widget.videoId,
        limit: _pageSize,
        offset: 0,
      );
      
      if (mounted) {
        setState(() {
          _comments = result['comments'] ?? [];
          _hasMore = result['hasMore'] == true;
          _currentOffset = _comments.length;
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

  Future<void> _loadMoreComments() async {
    if (!mounted || _isLoadingMore || !_hasMore) return;
    
    setState(() => _isLoadingMore = true);
    
    try {
      final result = await _commentService.getCommentsByVideoWithPagination(
        widget.videoId,
        limit: _pageSize,
        offset: _currentOffset,
      );
      
      if (mounted) {
        final newComments = result['comments'] ?? [];
        setState(() {
          _comments.addAll(newComments);
          _hasMore = result['hasMore'] == true;
          _currentOffset += (newComments.length as int);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more comments: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _sendComment() async {
    // Allow sending if there's text OR image
    if (_textController.text.trim().isEmpty && _selectedImage == null) return;
    
    if (!_authService.isLoggedIn || _authService.user == null) {
      if (mounted) {
        AppSnackBar.showInfo(context, _localeService.get('please_login_to_comment'));
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
        content, // Empty string is OK if image is attached
        parentId: replyToCommentId,
        imageFile: _selectedImage,
      );

      if (newComment != null && mounted) {
        _textController.clear();
        _selectedImage = null;
        
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
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        AppSnackBar.showError(context, errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
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
                    (_isCommentRestricted || !widget.allowComments)
                        ? _localeService.get('x_comments')
                        : '${_comments.length} ${_localeService.get('x_comments')}',
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
            
            // When comments are disabled (user-level or per-video), show centered message
            if (_isCommentRestricted || !widget.allowComments)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.comments_disabled_outlined,
                        size: 56,
                        color: _themeService.textSecondaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _localeService.get('comments_disabled'),
                        style: TextStyle(
                          color: _themeService.textSecondaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
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
                                _localeService.get('be_first_comment'),
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
                          itemCount: _comments.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at the end
                            if (index == _comments.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(CommentTheme.primaryRed),
                                    ),
                                  ),
                                ),
                              );
                            }
                            
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
                              filterComments: _filterComments,
                              onReply: _startReply,
                              onDelete: () async {
                                await _loadComments();
                                widget.onCommentDeleted?.call();
                              },
                              onEdited: () async {
                                await _loadComments();
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
            // Don't show input if comments are disabled or restricted by user privacy
            if (_isCommentRestricted)
              _buildCommentRestrictedBanner(bottomPadding)
            else if (widget.allowComments)
              isLoggedIn 
                  ? _buildLoggedInInput(bottomPadding)
                  : _buildLoggedOutPrompt(bottomPadding)
            else
              _buildCommentsDisabledBanner(bottomPadding),
            ], // end else ...[
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInInput(double bottomPadding) {
    final hasContent = _textController.text.trim().isNotEmpty || _selectedImage != null;
    
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image preview - TikTok style with constrained size
          if (_selectedImage != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                constraints: const BoxConstraints(
                  maxWidth: 150,
                  maxHeight: 150,
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _removeSelectedImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _themeService.inputBackground,
                backgroundImage: _authService.avatarUrl != null && _authService.avatarUrl!.isNotEmpty && _apiService.getAvatarUrl(_authService.avatarUrl!).isNotEmpty
                    ? NetworkImage(_apiService.getAvatarUrl(_authService.avatarUrl!))
                    : null,
                child: _authService.avatarUrl == null || _authService.avatarUrl!.isEmpty || _apiService.getAvatarUrl(_authService.avatarUrl!).isEmpty
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
                  child: Row(
                    children: [
                      Expanded(
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
                      // Image picker button
                      GestureDetector(
                        onTap: _isSending ? null : _pickImage,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.image_outlined,
                            color: _themeService.textSecondaryColor,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
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
                    color: hasContent
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
                            color: hasContent
                                ? Colors.white
                                : CommentTheme.accent,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
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

  Widget _buildCommentRestrictedBanner(double bottomPadding) {
    final reason = _commentRestrictedReason;
    final displayText = (reason != null && reason.isNotEmpty)
        ? reason
        : (_localeService.isVietnamese
            ? 'Bạn không thể bình luận video này'
            : 'You cannot comment on this video');
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: bottomPadding + 14,
      ),
      decoration: BoxDecoration(
        color: _themeService.backgroundColor,
        border: Border(
          top: BorderSide(color: _themeService.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            color: _themeService.textSecondaryColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              displayText,
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsDisabledBanner(double bottomPadding) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: bottomPadding + 14,
      ),
      decoration: BoxDecoration(
        color: _themeService.backgroundColor,
        border: Border(
          top: BorderSide(color: _themeService.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.comments_disabled_outlined,
            color: _themeService.textSecondaryColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _localeService.isVietnamese 
                  ? 'Nhà sáng tạo đã tắt bình luận cho video này'
                  : 'Creator has disabled comments for this video',
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 14,
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
  final VoidCallback onEdited;
  final bool isInitiallyExpanded;
  final Function(String, bool) onExpandedChanged;
  final bool filterComments;

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
    required this.onEdited,
    this.isInitiallyExpanded = false,
    required this.onExpandedChanged,
    this.filterComments = true,
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
  bool _isCensored = true; // Whether this toxic comment is currently hidden
  
  // Translation state
  bool _isTranslated = false;
  String? _translatedText;
  bool _isTranslating = false;
  
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

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Center(
                child: InteractiveViewer(
                  child: Image.network(
                    widget.apiService.getCommentImageUrl(imageUrl),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      AppSnackBar.showInfo(context, widget.localeService.get('please_login'));
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
        _isLiked = result['liked'] == true;
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

  void _navigateToUserProfile(BuildContext context, dynamic userId) {
    if (userId == null) return;
    
    final userIdInt = int.tryParse(userId.toString());
    if (userIdInt == null) return;
    
    // Close the comment bottom sheet first
    Navigator.pop(context);
    
    // Navigate to user profile
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userIdInt),
      ),
    );
  }

  void _showOptions() {
    final isOwnComment = widget.authService.user != null && 
                         widget.authService.user!['id'].toString() == widget.comment['userId'].toString();
    final isLightMode = widget.themeService.isLightMode;

    // Check if within 5 minutes edit window
    bool canEdit = false;
    if (isOwnComment) {
      try {
        final createdAt = DateTime.parse(widget.comment['createdAt']);
        canEdit = DateTime.now().difference(createdAt).inMinutes < 5;
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: isLightMode ? Colors.white : const Color(0xFF262626),
          borderRadius: BorderRadius.circular(14),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isLightMode ? Colors.grey[350] : Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Copy
              _buildOptionTile(
                ctx: ctx,
                icon: Icons.content_copy_rounded,
                label: widget.localeService.get('copy_comment'),
                iconColor: isLightMode ? Colors.grey[700]! : Colors.grey[300]!,
                textColor: isLightMode ? Colors.black87 : Colors.white,
                onTap: () {
                  Navigator.pop(ctx);
                  _copyComment();
                },
              ),
              _optionDivider(isLightMode),
              // Translate / See original
              _buildOptionTile(
                ctx: ctx,
                icon: _isTranslated ? Icons.g_translate_rounded : Icons.translate_rounded,
                label: _isTranslated
                    ? widget.localeService.get('show_original')
                    : widget.localeService.get('see_translation'),
                iconColor: const Color(0xFF4285F4),
                textColor: isLightMode ? Colors.black87 : Colors.white,
                onTap: () {
                  Navigator.pop(ctx);
                  if (_isTranslated) {
                    setState(() {
                      _isTranslated = false;
                      _translatedText = null;
                    });
                  } else {
                    _translateComment();
                  }
                },
              ),
              if (isOwnComment && canEdit) ...[
                _optionDivider(isLightMode),
                _buildOptionTile(
                  ctx: ctx,
                  icon: Icons.edit_rounded,
                  label: widget.localeService.get('edit_comment'),
                  iconColor: isLightMode ? Colors.grey[700]! : Colors.grey[300]!,
                  textColor: isLightMode ? Colors.black87 : Colors.white,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog();
                  },
                ),
              ],
              if (isOwnComment) ...[
                _optionDivider(isLightMode),
                _buildOptionTile(
                  ctx: ctx,
                  icon: Icons.delete_outline_rounded,
                  label: widget.localeService.get('delete_comment'),
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete();
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionDivider(bool isLightMode) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 20,
      endIndent: 20,
      color: isLightMode ? Colors.grey[200] : Colors.grey[800],
    );
  }

  void _copyComment() {
    // Copy the currently displayed text (translated if showing translation, else original)
    final isToxic = widget.comment['isToxic'] == true;
    final originalText = isToxic && widget.filterComments && _isCensored
        ? (widget.comment['censoredContent'] ?? widget.comment['content'] ?? '')
        : (widget.comment['content'] ?? '');
    final textToCopy = _isTranslated && _translatedText != null
        ? _translatedText!
        : originalText.toString();
    
    Clipboard.setData(ClipboardData(text: textToCopy));
    AppSnackBar.showSuccess(context, widget.localeService.get('comment_copied'));
  }

  void _confirmDelete() {
    final isLightMode = widget.themeService.isLightMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isLightMode ? Colors.white : const Color(0xFF262626),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.localeService.get('confirm_delete'),
          style: TextStyle(
            color: isLightMode ? Colors.black87 : Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          widget.localeService.get('delete_comment_confirm'),
          style: TextStyle(
            color: isLightMode ? Colors.black54 : Colors.grey[400],
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              widget.localeService.get('cancel'),
              style: TextStyle(
                color: isLightMode ? Colors.grey[600] : Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = widget.authService.user!['id'].toString();
              final deleted = await widget.commentService.deleteComment(
                widget.comment['id'].toString(),
                userId,
              );
              if (deleted) widget.onDelete();
            },
            child: Text(
              widget.localeService.get('delete_comment'),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _translateComment() async {
    final isToxic = widget.comment['isToxic'] == true;
    final textToTranslate = isToxic 
        ? (widget.comment['censoredContent'] ?? widget.comment['content'] ?? '')
        : (widget.comment['content'] ?? '');
    
    if (textToTranslate.toString().trim().isEmpty) return;
    
    // Translate TO user's current language (same as chat does)
    final targetLang = widget.localeService.isVietnamese ? 'vi' : 'en';
    
    setState(() => _isTranslating = true);
    
    try {
      final result = await MessageService().translateMessage(textToTranslate.toString(), targetLang);
      
      if (!mounted) return;
      
      if (result['success'] == true && result['translatedText'] != null) {
        setState(() {
          _translatedText = result['translatedText'].toString();
          _isTranslated = true;
          _isTranslating = false;
        });
      } else {
        setState(() => _isTranslating = false);
        if (mounted) {
          AppSnackBar.showError(context, widget.localeService.get('translation_error'));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        AppSnackBar.showError(context, widget.localeService.get('translation_error'));
      }
    }
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: widget.comment['content'] ?? '');
    final isLightMode = widget.themeService.isLightMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isLightMode ? Colors.white : const Color(0xFF1E1E1E),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isLightMode ? Colors.grey[400] : Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        children: [
                          Text(
                            widget.localeService.isVietnamese ? 'Chỉnh sửa bình luận' : 'Edit comment',
                            style: TextStyle(
                              color: widget.themeService.textPrimaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isLightMode ? Colors.grey[200] : Colors.grey[800],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close_rounded, size: 18,
                                color: isLightMode ? Colors.grey[600] : Colors.grey[400]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Input field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          color: isLightMode ? Colors.grey[100] : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: controller,
                          maxLines: null,
                          minLines: 3,
                          autofocus: true,
                          style: TextStyle(
                            color: widget.themeService.textPrimaryColor,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.localeService.isVietnamese ? 'Nhập nội dung...' : 'Enter content...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                      ),
                    ),
                    // Save button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            final newContent = controller.text.trim();
                            if (newContent.isEmpty) return;
                            setDialogState(() => isSaving = true);
                            try {
                              final userId = widget.authService.user!['id'].toString();
                              await widget.commentService.editComment(
                                widget.comment['id'].toString(),
                                userId,
                                newContent,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              widget.onEdited();
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CommentTheme.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: CommentTheme.accent.withOpacity(0.5),
                          ),
                          child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                widget.localeService.isVietnamese ? 'Lưu thay đổi' : 'Save changes',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(ctx).padding.bottom),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final replyCount = widget.comment['replyCount'] ?? 0;
    final bool isPinned = widget.comment['isPinned'] == true;

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
                        widget.localeService.get('pinned_by_author'),
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
                  GestureDetector(
                    onTap: () => _navigateToUserProfile(context, widget.comment['userId']),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: CommentTheme.cardBackground,
                      backgroundImage: userInfo['avatar'] != null && userInfo['avatar'].toString().isNotEmpty && widget.apiService.getAvatarUrl(userInfo['avatar']).isNotEmpty
                          ? NetworkImage(widget.apiService.getAvatarUrl(userInfo['avatar']))
                          : null,
                      child: userInfo['avatar'] == null || userInfo['avatar'].toString().isEmpty || widget.apiService.getAvatarUrl(userInfo['avatar']).isEmpty
                          ? const Icon(Icons.person, size: 18, color: Colors.white54)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _navigateToUserProfile(context, widget.comment['userId']),
                              child: Text(
                                userInfo['fullName'] ?? userInfo['username'] ?? 'user',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: CommentTheme.textSecondary,
                                ),
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
                            // "Edited" badge
                            if (widget.comment['isEdited'] == true) ...[
                              const SizedBox(width: 6),
                              Text(
                                widget.localeService.isVietnamese ? '· đã chỉnh sửa' : '· edited',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Comment content: show translated, censored, or full
                        if ((widget.comment['content'] ?? '').toString().trim().isNotEmpty && 
                            widget.comment['content'] != '📷') ...[
                          if (_isTranslated && _translatedText != null)
                            Text(
                              _translatedText!,
                              style: TextStyle(
                                color: widget.themeService.textPrimaryColor,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            )
                          else
                            Text(
                              (widget.comment['isToxic'] == true && widget.filterComments && _isCensored
                                  ? (widget.comment['censoredContent'] ?? widget.comment['content'] ?? '')
                                  : (widget.comment['content'] ?? '')
                              ).toString(),
                              style: TextStyle(
                                color: widget.themeService.textPrimaryColor,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                        ],
                        // Translation indicator
                        if (_isTranslating) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.localeService.get('translating'),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_isTranslated && _translatedText != null) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => setState(() {
                              _isTranslated = false;
                              _translatedText = null;
                            }),
                            child: Row(
                              children: [
                                Icon(Icons.translate_rounded, size: 12, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Text(
                                  widget.localeService.get('translated'),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '·',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.localeService.get('show_original'),
                                  style: TextStyle(
                                    color: const Color(0xFF4285F4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Toxic warning + reveal/hide toggle
                        if (widget.comment['isToxic'] == true && widget.filterComments) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.localeService.isVietnamese
                                      ? 'Bình luận có thể chứa nội dung không phù hợp'
                                      : 'May contain inappropriate content',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() => _isCensored = !_isCensored),
                                child: Text(
                                  _isCensored
                                      ? (widget.localeService.isVietnamese ? 'Xem' : 'View')
                                      : (widget.localeService.isVietnamese ? 'Ẩn' : 'Hide'),
                                  style: TextStyle(
                                    color: CommentTheme.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Display comment image if exists - TikTok style
                        if (widget.comment['imageUrl'] != null) ...[
                          const SizedBox(height: 8),
                          // TikTok style - constrained image size
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 200,
                              maxHeight: 200,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: GestureDetector(
                                onTap: () => _showFullImage(context, widget.comment['imageUrl']),
                                child: Image.network(
                                  widget.apiService.getCommentImageUrl(widget.comment['imageUrl']),
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 150,
                                      height: 150,
                                      color: Colors.grey[800],
                                      child: const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[800],
                                      child: const Center(
                                        child: Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
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
                                          ? widget.localeService.get('hide_replies') 
                                          : '${widget.localeService.get('view_label')} $replyCount ${widget.localeService.get('reply')}',
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
                        filterComments: widget.filterComments,
                        onEdited: widget.onEdited,
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
  final bool filterComments;
  final VoidCallback? onEdited;

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
    this.filterComments = false,
    this.onEdited,
  });

  @override
  State<_ReplyItem> createState() => _ReplyItemState();
}

class _ReplyItemState extends State<_ReplyItem> with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isCensored = true;
  
  // Translation state
  bool _isTranslated = false;
  String? _translatedText;
  bool _isTranslating = false;
  
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
        _isLiked = result['liked'] == true;
        _likeCount = result['likeCount'] ?? 0;
      });
    }
  }

  void _showOptions() {
    final isOwnComment = widget.authService.user != null && 
                         widget.authService.user!['id'].toString() == widget.reply['userId'].toString();
    final isLightMode = widget.themeService.isLightMode;

    // Check 5-minute edit window
    bool canEdit = false;
    if (isOwnComment) {
      try {
        final createdAt = DateTime.parse(widget.reply['createdAt']);
        canEdit = DateTime.now().difference(createdAt).inMinutes < 5;
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        decoration: BoxDecoration(
          color: isLightMode ? Colors.white : const Color(0xFF262626),
          borderRadius: BorderRadius.circular(14),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isLightMode ? Colors.grey[350] : Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Copy
              _buildOptionTile(
                ctx: ctx,
                icon: Icons.content_copy_rounded,
                label: widget.localeService.get('copy_comment'),
                iconColor: isLightMode ? Colors.grey[700]! : Colors.grey[300]!,
                textColor: isLightMode ? Colors.black87 : Colors.white,
                onTap: () {
                  Navigator.pop(ctx);
                  _copyReply();
                },
              ),
              _optionDivider(isLightMode),
              // Translate / See original
              _buildOptionTile(
                ctx: ctx,
                icon: _isTranslated ? Icons.g_translate_rounded : Icons.translate_rounded,
                label: _isTranslated
                    ? widget.localeService.get('show_original')
                    : widget.localeService.get('see_translation'),
                iconColor: const Color(0xFF4285F4),
                textColor: isLightMode ? Colors.black87 : Colors.white,
                onTap: () {
                  Navigator.pop(ctx);
                  if (_isTranslated) {
                    setState(() {
                      _isTranslated = false;
                      _translatedText = null;
                    });
                  } else {
                    _translateReply();
                  }
                },
              ),
              if (isOwnComment && canEdit) ...[
                _optionDivider(isLightMode),
                _buildOptionTile(
                  ctx: ctx,
                  icon: Icons.edit_rounded,
                  label: widget.localeService.get('edit_reply'),
                  iconColor: isLightMode ? Colors.grey[700]! : Colors.grey[300]!,
                  textColor: isLightMode ? Colors.black87 : Colors.white,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog();
                  },
                ),
              ],
              if (isOwnComment) ...[
                _optionDivider(isLightMode),
                _buildOptionTile(
                  ctx: ctx,
                  icon: Icons.delete_outline_rounded,
                  label: widget.localeService.get('delete_comment'),
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete();
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionDivider(bool isLightMode) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 20,
      endIndent: 20,
      color: isLightMode ? Colors.grey[200] : Colors.grey[800],
    );
  }

  void _copyReply() {
    final isToxic = widget.reply['isToxic'] == true;
    final originalText = isToxic && widget.filterComments && _isCensored
        ? (widget.reply['censoredContent'] ?? widget.reply['content'] ?? '')
        : (widget.reply['content'] ?? '');
    final textToCopy = _isTranslated && _translatedText != null
        ? _translatedText!
        : originalText.toString();
    
    Clipboard.setData(ClipboardData(text: textToCopy));
    AppSnackBar.showSuccess(context, widget.localeService.get('comment_copied'));
  }

  void _confirmDelete() {
    final isLightMode = widget.themeService.isLightMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isLightMode ? Colors.white : const Color(0xFF262626),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.localeService.get('confirm_delete'),
          style: TextStyle(
            color: isLightMode ? Colors.black87 : Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          widget.localeService.get('delete_reply_confirm'),
          style: TextStyle(
            color: isLightMode ? Colors.black54 : Colors.grey[400],
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              widget.localeService.get('cancel'),
              style: TextStyle(
                color: isLightMode ? Colors.grey[600] : Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = widget.authService.user!['id'].toString();
              final deleted = await widget.commentService.deleteComment(
                widget.reply['id'].toString(),
                userId,
              );
              if (deleted) widget.onDelete();
            },
            child: Text(
              widget.localeService.get('delete_comment'),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _translateReply() async {
    final isToxic = widget.reply['isToxic'] == true;
    final textToTranslate = isToxic 
        ? (widget.reply['censoredContent'] ?? widget.reply['content'] ?? '')
        : (widget.reply['content'] ?? '');
    
    if (textToTranslate.toString().trim().isEmpty) return;
    
    // Translate TO user's current language (same as chat does)
    final targetLang = widget.localeService.isVietnamese ? 'vi' : 'en';
    
    setState(() => _isTranslating = true);
    
    try {
      final result = await MessageService().translateMessage(textToTranslate.toString(), targetLang);
      
      if (!mounted) return;
      
      if (result['success'] == true && result['translatedText'] != null) {
        setState(() {
          _translatedText = result['translatedText'].toString();
          _isTranslated = true;
          _isTranslating = false;
        });
      } else {
        setState(() => _isTranslating = false);
        if (mounted) {
          AppSnackBar.showError(context, widget.localeService.get('translation_error'));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        AppSnackBar.showError(context, widget.localeService.get('translation_error'));
      }
    }
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: widget.reply['content'] ?? '');
    final isLightMode = widget.themeService.isLightMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isLightMode ? Colors.white : const Color(0xFF1E1E1E),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isLightMode ? Colors.grey[400] : Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Row(
                        children: [
                          Text(
                            widget.localeService.isVietnamese ? 'Chỉnh sửa phản hồi' : 'Edit reply',
                            style: TextStyle(
                              color: widget.themeService.textPrimaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isLightMode ? Colors.grey[200] : Colors.grey[800],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close_rounded, size: 18,
                                color: isLightMode ? Colors.grey[600] : Colors.grey[400]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Input field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          color: isLightMode ? Colors.grey[100] : const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: controller,
                          maxLines: null,
                          minLines: 3,
                          autofocus: true,
                          style: TextStyle(
                            color: widget.themeService.textPrimaryColor,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.localeService.isVietnamese ? 'Nhập nội dung...' : 'Enter content...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(14),
                          ),
                        ),
                      ),
                    ),
                    // Save button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: isSaving ? null : () async {
                            final newContent = controller.text.trim();
                            if (newContent.isEmpty) return;
                            setDialogState(() => isSaving = true);
                            try {
                              final userId = widget.authService.user!['id'].toString();
                              await widget.commentService.editComment(
                                widget.reply['id'].toString(),
                                userId,
                                newContent,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              widget.onEdited?.call();
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CommentTheme.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: CommentTheme.accent.withOpacity(0.5),
                          ),
                          child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                widget.localeService.isVietnamese ? 'Lưu thay đổi' : 'Save changes',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(ctx).padding.bottom),
                  ],
                ),
              ),
            );
          },
        );
      },
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
                backgroundImage: userInfo['avatar'] != null && userInfo['avatar'].toString().isNotEmpty && widget.apiService.getAvatarUrl(userInfo['avatar']).isNotEmpty
                    ? NetworkImage(widget.apiService.getAvatarUrl(userInfo['avatar']))
                    : null,
                child: userInfo['avatar'] == null || userInfo['avatar'].toString().isEmpty || widget.apiService.getAvatarUrl(userInfo['avatar']).isEmpty
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
                          userInfo['fullName'] ?? userInfo['username'] ?? 'user',
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
                        if (widget.reply['isEdited'] == true) ...[
                          Text(
                            widget.localeService.isVietnamese ? ' · đã chỉnh sửa' : ' · edited',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Reply content: show translated, censored, or full
                    if (_isTranslated && _translatedText != null)
                      _buildReplyContent(_translatedText!)
                    else
                      _buildReplyContent(
                        (widget.reply['isToxic'] == true && widget.filterComments && _isCensored
                            ? (widget.reply['censoredContent'] ?? widget.reply['content'] ?? '')
                            : (widget.reply['content'] ?? '')
                        ).toString(),
                      ),
                    // Translation indicator
                    if (_isTranslating) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          SizedBox(
                            width: 9,
                            height: 9,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.localeService.get('translating'),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_isTranslated && _translatedText != null) ...[
                      const SizedBox(height: 3),
                      GestureDetector(
                        onTap: () => setState(() {
                          _isTranslated = false;
                          _translatedText = null;
                        }),
                        child: Row(
                          children: [
                            Icon(Icons.translate_rounded, size: 11, color: Colors.grey[500]),
                            const SizedBox(width: 3),
                            Text(
                              widget.localeService.get('translated'),
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '·',
                              style: TextStyle(color: Colors.grey[500], fontSize: 10),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.localeService.get('show_original'),
                              style: TextStyle(
                                color: const Color(0xFF4285F4),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Toxic warning + reveal/hide toggle
                    if (widget.reply['isToxic'] == true && widget.filterComments) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 11, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.localeService.isVietnamese
                                  ? 'Có thể chứa nội dung không phù hợp'
                                  : 'May contain inappropriate content',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _isCensored = !_isCensored),
                            child: Text(
                              _isCensored
                                  ? (widget.localeService.isVietnamese ? 'Xem' : 'View')
                                  : (widget.localeService.isVietnamese ? 'Ẩn' : 'Hide'),
                              style: TextStyle(
                                color: CommentTheme.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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