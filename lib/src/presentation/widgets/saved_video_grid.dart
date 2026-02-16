import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/saved_video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';

class SavedVideoGrid extends StatefulWidget {
  const SavedVideoGrid({super.key});

  @override
  State<SavedVideoGrid> createState() => _SavedVideoGridState();
}

class _SavedVideoGridState extends State<SavedVideoGrid> {
  final SavedVideoService _savedVideoService = SavedVideoService();
  final AuthService _authService = AuthService();
  final VideoService _videoService = VideoService();
  final LocaleService _localeService = LocaleService();
  final ThemeService _themeService = ThemeService();
  
  List<dynamic> _savedVideos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _authService.addLogoutListener(_onLogout);
    _authService.addLoginListener(_onLogin);
    _loadSavedVideos();
  }

  void _onLogin() {
    print('SavedVideoGrid: Login event - loading saved videos');
    _loadSavedVideos();
  }

  void _onLogout() {
    print('SavedVideoGrid: Logout event - clearing saved videos');
    if (mounted) {
      setState(() {
        _savedVideos = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSavedVideos() async {
    if (!_authService.isLoggedIn || _authService.user == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _authService.user!['id'].toString();
      final videos = await _savedVideoService.getSavedVideos(userId);

      if (mounted) {
        setState(() {
          _savedVideos = videos;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading saved videos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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

    if (_savedVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 80,
              color: _themeService.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.get('no_saved_videos'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _localeService.get('save_videos_hint'),
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
      onRefresh: _loadSavedVideos,
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0,
        ),
        itemCount: _savedVideos.length,
        itemBuilder: (context, index) {
          final video = _savedVideos[index];
          
          final thumbnailUrl = video['thumbnailUrl'] != null
              ? _videoService.getVideoUrl(video['thumbnailUrl'])
              : null;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoDetailScreen(
                    videos: _savedVideos,
                    initialIndex: index,
                    screenTitle: _localeService.get('saved_videos'),
                  ),
                ),
              ).then((_) {
                // Refresh videos to update view counts
                _loadSavedVideos();
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
                    
                    // Bookmark indicator
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.bookmark,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    
                    // View count overlay
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
