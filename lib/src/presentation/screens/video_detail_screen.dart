import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/hls_video_player.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_controls_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/like_service.dart';
import 'package:scalable_short_video_app/src/services/comment_service.dart';

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

  late PageController _pageController;
  int _currentPage = 0;

  Map<String, bool> _likeStatus = {};
  Map<String, int> _likeCounts = {};
  Map<String, int> _commentCounts = {};
  Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initializeVideoData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideoData() async {
    for (var video in widget.videos) {
      if (video == null || video['id'] == null) continue;

      final videoId = video['id'].toString();
      _likeCounts[videoId] = (video['likeCount'] ?? 0) as int;
      _commentCounts[videoId] = (video['commentCount'] ?? 0) as int;

      if (_authService.isLoggedIn && _authService.user != null) {
        final userId = _authService.user!['id']?.toString();
        if (userId != null) {
          final isLiked = await _likeService.isLikedByUser(videoId, userId);
          _likeStatus[videoId] = isLiked;
        }
      }
    }

    if (mounted) {
      setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Video', style: TextStyle(color: Colors.white)),
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

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: userInfo['avatar'] != null
                                    ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                                    : null,
                                child: userInfo['avatar'] == null
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
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8.0,
                                      color: Colors.black87,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
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

              // Controls
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
                    onMoreTap: () {},
                    onShareTap: () {},
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
