import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

class VideoService {
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  // Use centralized config for URLs
  String get _baseUrl => AppConfig.videoServiceUrl;
  String get _userServiceUrl => AppConfig.userServiceUrl;

  String get _videoApiUrl => '$_baseUrl/videos';

  /// Upload video to video-service with optional category tags
  Future<Map<String, dynamic>> uploadVideo({
    required XFile videoFile,
    required String userId,
    required String title,
    String? description,
    required String token,
    List<int>? categoryIds,
    double? thumbnailTimestamp,
    String? visibility,
    bool? allowComments,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_videoApiUrl/upload'));
      
      // Add headers
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add video file - Use readAsBytes() for web compatibility
      final bytes = await videoFile.readAsBytes();
      
      // Detect MIME type from filename
      final mimeType = lookupMimeType(videoFile.name) ?? 'video/mp4';
      print('Detected MIME type: $mimeType');
      
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
        print('Categories: $categoryIds');
      }

      // Add thumbnail timestamp for frame selection
      if (thumbnailTimestamp != null) {
        request.fields['thumbnailTimestamp'] = thumbnailTimestamp.toStringAsFixed(3);
        print('Thumbnail timestamp: ${thumbnailTimestamp}s');
      }

      // Add privacy settings
      if (visibility != null) {
        request.fields['visibility'] = visibility;
        print('Visibility: $visibility');
      }
      if (allowComments != null) {
        request.fields['allowComments'] = allowComments.toString();
        print('Allow comments: $allowComments');
      }
      
      print('Uploading video to: $_videoApiUrl/upload');
      print('   File: ${videoFile.name}');
      print('   Size: ${bytes.length} bytes');
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('Upload response: $responseBody');
      
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
      print('Error uploading video: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Get video by ID
  Future<Map<String, dynamic>?> getVideoById(String videoId) async {
    try {
      print('Fetching video by ID: $videoId');
      
      // Pass requesterId so backend can block hidden videos for non-owners
      final currentUserId = AuthService().user?['id']?.toString();
      String url = '$_baseUrl/videos/$videoId';
      if (currentUserId != null) {
        url += '?requesterId=$currentUserId';
      }
      
      final response = await http.get(
        Uri.parse(url),
      );

      print('Video response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        // Backend returns null for hidden videos when requester is not the owner
        if (decoded == null) return null;
        final video = decoded as Map<String, dynamic>;
        
        print('Video data: $video');
        print('Video userId: ${video['userId']}');
        
        // Fetch username if userId exists
        if (video['userId'] != null) {
          try {
            final userUrl = '$_userServiceUrl/users/id/${video['userId']}';
            print('Fetching user from: $userUrl');
            
            final userResponse = await http.get(
              Uri.parse(userUrl),
            );
            
            print('User response: ${userResponse.statusCode} - ${userResponse.body}');
            
            if (userResponse.statusCode == 200) {
              final userData = json.decode(userResponse.body);
              video['username'] = userData['username'] ?? 'user';
              video['userAvatar'] = userData['avatar'];
              print('Got username: ${video['username']}');
            } else {
              print('User fetch failed: ${userResponse.statusCode}');
              video['username'] = 'user';
              video['userAvatar'] = null;
            }
          } catch (e) {
            print('Error fetching user for video: $e');
            video['username'] = 'user';
            video['userAvatar'] = null;
          }
        } else {
          print('No userId in video');
          video['username'] = 'user';
          video['userAvatar'] = null;
        }
        
        return video;
      }
      
      print('Video not found: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error getting video by id: $e');
      return null;
    }
  }

  /// Get videos by user ID
  Future<void> incrementViewCount(String videoId) async {
    try {
      print('Incrementing view count for video: $videoId');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/videos/$videoId/view'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('View count updated: ${data['viewCount']}');
      } else {
        print('Failed to increment view count: ${response.statusCode}');
      }
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  Future<List<dynamic>> getUserVideos(String userId) async {
    try {
      print('Fetching videos for user $userId...');
      
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
          print('Loaded ${videos.length} videos for user $userId');
          return videos;
        } else if (data is List) {
          // Fallback for direct list response
          print('Loaded ${data.length} videos for user $userId');
          return data;
        } else {
          print('Unexpected response format');
          return [];
        }
      } else {
        print('Failed to load user videos: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error loading user videos: $e');
      return [];
    }
  }

  /// Get all videos for feed (guest mode)
  Future<List<dynamic>> getAllVideos() async {
    try {
      print('Fetching all videos from: $_videoApiUrl/feed/all');
      
      final response = await http.get(
        Uri.parse('$_videoApiUrl/feed/all'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout - server không phản hồi');
        },
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> videos = json.decode(response.body);
        print('Loaded ${videos.length} videos');
        return videos;
      } else {
        print('Failed to load videos: ${response.statusCode}');
        print('   Body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching all videos: $e');
      print('   Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Get HLS video URL
  String getVideoUrl(String hlsUrl) {
    // HLS URL từ backend: /uploads/processed_videos/xxx/playlist.m3u8 hoặc full URL (CloudFront)
    if (hlsUrl.startsWith('http://') || hlsUrl.startsWith('https://')) {
      return hlsUrl;
    }
    // Prefer CloudFront CDN in production, fallback to gateway/direct URL
    final baseUrl = AppConfig.cloudFrontUrl ?? _baseUrl;
    return '$baseUrl$hlsUrl';
  }

  /// Get videos by user ID (for user profile)
  /// Returns { 'videos': List, 'privacyRestricted': bool, 'reason': String? }
  Future<Map<String, dynamic>> getVideosByUserIdWithPrivacy(String userId, {String? requesterId}) async {
    try {
      print('Fetching videos for user $userId (requesterId: $requesterId)...');
      
      String url = '$_baseUrl/videos/user/$userId';
      if (requesterId != null && requesterId.isNotEmpty) {
        url += '?requesterId=$requesterId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is Map && data['success'] == true) {
          final bool privacyRestricted = data['privacyRestricted'] == true;
          final String? reason = data['reason'];
          final List<dynamic> videos = (data['data'] ?? [])
              .where((v) => v != null && v['status'] == 'ready' && v['isHidden'] != true)
              .toList();
          
          return {
            'videos': videos,
            'privacyRestricted': privacyRestricted,
            'reason': reason,
          };
        }
        return {'videos': [], 'privacyRestricted': false};
      } else {
        return {'videos': [], 'privacyRestricted': false};
      }
    } catch (e) {
      print('Error loading user videos: $e');
      return {'videos': [], 'privacyRestricted': false};
    }
  }

  Future<List<dynamic>> getVideosByUserId(String userId, {String? requesterId}) async {
    try {
      print('Fetching videos for user $userId (requesterId: $requesterId)...');
      
      String url = '$_baseUrl/videos/user/$userId';
      if (requesterId != null && requesterId.isNotEmpty) {
        url += '?requesterId=$requesterId';
      }
      
      final response = await http.get(
        Uri.parse(url),
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
        print('Failed to load user videos: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error loading user videos: $e');
      return [];
    }
  }

  /// Get videos from users that the current user is following (excluding mutual friends)
  /// This is for the "Following" tab - shows videos from one-way follows only
  Future<List<dynamic>> getFollowingVideos(String userId) async {
    try {
      print('Fetching following videos for user $userId (excluding friends)...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/videos/feed/following/$userId'),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> videos = json.decode(response.body);
        print('Loaded ${videos.length} following videos (excluding friends)');
        return videos;
      } else {
        print('Failed to load following videos: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching following videos: $e');
      return [];
    }
  }

  /// Get videos from mutual friends only (users who follow each other)
  /// This is for the "Friends" tab - shows videos from two-way/mutual follows
  Future<List<dynamic>> getFriendsVideos(String userId) async {
    try {
      print('Fetching friends videos for user $userId...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/videos/feed/friends/$userId'),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> videos = json.decode(response.body);
        print('Loaded ${videos.length} friends videos');
        return videos;
      } else {
        print('Failed to load friends videos: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching friends videos: $e');
      return [];
    }
  }

  /// Get count of new videos from following users since a given date
  Future<int> getFollowingNewVideoCount(String userId, DateTime since) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/videos/feed/following/$userId/new-count?since=${since.toIso8601String()}'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['newCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error fetching following new count: $e');
      return 0;
    }
  }

  /// Get count of new videos from friends since a given date
  Future<int> getFriendsNewVideoCount(String userId, DateTime since) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/videos/feed/friends/$userId/new-count?since=${since.toIso8601String()}'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['newCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error fetching friends new count: $e');
      return 0;
    }
  }

  /// Search videos by title or description
  Future<List<dynamic>> searchVideos(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      print('Searching videos for: "$query"');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/videos/search?q=${Uri.encodeComponent(query)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['videos'] != null) {
          final List<dynamic> videos = data['videos'];
          print('Found ${videos.length} videos for query: "$query"');
          
          // Fetch user info for each video
          final videosWithUser = await Future.wait(
            videos.map((video) async {
              if (video['userId'] != null) {
                try {
                  final userUrl = '$_userServiceUrl/users/id/${video['userId']}';
                  final userResponse = await http.get(Uri.parse(userUrl));
                  
                  if (userResponse.statusCode == 200) {
                    final userData = json.decode(userResponse.body);
                    video['user'] = {
                      'username': userData['username'] ?? 'user',
                      'avatar': userData['avatar'],
                    };
                  } else {
                    video['user'] = {'username': 'user', 'avatar': null};
                  }
                } catch (e) {
                  print('Error fetching user for video ${video['id']}: $e');
                  video['user'] = {'username': 'user', 'avatar': null};
                }
              } else {
                video['user'] = {'username': 'user', 'avatar': null};
              }
              return video;
            }).toList(),
          );
          
          return videosWithUser;
        }
        return [];
      } else {
        print('Search failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error searching videos: $e');
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
      print('Error toggling hide video: $e');
      rethrow;
    }
  }

  /// Delete a video
  Future<bool> deleteVideo(String videoId, String userId) async {
    try {
      print('Deleting video: $videoId');
      final response = await http.post(
        Uri.parse('$_baseUrl/videos/$videoId/delete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      print('Delete response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('Video deleted successfully');
          return true;
        } else {
          print('Delete failed: ${data['message']}');
          throw Exception(data['message'] ?? 'Failed to delete video');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to delete video');
      }
    } catch (e) {
      print('Error deleting video: $e');
      rethrow; // Re-throw to handle in UI
    }
  }

  /// Get personalized recommended videos for For You feed
  Future<List<dynamic>> getRecommendedVideos(int userId, {int limit = 50, List<String>? excludeIds}) async {
    try {
      print('Fetching recommended videos for user $userId...');
      
      String url = '$_baseUrl/recommendation/for-you/$userId?limit=$limit';
      if (excludeIds != null && excludeIds.isNotEmpty) {
        url += '&excludeIds=${excludeIds.join(',')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('Recommendation response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> videos = data['data'];
          print('Loaded ${videos.length} recommended videos');
          return videos;
        }
        return [];
      } else {
        print('Failed to load recommendations: ${response.statusCode}');
        // Fallback to regular feed
        return await getAllVideos();
      }
    } catch (e) {
      print('Error fetching recommendations: $e');
      // Fallback to regular feed
      return await getAllVideos();
    }
  }

  /// Get trending videos (for new users or discovery)
  Future<List<dynamic>> getTrendingVideos({int limit = 50}) async {
    try {
      print('Fetching trending videos...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/recommendation/trending?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      print('Trending response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> videos = data['data'];
          print('Loaded ${videos.length} trending videos');
          return videos;
        }
        return [];
      } else {
        print('Failed to load trending videos: ${response.statusCode}');
        return await getAllVideos();
      }
    } catch (e) {
      print('Error fetching trending videos: $e');
      return await getAllVideos();
    }
  }

