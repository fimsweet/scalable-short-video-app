import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';

class HiddenVideoGrid extends StatefulWidget {
  const HiddenVideoGrid({super.key});

  @override
  State<HiddenVideoGrid> createState() => _HiddenVideoGridState();
}

class _HiddenVideoGridState extends State<HiddenVideoGrid> {
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  
  List<dynamic> _hiddenVideos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authService.addLogoutListener(_onLogout);
    _authService.addLoginListener(_onLogin);
    _loadHiddenVideos();
  }

  void _onLogin() {
    print('HiddenVideoGrid: Login event - loading hidden videos');
    _loadHiddenVideos();
  }

  void _onLogout() {
    print('HiddenVideoGrid: Logout event - clearing hidden videos');
    if (mounted) {
      setState(() {
        _hiddenVideos = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHiddenVideos() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = _authService.user!['id'].toString();
      final videos = await _videoService.getUserVideos(userId);

      // Debug: Log all videos data
      print('All videos from backend: ${videos.length}');
      for (var video in videos) {
        print('   Video ID: ${video['id']}');
        print('   likeCount: ${video['likeCount']}');
        print('   commentCount: ${video['commentCount']}');
        print('   saveCount: ${video['saveCount']}');
        print('   shareCount: ${video['shareCount']}');
        print('   viewCount: ${video['viewCount']}');
        print('   isHidden: ${video['isHidden']}');
        print('   ---');
      }

      // Filter only hidden videos
      final hiddenVideos = videos
          .where((video) => video['isHidden'] == true)
          .toList();

      if (mounted) {
        setState(() {
          _hiddenVideos = hiddenVideos;
          _isLoading = false;
        });
        print('Loaded ${hiddenVideos.length} hidden videos');
      }
    } catch (e) {
      print('Error loading hidden videos: $e');
      if (mounted) {
        setState(() {
          _error = 'Không thể tải video: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _authService.removeLogoutListener(_onLogout);
    _authService.removeLoginListener(_onLogin);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHiddenVideos,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_hiddenVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có video đã ẩn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Video đã ẩn chỉ hiển thị cho người theo dõi',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHiddenVideos,
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0, // Square tiles like other grids
        ),
        itemCount: _hiddenVideos.length,
        itemBuilder: (context, index) {
          final video = _hiddenVideos[index];
          
          final thumbnailUrl = video['thumbnailUrl'] != null
              ? _videoService.getVideoUrl(video['thumbnailUrl'])
              : null;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoDetailScreen(
                    videos: _hiddenVideos,
                    initialIndex: index,
                    screenTitle: 'Video đã ẩn',
                    onVideoDeleted: () {
                      // Refresh the hidden videos list
                      _loadHiddenVideos();
                    },
                  ),
                ),
              ).then((_) {
                _loadHiddenVideos();
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
              ),
              child: ClipRRect(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail
                    if (thumbnailUrl != null)
                      Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.video_library_outlined,
                              size: 32,
                              color: Colors.white54,
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.video_library_outlined,
                          size: 32,
                          color: Colors.white54,
                        ),
                      ),
                    
                    // Dark gradient overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                                Colors.black.withOpacity(0.85),
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Lock icon indicator at top right
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    
                    // View count overlay at bottom (like other grids)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatCount(video['viewCount'] ?? 0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
          );
        },
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
