import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';

/// Full-screen view for a video that is still being processed.
/// Shows processing progress with auto-refresh.
/// When processing completes, automatically transitions to video playback.
/// When processing fails, shows error state with retry button.
class ProcessingVideoScreen extends StatefulWidget {
  final Map<String, dynamic> video;
  final VoidCallback? onVideoReady;

  const ProcessingVideoScreen({
    super.key,
    required this.video,
    this.onVideoReady,
  });

  @override
  State<ProcessingVideoScreen> createState() => _ProcessingVideoScreenState();
}

class _ProcessingVideoScreenState extends State<ProcessingVideoScreen>
    with SingleTickerProviderStateMixin {
  final VideoService _videoService = VideoService();
  final AuthService _authService = AuthService();
  Timer? _pollTimer;
  Timer? _progressTimer;
  late Map<String, dynamic> _video;
  double _progress = 0.0;
  bool _isReady = false;
  bool _isFailed = false;
  bool _isRetrying = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _video = Map.from(widget.video);

    // Check initial status
    final status = _video['status']?.toString();
    if (status == 'failed') {
      _isFailed = true;
      _progress = 0.0;
    } else {
      _progress = _estimateProgress();
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (!_isFailed) {
      _startPolling();
    }
  }

  void _startPolling() {
    _stopPolling();

    // Update progress every second for smooth animation
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isReady && !_isFailed) {
        setState(() {
          _progress = _estimateProgress();
        });
      }
    });

    // Poll backend every 5 seconds to check if video is ready
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkVideoStatus();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _progressTimer?.cancel();
    _pollTimer = null;
    _progressTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    _pulseController.dispose();
    super.dispose();
  }

  double _estimateProgress() {
    final createdAtStr = _video['createdAt'];
    if (createdAtStr == null) return 0.0;

    final createdAt = DateTime.tryParse(createdAtStr.toString());
    if (createdAt == null) return 0.0;

    final elapsed = DateTime.now().difference(createdAt).inSeconds;
    final rawSize = _video['fileSize'];
    final fileSize = rawSize == null
        ? 0
        : (rawSize is int ? rawSize : int.tryParse(rawSize.toString()) ?? 0);

    double estimatedSeconds;
    if (fileSize < 5 * 1024 * 1024) {
      estimatedSeconds = 45;
    } else if (fileSize < 20 * 1024 * 1024) {
      estimatedSeconds = 90;
    } else if (fileSize < 50 * 1024 * 1024) {
      estimatedSeconds = 150;
    } else if (fileSize < 100 * 1024 * 1024) {
      estimatedSeconds = 240;
    } else {
      estimatedSeconds = 360;
    }

    return min(elapsed / estimatedSeconds, 0.95).clamp(0.0, 0.95);
  }

  String _getStageLabel(double progress) {
    if (progress < 0.05) return 'Đang chuẩn bị xử lý...';
    if (progress < 0.30) return 'Đang xử lý video...';
    if (progress < 0.55) return 'Đang tối ưu chất lượng...';
    if (progress < 0.75) return 'Đang hoàn thiện video...';
    if (progress < 0.85) return 'Đang tạo ảnh bìa...';
    if (progress < 0.95) return 'Sắp hoàn tất...';
    return 'Sắp hoàn tất...';
  }

  Future<void> _checkVideoStatus() async {
    if (!mounted || _isReady || _isFailed) return;

    try {
      final videoId = _video['id']?.toString();
      if (videoId == null) return;

      final updatedVideo = await _videoService.getVideoById(videoId);
      if (updatedVideo == null || !mounted) return;

      final status = updatedVideo['status']?.toString();

      if (status == 'ready') {
        setState(() {
          _video = updatedVideo;
          _isReady = true;
          _progress = 1.0;
        });

        _stopPolling();

        // Brief delay to show 100% then navigate to video playback
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        widget.onVideoReady?.call();

        // Replace this screen with VideoDetailScreen showing the ready video
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(
              videos: [_video],
              initialIndex: 0,
              screenTitle: 'Video đã đăng',
            ),
          ),
        );
      } else if (status == 'failed') {
        setState(() {
          _video = updatedVideo;
          _isFailed = true;
          _progress = 0.0;
        });
        _stopPolling();
      }
    } catch (e) {
      print('Error checking video status: $e');
    }
  }

  Future<void> _retryVideo() async {
    if (_isRetrying) return;

    final userId = _authService.user?['id']?.toString();
    final videoId = _video['id']?.toString();
    if (userId == null || videoId == null) return;

    setState(() {
      _isRetrying = true;
    });

    try {
      final result = await _videoService.retryVideo(
        videoId: videoId,
        userId: userId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _isFailed = false;
          _isRetrying = false;
          _progress = 0.0;
          _video['status'] = 'processing';
          _video['errorMessage'] = null;
        });
        // Restart polling for progress
        _startPolling();
      } else {
        setState(() {
          _isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Không thể thử lại. Vui lòng thử sau.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xảy ra lỗi. Vui lòng thử lại sau.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _video['title'] ?? 'Video';
    final percentText = _isFailed ? '!' : '${(_progress * 100).toStringAsFixed(0)}%';
    final stageLabel = _isFailed
        ? 'Xử lý thất bại'
        : (_isReady ? 'Hoàn tất!' : _getStageLabel(_progress));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background - thumbnail or dark gradient
          _buildBackground(),

          // Dark overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.85),
                    Colors.black.withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                ),

                // Center content - progress
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress ring or error icon
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background ring
                              SizedBox(
                                width: 140,
                                height: 140,
                                child: CircularProgressIndicator(
                                  value: 1.0,
                                  strokeWidth: 5,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _isFailed ? Colors.red.withOpacity(0.3) : Colors.grey[800]!,
                                  ),
                                ),
                              ),
                              // Progress ring (hidden when failed)
                              if (!_isFailed)
                                SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: _progress),
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOut,
                                    builder: (context, value, _) {
                                      return CircularProgressIndicator(
                                        value: value,
                                        strokeWidth: 5,
                                        strokeCap: StrokeCap.round,
                                        backgroundColor: Colors.transparent,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _isReady
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFF00BFA5),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              // Center icon/text
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isFailed)
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.redAccent,
                                      size: 48,
                                    )
                                  else
                                    Text(
                                      percentText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                  if (!_isReady && !_isFailed)
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) {
                                        return Opacity(
                                          opacity: 0.5 + _pulseController.value * 0.5,
                                          child: child,
                                        );
                                      },
                                      child: const Text(
                                        'đang xử lý',
                                        style: TextStyle(
                                          color: Color(0xFF00BFA5),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Stage label
                        Text(
                          stageLabel,
                          style: TextStyle(
                            color: _isFailed
                                ? Colors.redAccent
                                : (_isReady ? const Color(0xFF4CAF50) : Colors.grey[400]),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Info box or retry button
                        if (_isFailed) ...[
                          // Error message
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.15),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _video['errorMessage'] != null
                                      ? 'Lỗi: ${_video['errorMessage']}'
                                      : 'Video không thể xử lý được.\nBạn có thể thử lại.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Retry button
                          SizedBox(
                            width: 200,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isRetrying ? null : _retryVideo,
                              icon: _isRetrying
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.refresh, size: 20),
                              label: Text(
                                _isRetrying ? 'Đang gửi lại...' : 'Thử lại',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00BFA5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ] else
                          // Normal info box (processing or ready)
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _isReady ? Icons.check_circle_outline : Icons.info_outline,
                                  color: _isReady ? const Color(0xFF4CAF50) : Colors.grey[500],
                                  size: 20,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isReady
                                      ? 'Video đã sẵn sàng!'
                                      : 'Video đang được xử lý.\nBạn có thể quay lại sau.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    final thumbnailUrl = _video['thumbnailUrl'] != null
        ? _videoService.getVideoUrl(_video['thumbnailUrl'])
        : null;

    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return Positioned.fill(
        child: Image.network(
          thumbnailUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.black),
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[900]!,
              Colors.black,
            ],
          ),
        ),
      ),
    );
  }
}
