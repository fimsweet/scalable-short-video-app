import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/hls_video_player.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_controls_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/like_service.dart';
import 'package:scalable_short_video_app/src/services/comment_service.dart';
import 'package:scalable_short_video_app/src/services/saved_video_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/main_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/share_video_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/login_required_dialog.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/expandable_caption.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_privacy_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_more_options_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/app_snackbar.dart';
import 'package:scalable_short_video_app/src/presentation/screens/search_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_video_screen.dart';

class VideoDetailScreen extends StatefulWidget {
  final List<dynamic> videos;
  final int initialIndex;
  final String? screenTitle;
  final VoidCallback? onVideoDeleted; // Callback when video is deleted
  final bool openCommentsOnLoad; // Auto-open comments when loaded

  const VideoDetailScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
    this.screenTitle,
    this.onVideoDeleted,
    this.openCommentsOnLoad = false,
  });

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final LikeService _likeService = LikeService();
  final CommentService _commentService = CommentService();
  final SavedVideoService _savedVideoService = SavedVideoService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();

  late PageController _pageController;
  late List<dynamic> _videos; // Make videos mutable
  int _currentPage = 0;
  int _pageViewKey = 0; // Add key for PageView rebuild

  Map<String, bool> _likeStatus = {};
  Map<String, int> _likeCounts = {};
  Map<String, int> _commentCounts = {};
  Map<String, int> _saveCounts = {};
  Map<String, int> _shareCounts = {};
  Map<String, int> _viewCounts = {}; // Track view counts
  Map<String, Map<String, dynamic>> _userCache = {};
  Map<String, bool> _saveStatus = {};

  @override
  void initState() {
    super.initState();
    print('VideoDetailScreen.initState');
    print('   Initial videos count: ${widget.videos.length}');
    print('   Initial index: ${widget.initialIndex}');
    
    _videos = List.from(widget.videos); // Create mutable copy
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Listen to logout events
    _authService.addLogoutListener(_onLogout);
    
    // Listen to login events - ADD THIS
    _authService.addLoginListener(_onLogin);
    
    // Listen to theme and locale changes
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    
    _initializeVideoData();
    
    // Auto-open comments if requested (e.g., from notification)
    if (widget.openCommentsOnLoad && _videos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openCommentsForCurrentVideo();
      });
    }
  }
  
  void _openCommentsForCurrentVideo() {
    if (_videos.isEmpty || _currentPage >= _videos.length) return;
    final video = _videos[_currentPage];
    if (video == null || video['id'] == null) return;
    final videoId = video['id'].toString();
    
    showModalBottomSheet(
      context: context,
      builder: (context) => CommentSectionWidget(
        videoId: videoId,
        onCommentAdded: () async {
          final count = await _commentService.getCommentCount(videoId);
          if (mounted) {
            setState(() {
              _commentCounts[videoId] = count;
            });
          }
        },
        onCommentDeleted: () async {
          final count = await _commentService.getCommentCount(videoId);
          if (mounted) {
            setState(() {
              _commentCounts[videoId] = count;
            });
          }
        },
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: false,
    );
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  // ADD THIS METHOD
  void _onLogin() {
    print('VideoDetailScreen: Login event received - reloading statuses');
    _initializeVideoData();
  }

  void _onLogout() {
    print('VideoDetailScreen: Logout event received - resetting statuses');
    
    // Clear all statuses
    _likeStatus.clear();
    _saveStatus.clear();
    
    // Set all to default (not liked, not saved)
    for (var video in _videos) {
      if (video == null || video['id'] == null) continue;
      final videoId = video['id'].toString();
      _likeStatus[videoId] = false;
      _saveStatus[videoId] = false;
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _authService.removeLogoutListener(_onLogout);
    _authService.removeLoginListener(_onLogin); // ADD THIS
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoData() async {
    // Clear old status
    _likeStatus.clear();
    _saveStatus.clear();
    _saveCounts.clear();
    _shareCounts.clear();
    _viewCounts.clear();
    
    // Initialize counts first
    for (var video in _videos) {
      if (video == null || video['id'] == null) continue;

      final videoId = video['id'].toString();
      _likeCounts[videoId] = _parseIntSafe(video['likeCount']);
      _commentCounts[videoId] = _parseIntSafe(video['commentCount']);
      _saveCounts[videoId] = _parseIntSafe(video['saveCount']);
      _shareCounts[videoId] = _parseIntSafe(video['shareCount']);
      _viewCounts[videoId] = _parseIntSafe(video['viewCount']);
      
      // Set default values
      _likeStatus[videoId] = false;
      _saveStatus[videoId] = false;
    }
    
    // Increment view count for the initial video
    if (_videos.isNotEmpty && 
        widget.initialIndex < _videos.length &&
        _videos[widget.initialIndex] != null) {
      final initialVideo = _videos[widget.initialIndex];
      if (initialVideo['id'] != null) {
        final videoId = initialVideo['id'].toString();
        _videoService.incrementViewCount(videoId);
      }
    }

    // Load status from server if logged in
    if (_authService.isLoggedIn && _authService.user != null) {
      final userId = _authService.user!['id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        List<Future<void>> statusFutures = [];

        for (var video in _videos) {
          if (video == null || video['id'] == null) continue;

          final videoId = video['id'].toString();
          
          // Check like status
          statusFutures.add(
            _likeService.isLikedByUser(videoId, userId).then((isLiked) {
              _likeStatus[videoId] = isLiked;
              print('Detail - Video $videoId liked: $isLiked');
            }).catchError((e) {
              _likeStatus[videoId] = false;
            })
          );

          // Check save status
          statusFutures.add(
            _savedVideoService.isSavedByUser(videoId, userId).then((isSaved) {
              _saveStatus[videoId] = isSaved;
              print('Detail - Video $videoId saved: $isSaved');
            }).catchError((e) {
              _saveStatus[videoId] = false;
            })
          );
        }

        // Wait for all status checks
        await Future.wait(statusFutures);
        
        print('Detail screen - All statuses loaded');
      }
    }

    if (mounted) {
      setState(() {}); // Trigger rebuild with loaded statuses
    }
  }

  Future<void> _handleLike(String videoId) async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      LoginRequiredDialog.show(context, 'like');
      return;
    }

    final userId = _authService.user!['id']?.toString();
    if (userId == null) return;

    final result = await _likeService.toggleLike(videoId, userId);

    if (mounted) {
      setState(() {
        _likeStatus[videoId] = result['liked'] ?? false;
        _likeCounts[videoId] = result['likeCount'] ?? 0;
      });
    }
  }

  Future<void> _handleSave(String videoId) async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      LoginRequiredDialog.show(context, 'save');
      return;
    }

    final userId = _authService.user!['id']?.toString();
    if (userId == null || userId.isEmpty) return;

    final result = await _savedVideoService.toggleSave(videoId, userId);

    if (mounted) {
      setState(() {
        _saveStatus[videoId] = result['saved'] ?? false;
        _saveCounts[videoId] = result['saveCount'] ?? (_saveCounts[videoId] ?? 0);
      });

      print(result['saved'] ? '🟡 Video saved' : '⚪ Video unsaved');
    }
  }

  void _handleShare(String videoId) {
    if (!_authService.isLoggedIn || _authService.user == null) {
      LoginRequiredDialog.show(context, 'share');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareVideoSheet(
        videoId: videoId,
        onShareComplete: (shareCount) {
          if (mounted) {
            setState(() {
              _shareCounts[videoId] = shareCount;
            });
          }
        },
      ),
    );
  }

  // Quick emoji comment
  Future<void> _sendQuickEmojiComment(String videoId, String emoji) async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      LoginRequiredDialog.show(context, 'comment');
      return;
    }

    final userId = _authService.user!['id']?.toString();
    if (userId == null) return;

    try {
      final result = await _commentService.createComment(videoId, userId, emoji);
      if (result != null && mounted) {
        // Update comment count
        final count = await _commentService.getCommentCount(videoId);
        setState(() {
          _commentCounts[videoId] = count;
        });
        
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _localeService.isVietnamese 
                  ? 'Đã gửi bình luận $emoji'
                  : 'Sent comment $emoji',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      print('Error sending emoji comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_localeService.get('error_occurred')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getUserInfo(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return {'username': 'user', 'avatar': null};
    }

    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final userInfo = await _apiService.getUserById(userId);
      if (userInfo != null) {
        _userCache[userId] = userInfo;
        return userInfo;
      }
    } catch (e) {
      print('Error fetching user info: $e');
    }

    return {'username': 'user', 'avatar': null};
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _navigateToProfile(int? userId) {
    if (userId == null) return;
    
    final currentUserId = _authService.user?['id'] as int?;
    final isOwnProfile = currentUserId != null && currentUserId == userId;
    
    if (isOwnProfile) {
      // Pop back to MainScreen and switch to profile tab
      Navigator.of(context).popUntil((route) => route.isFirst);
      mainScreenKey.currentState?.switchToProfileTab();
    } else {
      // Navigate to other user's profile
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: userId),
        ),
      );
    }
  }

  // Add helper method
  int _parseIntSafe(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Get visibility icon based on visibility value
  IconData _getVisibilityIcon(String visibility) {
    switch (visibility) {
      case 'private':
        return Icons.lock_outline;
      case 'friends':
        return Icons.people_outline;
      default:
        return Icons.public;
    }
  }

  // Build search box for AppBar (like TikTok search)
  Widget _buildSearchBox() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SearchScreen(),
          ),
        );
      },
      child: Container(
        height: 36,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: Colors.white.withOpacity(0.7),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.screenTitle ?? _localeService.get('search_hint'),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _localeService.get('search'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show privacy settings bottom sheet
  void _showPrivacySettings(dynamic video) {
    final videoId = video['id']?.toString() ?? '';
    final userId = video['userId']?.toString() ?? '';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VideoPrivacySheet(
        videoId: videoId,
        userId: userId,
        currentVisibility: video['visibility'] ?? 'public',
        allowComments: video['allowComments'] ?? true,
        allowDuet: video['allowDuet'] ?? true,
        onChanged: (visibility, allowComments, allowDuet) {
          if (mounted) {
            setState(() {
              video['visibility'] = visibility;
              video['allowComments'] = allowComments;
              video['allowDuet'] = allowDuet;
            });
          }
        },
      ),
    );
  }

  // Show owner options menu (delete, hide, etc.) - TikTok style "More" sheet
  void _showOwnerOptionsMenu(dynamic video) {
    final videoId = video['id']?.toString() ?? '';
    final userId = video['userId']?.toString() ?? '';
    
    // Save navigator before showing modal
    final screenNavigator = Navigator.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => VideoMoreOptionsSheet(
        videoId: videoId,
        userId: userId,
        isHidden: video['isHidden'] ?? false,
        onEditTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditVideoScreen(
                videoId: videoId,
                userId: userId,
                currentTitle: video['title']?.toString(),
                currentDescription: video['description']?.toString(),
                currentThumbnailUrl: video['thumbnailUrl']?.toString(),
                onSaved: (description, thumbnailUrl) {
                  if (mounted) {
                    setState(() {
                      video['description'] = description;
                      if (thumbnailUrl != null) {
                        video['thumbnailUrl'] = thumbnailUrl;
                      }
                    });
                  }
                },
              ),
            ),
          );
        },
        onPrivacyTap: () {
          _showPrivacySettings(video);
        },
        onHideTap: () async {
          final isHidden = video['isHidden'] ?? false;
          try {
            final result = await _videoService.toggleHideVideo(videoId, userId);
            if (result['success'] == true && mounted) {
              setState(() {
                video['isHidden'] = result['isHidden'] ?? !isHidden;
              });
              AppSnackBar.showSuccess(
                context,
                result['isHidden'] == true
                    ? (_localeService.isVietnamese ? 'Đã ẩn video' : 'Video hidden')
                    : (_localeService.isVietnamese ? 'Đã hiện video' : 'Video visible'),
              );
            }
          } catch (e) {
            print('Error toggling video visibility: $e');
          }
        },
        onDeleteTap: () {
          // Show delete confirmation dialog
          _showDeleteConfirmation(video, screenNavigator);
        },
      ),
    );
  }

  // Show delete confirmation dialog - Modern style
  void _showDeleteConfirmation(dynamic video, NavigatorState screenNavigator) async {
    final videoId = video['id']?.toString() ?? '';
    final userId = video['userId']?.toString() ?? '';
    
    final confirmed = await AppDialog.showDeleteConfirmation(
      context,
      title: _localeService.isVietnamese ? 'Xóa video?' : 'Delete video?',
      message: _localeService.isVietnamese 
          ? 'Video sẽ bị xóa vĩnh viễn. Bạn không thể hoàn tác hành động này.'
          : 'This video will be permanently deleted. You cannot undo this action.',
    );
    
    if (confirmed == true && mounted) {
      try {
        final success = await _videoService.deleteVideo(videoId, userId);
        if (success) {
          AppSnackBar.showSuccess(
            context, 
            _localeService.isVietnamese ? 'Đã xóa video' : 'Video deleted',
          );
          // Call parent callback first to refresh the grid
          widget.onVideoDeleted?.call();
          
          // Pop VideoDetailScreen
          if (screenNavigator.canPop()) {
            screenNavigator.pop();
          }
        } else {
          if (mounted) {
            AppSnackBar.showError(context, _localeService.get('error_occurred'));
          }
        }
      } catch (e) {
        print('Error deleting video: $e');
        if (mounted) {
          AppSnackBar.showError(context, _localeService.get('error_occurred'));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if current video belongs to the logged-in user
    final currentVideo = _videos.isNotEmpty && _currentPage < _videos.length 
        ? _videos[_currentPage] 
        : null;
    final currentVideoUserId = currentVideo?['userId']?.toString();
    final isOwnVideo = _authService.isLoggedIn && 
        _authService.user != null && 
        currentVideoUserId != null &&
        _authService.user!['id'].toString() == currentVideoUserId;
    
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            color: Colors.white,
            size: 32,
            shadows: [
              Shadow(
                blurRadius: 12.0,
                color: Colors.black87,
                offset: Offset(0, 2),
              ),
            ],
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: isOwnVideo ? null : _buildSearchBox(),
        titleSpacing: 0,
        centerTitle: false,
        actions: isOwnVideo ? [
          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.white,
              size: 24,
              shadows: [
                Shadow(
                  blurRadius: 12.0,
                  color: Colors.black87,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
        ] : null,
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Only handle at last video when trying to scroll down
          if (_currentPage == _videos.length - 1) {
            if (notification is ScrollUpdateNotification) {
              // Check if trying to scroll down (negative delta means scrolling down)
              if (notification.metrics.pixels > notification.metrics.maxScrollExtent) {
                final overscroll = notification.metrics.pixels - notification.metrics.maxScrollExtent;
                if (overscroll > 100) {
                  Navigator.pop(context);
                  return true;
                }
              }
            }
          }
          return false;
        },
        child: PageView.builder(
          key: ValueKey('pageview_$_pageViewKey'),
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _videos.length,
          physics: const ClampingScrollPhysics(),
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
            
            // Increment view count when video is viewed
            final video = _videos[index];
            if (video != null && video['id'] != null) {
              final videoId = video['id'].toString();
              _videoService.incrementViewCount(videoId);
            }
          },
        itemBuilder: (context, index) {
          final video = _videos[index];
          if (video == null) {
            return Center(
              child: Text(_localeService.get('invalid_video'), style: const TextStyle(color: Colors.white)),
            );
          }

          final videoId = video['id']?.toString() ?? '';
          final hlsUrl = video['hlsUrl'] != null
              ? _videoService.getVideoUrl(video['hlsUrl'])
              : '';
          final userId = video['userId']?.toString();

          return Stack(
            children: [
              // Video player
              if (hlsUrl.isNotEmpty)
                HLSVideoPlayer(
                  key: ValueKey('detail_$videoId'),
                  videoUrl: hlsUrl,
                  autoPlay: index == _currentPage,
                )
              else
                Container(
                  color: Colors.black,
                  child: Center(
                    child: Text(
                      _localeService.get('video_unavailable'),
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),

              // User info and caption - position higher to make room for bottom bar
              Positioned(
                bottom: 60, // Always higher since both owner and viewer have bottom bar
                left: 12,
                right: 90,
                child: SafeArea(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _getUserInfo(userId),
                    builder: (context, snapshot) {
                      final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
                      final videoOwnerId = int.tryParse(userId ?? '');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              // Avatar - clickable to go to profile
                              GestureDetector(
                                onTap: () => _navigateToProfile(videoOwnerId),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.grey[800],
                                  backgroundImage: userInfo['avatar'] != null && _apiService.getAvatarUrl(userInfo['avatar']).isNotEmpty
                                      ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                                      : null,
                                  child: userInfo['avatar'] == null || _apiService.getAvatarUrl(userInfo['avatar']).isEmpty
                                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Username - clickable to go to profile
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _navigateToProfile(videoOwnerId),
                                  child: Text(
                                    userInfo['username']?.toString() ?? 'user',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 8.0,
                                          color: Colors.black87,
                                          offset: Offset(1, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ExpandableCaption(
                            key: ValueKey('caption_$videoId'),
                            description: video['description']?.toString() ?? video['title']?.toString() ?? '',
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Owner bottom bar - show view count and privacy settings for video owner
              if (_authService.isLoggedIn && 
                  _authService.user != null && 
                  userId != null &&
                  _authService.user!['id'].toString() == userId)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 16, right: 16, top: 12,
                      bottom: 12 + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                        children: [
                          // View count with play icon
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatCount(_viewCounts[videoId] ?? video['viewCount'] ?? 0)} ${_localeService.isVietnamese ? 'lượt xem' : 'views'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          
                          const Spacer(),
                          
                          // Privacy settings button
                          GestureDetector(
                            onTap: () => _showPrivacySettings(video),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getVisibilityIcon(video['visibility'] ?? 'public'),
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _localeService.isVietnamese ? 'Cài đặt quyền riêng tư' : 'Privacy settings',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ),

              // Viewer bottom bar - comment input and search (when viewing other's video)
              if (userId != null && 
                  (!_authService.isLoggedIn || 
                   _authService.user == null || 
                   _authService.user!['id'].toString() != userId))
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 12, right: 12, top: 10,
                      bottom: 10 + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                        children: [
                          // Comment input field
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                final allowComments = video['allowComments'] ?? true;
                                if (allowComments) {
                                  // Open comment section
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (context) => CommentSectionWidget(
                                      videoId: videoId,
                                      autoFocus: true,
                                      onCommentAdded: () async {
                                        final count = await _commentService.getCommentCount(videoId);
                                        if (mounted) {
                                          setState(() {
                                            _commentCounts[videoId] = count;
                                          });
                                        }
                                      },
                                      onCommentDeleted: () async {
                                        final count = await _commentService.getCommentCount(videoId);
                                        if (mounted) {
                                          setState(() {
                                            _commentCounts[videoId] = count;
                                          });
                                        }
                                      },
                                    ),
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    useSafeArea: false,
                                  );
                                } else {
                                  // Show disabled message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        _localeService.isVietnamese 
                                            ? 'Chủ video đã tắt bình luận cho video này'
                                            : 'The video owner has disabled comments for this video',
                                      ),
                                      backgroundColor: Colors.grey[800],
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (video['allowComments'] ?? true)
                                            ? (_localeService.isVietnamese ? 'Thêm bình luận...' : 'Add a comment...')
                                            : (_localeService.isVietnamese ? 'Bình luận đã bị tắt' : 'Comments are disabled'),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    // Emoji icons like TikTok - tappable to send quick comments
                                    if (video['allowComments'] ?? true) ...[
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _sendQuickEmojiComment(videoId, '😊'),
                                        child: const Text('😊', style: TextStyle(fontSize: 18)),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => _sendQuickEmojiComment(videoId, '😂'),
                                        child: const Text('😂', style: TextStyle(fontSize: 18)),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () => _sendQuickEmojiComment(videoId, '🥰'),
                                        child: const Text('🥰', style: TextStyle(fontSize: 18)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ),

              // Controls - position higher when there's bottom bar
              if (videoId.isNotEmpty)
                Positioned(
                  bottom: 50, // Always position higher to make room for bottom bar
                  right: 0,
                  child: GestureDetector(
                    onTap: () {},
                    behavior: HitTestBehavior.opaque,
                    child: VideoControlsWidget(
                      isLiked: _likeStatus[videoId] ?? false,
                      isSaved: _saveStatus[videoId] ?? false,
                      likeCount: _formatCount(_likeCounts[videoId] ?? 0),
                      commentCount: _formatCount(_commentCounts[videoId] ?? 0),
                      saveCount: _formatCount(_saveCounts[videoId] ?? 0),
                      shareCount: (_shareCounts[videoId] ?? 0) == 0 ? _localeService.get('share') : _formatCount(_shareCounts[videoId] ?? 0),
                      showManageButton: false,
                      showMoreButton: _authService.isLoggedIn && 
                          _authService.user != null && 
                          userId != null &&
                          _authService.user!['id'].toString() == userId,
                      onMoreTap: () => _showOwnerOptionsMenu(video),
                      onManageTap: () {},
                      onLikeTap: () => _handleLike(videoId),
                      onCommentTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => CommentSectionWidget(
                            videoId: videoId,
                            onCommentAdded: () async {
                              final count = await _commentService.getCommentCount(videoId);
                              if (mounted) {
                                setState(() {
                                  _commentCounts[videoId] = count;
                                });
                              }
                            },
                            onCommentDeleted: () async {
                              final count = await _commentService.getCommentCount(videoId);
                              if (mounted) {
                                setState(() {
                                  _commentCounts[videoId] = count;
                                });
                              }
                            },
                          ),
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          useSafeArea: false,
                        );
                      },
                      onSaveTap: () => _handleSave(videoId),
                      onShareTap: () => _handleShare(videoId),
                    ),
                  ),
                ),
            ],
          );
        },
        ),
      ),
    );
  }
}
