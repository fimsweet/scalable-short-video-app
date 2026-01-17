import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'dart:js' as js;

class WebVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const WebVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<WebVideoPlayer> {
  final String _viewId = 'video-player-${DateTime.now().millisecondsSinceEpoch}';
  bool _isPlaying = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _registerVideoPlayer();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    // Control video playback via JavaScript
    js.context.callMethod('eval', ['''
      (function() {
        var video = document.getElementById('video-$_viewId');
        if (video) {
          if ($_isPlaying) {
            video.play();
          } else {
            video.pause();
          }
        }
      })();
    ''']);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    
    // Control video mute via JavaScript
    js.context.callMethod('eval', ['''
      (function() {
        var video = document.getElementById('video-$_viewId');
        if (video) {
          video.muted = $_isMuted;
        }
      })();
    ''']);
  }

  void _registerVideoPlayer() {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final container = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.position = 'relative';

      // Load HLS.js script
      final script = html.ScriptElement()
        ..src = 'https://cdn.jsdelivr.net/npm/hls.js@latest'
        ..async = true;
      
      container.append(script);
      
      // Create video element
      final video = html.VideoElement()
        ..id = 'video-$_viewId'
        ..autoplay = true
        ..loop = true
        ..controls = false
        ..muted = false
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover' // TikTok-style: cover entire screen
        ..style.cursor = 'pointer';
      
      // Add click handler to video - but ignore clicks in the top 100px where Flutter tab bar is
      video.onClick.listen((event) {
        // Get click Y position relative to video
        final clickY = event.client.y;
        // Only toggle play if click is not in the top 100px (tab bar area)
        if (clickY > 100) {
          _togglePlayPause();
        } else {
          // Prevent default and stop propagation for tab bar area clicks
          event.preventDefault();
          event.stopPropagation();
        }
      });
      
      container.append(video);
      
      // Add a transparent overlay at top to block HTML video from receiving clicks there
      // This overlay has pointer-events: none so Flutter widgets can receive the events
      final topOverlay = html.DivElement()
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        ..style.right = '0'
        ..style.width = '100%'
        ..style.height = '100px' // Height for tab bar area
        ..style.pointerEvents = 'none' // Allow events to pass through to Flutter
        ..style.zIndex = '999';
      
      container.append(topOverlay);

      script.onLoad.listen((_) {
        // Use HLS.js
        js.context.callMethod('eval', ['''
          (function() {
            var video = document.getElementById('video-$_viewId');
            
            if (Hls.isSupported()) {
              var hls = new Hls({
                debug: false,
                enableWorker: true,
              });
              
              hls.loadSource('${widget.videoUrl}');
              hls.attachMedia(video);
              
              hls.on(Hls.Events.MANIFEST_PARSED, function() {
                video.play().catch(function(e) {
                  // Silently ignore autoplay errors
                });
              });
            } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
              video.src = '${widget.videoUrl}';
              video.play().catch(function(e) {
                // Silently ignore autoplay errors
              });
            }
          })();
        ''']);
      });

      return container;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HtmlElementView(viewType: _viewId),
        
        // IMPORTANT: Add a transparent hit area at top to capture events for Flutter widgets above
        // This blocks HTML video from capturing clicks in the tab bar area
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {
              // Do nothing - just block video from receiving tap
              // The Flutter widgets on top (FeedTabBar) will handle their own taps
            },
            behavior: HitTestBehavior.translucent,
            child: Container(
              height: 100, // Height for tab bar area
              color: Colors.transparent,
            ),
          ),
        ),
        
        // Top gradient overlay
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
        
        // Bottom gradient overlay
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
        if (!_isPlaying)
          IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Icon(
                  Icons.play_arrow,
                  size: 80,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ),
      ],
    );
  }
}