  /// Update video privacy settings
  Future<Map<String, dynamic>> updateVideoPrivacy({
    required String videoId,
    required String userId,
    String? visibility,
    bool? allowComments,
    bool? allowDuet,
  }) async {
    try {
      print('Updating privacy for video $videoId...');
      
      final body = <String, dynamic>{'userId': userId};
      if (visibility != null) body['visibility'] = visibility;
      if (allowComments != null) body['allowComments'] = allowComments;
      if (allowDuet != null) body['allowDuet'] = allowDuet;
      
      final response = await http.put(
        Uri.parse('$_baseUrl/videos/$videoId/privacy'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      print('Privacy update response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('Video privacy updated');
          return data;
        }
      }
      
      throw Exception('Failed to update video privacy');
    } catch (e) {
      print('Error updating video privacy: $e');
      rethrow;
    }
  }

  /// Edit video (title, description)
  Future<Map<String, dynamic>> editVideo({
    required String videoId,
    required String userId,
    String? title,
    String? description,
  }) async {
    try {
      print('Editing video $videoId...');
      
      final body = <String, dynamic>{'userId': userId};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      
      final response = await http.put(
        Uri.parse('$_baseUrl/videos/$videoId/edit'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      print('Edit response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('Video edited successfully');
          return data;
        }
      }
      
      throw Exception('Failed to edit video');
    } catch (e) {
      print('Error editing video: $e');
      rethrow;
    }
  }

  /// Update video thumbnail
  Future<Map<String, dynamic>> updateThumbnail({
    required String videoId,
    required String userId,
    required XFile thumbnailFile,
  }) async {
    try {
      print('Updating thumbnail for video $videoId...');
      
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$_baseUrl/videos/$videoId/thumbnail'),
      );
      
      // Add thumbnail file
      final bytes = await thumbnailFile.readAsBytes();
      final mimeType = lookupMimeType(thumbnailFile.name) ?? 'image/jpeg';
      
      request.files.add(http.MultipartFile.fromBytes(
        'thumbnail',
        bytes,
        filename: thumbnailFile.name,
        contentType: MediaType.parse(mimeType),
      ));
      
      // Add userId field
      request.fields['userId'] = userId;
      
      print('Uploading thumbnail...');
      print('   File: ${thumbnailFile.name}');
      print('   Size: ${bytes.length} bytes');
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('Thumbnail update response: $responseBody');
      
      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        if (data['success'] == true) {
          print('Thumbnail updated successfully');
          return data;
        }
      }
      
      throw Exception('Failed to update thumbnail');
    } catch (e) {
      print('Error updating thumbnail: $e');
      rethrow;
    }
  }

