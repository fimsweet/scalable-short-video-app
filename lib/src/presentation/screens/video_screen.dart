import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/options_menu_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/share_sheet_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_controls_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/hls_video_player.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  List<dynamic> _videos = [];
  bool _isLoading = true;
  String? _error;
  
  // Track expanded state for each video caption
  Map<int, bool> _expandedCaptions = {};
  
  // Cache user info for each video owner
  Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void deactivate() {
    // This is called when navigating away from this screen
    // Stop all videos to prevent audio playing in background
    super.deactivate();
  }

  Future<void> _loadVideos() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load all videos for feed (guest mode - no login required)
      final videos = await _videoService.getAllVideos();
      
      // Filter only ready videos (processed successfully)
      final readyVideos = videos.where((v) => v['status'] == 'ready').toList();

      setState(() {
        _videos = readyVideos;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading videos: $e');
      setState(() {
        _error = 'Không thể tải video. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
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

  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }
    
    // Fetch from API
    final userInfo = await _apiService.getUserById(userId);
    if (userInfo != null) {
      _userCache[userId] = userInfo;
      return userInfo;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Lỗi: $_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
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
                          const Icon(
                            Icons.video_library_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Chưa có video nào',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Hãy tải video đầu tiên của bạn!',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadVideos,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Làm mới'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadVideos,
                      child: PageView.builder(
                        scrollDirection: Axis.vertical,
                        itemCount: _videos.length,
                        itemBuilder: (context, index) {
                          final video = _videos[index];
                          final hlsUrl = _videoService.getVideoUrl(video['hlsUrl'] ?? '');
                          
                          // Debug logging
                          print('🎬 Video ${index + 1}:');
                          print('   videoId: ${video['id']}');
                          print('   hlsUrl from DB: ${video['hlsUrl']}');
                          print('   Full URL: $hlsUrl');
                          
                          return Stack(
                            children: [
                              // HLS Video Player
                              if (hlsUrl.isNotEmpty)
                                HLSVideoPlayer(videoUrl: hlsUrl)
                              else
                                Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 80,
                                          color: Colors.white,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Video không khả dụng',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              
                              // Instagram Reels-style layout
                              // Bottom-left: Avatar + Username + Follow + Caption
                              Positioned(
                                bottom: 10,
                                left: 12,
                                right: 90,
                                child: SafeArea(
                                  child: FutureBuilder<Map<String, dynamic>>(
                                    future: _getUserInfo(video['userId'].toString()),
                                    builder: (context, snapshot) {
                                      final userInfo = snapshot.data ?? {'username': 'user', 'avatar': null};
                                      
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Row: Avatar + Username + Follow button
                                          Row(
                                            children: [
                                              // Avatar (from video owner)
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: Colors.grey[800],
                                                backgroundImage: userInfo['avatar'] != null && 
                                                                 userInfo['avatar'].toString().isNotEmpty
                                                    ? NetworkImage(_apiService.getAvatarUrl(userInfo['avatar']))
                                                    : null,
                                                child: userInfo['avatar'] == null || 
                                                       userInfo['avatar'].toString().isEmpty
                                                    ? const Icon(
                                                        Icons.person,
                                                        color: Colors.white,
                                                        size: 20,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              // Username (from video owner)
                                              Text(
                                                userInfo['username'] ?? 'user',
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
                                              const SizedBox(width: 8),
                                              // Follow button (Instagram style)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 4,
                                                ),
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
                                                    shadows: [
                                                      Shadow(
                                                        blurRadius: 6.0,
                                                        color: Colors.black87,
                                                      ),
                                                    ],
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
                                              video['description'] ?? video['title'] ?? '',
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
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: VideoControlsWidget(
                                  onCommentTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (context) {
                                        return DraggableScrollableSheet(
                                          initialChildSize: 0.6,
                                          minChildSize: 0.2,
                                          maxChildSize: 0.9,
                                          builder: (BuildContext context,
                                              ScrollController scrollController) {
                                            return CommentSectionWidget(
                                                controller: scrollController);
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
