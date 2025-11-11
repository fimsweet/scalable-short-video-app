import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class SavedVideoService {
  static final SavedVideoService _instance = SavedVideoService._internal();
  factory SavedVideoService() => _instance;
  SavedVideoService._internal();

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3002';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3002';
    } else {
      return 'http://localhost:3002';
    }
  }

  Future<Map<String, dynamic>> toggleSave(String videoId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/saved-videos/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'videoId': videoId, 'userId': userId}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'saved': false};
    } catch (e) {
      print('❌ Error toggling save: $e');
      return {'saved': false};
    }
  }

  Future<bool> isSavedByUser(String videoId, String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/saved-videos/check/$videoId/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['saved'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error checking saved status: $e');
      return false;
    }
  }

  Future<List<dynamic>> getSavedVideos(String userId) async {
    try {
      print('📥 Fetching saved videos for user $userId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/saved-videos/user/$userId'),
      );

      print('📥 Saved videos response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        print('✅ Found ${data.length} saved videos');
        
        // Log để kiểm tra data structure
        if (data.isNotEmpty) {
          print('📊 First saved video data: ${data[0]}');
          print('   Keys: ${data[0].keys.toList()}');
          print('   likeCount: ${data[0]['likeCount']}');
          print('   commentCount: ${data[0]['commentCount']}');
        }
        
        return data;
      }
      
      print('❌ Failed to fetch saved videos: ${response.statusCode}');
      return [];
    } catch (e) {
      print('❌ Error getting saved videos: $e');
      return [];
    }
  }
}
