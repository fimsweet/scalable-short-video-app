import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class LikeService {
  static final LikeService _instance = LikeService._internal();
  factory LikeService() => _instance;
  LikeService._internal();

  String get _baseUrl => AppConfig.videoServiceUrl;

  Future<Map<String, dynamic>> toggleLike(String videoId, String userId) async {
    try {
      print('📤 Toggle like request: videoId=$videoId, userId=$userId');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/likes/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'videoId': videoId, 'userId': userId}),
      );

      print('📥 Toggle like response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'liked': false, 'likeCount': 0};
    } catch (e) {
      print('❌ Error toggling like: $e');
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
      print('❌ Error getting like count: $e');
      return 0;
    }
  }

  Future<bool> isLikedByUser(String videoId, String userId) async {
    try {
      print('🔍 Check like status: videoId=$videoId, userId=$userId');
      
      final url = '$_baseUrl/likes/check/$videoId/$userId';
      print('📡 Request URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('📥 Check like response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final liked = data['liked'] ?? false;
        print('✅ isLikedByUser result: $liked');
        return liked;
      }
      
      print('⚠️ Unexpected status code: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error checking like: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getUserLikedVideos(String userId) async {
    try {
      print('📥 Fetching liked videos for user: $userId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/likes/user/$userId'),
      );

      print('📦 Liked videos response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ Found ${data.length} liked videos');
        return data.cast<Map<String, dynamic>>();
      }
      
      print('⚠️ Unexpected status code: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Error fetching liked videos: $e');
      return [];
    }
  }
}
