import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/like_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';

class LikedVideoGrid extends StatefulWidget {
  const LikedVideoGrid({super.key});

  @override
  State<LikedVideoGrid> createState() => _LikedVideoGridState();
}

class _LikedVideoGridState extends State<LikedVideoGrid> {
  final LikeService _likeService = LikeService();
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  final LocaleService _localeService = LocaleService();
  final ThemeService _themeService = ThemeService();
  
  List<dynamic> _likedVideos = [];
  bool _isLoadingLikedVideos = false;

  @override
  void initState() {
    super.initState();
    _loadLikedVideos();
  }

  Future<void> _loadLikedVideos() async {
    if (_authService.isLoggedIn && _authService.user != null) {
      try {
        setState(() {
          _isLoadingLikedVideos = true;
        });

        final userIdValue = _authService.user!['id'];
        if (userIdValue == null) {
          print('User ID is null');
          setState(() {
            _likedVideos = [];
            _isLoadingLikedVideos = false;
          });
          return;
        }
        
        final userId = userIdValue.toString();
        final videos = await _likeService.getUserLikedVideos(userId);
        
        if (mounted) {
          setState(() {
            _likedVideos = videos;
            _isLoadingLikedVideos = false;
          });
          print('Loaded ${videos.length} liked videos');
        }
      } catch (e) {
        print('Error loading liked videos: $e');
        if (mounted) {
          setState(() {
            _likedVideos = [];
            _isLoadingLikedVideos = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _likedVideos = [];
          _isLoadingLikedVideos = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLikedVideos) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_likedVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color: _themeService.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.get('no_liked_videos'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _localeService.get('like_videos_hint'),
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLikedVideos,
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0,
        ),
        itemCount: _likedVideos.length,
        itemBuilder: (context, index) {
          final video = _likedVideos[index];
          
          final thumbnailUrl = video['thumbnailUrl'] != null
              ? _videoService.getVideoUrl(video['thumbnailUrl'])
              : null;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoDetailScreen(
                    videos: _likedVideos,
                    initialIndex: index,
                    screenTitle: _localeService.get('liked_videos'),
                    onVideoDeleted: () {
                      // Refresh the liked videos list
                      _loadLikedVideos();
                    },
                  ),
                ),
              ).then((_) {
                // Refresh videos to update counts
                _loadLikedVideos();
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
                    
                    // Dark gradient overlay from top to bottom (smooth fade)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.75),
                                Colors.black.withOpacity(0.4),
                                Colors.black.withOpacity(0.15),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.35, 0.65, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // View count overlay (no heart icon for liked grid)
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
