import 'package:flutter/material.dart';

/// Stub implementation for non-web platforms
/// This file is used when running on Android/iOS to avoid dart:html import errors
class WebVideoPlayer extends StatelessWidget {
  final String videoUrl;

  const WebVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  Widget build(BuildContext context) {
    // This should never be called on non-web platforms
    // because hls_video_player.dart checks kIsWeb first
    return const Center(
      child: Text('Web player not supported on this platform'),
    );
  }
}
