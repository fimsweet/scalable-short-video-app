import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

class _HLSVideoPlayerState extends State<HLSVideoPlayer> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isMuted = false;
  bool _isFullscreen = false;
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => false; // Don't keep state alive

  // Check if video needs fullscreen button (has black bars)
  bool get _needsFullscreenButton {
    if (!_isInitialized) return false;
    
    final videoAspect = _controller!.value.aspectRatio;
    const targetAspect = 9 / 16; // Portrait mode (0.5625)
    
    // Show fullscreen button if video aspect ratio differs significantly from 9:16
    // Allow small tolerance (±0.05) for rounding errors
    return (videoAspect - targetAspect).abs() > 0.05;
  }

  bool get _isPortraitVideo {
    if (!_isInitialized) return true;
    final videoAspect = _controller!.value.aspectRatio;
    // Video is portrait if aspect ratio is close to or less than 9:16
    return videoAspect <= (9 / 16 + 0.1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (_isDisposed) return;
    
    try {
      print('🎬 Initializing HLS player for: ${widget.videoUrl}');
      
      // Dispose previous controller if exists
      await _controller?.dispose();
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );

      // Add error listener
      _controller?.addListener(_videoListener);

      await _controller?.initialize();
      
      if (!_isDisposed && mounted) {
        setState(() {
          _isInitialized = true;
        });

        if (widget.autoPlay) {
          await _controller?.play();
          await _controller?.setLooping(true);
        }
      }

      print('✅ HLS player initialized successfully');
    } catch (e) {
      print('❌ Error initializing video player: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _videoListener() {
    if (_controller?.value.hasError ?? false) {
      print('❌ Video player error: ${_controller?.value.errorDescription}');
      if (!_isDisposed && mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = _controller?.value.errorDescription ?? 'Unknown error';
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    
    // Reset orientation when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Properly cleanup video controller
    _controller?.removeListener(_videoListener);
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (_controller == null) return;
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Pause video when app goes to background
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      // Resume video when app comes back if it was playing
      if (widget.autoPlay && mounted) {
        _controller?.play();
      }
    }
  }

  @override
  void didUpdateWidget(HLSVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Handle autoPlay changes (when swiping between videos or switching tabs)
    if (widget.autoPlay != oldWidget.autoPlay) {
      if (widget.autoPlay) {
        _controller?.play();
      } else {
        _controller?.pause();
      }
    }
  }

  void _togglePlayPause() {
    if (_isDisposed || _controller == null) return;
    
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
  }

  void _toggleMute() {
    if (_isDisposed || _controller == null) return;
    
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    
    if (_isFullscreen) {
      // Enter fullscreen - landscape mode
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // Exit fullscreen - portrait mode
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
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

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate video display height based on aspect ratio
    final videoAspect = _controller!.value.aspectRatio;
    final videoDisplayHeight = screenWidth / videoAspect;

    return Stack(
      children: [
        // Video player - Smart display based on aspect ratio
        GestureDetector(
          onTap: _togglePlayPause,
          behavior: HitTestBehavior.opaque,
          child: _isPortraitVideo
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover, // Portrait: Cover entire screen like TikTok
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              : Container(
                  color: Colors.black, // Landscape: Black background for letterboxing
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
        ),
        
        // Top gradient overlay (dark to transparent)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Bottom gradient overlay (transparent to dark)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Play icon overlay
        if (!_controller!.value.isPlaying)
          IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Icon(
                  Icons.play_arrow,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        
        // Back button (top-left) - ONLY in fullscreen
        if (_isFullscreen)
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: GestureDetector(
                onTap: _toggleFullscreen,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        
        // Mute button (top-right)
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 40), // Giảm từ 40 xuống 8 để sát trên cùng
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Fullscreen button (just below video, in black bar) - TikTok style
        if (_needsFullscreenButton)
          Positioned(
            top: (screenHeight - videoDisplayHeight) / 2 + videoDisplayHeight + 8,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _toggleFullscreen,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isFullscreen ? 'Thoát' : 'Toàn màn hình',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        
        // Video progress bar (at the very bottom)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: VideoProgressIndicator(
            _controller!,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white30,
              backgroundColor: Colors.white10,
            ),
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
          ),
        ),
      ],
    );
  }
}


