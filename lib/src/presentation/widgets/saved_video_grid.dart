import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/saved_video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
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
  
  List<dynamic> _savedVideos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedVideos();
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
      print('❌ Error loading saved videos: $e');
      if (mounted) {
        setState(() => _isLoading = false);
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

    if (_savedVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 80,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có video đã lưu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lưu video yêu thích để xem lại sau',
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
                  ),
                ),
              );
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
                    
                    // Bookmark indicator
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.bookmark,
                          size: 16,
                          color: Colors.white,
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
}
