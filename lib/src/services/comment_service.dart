import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class CommentService {
  static final CommentService _instance = CommentService._internal();
  factory CommentService() => _instance;
  CommentService._internal();

  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3002';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3002';
    } else {
      return 'http://localhost:3002';
    }
  }

  Future<Map<String, dynamic>?> createComment(String videoId, String userId, String content) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/comments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'videoId': videoId,
          'userId': userId,
          'content': content,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error creating comment: $e');
      return null;
    }
  }

  Future<List<dynamic>> getCommentsByVideo(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/comments/video/$videoId'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('❌ Error getting comments: $e');
      return [];
    }
  }

  Future<int> getCommentCount(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/comments/count/$videoId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ Error getting comment count: $e');
      return 0;
    }
  }

  Future<bool> deleteComment(String commentId, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/comments/$commentId/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting comment: $e');
      return false;
    }
  }
}
