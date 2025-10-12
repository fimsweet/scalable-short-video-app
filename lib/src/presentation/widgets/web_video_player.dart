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
        ..style.objectFit = 'cover'
        ..style.cursor = 'pointer';
      
      // Add click handler to video
      video.onClick.listen((event) {
        _togglePlayPause();
      });
      
      container.append(video);

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
                  console.log('Play failed:', e);
                });
              });
            } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
              video.src = '${widget.videoUrl}';
              video.play();
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
        // Show play icon overlay when paused (triangle only)
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
        // Mute/Unmute button (top-right corner) - FIXED
        Positioned(
          top: 12,
          right: 12,
          child: SafeArea(
            child: GestureDetector(
              onTap: _toggleMute, // Chỉ gọi hàm toggleMute
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
      ],
    );
  }
}