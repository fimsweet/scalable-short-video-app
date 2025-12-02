import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3002';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3002';
    } else {
      return 'http://localhost:3002';
    }
  }

  Future<Map<String, dynamic>> shareVideo(
    String videoId,
    String sharerId,
    String recipientId,
  ) async {
    try {
      print('📤 Sharing video: videoId=$videoId, sharerId=$sharerId, recipientId=$recipientId');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/shares'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'videoId': videoId,
          'sharerId': sharerId,
          'recipientId': recipientId,
        }),
      );

      print('📥 Share response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'shareCount': data['shareCount'] ?? 0,
        };
      }
      
      return {'success': false, 'shareCount': 0};
    } catch (e) {
      print('❌ Error in shareVideo: $e');
      return {'success': false, 'shareCount': 0};
    }
  }

  Future<int> getShareCount(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/shares/count/$videoId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ Error getting share count: $e');
      return 0;
    }
  }
}
