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

  /// Upload video to video-service with optional category tags
  Future<Map<String, dynamic>> uploadVideo({
    required XFile videoFile,
    required String userId,
    required String title,
    String? description,
    required String token,
    List<int>? categoryIds,
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
      
      // Add category IDs as JSON array
      if (categoryIds != null && categoryIds.isNotEmpty) {
        request.fields['categoryIds'] = json.encode(categoryIds);
        print('🏷️ Categories: $categoryIds');
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
  Future<void> incrementViewCount(String videoId) async {
    try {
      print('👁️ Incrementing view count for video: $videoId');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/videos/$videoId/view'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ View count updated: ${data['viewCount']}');
      } else {
        print('⚠️ Failed to increment view count: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error incrementing view count: $e');
    }
  }

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

  /// Search videos by title or description
  Future<List<dynamic>> searchVideos(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      print('🔍 Searching videos for: "$query"');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/videos/search?q=${Uri.encodeComponent(query)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['videos'] != null) {
          final List<dynamic> videos = data['videos'];
          print('✅ Found ${videos.length} videos for query: "$query"');
          return videos;
        }
        return [];
      } else {
        print('❌ Search failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error searching videos: $e');
      return [];
    }
  }

  /// Toggle hide status of a video
  Future<Map<String, dynamic>> toggleHideVideo(String videoId, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/videos/$videoId/hide'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to toggle hide video');
      }
    } catch (e) {
      print('❌ Error toggling hide video: $e');
      rethrow;
    }
  }

  /// Delete a video
  Future<bool> deleteVideo(String videoId, String userId) async {
    try {
      print('🗑️ Deleting video: $videoId');
      final response = await http.post(
        Uri.parse('$_baseUrl/videos/$videoId/delete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      print('📥 Delete response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Video deleted successfully');
          return true;
        } else {
          print('❌ Delete failed: ${data['message']}');
          throw Exception(data['message'] ?? 'Failed to delete video');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete video');
      }
    } catch (e) {
      print('❌ Error deleting video: $e');
      rethrow; // Re-throw to handle in UI
    }
  }

  /// Get personalized recommended videos for For You feed
  Future<List<dynamic>> getRecommendedVideos(int userId, {int limit = 50}) async {
    try {
      print('🎯 Fetching recommended videos for user $userId...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/recommendation/for-you/$userId?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('📥 Recommendation response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> videos = data['data'];
          print('✅ Loaded ${videos.length} recommended videos');
          return videos;
        }
        return [];
      } else {
        print('❌ Failed to load recommendations: ${response.statusCode}');
        // Fallback to regular feed
        return await getAllVideos();
      }
    } catch (e) {
      print('❌ Error fetching recommendations: $e');
      // Fallback to regular feed
      return await getAllVideos();
    }
  }

  /// Get trending videos (for new users or discovery)
  Future<List<dynamic>> getTrendingVideos({int limit = 50}) async {
    try {
      print('📈 Fetching trending videos...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/recommendation/trending?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('📥 Trending response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> videos = data['data'];
          print('✅ Loaded ${videos.length} trending videos');
          return videos;
        }
        return [];
      } else {
        print('❌ Failed to load trending videos: ${response.statusCode}');
        return await getAllVideos();
      }
    } catch (e) {
      print('❌ Error fetching trending videos: $e');
      return await getAllVideos();
    }
  }
}
