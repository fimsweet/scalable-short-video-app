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

  // User service URL
  String get _userServiceUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'http://localhost:3000';
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
      print('📹 Fetching video by ID: $videoId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/videos/$videoId'),
      );

      print('📥 Video response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final video = json.decode(response.body);
        
        print('📹 Video data: $video');
        print('📹 Video userId: ${video['userId']}');
        
        // Fetch username if userId exists
        if (video['userId'] != null) {
          try {
            final userUrl = '$_userServiceUrl/users/id/${video['userId']}';
            print('👤 Fetching user from: $userUrl');
            
            final userResponse = await http.get(
              Uri.parse(userUrl),
            );
            
            print('👤 User response: ${userResponse.statusCode} - ${userResponse.body}');
            
            if (userResponse.statusCode == 200) {
              final userData = json.decode(userResponse.body);
              video['username'] = userData['username'] ?? 'user';
              video['userAvatar'] = userData['avatar'];
              print('✅ Got username: ${video['username']}');
            } else {
              print('❌ User fetch failed: ${userResponse.statusCode}');
              video['username'] = 'user';
              video['userAvatar'] = null;
            }
          } catch (e) {
            print('❌ Error fetching user for video: $e');
            video['username'] = 'user';
            video['userAvatar'] = null;
          }
        } else {
          print('⚠️ No userId in video');
          video['username'] = 'user';
          video['userAvatar'] = null;
        }
        
        return video;
      }
      
      print('❌ Video not found: ${response.statusCode}');
      return null;
    } catch (e) {
      print('❌ Error getting video by id: $e');
      return null;
    }
  }

  /// Get videos by user ID
  Future<List<dynamic>> getUserVideos(String userId) async {
    try {
      print('📹 Fetching videos for user $userId...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/videos/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Check if response has success flag and data field
        if (data is Map && data['success'] == true && data['data'] != null) {
          final List<dynamic> videos = data['data'];
          print('✅ Loaded ${videos.length} videos for user $userId');
          return videos;
        } else if (data is List) {
          // Fallback for direct list response
          print('✅ Loaded ${data.length} videos for user $userId');
          return data;
        } else {
          print('⚠️ Unexpected response format');
          return [];
        }
      } else {
        print('❌ Failed to load user videos: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error loading user videos: $e');
      return [];
    }
  }

  /// Get all videos for feed (guest mode)
  Future<List<dynamic>> getAllVideos() async {
    try {
      print('📹 Fetching all videos from: $_videoApiUrl/feed/all');
      
      final response = await http.get(
        Uri.parse('$_videoApiUrl/feed/all'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - server không phản hồi');
        },
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> videos = json.decode(response.body);
        print('✅ Loaded ${videos.length} videos');
        return videos;
      } else {
        print('❌ Failed to load videos: ${response.statusCode}');
        print('   Body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching all videos: $e');
      print('   Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Get HLS video URL
  String getVideoUrl(String hlsUrl) {
    // HLS URL từ backend: /uploads/processed_videos/xxx/playlist.m3u8
    // Convert thành full URL with platform-specific base
    return '$_baseUrl$hlsUrl';
  }

  /// Get videos by user ID (for user profile)
  Future<List<dynamic>> getVideosByUserId(String userId) async {
    try {
      print('📹 Fetching videos for user $userId...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/videos/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Handle different response formats
        if (data is Map && data['success'] == true && data['data'] != null) {
          final List<dynamic> videos = data['data'];
          // Filter only ready videos
          return videos.where((v) => v != null && v['status'] == 'ready').toList();
        } else if (data is List) {
          return data.where((v) => v != null && v['status'] == 'ready').toList();
        }
        return [];
      } else {
        print('❌ Failed to load user videos: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error loading user videos: $e');
      return [];
    }
  }

  Future<List<dynamic>> getFollowingVideos(String userId) async {
    try {
      print('📹 Fetching following videos for user $userId...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/videos/feed/following/$userId'),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> videos = json.decode(response.body);
        print('✅ Loaded ${videos.length} following videos');
        return videos;
      } else {
        print('❌ Failed to load following videos: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching following videos: $e');
      return [];
    }
  }
}
