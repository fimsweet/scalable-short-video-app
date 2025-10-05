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

      // Get current user from AuthService
      final user = _authService.user;
      if (user == null) {
        setState(() {
          _videos = [];
          _isLoading = false;
          _error = 'Vui lòng đăng nhập';
        });
        return;
      }

      // Fetch user's videos from backend
      // Convert userId to String to avoid type error
      final userId = user['id'].toString();
      final videos = await _videoService.getUserVideos(userId);
      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Video vui',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVideos,
          ),
        ],
      ),
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
                              
                              // User Info (Top-left - TikTok style)
                              Positioned(
                                top: 60,
                                left: 16,
                                child: Row(
                                  children: [
                                    // Avatar
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey[800],
                                      backgroundImage: _authService.avatarUrl != null && 
                                                       _authService.avatarUrl!.isNotEmpty
                                          ? NetworkImage(_apiService.getAvatarUrl(_authService.avatarUrl))
                                          : null,
                                      child: _authService.avatarUrl == null || 
                                             _authService.avatarUrl!.isEmpty
                                          ? Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 24,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    // Username
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '@${_authService.username ?? 'user'}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 8.0,
                                              color: Colors.black,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Video Info Overlay (Bottom-left)
                              Positioned(
                                bottom: 100,
                                left: 16,
                                right: 80,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video['title'] ?? 'Untitled',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 10.0,
                                            color: Colors.black,
                                            offset: Offset(0, 0),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (video['description'] != null && 
                                        video['description'].toString().isNotEmpty)
                                      Text(
                                        video['description'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 10.0,
                                              color: Colors.black,
                                              offset: Offset(0, 0),
                                            ),
                                          ],
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time, 
                                          size: 14, color: Colors.white70),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDate(video['createdAt']),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
