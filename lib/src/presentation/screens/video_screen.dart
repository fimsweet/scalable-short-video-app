import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/options_menu_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/share_sheet_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_controls_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/hls_video_player.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/like_service.dart';
import 'package:scalable_short_video_app/src/services/comment_service.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/saved_video_service.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/feed_tab_bar.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> with AutomaticKeepAliveClientMixin {
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final LikeService _likeService = LikeService();
  final CommentService _commentService = CommentService();
  final FollowService _followService = FollowService();
  final SavedVideoService _savedVideoService = SavedVideoService();
  
  List<dynamic> _videos = [];
  bool _isLoading = true;
  String? _error;
  
  // Track expanded state for each video caption
  Map<int, bool> _expandedCaptions = {};
  
  // Cache user info for each video owner
  Map<String, Map<String, dynamic>> _userCache = {};
  
  // Track like status for each video
  Map<String, bool> _likeStatus = {};
  Map<String, int> _likeCounts = {};
  Map<String, int> _commentCounts = {};
  
  // Track follow status for each user
  Map<String, bool> _followStatus = {};
  
  // Track save status for each video
  Map<String, bool> _saveStatus = {};
  
  // PageView controller for better lifecycle management
  PageController? _pageController;
  int _currentPage = 0;

  int _selectedFeedTab = 1; // 0 = Following, 1 = For You (default)
  
  // Separate video lists for each tab
  List<dynamic> _forYouVideos = [];
  List<dynamic> _followingVideos = [];

  bool _lastLoginState = false;
  int? _lastUserId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    _pageController!.addListener(() {
      if (_pageController!.page != null) {
        final newPage = _pageController!.page!.round();
        if (newPage != _currentPage) {
          setState(() {
            _currentPage = newPage;
          });
        }
      }
    });
    
    // Initialize login state tracking
    _lastLoginState = _authService.isLoggedIn;
    _lastUserId = _authService.user?['id'] as int?;
    
    // Remove listeners - MainScreen handles rebuild now
    // _authService.addLogoutListener(_onLogout);
    // _authService.addLoginListener(_onLogin);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideos();
    });
  }

  // Remove these methods - no longer needed
  // void _onLogin() { ... }
  // void _onLogout() { ... }

  // Remove didChangeDependencies check - not needed with key-based rebuild
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Remove _checkAndReloadIfNeeded() - MainScreen handles this now
  }

  // Remove _checkAndReloadIfNeeded method

  @override
  void dispose() {
    // Remove listener cleanup
    // _authService.removeLogoutListener(_onLogout);
    // _authService.removeLoginListener(_onLogin);
    _pageController?.dispose();
    _userCache.clear();
    _likeStatus.clear();
    _likeCounts.clear();
    _commentCounts.clear();
    _followStatus.clear();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      if (_selectedFeedTab == 1) {
        // For You feed - all videos
        await _loadForYouVideos();
      } else {
        // Following feed - videos from followed users
        await _loadFollowingVideos();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading videos: $e');
      if (mounted) {
        setState(() {
          _error = 'Không thể tải video. Vui lòng thử lại.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadForYouVideos() async {
    // REMOVE cache check - always reload status from server
    // if (_forYouVideos.isNotEmpty) { ... }

    final videos = await _videoService.getAllVideos();
    final readyVideos = videos.where((v) => v != null && v['status'] == 'ready').toList();

    // Process videos and wait for all status checks to complete
    await _processVideos(readyVideos);
    
    if (mounted) {
      setState(() {
        _forYouVideos = readyVideos;
        _videos = _forYouVideos;
      });
    }
  }

  Future<void> _loadFollowingVideos() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      if (mounted) {
        setState(() {
          _followingVideos = [];
          _videos = _followingVideos;
        });
      }
      return;
    }

    // REMOVE cache check - always reload status from server
    // if (_followingVideos.isNotEmpty) { ... }

    final userId = _authService.user!['id'].toString();
    final videos = await _videoService.getFollowingVideos(userId);
    final readyVideos = videos.where((v) => v != null && v['status'] == 'ready').toList();

    await _processVideos(readyVideos);
    
    if (mounted) {
      setState(() {
        _followingVideos = readyVideos;
        _videos = _followingVideos;
      });
    }
  }

  Future<void> _processVideos(List<dynamic> readyVideos) async {
    // Clear all status maps before reloading
    _likeStatus.clear();
    _followStatus.clear();
    _saveStatus.clear();

    // Initialize counts first (immediate display)
    for (var video in readyVideos) {
      if (video == null || video['id'] == null) continue;
      
      final videoId = video['id'].toString();
      _likeCounts[videoId] = (video['likeCount'] ?? 0) as int;
      _commentCounts[videoId] = (video['commentCount'] ?? 0) as int;
      
      // Set default values - NOT logged in defaults to false
      _likeStatus[videoId] = false;
      _saveStatus[videoId] = false;
    }

    // IMPORTANT: Update UI immediately with default values
    if (mounted) {
      setState(() {});
    }

    // Load like/save status from server if logged in
    if (_authService.isLoggedIn && _authService.user != null) {
      final userId = _authService.user!['id']?.toString();
      print('🔐 User logged in, loading statuses for userId: $userId');
      
      if (userId != null && userId.isNotEmpty) {
        // Create list of futures to run in parallel
        List<Future<void>> statusFutures = [];

        for (var video in readyVideos) {
          if (video == null || video['id'] == null) continue;
          
          final videoId = video['id'].toString();
          
          // Check like status
          statusFutures.add(
            _likeService.isLikedByUser(videoId, userId).then((isLiked) {
              _likeStatus[videoId] = isLiked;
              print('📌 Video $videoId liked: $isLiked');
            }).catchError((e) {
              print('❌ Error checking like status for $videoId: $e');
              _likeStatus[videoId] = false;
            })
          );
          
          // Check save status
          statusFutures.add(
            _savedVideoService.isSavedByUser(videoId, userId).then((isSaved) {
              _saveStatus[videoId] = isSaved;
              print('📌 Video $videoId saved: $isSaved');
            }).catchError((e) {
              print('❌ Error checking save status for $videoId: $e');
              _saveStatus[videoId] = false;
            })
          );
        }

        // Wait for all status checks to complete
        await Future.wait(statusFutures);
        
        print('✅ All like/save statuses loaded:');
        _likeStatus.forEach((k, v) => print('   Like $k: $v'));
        _saveStatus.forEach((k, v) => print('   Save $k: $v'));
        
        // IMPORTANT: Trigger rebuild AFTER all statuses are loaded
        if (mounted) {
          setState(() {
            print('🔄 Rebuilding UI with loaded statuses');
          });
        }
      }
    } else {
      print('🔓 User not logged in, all statuses set to false');
    }

    // Check follow status for each video owner
    if (_authService.isLoggedIn && _authService.user != null) {
      final currentUserId = _authService.user!['id'] as int;
      
      List<Future<void>> followFutures = [];
      
      for (var video in readyVideos) {
        if (video == null || video['userId'] == null) continue;
        
        final videoOwnerId = int.tryParse(video['userId'].toString());
        if (videoOwnerId != null && videoOwnerId != currentUserId) {
          followFutures.add(
            _followService.isFollowing(currentUserId, videoOwnerId).then((isFollowing) {
              _followStatus[videoOwnerId.toString()] = isFollowing;
            }).catchError((e) {
              _followStatus[videoOwnerId.toString()] = false;
            })
          );
        }
      }
      
      await Future.wait(followFutures);
      
      // Update UI after follow statuses loaded
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _onTabChanged(int index) {
    if (_selectedFeedTab == index) return;
    
    setState(() {
      _selectedFeedTab = index;
      _currentPage = 0;
    });
    
    // DON'T reset page controller - just load new videos
    // This prevents audio issues when switching tabs
    
    // Load videos for selected tab (will use cache if available)
    _loadVideos();
  }

  Future<void> _handleLike(String videoId) async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để thích video')),
      );
      return;
    }

    final userId = _authService.user!['id']?.toString();
    if (userId == null || userId.isEmpty) {
      print('❌ Invalid user ID');
      return;
    }

    print('👆 Toggle like for video $videoId by user $userId');
    
    final result = await _likeService.toggleLike(videoId, userId);

    if (mounted) {
      setState(() {
        _likeStatus[videoId] = result['liked'] ?? false;
        _likeCounts[videoId] = result['likeCount'] ?? 0;
      });
      
      print('${result['liked'] ? '❤️' : '🤍'} Like toggled - Status: ${result['liked']}, Count: ${result['likeCount']}');
    }
  }

  Future<void> _handleFollow(int videoOwnerId) async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để theo dõi')),
      );
      return;
    }

    final currentUserId = _authService.user!['id'] as int;
    
    if (currentUserId == videoOwnerId) {
      return;
    }

    print('👆 Toggle follow for user $videoOwnerId by user $currentUserId');
    
    final result = await _followService.toggleFollow(currentUserId, videoOwnerId);

    if (mounted) {
      setState(() {
        _followStatus[videoOwnerId.toString()] = result['following'] ?? false;
      });
      
      print('${result['following'] ? '✅' : '❌'} Follow toggled - Status: ${result['following']}');
    }
  }

  Future<void> _handleSave(String videoId) async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để lưu video')),
      );
      return;
    }

    final userId = _authService.user!['id']?.toString();
    if (userId == null || userId.isEmpty) return;

    final result = await _savedVideoService.toggleSave(videoId, userId);

    if (mounted) {
      setState(() {
        _saveStatus[videoId] = result['saved'] ?? false;
      });

      // Removed SnackBar - icon color change is enough visual feedback
      print(result['saved'] ? '🟡 Video saved' : '⚪ Video unsaved');
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
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

  Widget _buildCaption(String caption, bool isExpanded) {
    if (caption.isEmpty) return const SizedBox.shrink();

    const int maxLinesCollapsed = 2;
    
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.3,
          shadows: [
            Shadow(
              blurRadius: 8.0,
              color: Colors.black87,
              offset: Offset(1, 1),
            ),
          ],
        ),
        children: [
          TextSpan(
            text: isExpanded 
                ? caption 
                : (caption.length > 100 
                    ? '${caption.substring(0, 100)}...' 
                    : caption),
          ),
          if (!isExpanded && caption.length > 100)
            const TextSpan(
              text: ' xem thêm',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      maxLines: isExpanded ? null : maxLinesCollapsed,
      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    if (_pageController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageStorage(
        bucket: PageStorageBucket(),
        child: Stack(
          children: [
            // Video feed
            _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text('Đang tải video...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadVideos, child: const Text('Thử lại')),
                          ],
                        ),
                      )
                    : _videos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedFeedTab == 0 ? Icons.people_outline : Icons.video_library_outlined,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _selectedFeedTab == 0 
                                      ? 'Chưa có video từ người bạn theo dõi'
                                      : 'Chưa có video nào',
                                  style: const TextStyle(color: Colors.white, fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedFeedTab == 0
                                      ? 'Hãy theo dõi người khác để xem video của họ!'
                                      : 'Hãy là người đầu tiên upload video!',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _loadVideos,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Tải lại'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadVideos,
                            child: PageView.builder(
                              key: PageStorageKey('video_feed_$_selectedFeedTab'), // Add key for storage
                              controller: _pageController!,
                              scrollDirection: Axis.vertical,
                              itemCount: _videos.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentPage = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                final video = _videos[index];
                                
                                if (video == null) {
                                  return const Center(
                                    child: Text('Video không hợp lệ', style: TextStyle(color: Colors.white)),
                                  );
                                }
                                
                                final videoId = video['id']?.toString() ?? '';
                                final hlsUrl = video['hlsUrl'] != null 
                                    ? _videoService.getVideoUrl(video['hlsUrl']) 
                                    : '';
                                final userId = video['userId']?.toString();
                                
                                final shouldLoadVideo = (index - _currentPage).abs() <= 1;
                                
                                return Stack(
                                  children: [
                                    // Video player - Add unique key
                                    if (hlsUrl.isNotEmpty && shouldLoadVideo)
                                      HLSVideoPlayer(
                                        key: ValueKey('video_${_selectedFeedTab}_$videoId'), // Unique key per tab
                                        videoUrl: hlsUrl,
                                        autoPlay: index == _currentPage,
                                      )
                                    else if (!shouldLoadVideo)
                                      Container(
                                        color: Colors.black,
                                        child: const Center(
                                          child: CircularProgressIndicator(color: Colors.white),
                                        ),
                                      )
                                    else
                                      Container(
                                        color: Colors.black,
                                        child: const Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.error_outline, size: 80, color: Colors.white),
                                              SizedBox(height: 16),
                                              Text('Video không khả dụng', style: TextStyle(color: Colors.white, fontSize: 18)),
                                            ],
                                          ),
                                        ),
                                      ),
                                  
                                    // Bottom info
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
                                            final currentUserId = _authService.user?['id'] as int?;
                                            final isOwnVideo = videoOwnerId != null && currentUserId != null && videoOwnerId == currentUserId;
                                            final isFollowing = videoOwnerId != null ? (_followStatus[videoOwnerId.toString()] ?? false) : false;
                                            
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 18,
                                                      backgroundColor: Colors.grey[800],
                                                      backgroundImage: userInfo['avatar'] != null && userInfo['avatar'].toString().isNotEmpty
                                                          ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                                                          : null,
                                                      child: userInfo['avatar'] == null || userInfo['avatar'].toString().isEmpty
                                                          ? const Icon(Icons.person, color: Colors.white, size: 20)
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      userInfo['username']?.toString() ?? 'user',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        shadows: [Shadow(blurRadius: 8.0, color: Colors.black87, offset: Offset(1, 1))],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    if (!isOwnVideo && videoOwnerId != null)
                                                      GestureDetector(
                                                        onTap: () => _handleFollow(videoOwnerId),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            // Solid red background - modern & clean
                                                            color: isFollowing ? const Color(0xFFFF3B5C) : Colors.transparent,
                                                            border: Border.all(
                                                              color: isFollowing ? Colors.transparent : Colors.white, 
                                                              width: 1.5,
                                                            ),
                                                            borderRadius: BorderRadius.circular(4),
                                                            // Subtle glow effect
                                                            boxShadow: isFollowing ? [
                                                              BoxShadow(
                                                                color: const Color(0xFFFF3B5C).withOpacity(0.4),
                                                                blurRadius: 8,
                                                                spreadRadius: 0,
                                                              ),
                                                            ] : null,
                                                          ),
                                                          child: Text(
                                                            isFollowing ? 'Đang theo dõi' : 'Theo dõi',
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w600,
                                                              letterSpacing: 0.3,
                                                              shadows: [Shadow(blurRadius: 6.0, color: Colors.black87)],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _expandedCaptions[index] = !(_expandedCaptions[index] ?? false);
                                                    });
                                                  },
                                                  child: _buildCaption(
                                                    video['description']?.toString() ?? video['title']?.toString() ?? '',
                                                    _expandedCaptions[index] ?? false,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  
                                    // Controls
                                    if (videoId.isNotEmpty)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () {}, // Absorb taps
                                          behavior: HitTestBehavior.opaque,
                                          child: VideoControlsWidget(
                                            isLiked: _likeStatus[videoId] ?? false,
                                            isSaved: _saveStatus[videoId] ?? false,
                                            likeCount: _formatCount(_likeCounts[videoId] ?? 0),
                                            commentCount: _formatCount(_commentCounts[videoId] ?? 0),
                                            onLikeTap: () => _handleLike(videoId),
                                            onCommentTap: () {
                                              showModalBottomSheet(
                                                context: context,
                                                builder: (context) => Padding(
                                                  padding: EdgeInsets.only(
                                                    bottom: MediaQuery.of(context).viewInsets.bottom,
                                                  ),
                                                  child: CommentSectionWidget(
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
                                                ),
                                                isScrollControlled: true,
                                                backgroundColor: Colors.transparent,
                                                useSafeArea: false,
                                              );
                                            },
                                            onSaveTap: () => _handleSave(videoId),
                                            onShareTap: () {
                                              showModalBottomSheet(
                                                context: context,
                                                builder: (context) => const ShareSheetWidget(),
                                                isScrollControlled: true,
                                                backgroundColor: Colors.transparent,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
          
            // Tab bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: FeedTabBar(
                  selectedIndex: _selectedFeedTab,
                  onTabChanged: _onTabChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

