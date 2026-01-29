import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

/// Service for tracking video analytics and engagement metrics
class AnalyticsTrackingService {
  static final AnalyticsTrackingService _instance = AnalyticsTrackingService._internal();
  factory AnalyticsTrackingService() => _instance;
  AnalyticsTrackingService._internal();

  String get _baseUrl => AppConfig.videoServiceUrl;

  // Track video engagement events
  final Map<String, DateTime> _viewStartTimes = {};
  final Map<String, int> _watchDurations = {};
  final Set<String> _trackedViews = {};

  /// Start tracking when user begins watching a video
  void startWatching(String videoId) {
    _viewStartTimes[videoId] = DateTime.now();
    print('📊 Started tracking watch time for video: $videoId');
  }

  /// Stop tracking and calculate watch duration
  int stopWatching(String videoId) {
    final startTime = _viewStartTimes[videoId];
    if (startTime == null) return 0;

    final duration = DateTime.now().difference(startTime).inSeconds;
    _watchDurations[videoId] = (_watchDurations[videoId] ?? 0) + duration;
    _viewStartTimes.remove(videoId);

    print('📊 Stopped tracking video: $videoId, duration: ${duration}s, total: ${_watchDurations[videoId]}s');
    return duration;
  }

  /// Check if view should be counted (prevent duplicate views in same session)
  bool shouldCountView(String videoId) {
    if (_trackedViews.contains(videoId)) {
      return false;
    }
    _trackedViews.add(videoId);
    return true;
  }

  /// Reset tracked views (call when user logs out or app restarts)
  void resetTrackedViews() {
    _trackedViews.clear();
    _viewStartTimes.clear();
    _watchDurations.clear();
    print('📊 Analytics tracking reset');
  }

  /// Track video interaction (like, comment, share)
  Future<void> trackInteraction({
    required String videoId,
    required String userId,
    required InteractionType type,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/analytics/interaction'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'videoId': videoId,
          'userId': userId,
          'type': type.name,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('📊 Tracked ${type.name} interaction for video: $videoId');
      }
    } catch (e) {
      // Silent fail - don't disrupt user experience
      print('⚠️ Failed to track interaction: $e');
    }
  }

  /// Track video completion (user watched to end)
  Future<void> trackVideoCompletion({
    required String videoId,
    required String userId,
    required int watchDurationSeconds,
    required int videoDurationSeconds,
  }) async {
    try {
      final completionRate = videoDurationSeconds > 0
          ? (watchDurationSeconds / videoDurationSeconds * 100).clamp(0, 100)
          : 0;

      final response = await http.post(
        Uri.parse('$_baseUrl/analytics/completion'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'videoId': videoId,
          'userId': userId,
          'watchDuration': watchDurationSeconds,
          'videoDuration': videoDurationSeconds,
          'completionRate': completionRate.toDouble(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('📊 Tracked completion: ${completionRate.toStringAsFixed(1)}% for video: $videoId');
      }
    } catch (e) {
      // Silent fail
      print('⚠️ Failed to track completion: $e');
    }
  }

  /// Get watch duration for a video in current session
  int getWatchDuration(String videoId) {
    return _watchDurations[videoId] ?? 0;
  }

  /// Check if currently watching a video
  bool isWatching(String videoId) {
    return _viewStartTimes.containsKey(videoId);
  }
}

enum InteractionType {
  like,
  unlike,
  comment,
  share,
  save,
  unsave,
  follow,
  unfollow,
}
