import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'web_video_player_stub.dart'
    if (dart.library.html) 'web_video_player.dart';

class HLSVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;

  const HLSVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
  });

  @override
  State<HLSVideoPlayer> createState() => _HLSVideoPlayerState();
}

class _HLSVideoPlayerState extends State<HLSVideoPlayer> with WidgetsBindingObserver {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      print('🎬 Initializing HLS player for: ${widget.videoUrl}');
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _controller.initialize();
      
      setState(() {
        _isInitialized = true;
      });

      if (widget.autoPlay) {
        _controller.play();
        _controller.setLooping(true);
      }

      print('✅ HLS player initialized successfully');
    } catch (e) {
      print('❌ Error initializing video player: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause video when app goes to background or user navigates away
    if (state == AppLifecycleState.paused || 
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (_isInitialized && _controller.value.isPlaying) {
        _controller.pause();
      }
    }
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use web-specific player for web platform
    if (kIsWeb) {
      return WebVideoPlayer(videoUrl: widget.videoUrl);
    }
    
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Không thể phát video',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: Stack(
              children: [
                VideoPlayer(_controller),
                // Play/Pause overlay with better styling
                if (!_controller.value.isPlaying)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
