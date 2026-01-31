import 'package:flutter/foundation.dart';

/// State for a specific video in a tab
class VideoState {
  final Duration position;
  final bool wasManuallyPaused;
  
  VideoState({required this.position, required this.wasManuallyPaused});
  
  @override
  String toString() => 'VideoState(position: $position, paused: $wasManuallyPaused)';
}

/// Singleton service to manage video playback state across the app.
/// This allows different screens to control video playback without using GlobalKeys.
class VideoPlaybackService extends ChangeNotifier {
  static final VideoPlaybackService _instance = VideoPlaybackService._internal();
  factory VideoPlaybackService() => _instance;
  VideoPlaybackService._internal();

  bool _isVideoTabVisible = true;
  
  // Track if user manually paused the video - PER TAB (tab index -> isPaused)
  final Map<int, bool> _wasManuallyPausedPerTab = {};
  
  // Current active tab index for global pause state check
  int _currentTabIndex = 2; // Default to For You tab
  
  // Store video playback state per tab and video
  // Key format: "tab_videoId" e.g. "2_abc123"
  final Map<String, VideoState> _videoStates = {};
  
  /// Whether the video tab is currently visible
  bool get isVideoTabVisible => _isVideoTabVisible;
  
  /// Whether the user manually paused the video (for current tab)
  bool get wasManuallyPaused => _wasManuallyPausedPerTab[_currentTabIndex] ?? false;
  
  /// Set current tab index (call when switching tabs)
  void setCurrentTabIndex(int tabIndex) {
    _currentTabIndex = tabIndex;
    print('VideoPlaybackService: Current tab changed to $tabIndex');
  }

  /// Set manually paused state FOR CURRENT TAB (call when user taps to pause)
  void setManuallyPaused(bool value) {
    final currentValue = _wasManuallyPausedPerTab[_currentTabIndex] ?? false;
    if (currentValue != value) {
      _wasManuallyPausedPerTab[_currentTabIndex] = value;
      print('VideoPlaybackService: Manual pause state for tab $_currentTabIndex changed to $value');
    }
  }
  
  /// Set manually paused state for a SPECIFIC TAB
  void setManuallyPausedForTab(int tabIndex, bool value) {
    final currentValue = _wasManuallyPausedPerTab[tabIndex] ?? false;
    if (currentValue != value) {
      _wasManuallyPausedPerTab[tabIndex] = value;
      print('VideoPlaybackService: Manual pause state for tab $tabIndex changed to $value');
    }
  }
  
  /// Get manually paused state for a SPECIFIC TAB
  bool wasManuallyPausedForTab(int tabIndex) {
    return _wasManuallyPausedPerTab[tabIndex] ?? false;
  }

  /// Call when video tab becomes visible
  void setVideoTabVisible() {
    if (!_isVideoTabVisible) {
      _isVideoTabVisible = true;
      print('VideoPlaybackService: Video tab became visible (wasManuallyPaused for tab $_currentTabIndex = $wasManuallyPaused)');
      notifyListeners();
    }
  }

  /// Call when video tab becomes invisible
  void setVideoTabInvisible() {
    if (_isVideoTabVisible) {
      _isVideoTabVisible = false;
      print('VideoPlaybackService: Video tab became invisible (wasManuallyPaused for tab $_currentTabIndex = $wasManuallyPaused)');
      notifyListeners();
    }
  }
  
  /// Reset manual pause state FOR CURRENT TAB (call when switching to a new video)
  void resetManualPauseState() {
    if (_wasManuallyPausedPerTab[_currentTabIndex] == true) {
      print('VideoPlaybackService: Resetting manual pause state for tab $_currentTabIndex (was true)');
      _wasManuallyPausedPerTab[_currentTabIndex] = false;
    }
  }
  
  /// Save video state for a specific tab and video
  void saveVideoState(int tabIndex, String videoId, Duration position, bool isPaused) {
    final key = '${tabIndex}_$videoId';
    _videoStates[key] = VideoState(position: position, wasManuallyPaused: isPaused);
    print('VideoPlaybackService: Saved state for $key: position=$position, paused=$isPaused');
  }
  
  /// Get saved video state for a specific tab and video
  VideoState? getVideoState(int tabIndex, String videoId) {
    final key = '${tabIndex}_$videoId';
    final state = _videoStates[key];
    if (state != null) {
      print('VideoPlaybackService: Retrieved state for $key: $state');
    }
    return state;
  }
  
  /// Clear all video states (call on logout or refresh)
  void clearAllVideoStates() {
    _videoStates.clear();
    print('VideoPlaybackService: Cleared all video states');
  }
  
  /// Clear video states for a specific tab
  void clearTabVideoStates(int tabIndex) {
    _videoStates.removeWhere((key, _) => key.startsWith('${tabIndex}_'));
    print('VideoPlaybackService: Cleared video states for tab $tabIndex');
  }
}
