import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  // Use 10.0.2.2 for Android emulator to connect to host's localhost
  // For web and other platforms, use localhost.
  static final String _baseUrl = (kIsWeb || !Platform.isAndroid)
      ? 'http://localhost:3000'
      : 'http://10.0.2.2:3000';

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': responseBody};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Đăng ký thất bại'};
      }
    } catch (e) {
      print('API Error: $e');
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': responseBody};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Đăng nhập thất bại'};
      }
    } catch (e) {
      print('API Error: $e');
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ. Vui lòng thử lại.'};
    }
  }

  Future<Map<String, dynamic>> getProfile(String token) async {
    final url = Uri.parse('$_baseUrl/auth/profile');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': responseBody};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Failed to get profile'};
      }
    } catch (e) {
      print('API Error: $e');
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  Future<Map<String, dynamic>> uploadAvatar({
    required String token,
    required dynamic imageFile, // Đổi từ File thành dynamic
  }) async {
    final url = Uri.parse('$_baseUrl/users/avatar');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      
      if (kIsWeb) {
        // Web: sử dụng bytes
        final bytes = await imageFile.readAsBytes();
        final filename = imageFile.name;
        request.files.add(
          http.MultipartFile.fromBytes(
            'avatar',
            bytes,
            filename: filename,
          ),
        );
      } else {
        // Mobile: sử dụng path
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            imageFile.path,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': responseBody};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Upload failed'};
      }
    } catch (e) {
      print('API Error: $e');
      return {'success': false, 'message': 'Could not upload avatar. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> removeAvatar({required String token}) async {
    final url = Uri.parse('$_baseUrl/users/avatar');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': responseBody};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Remove failed'};
      }
    } catch (e) {
      print('API Error: $e');
      return {'success': false, 'message': 'Could not remove avatar.'};
    }
  }

  String getAvatarUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) {
      return '';
    }
    return '$_baseUrl$avatarPath';
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/id/$userId'),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching user: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? bio,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          if (bio != null) 'bio': bio,
        }),
      );

      print('Profile update response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': json.decode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update profile: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  /// Get followers of a user
  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    try {
      // First get follower IDs
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/followers/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final followerIds = List<int>.from(data['followerIds'] ?? []);
        
        // Fetch user info for each follower
        List<Map<String, dynamic>> followers = [];
        for (var id in followerIds) {
          final userInfo = await getUserById(id.toString());
          if (userInfo != null) {
            followers.add({
              ...userInfo,
              'id': id,
            });
          }
        }
        
        return followers;
      }
      return [];
    } catch (e) {
      print('❌ Error getting followers: $e');
      return [];
    }
  }

  /// Get following users of a user
  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    try {
      // First get following IDs
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/following/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final followingIds = List<int>.from(data['followingIds'] ?? []);
        
        // Fetch user info for each following
        List<Map<String, dynamic>> following = [];
        for (var id in followingIds) {
          final userInfo = await getUserById(id.toString());
          if (userInfo != null) {
            following.add({
              ...userInfo,
              'id': id,
            });
          }
        }
        
        return following;
      }
      return [];
    } catch (e) {
      print('❌ Error getting following: $e');
      return [];
    }
  }
}