import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class LikeService {
  static final LikeService _instance = LikeService._internal();
  factory LikeService() => _instance;
  LikeService._internal();

  String get _baseUrl => AppConfig.videoServiceUrl;

  /// Notifier that increments whenever a like is toggled.
  /// Listeners (e.g. profile screen) can react by refreshing received-likes
  /// count so the UI stays in sync – TikTok-style real-time update.
  static final ValueNotifier<int> likeChangeNotifier = ValueNotifier<int>(0);

  /// In-memory cache: videoId → isLiked.
  /// Updated on every toggleLike / isLikedByUser API response.
  /// Cleared on logout so stale state is never shown for a new session.
  static final Map<String, bool> _likeCache = {};

  /// In-memory cache: videoId → likeCount.
  /// Updated on every toggleLike API response so re-entering a video
  /// immediately shows the correct count without waiting for a network call.
  static final Map<String, int> _likeCountCache = {};

  static void clearCache() {
    _likeCache.clear();
    _likeCountCache.clear();
    print('[LikeService] Cache cleared');
  }

  /// Returns the cached like status for [videoId], or null if unknown.
  bool? getCached(String videoId) => _likeCache[videoId];

  /// Returns the cached like count for [videoId], or null if unknown.
  int? getCachedCount(String videoId) => _likeCountCache[videoId];

  Future<Map<String, dynamic>> toggleLike(String videoId, String userId) async {
    try {
      print('Toggle like request: videoId=$videoId, userId=$userId');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/likes/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'videoId': videoId, 'userId': userId}),
      );

      print('Toggle like response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final result = json.decode(response.body);
        // Update caches so next screen open shows correct state immediately
        _likeCache[videoId] = result['liked'] == true;
        if (result['likeCount'] != null) {
          _likeCountCache[videoId] = (result['likeCount'] as num).toInt();
        }
        // Notify listeners (profile screen) to refresh received-likes count
        likeChangeNotifier.value++;
        return result;
      }
      return {'liked': false, 'likeCount': 0};
    } catch (e) {
      print('Error toggling like: $e');
      return {'liked': false, 'likeCount': 0};
    }
  }

  Future<int> getLikeCount(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/likes/count/$videoId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting like count: $e');
      return 0;
    }
  }

  Future<bool> isLikedByUser(String videoId, String userId) async {
    try {
      print('Check like status: videoId=$videoId, userId=$userId');
      
      final url = '$_baseUrl/likes/check/$videoId/$userId';
      print('Request URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('Check like response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final liked = data['liked'] == true;
        _likeCache[videoId] = liked; // keep cache fresh
        print('isLikedByUser result: $liked');
        return liked;
      }
      
      print('Unexpected status code: ${response.statusCode}');
      return _likeCache[videoId] ?? false; // fall back to cache on error
    } catch (e) {
      print('Error checking like: $e');
      return _likeCache[videoId] ?? false; // fall back to cache on timeout/error
    }
  }

  Future<List<Map<String, dynamic>>> getUserLikedVideos(String userId) async {
    try {
      print('Fetching liked videos for user: $userId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/likes/user/$userId'),
      );

      print('Liked videos response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Found ${data.length} liked videos');
        return data.cast<Map<String, dynamic>>();
      }
      
      print('Unexpected status code: ${response.statusCode}');
      return [];
    } catch (e) {
      print('Error fetching liked videos: $e');
      return [];
    }
  }

  /// Get total likes received by a user across all their videos
  Future<int> getTotalReceivedLikes(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/likes/received/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting total received likes: $e');
      return 0;
    }
  }
}
