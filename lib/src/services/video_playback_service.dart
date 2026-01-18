import 'package:flutter/foundation.dart';

/// Singleton service to manage video playback state across the app.
/// This allows different screens to control video playback without using GlobalKeys.
class VideoPlaybackService extends ChangeNotifier {
  static final VideoPlaybackService _instance = VideoPlaybackService._internal();
  factory VideoPlaybackService() => _instance;
  VideoPlaybackService._internal();

  bool _isVideoTabVisible = true;
  
  /// Whether the video tab is currently visible
  bool get isVideoTabVisible => _isVideoTabVisible;

  /// Call when video tab becomes visible
  void setVideoTabVisible() {
    if (!_isVideoTabVisible) {
      _isVideoTabVisible = true;
      print('🎬 VideoPlaybackService: Video tab became visible');
      notifyListeners();
    }
  }

  /// Call when video tab becomes invisible
  void setVideoTabInvisible() {
    if (_isVideoTabVisible) {
      _isVideoTabVisible = false;
      print('⏸️ VideoPlaybackService: Video tab became invisible');
      notifyListeners();
    }
  }
}
