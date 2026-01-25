import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/hls_video_player.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_controls_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/options_menu_widget.dart';
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
import 'package:scalable_short_video_app/src/presentation/widgets/video_management_sheet.dart';

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
  Map<String, Map<String, dynamic>> _userCache = {};
  Map<String, bool> _saveStatus = {};

  @override
  void initState() {
    super.initState();
    print('🎬 VideoDetailScreen.initState');
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
    print('🔔 VideoDetailScreen: Login event received - reloading statuses');
    _initializeVideoData();
  }

  void _onLogout() {
    print('🔔 VideoDetailScreen: Logout event received - resetting statuses');
    
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
    
    // Initialize counts first
    for (var video in _videos) {
      if (video == null || video['id'] == null) continue;

      final videoId = video['id'].toString();
      _likeCounts[videoId] = _parseIntSafe(video['likeCount']);
      _commentCounts[videoId] = _parseIntSafe(video['commentCount']);
      _saveCounts[videoId] = _parseIntSafe(video['saveCount']);
      _shareCounts[videoId] = _parseIntSafe(video['shareCount']);
      
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
              print('📌 Detail - Video $videoId liked: $isLiked');
            }).catchError((e) {
              _likeStatus[videoId] = false;
            })
          );

          // Check save status
          statusFutures.add(
            _savedVideoService.isSavedByUser(videoId, userId).then((isSaved) {
              _saveStatus[videoId] = isSaved;
              print('📌 Detail - Video $videoId saved: $isSaved');
            }).catchError((e) {
              _saveStatus[videoId] = false;
            })
          );
        }

        // Wait for all status checks
        await Future.wait(statusFutures);
        
        print('✅ Detail screen - All statuses loaded');
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
      print('❌ Error fetching user info: $e');
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

  @override
  Widget build(BuildContext context) {
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
            Icons.arrow_back,
            color: Colors.white,
            size: 28,
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
        title: Text(
          widget.screenTitle ?? 'Video',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                blurRadius: 12.0,
                color: Colors.black87,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        titleSpacing: 0, // Remove spacing between leading and title
        centerTitle: false, // Align title to the left, close to back button
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

              // User info and caption
              Positioned(
                bottom: 10,
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
                                  backgroundImage: userInfo['avatar'] != null
                                      ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                                      : null,
                                  child: userInfo['avatar'] == null
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

              // Controls - NOW WITH SAVE COUNT
              if (videoId.isNotEmpty)
                Positioned(
                  bottom: 0,
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
                      shareCount: _formatCount(_shareCounts[videoId] ?? 0),
                      showManageButton: _authService.isLoggedIn && 
                          _authService.user != null && 
                          userId != null &&
                          _authService.user!['id'].toString() == userId,
                      onManageTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (modalContext) => VideoManagementSheet(
                            videoId: videoId,
                            userId: userId!,
                            isHidden: video['isHidden'] ?? false,
                            onDeleted: () {
                              print('📱 VideoDetailScreen.onDeleted called');
                              print('   Current page: $_currentPage');
                              print('   Videos count before removal: ${_videos.length}');
                              print('   Mounted: $mounted');
                              
                              // Remove video from list
                              if (!mounted) {
                                print('   ⚠️ Widget not mounted, skipping...');
                                return;
                              }
                              
                              // If no more videos, close the screen immediately
                              if (_videos.length <= 1) {
                                print('   📤 Last video or empty, closing VideoDetailScreen...');
                                
                                // Call parent callback first
                                widget.onVideoDeleted?.call();
                                
                                // Then pop after a short delay to ensure callback completes
                                Future.delayed(const Duration(milliseconds: 100), () {
                                  if (mounted && Navigator.of(context).canPop()) {
                                    print('   🚪 Popping navigation...');
                                    Navigator.of(context).pop();
                                    print('   ✅ Navigated back to parent');
                                  }
                                });
                                return;
                              }
                              
                              // Remove video and update state
                              setState(() {
                                _videos.removeAt(_currentPage);
                                print('   ✅ Video removed from list');
                                print('   Videos count after removal: ${_videos.length}');
                                
                                // Adjust current page if needed
                                if (_currentPage >= _videos.length) {
                                  _currentPage = _videos.length - 1;
                                  print('   🔄 Adjusted current page to: $_currentPage');
                                }
                                
                                // Increment key to force PageView rebuild
                                _pageViewKey++;
                                print('   🔄 PageView key updated to: $_pageViewKey');
                              });
                              
                              // Recreate PageController with new page
                              _pageController.dispose();
                              _pageController = PageController(initialPage: _currentPage);
                              print('   🔄 PageController recreated for page: $_currentPage');
                              
                              // Call the callback to refresh parent screen
                              widget.onVideoDeleted?.call();
                              print('   ✅ Parent callback called');
                              
                              // Force a rebuild
                              setState(() {});
                              print('   ✅ State updated, UI should rebuild');
                            },
                            onHiddenChanged: (isHidden) {
                              if (mounted) {
                                setState(() {
                                  video['isHidden'] = isHidden;
                                });
                              }
                            },
                          ),
                        );
                      },
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
