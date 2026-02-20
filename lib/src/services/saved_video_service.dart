import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class SavedVideoService {
  static final SavedVideoService _instance = SavedVideoService._internal();
  factory SavedVideoService() => _instance;
  SavedVideoService._internal();

  String get _baseUrl => AppConfig.videoServiceUrl;

  /// In-memory caches: videoId → saved status / saveCount.
  /// Updated on every toggleSave / isSavedByUser response.
  /// Cleared on logout so stale state is never shown.
  static final Map<String, bool> _saveCache = {};
  static final Map<String, int> _saveCountCache = {};

  static void clearCache() {
    _saveCache.clear();
    _saveCountCache.clear();
    print('[SavedVideoService] Cache cleared');
  }

  bool? getCached(String videoId) => _saveCache[videoId];
  int? getCachedCount(String videoId) => _saveCountCache[videoId];

  Future<Map<String, dynamic>> toggleSave(String videoId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/saved-videos/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'videoId': videoId, 'userId': userId}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final result = json.decode(response.body);
        _saveCache[videoId] = result['saved'] == true;
        if (result['saveCount'] != null) {
          _saveCountCache[videoId] = (result['saveCount'] as num).toInt();
        }
        return result;
      }
      return {'saved': false};
    } catch (e) {
      print('Error toggling save: $e');
      return {'saved': false};
    }
  }

  Future<bool> isSavedByUser(String videoId, String userId) async {
    try {
      print('Check saved status: videoId=$videoId, userId=$userId');
      
      final url = '$_baseUrl/saved-videos/check/$videoId/$userId';
      print('Request URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('Check saved response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final saved = data['saved'] == true;
        _saveCache[videoId] = saved; // keep cache fresh
        print('isSavedByUser result: $saved');
        return saved;
      }
      
      print('Unexpected status code: ${response.statusCode}');
      return _saveCache[videoId] ?? false;
    } catch (e) {
      print('Error checking saved status: $e');
      return _saveCache[videoId] ?? false;
    }
  }

  Future<List<dynamic>> getSavedVideos(String userId) async {
    try {
      print('Fetching saved videos for user $userId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/saved-videos/user/$userId'),
      );

      print('Saved videos response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        print('Found ${data.length} saved videos');
        
        // Log để kiểm tra data structure
        if (data.isNotEmpty) {
          print('First saved video data: ${data[0]}');
          print('   Keys: ${data[0].keys.toList()}');
          print('   likeCount: ${data[0]['likeCount']}');
          print('   commentCount: ${data[0]['commentCount']}');
        }
        
        return data;
      }
      
      print('Failed to fetch saved videos: ${response.statusCode}');
      return [];
    } catch (e) {
      print('Error getting saved videos: $e');
      return [];
    }
  }
}
