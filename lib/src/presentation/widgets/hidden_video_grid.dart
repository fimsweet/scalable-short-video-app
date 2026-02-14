import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';

class HiddenVideoGrid extends StatefulWidget {
  const HiddenVideoGrid({super.key});

  @override
  State<HiddenVideoGrid> createState() => _HiddenVideoGridState();
}

class _HiddenVideoGridState extends State<HiddenVideoGrid> {
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  
  List<dynamic> _hiddenVideos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authService.addLogoutListener(_onLogout);
    _authService.addLoginListener(_onLogin);
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
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

  void _onThemeChanged() => mounted ? setState(() {}) : null;
  void _onLocaleChanged() => mounted ? setState(() {}) : null;

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
          _error = _localeService.isVietnamese
              ? 'Không thể tải video: $e'
              : 'Cannot load videos: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _authService.removeLogoutListener(_onLogout);
    _authService.removeLoginListener(_onLogin);
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: ThemeService.accentColor),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: _themeService.textPrimaryColor)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHiddenVideos,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeService.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_localeService.isVietnamese ? 'Thử lại' : 'Retry'),
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
              Icons.visibility_off_rounded,
              size: 80,
              color: _themeService.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _localeService.isVietnamese
                  ? 'Chưa có video đã ẩn'
                  : 'No hidden videos',
              style: TextStyle(
                color: _themeService.textPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _localeService.isVietnamese
                    ? 'Video bị ẩn sẽ không hiển thị trong feed của bất kỳ ai'
                    : 'Hidden videos won\'t appear in anyone\'s feed',
                style: TextStyle(
                  color: _themeService.textSecondaryColor,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHiddenVideos,
      color: ThemeService.accentColor,
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
                    screenTitle: _localeService.isVietnamese
                        ? 'Video đã ẩn'
                        : 'Hidden videos',
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
                color: _themeService.isLightMode ? Colors.grey[200] : Colors.grey[900],
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
                            color: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
                            child: Icon(
                              Icons.video_library_outlined,
                              size: 32,
                              color: _themeService.textSecondaryColor,
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: _themeService.isLightMode ? Colors.grey[300] : Colors.grey[800],
                        child: Icon(
                          Icons.video_library_outlined,
                          size: 32,
                          color: _themeService.textSecondaryColor,
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
                                Colors.black.withOpacity(0.5),
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Hidden icon indicator at top right
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
                          Icons.visibility_off_rounded,
                          size: 16,
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
