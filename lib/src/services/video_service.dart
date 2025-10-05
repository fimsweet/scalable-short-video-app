import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class VideoService {
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  // Use 10.0.2.2 for Android emulator, localhost for web/iOS
  String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3002';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3002';
    } else {
      return 'http://localhost:3002';
    }
  }

  String get _videoApiUrl => '$_baseUrl/videos';

  /// Upload video to video-service
  Future<Map<String, dynamic>> uploadVideo({
    required XFile videoFile,
    required String userId,
    required String title,
    String? description,
    required String token,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_videoApiUrl/upload'));
      
      // Add headers
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add video file - Use readAsBytes() for web compatibility
      final bytes = await videoFile.readAsBytes();
      
      // Detect MIME type from filename
      final mimeType = lookupMimeType(videoFile.name) ?? 'video/mp4';
      print('🎬 Detected MIME type: $mimeType');
      
      request.files.add(http.MultipartFile.fromBytes(
        'video',
        bytes,
        filename: videoFile.name,
        contentType: MediaType.parse(mimeType), // ← FIX: Add contentType
      ));
      
      // Add fields
      request.fields['userId'] = userId;
      request.fields['title'] = title;
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }
      
      print('📤 Uploading video to: $_videoApiUrl/upload');
      print('   File: ${videoFile.name}');
      print('   Size: ${bytes.length} bytes');
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('📥 Upload response: $responseBody');
      
      if (response.statusCode == 202) {
        return {
          'success': true,
          'data': json.decode(responseBody),
        };
      } else {
        return {
          'success': false,
          'message': 'Upload failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error uploading video: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Get video by ID
  Future<Map<String, dynamic>?> getVideoById(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('$_videoApiUrl/$videoId'),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching video: $e');
      return null;
    }
  }

  /// Get videos by user ID
  Future<List<dynamic>> getUserVideos(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_videoApiUrl/user/$userId'),
      );
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print('❌ Error fetching user videos: $e');
      return [];
    }
  }

  /// Get HLS video URL
  String getVideoUrl(String hlsUrl) {
    // HLS URL từ backend: /uploads/processed_videos/xxx/playlist.m3u8
    // Convert thành full URL with platform-specific base
    return '$_baseUrl$hlsUrl';
  }
}
