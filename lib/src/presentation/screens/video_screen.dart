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

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  final LikeService _likeService = LikeService();
  final CommentService _commentService = CommentService();
  
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
  
  // PageView controller for better lifecycle management
  PageController? _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Listen to page changes to cleanup old videos
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVideos();
    });
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _userCache.clear();
    _likeStatus.clear();
    _likeCounts.clear();
    _commentCounts.clear();
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

      // Load all videos for feed (guest mode - no login required)
      final videos = await _videoService.getAllVideos();
      
      // Filter only ready videos (processed successfully)
      final readyVideos = videos.where((v) => v != null && v['status'] == 'ready').toList();

      // Initialize counts and like status from backend response with null safety
      for (var video in readyVideos) {
        if (video == null || video['id'] == null) continue;
        
        final videoId = video['id'].toString();
        _likeCounts[videoId] = (video['likeCount'] ?? 0) as int;
        _commentCounts[videoId] = (video['commentCount'] ?? 0) as int;
        
        // IMPORTANT: Always check like status for logged-in users
        if (_authService.isLoggedIn && _authService.user != null) {
          try {
            final userId = _authService.user!['id']?.toString();
            if (userId != null && userId.isNotEmpty) {
              print('🔍 Checking like status for video $videoId, user $userId');
              final isLiked = await _likeService.isLikedByUser(videoId, userId);
              _likeStatus[videoId] = isLiked;
              print('${isLiked ? '❤️' : '🤍'} Video $videoId like status: $isLiked');
            } else {
              _likeStatus[videoId] = false;
            }
          } catch (e) {
            print('❌ Error checking like status: $e');
            _likeStatus[videoId] = false;
          }
        } else {
          // Guest user - no likes
          _likeStatus[videoId] = false;
        }
      }

      if (mounted) {
        setState(() {
          _videos = readyVideos;
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

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) {
        return '${diff.inDays} ngày trước';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} giờ trước';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} phút trước';
      } else {
        return 'Vừa xong';
      }
    } catch (e) {
      return '';
    }
  }

  Future<Map<String, dynamic>> _getUserInfo(String? userId) async {
    // Add null check for userId
    if (userId == null || userId.isEmpty) {
      return {'username': 'user', 'avatar': null};
    }
    
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }
    
    try {
      // Fetch from API
      final userInfo = await _apiService.getUserById(userId);
      if (userInfo != null) {
        _userCache[userId] = userInfo;
        return userInfo;
      }
    } catch (e) {
      print('❌ Error fetching user info: $e');
    }
    
    // Return default user info if fetch fails
    return {'username': 'user', 'avatar': null};
  }

  Widget _buildCaption(String caption, bool isExpanded) {
    if (caption.isEmpty) return const SizedBox.shrink();

    // Max lines when collapsed
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

  bool _shouldShowFullscreenButton(dynamic video) {
    // Check if video needs fullscreen button based on aspect ratio
    // This is a simplified check - ideally we'd get aspect ratio from backend
    
    // For now, always show for horizontal videos (16:9, etc.)
    // We can improve this by storing aspect ratio in backend
    
    // Placeholder logic: show if aspectRatio field exists and is not "9:16"
    final aspectRatio = video['aspectRatio']?.toString() ?? '';
    
    // If aspectRatio is stored in backend and it's not 9:16, show fullscreen
    if (aspectRatio.isNotEmpty && aspectRatio != '9:16') {
      return true;
    }
    
    // Default: don't show (will be updated when backend sends aspect ratio)
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Add null check for pageController
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Đang tải video...',
                    style: TextStyle(color: Colors.white),
                  ),
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
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadVideos,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _videos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.video_library_outlined, size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có video nào',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hãy là người đầu tiên upload video!',
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
                          
                          // Only show video player for current page and adjacent pages
                          final shouldLoadVideo = (index - _currentPage).abs() <= 1;
                          
                          return Stack(
                            children: [
                              // HLS Video Player - only load if nearby
                              if (hlsUrl.isNotEmpty && shouldLoadVideo)
                                HLSVideoPlayer(
                                  key: ValueKey('video_$videoId'), // Unique key per video
                                  videoUrl: hlsUrl,
                                  autoPlay: index == _currentPage, // Only autoplay current
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
                                        Text(
                                          'Video không khả dụng',
                                          style: TextStyle(color: Colors.white, fontSize: 18),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              
                              // Bottom-left: Avatar + Username + Follow + Caption
                              Positioned(
                                bottom: 10,
                                left: 12,
                                right: 90,
                                child: SafeArea(
                                  child: FutureBuilder<Map<String, dynamic>>(
                                    future: _getUserInfo(userId),
                                    builder: (context, snapshot) {
                                      final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
                                      
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Avatar + Username + Follow button
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
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.white, width: 1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Theo dõi',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    shadows: [Shadow(blurRadius: 6.0, color: Colors.black87)],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          
                                          // Expandable Caption
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
                              
                              // UI Controls
                              if (videoId.isNotEmpty)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: VideoControlsWidget(
                                    isLiked: _likeStatus[videoId] ?? false,
                                    likeCount: _formatCount(_likeCounts[videoId] ?? 0),
                                    commentCount: _formatCount(_commentCounts[videoId] ?? 0),
                                    onLikeTap: () => _handleLike(videoId),
                                    onCommentTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (context) {
                                          return DraggableScrollableSheet(
                                            initialChildSize: 0.6,
                                            minChildSize: 0.2,
                                            maxChildSize: 0.9,
                                            builder: (BuildContext context, ScrollController scrollController) {
                                              return CommentSectionWidget(
                                                controller: scrollController,
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
                                              );
                                            },
                                          );
                                        },
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                      );
                                    },
                                    onMoreTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        builder: (context) => const OptionsMenuWidget(),
                                        backgroundColor: Colors.transparent,
                                      );
                                    },
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
                            ],
                          );
                        },
                      ),
                    ),
    );
  }
}
