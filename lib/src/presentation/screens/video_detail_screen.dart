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
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/main_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/share_video_sheet.dart';

class VideoDetailScreen extends StatefulWidget {
  final List<dynamic> videos;
  final int initialIndex;

  const VideoDetailScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
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

  late PageController _pageController;
  int _currentPage = 0;

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
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Listen to logout events
    _authService.addLogoutListener(_onLogout);
    
    // Listen to login events - ADD THIS
    _authService.addLoginListener(_onLogin);
    
    _initializeVideoData();
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
    for (var video in widget.videos) {
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
    for (var video in widget.videos) {
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

    // Load status from server if logged in
    if (_authService.isLoggedIn && _authService.user != null) {
      final userId = _authService.user!['id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        List<Future<void>> statusFutures = [];

        for (var video in widget.videos) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để thích video')),
      );
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
        _saveCounts[videoId] = result['saveCount'] ?? (_saveCounts[videoId] ?? 0);
      });

      print(result['saved'] ? '🟡 Video saved' : '⚪ Video unsaved');
    }
  }

  void _handleShare(String videoId) {
    if (!_authService.isLoggedIn || _authService.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để chia sẻ')),
      );
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
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Video đã lưu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        titleSpacing: 0, // Remove spacing between leading and title
        centerTitle: false, // Align title to the left, close to back button
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          final video = widget.videos[index];
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
                  child: const Center(
                    child: Text(
                      'Video không khả dụng',
                      style: TextStyle(color: Colors.white, fontSize: 18),
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
                              GestureDetector(
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
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            video['description']?.toString() ?? video['title']?.toString() ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              shadows: [
                                Shadow(
                                  blurRadius: 8.0,
                                  color: Colors.black87,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
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
                      shareCount: _formatCount(_shareCounts[videoId] ?? 0), // ADD THIS
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
                      onShareTap: () => _handleShare(videoId), // CHANGE THIS
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