  /// Upload video with custom thumbnail
  Future<Map<String, dynamic>> uploadVideoWithThumbnail({
    required XFile videoFile,
    XFile? thumbnailFile,
    required String userId,
    required String title,
    String? description,
    required String token,
    List<int>? categoryIds,
    double? thumbnailTimestamp,
    String? visibility,
    bool? allowComments,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_videoApiUrl/upload-with-thumbnail'),
      );
      
      // Add headers
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add video file
      final videoBytes = await videoFile.readAsBytes();
      final videoMimeType = lookupMimeType(videoFile.name) ?? 'video/mp4';
      print('Video MIME type: $videoMimeType');
      
      request.files.add(http.MultipartFile.fromBytes(
        'video',
        videoBytes,
        filename: videoFile.name,
        contentType: MediaType.parse(videoMimeType),
      ));
      
      // Add thumbnail file if provided
      if (thumbnailFile != null) {
        final thumbBytes = await thumbnailFile.readAsBytes();
        final thumbMimeType = lookupMimeType(thumbnailFile.name) ?? 'image/jpeg';
        print('Thumbnail MIME type: $thumbMimeType');
        
        request.files.add(http.MultipartFile.fromBytes(
          'thumbnail',
          thumbBytes,
          filename: thumbnailFile.name,
          contentType: MediaType.parse(thumbMimeType),
        ));
      }
      
      // Add fields
      request.fields['userId'] = userId;
      request.fields['title'] = title;
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }
      
