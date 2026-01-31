import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:scalable_short_video_app/src/services/video_playback_service.dart';
import 'web_video_player_stub.dart'
    if (dart.library.html) 'web_video_player.dart';

class HLSVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool isTabVisible; // Whether the parent tab is currently visible
  final ValueChanged<HLSVideoPlayerState?>? onPlayerCreated;
  final int tabIndex; // Tab index for saving state (0=Following, 1=Friends, 2=ForYou)
  final String videoId; // Video ID for saving state
  final Duration? initialPosition; // Initial position to seek to
  final String? thumbnailUrl; // Thumbnail to show while loading

  const HLSVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.isTabVisible = true,
    this.onPlayerCreated,
    this.tabIndex = 2,
    this.videoId = '',
    this.initialPosition,
    this.thumbnailUrl,
  });

  @override
  State<HLSVideoPlayer> createState() => HLSVideoPlayerState();
}

// Export state class so it can be accessed from outside
class HLSVideoPlayerState extends State<HLSVideoPlayer> with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  final VideoPlaybackService _playbackService = VideoPlaybackService();
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isMuted = false;
  bool _isFullscreen = false;
  bool _isDisposed = false;
  bool _hasRestoredPosition = false; // Track if we've already restored position

  @override
  bool get wantKeepAlive => true; // Keep state alive when switching tabs
  
  /// Get current playback position
  Duration get currentPosition => _controller?.value.position ?? Duration.zero;
  
  /// Check if video is currently playing
  bool get isPlaying => _controller?.value.isPlaying ?? false;

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
    // Notify parent about player state creation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPlayerCreated?.call(this);
    });
  }

  // Public methods to control video from outside
  void pauseVideo() {
    _controller?.pause();
  }
  
  void resumeVideo() {
    if (_isInitialized && !(_controller?.value.isPlaying ?? false)) {
      // Ensure volume is restored when resuming
      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
      _controller?.play();
    }
  }

  Future<void> _initializePlayer() async {
    if (_isDisposed) return;
    
    try {
      // Dispose previous controller if exists
      await _controller?.dispose();
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true, // Allow audio mixing to prevent audio conflicts
          allowBackgroundPlayback: false,
        ),
      );

      // Add error listener
      _controller?.addListener(_videoListener);

      await _controller?.initialize();
      
      if (!_isDisposed && mounted) {
        // Ensure volume is set to 1.0 (not muted) after initialization
        await _controller?.setVolume(1.0);
        _isMuted = false;
        
        setState(() {
          _isInitialized = true;
        });

        // Restore position if we have initial position or saved state
        if (!_hasRestoredPosition) {
          Duration? positionToRestore;
          bool? wasManuallyPaused;
          
          // Check for initial position passed directly
          if (widget.initialPosition != null && widget.initialPosition!.inMilliseconds > 0) {
            positionToRestore = widget.initialPosition;
            print('HLSVideoPlayer: Restoring from initialPosition: $positionToRestore');
          } else if (widget.videoId.isNotEmpty) {
            // Check for saved state in VideoPlaybackService
            final savedState = _playbackService.getVideoState(widget.tabIndex, widget.videoId);
            if (savedState != null) {
              positionToRestore = savedState.position;
              wasManuallyPaused = savedState.wasManuallyPaused;
              print('HLSVideoPlayer: Restoring from saved state: position=$positionToRestore, paused=$wasManuallyPaused');
            }
          }
          
          if (positionToRestore != null && positionToRestore.inMilliseconds > 0) {
            await _controller?.seekTo(positionToRestore);
            print('HLSVideoPlayer: Seeked to position $positionToRestore');
          }
          
          // Update manual pause state if we have it from saved state
          if (wasManuallyPaused != null) {
            _playbackService.setManuallyPaused(wasManuallyPaused);
          }
          
          _hasRestoredPosition = true;
        }

        // Only auto-play if autoPlay is true AND tab is visible AND not manually paused
        if (widget.autoPlay && widget.isTabVisible && !_playbackService.wasManuallyPaused) {
          await _controller?.play();
          await _controller?.setLooping(true);
        } else if (_playbackService.wasManuallyPaused) {
          print('HLSVideoPlayer: Not auto-playing because video was manually paused');
          await _controller?.setLooping(true);
        }
      }

    } catch (e) {
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
    // Save video state before disposing
    if (_isInitialized && widget.videoId.isNotEmpty && _controller != null) {
      final position = _controller!.value.position;
      final isPaused = !_controller!.value.isPlaying;
      _playbackService.saveVideoState(widget.tabIndex, widget.videoId, position, isPaused);
      print('HLSVideoPlayer: Saved state on dispose - position=$position, paused=$isPaused');
    }
    
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
      // Resume video ONLY if autoPlay is true AND tab is visible AND user didn't manually pause
      if (widget.autoPlay && widget.isTabVisible && mounted && !_playbackService.wasManuallyPaused) {
        _controller?.play();
      }
    }
  }

  @override
  void didUpdateWidget(HLSVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    final isTabVisibleChanged = widget.isTabVisible != oldWidget.isTabVisible;
    final autoPlayChanged = widget.autoPlay != oldWidget.autoPlay;
    
    print('HLSVideoPlayer.didUpdateWidget: isTabVisibleChanged=$isTabVisibleChanged, autoPlayChanged=$autoPlayChanged');
    print('HLSVideoPlayer.didUpdateWidget: isTabVisible=${widget.isTabVisible}, autoPlay=${widget.autoPlay}, wasManuallyPaused=${_playbackService.wasManuallyPaused}');
    
    // CASE 1: Tab visibility changed (switching tabs in bottom nav)
    // This takes priority - we handle the visibility change and return
    if (isTabVisibleChanged) {
      if (!widget.isTabVisible) {
        // Tab became invisible - pause immediately but DON'T change manual pause state
        _controller?.pause();
        print('HLSVideoPlayer: Video paused (tab became invisible)');
      } else {
        // Tab became visible - only resume if not manually paused
        if (widget.autoPlay && !_playbackService.wasManuallyPaused) {
          _controller?.setVolume(_isMuted ? 0.0 : 1.0);
          _controller?.play();
          print('HLSVideoPlayer: Video resumed (tab became visible, not manually paused)');
        } else if (_playbackService.wasManuallyPaused) {
          print('HLSVideoPlayer: Video NOT resumed (was manually paused by user)');
        }
      }
      // Don't process autoPlay changes if tab visibility changed
      // because the autoPlay change is just a side effect of setState rebuild
      return;
    }
    
    // CASE 2: Only autoPlay changed (swiping between videos within same tab)
    // This happens when user swipes to a different video while staying on the same tab
    if (autoPlayChanged && !isTabVisibleChanged) {
      if (widget.autoPlay && widget.isTabVisible) {
        // Swiping to a new video - reset manual pause state and play
        _playbackService.resetManualPauseState();
        _controller?.setVolume(_isMuted ? 0.0 : 1.0);
        _controller?.play();
        _controller?.setLooping(true);
        print('HLSVideoPlayer: Video started playing (swiped to this video, reset manual pause)');
      } else {
        // Pause when scrolling away
        _controller?.pause();
        print('HLSVideoPlayer: Video paused (scrolled away)');
      }
    }
  }

  void _togglePlayPause() {
    if (_isDisposed || _controller == null) return;
    
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _playbackService.setManuallyPaused(true); // Track manual pause
        print('HLSVideoPlayer: User manually paused video');
      } else {
        _controller!.play();
        _playbackService.setManuallyPaused(false); // User manually resumed
        print('HLSVideoPlayer: User manually resumed video');
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
      // Simple loading state: black screen with centered spinner (no thumbnail)
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
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 30,
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


