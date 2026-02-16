import 'package:flutter/material.dart';
import 'dart:async';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/processing_video_screen.dart';

class UserVideoGrid extends StatefulWidget {
  const UserVideoGrid({super.key});

  @override
  State<UserVideoGrid> createState() => _UserVideoGridState();
}

class _UserVideoGridState extends State<UserVideoGrid> {
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  final LocaleService _localeService = LocaleService();
  final ThemeService _themeService = ThemeService();
  
  List<dynamic> _videos = [];
  bool _isLoading = true;
  String? _error;
  
  // Auto-refresh for processing videos
  Timer? _processingRefreshTimer;
  static const _processingRefreshInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _loadUserVideos();
  }

  @override
  void dispose() {
    _stopProcessingRefreshTimer();
    super.dispose();
  }

  void _startProcessingRefreshTimer() {
    _stopProcessingRefreshTimer();
    _processingRefreshTimer = Timer.periodic(_processingRefreshInterval, (_) {
      _checkProcessingVideos();
    });
    print('Started auto-refresh timer for processing videos');
  }

  void _stopProcessingRefreshTimer() {
    _processingRefreshTimer?.cancel();
    _processingRefreshTimer = null;
    print('Stopped auto-refresh timer');
  }

  bool _hasProcessingVideos() {
    return _videos.any((v) => v['status'] != 'ready');
  }

  Future<void> _checkProcessingVideos() async {
    if (!mounted) return;
    
    // Only refresh if we still have processing videos
    if (!_hasProcessingVideos()) {
      _stopProcessingRefreshTimer();
      return;
    }

    try {
      final userId = _authService.user?['id'].toString();
      if (userId == null) return;
      
      final videos = await _videoService.getUserVideos(userId);
      
      // Filter hidden videos
      final allVideos = videos.where((v) => v != null && v['isHidden'] != true).toList();
      
      if (mounted) {
        // Check if any video changed status from processing to ready
        final oldProcessingCount = _videos.where((v) => v['status'] != 'ready').length;
        final newProcessingCount = allVideos.where((v) => v['status'] != 'ready').length;
        
        if (newProcessingCount < oldProcessingCount) {
          print('${oldProcessingCount - newProcessingCount} video(s) finished processing!');
        }
        
        setState(() {
          _videos = allVideos;
        });
        
        // Stop timer if no more processing videos
        if (!_hasProcessingVideos()) {
          _stopProcessingRefreshTimer();
        }
      }
    } catch (e) {
      print('Error checking processing videos: $e');
    }
  }

  Future<void> _loadUserVideos() async {
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
      
      // Debug: Log all videos data including status
      print('UserVideoGrid: Loaded ${videos.length} videos from backend');
      for (var i = 0; i < videos.length; i++) {
        final video = videos[i];
        print('   Video $i: ID=${video['id']}, status=${video['status']}, isHidden=${video['isHidden']}');
      }
      
      // Show only non-hidden videos (include all statuses including processing)
      final allVideos = videos.where((v) => v != null && v['isHidden'] != true).toList();
      print('UserVideoGrid: ${allVideos.length} videos after filtering hidden');

      if (mounted) {
        setState(() {
          _videos = allVideos;
          _isLoading = false;
        });
        
        // Start auto-refresh timer if there are processing videos
        if (_hasProcessingVideos()) {
          _startProcessingRefreshTimer();
        } else {
          _stopProcessingRefreshTimer();
        }
      }
    } catch (e) {
      print('Error loading user videos: $e');
      if (mounted) {
        setState(() {
          _error = _localeService.get('cannot_load_videos');
          _isLoading = false;
        });
      }
    }
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
              onPressed: _loadUserVideos,
              child: Text(_localeService.get('retry')),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 80,
              color: _themeService.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.get('no_posts_yet'),
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _localeService.get('post_your_first_video'),
              style: TextStyle(
                color: _themeService.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadUserVideos,
          child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0, // Square tiles (1:1 ratio)
        ),
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          final video = _videos[index];
          final isProcessing = video['status'] != 'ready';
          final isFailed = video['status'] == 'failed';
          
          final thumbnailUrl = video['thumbnailUrl'] != null
              ? _videoService.getVideoUrl(video['thumbnailUrl'])
              : null;

          final isHidden = video['isHidden'] == true;

          return GestureDetector(
            onTap: isProcessing ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProcessingVideoScreen(
                    video: video,
                    onVideoReady: () => _loadUserVideos(),
                  ),
                ),
              ).then((_) => _loadUserVideos());
            } : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoDetailScreen(
                    videos: _videos.where((v) => v['status'] == 'ready').toList(),
                    initialIndex: _videos.where((v) => v['status'] == 'ready').toList().indexOf(video),
                    screenTitle: _localeService.get('posted_videos'),
                    onVideoDeleted: () {
                      // Refresh the videos list
                      _loadUserVideos();
                    },
                  ),
                ),
              ).then((_) {
                // Refresh videos to update view counts
                _loadUserVideos();
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(0), // No rounded corners for cleaner grid
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail
                    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
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
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }
                          return Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(
                            Icons.video_library_outlined,
                            size: 32,
                            color: Colors.white54,
                          ),
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
                    
                    // Hidden overlay (full screen semi-transparent)
                    if (isHidden && !isProcessing)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.6),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.visibility_off_rounded,
                                  size: 32,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _localeService.get('hidden'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    // Visibility indicator (top-right) for private/friends-only videos
                    if (!isProcessing && !isHidden && (video['visibility'] == 'private' || video['visibility'] == 'friends'))
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            video['visibility'] == 'private' 
                                ? Icons.lock_rounded 
                                : Icons.people_rounded,
                            size: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    
                    // Processing/Failed overlay or view count
                    if (isProcessing)
                      Positioned.fill(
                        child: Container(
                          color: isFailed
                              ? Colors.black.withOpacity(0.75)
                              : Colors.black.withOpacity(0.7),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isFailed) ...[
                                Icon(
                                  Icons.error_outline,
                                  size: 28,
                                  color: Colors.redAccent.withOpacity(0.9),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _localeService.get('failed'),
                                  style: TextStyle(
                                    color: Colors.redAccent.withOpacity(0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _localeService.get('tap_to_retry'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 9,
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _localeService.get('processing'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    else
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
        ),
      ],
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