      // Add category IDs as JSON array
      if (categoryIds != null && categoryIds.isNotEmpty) {
        request.fields['categoryIds'] = json.encode(categoryIds);
        print('Categories: $categoryIds');
      }

      // Add thumbnail timestamp for frame selection
      if (thumbnailTimestamp != null) {
        request.fields['thumbnailTimestamp'] = thumbnailTimestamp.toStringAsFixed(3);
        print('Thumbnail timestamp: ${thumbnailTimestamp}s');
      }

      // Add privacy settings
      if (visibility != null) {
        request.fields['visibility'] = visibility;
        print('Visibility: $visibility');
      }
      if (allowComments != null) {
        request.fields['allowComments'] = allowComments.toString();
        print('Allow comments: $allowComments');
      }
      
      print('Uploading video with thumbnail to: $_videoApiUrl/upload-with-thumbnail');
      print('   Video: ${videoFile.name} (${videoBytes.length} bytes)');
      if (thumbnailFile != null) {
        print('   Thumbnail: ${thumbnailFile.name}');
      }
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      print('Upload response: $responseBody');
      
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
      print('Error uploading video with thumbnail: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Retry a failed video processing job
  Future<Map<String, dynamic>> retryVideo({
    required String videoId,
    required String userId,
  }) async {
    try {
      print('Retrying failed video: $videoId');

      final response = await http.post(
        Uri.parse('$_videoApiUrl/$videoId/retry'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': userId}),
      );

      print('Retry response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Retry failed: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error retrying video: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
}
