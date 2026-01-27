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

  // Video service base URL (port 3002)
  static final String _videoServiceBaseUrl = (kIsWeb || !Platform.isAndroid)
      ? 'http://localhost:3002'
      : 'http://10.0.2.2:3002';

  /// Generic GET request
  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    final url = Uri.parse('$_baseUrl$path');
    return await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
    );
  }

  /// Generic POST request
  Future<http.Response> post(String path, {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final url = Uri.parse('$_baseUrl$path');
    return await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        ...?headers,
      },
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
    String? phoneNumber,
    String? dateOfBirth,
    String? gender,
    String? language,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/register');
    try {
      final body = <String, dynamic>{
        'username': username,
        'email': email,
        'password': password,
      };
      
      // Add optional fields if provided
      if (fullName != null && fullName.isNotEmpty) {
        body['fullName'] = fullName;
      }
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        body['phoneNumber'] = phoneNumber;
      }
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) {
        body['dateOfBirth'] = dateOfBirth;
      }
      if (gender != null && gender.isNotEmpty) {
        body['gender'] = gender;
      }
      if (language != null && language.isNotEmpty) {
        body['language'] = language;
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
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

  // Phone registration with Firebase token
  Future<Map<String, dynamic>> registerWithPhone({
    required String firebaseIdToken,
    required String username,
    String? fullName,
    String? dateOfBirth,
    String? language,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/register/phone');
    try {
      final body = <String, dynamic>{
        'firebaseIdToken': firebaseIdToken,
        'username': username,
      };
      
      if (fullName != null && fullName.isNotEmpty) {
        body['fullName'] = fullName;
      }
      if (dateOfBirth != null && dateOfBirth.isNotEmpty) {
        body['dateOfBirth'] = dateOfBirth;
      }
      if (language != null && language.isNotEmpty) {
        body['language'] = language;
      }
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': responseBody};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      print('API Error: $e');
      return {'success': false, 'message': 'Could not connect to server. Please try again.'};
    }
  }

  // Phone login with Firebase token
  Future<Map<String, dynamic>> loginWithPhone(String firebaseIdToken) async {
    final url = Uri.parse('$_baseUrl/auth/login/phone');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'firebaseIdToken': firebaseIdToken}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': responseBody};
      } else {
        return {'success': false, 'message': responseBody['message'] ?? 'Login failed'};
      }
    } catch (e) {
      print('API Error: $e');
      return {'success': false, 'message': 'Could not connect to server. Please try again.'};
    }
  }

  // Check phone availability
  Future<Map<String, dynamic>> checkPhone(String phone) async {
    final url = Uri.parse('$_baseUrl/auth/check-phone?phone=${Uri.encodeComponent(phone)}');
    try {
      final response = await http.get(url);
      final responseBody = jsonDecode(response.body);
      return responseBody;
    } catch (e) {
      print('API Error: $e');
      return {'available': false, 'error': e.toString()};
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
    // If avatarPath is already a full URL (starts with http:// or https://), return as is
    if (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')) {
      return avatarPath;
    }
    return '$_baseUrl$avatarPath';
  }

  /// Get full URL for comment image
  String getCommentImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }
    return '$_videoServiceBaseUrl$imagePath';
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

  /// Send heartbeat to update user's online status
  Future<void> sendHeartbeat(String userId) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/users/$userId/heartbeat'),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      // Silently fail - heartbeat is not critical
    }
  }

  /// Get user's online status
  Future<Map<String, dynamic>> getOnlineStatus(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$userId/online-status'),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'isOnline': false, 'statusText': 'Offline'};
    } catch (e) {
      print('❌ Error fetching online status: $e');
      return {'success': false, 'isOnline': false, 'statusText': 'Offline'};
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? bio,
    String? gender,
    String? dateOfBirth,
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
          if (gender != null) 'gender': gender,
          if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
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

  /// Change password
  Future<Map<String, dynamic>> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final body = json.decode(response.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Đổi mật khẩu thất bại',
        };
      }
    } catch (e) {
      print('❌ Error changing password: $e');
      return {
        'success': false,
        'message': 'Không thể kết nối đến server',
      };
    }
  }

  /// Check if user has password (for OAuth users)
  Future<Map<String, dynamic>> hasPassword(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/has-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'success': false, 'hasPassword': false};
      }
    } catch (e) {
      print('❌ Error checking password: $e');
      return {'success': false, 'hasPassword': false};
    }
  }

  /// Set password for OAuth users (who don't have password yet)
  Future<Map<String, dynamic>> setPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/set-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final body = json.decode(response.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Đặt mật khẩu thất bại',
        };
      }
    } catch (e) {
      print('❌ Error setting password: $e');
      return {
        'success': false,
        'message': 'Không thể kết nối đến server',
      };
    }
  }

  /// Request password reset OTP
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final body = json.decode(response.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Gửi mã xác nhận thất bại',
        };
      }
    } catch (e) {
      print('❌ Error requesting password reset: $e');
      return {
        'success': false,
        'message': 'Không thể kết nối đến server',
      };
    }
  }

  /// Verify OTP only (without resetting password)
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final body = json.decode(response.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Xác minh mã thất bại',
        };
      }
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      return {
        'success': false,
        'message': 'Không thể kết nối đến server',
      };
    }
  }

  /// Verify OTP and reset password
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final body = json.decode(response.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Đặt lại mật khẩu thất bại',
        };
      }
    } catch (e) {
      print('❌ Error resetting password: $e');
      return {
        'success': false,
        'message': 'Không thể kết nối đến server',
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

  /// Check if username is available
  Future<Map<String, dynamic>> checkUsernameAvailability(String username) async {
    try {
      print('🔍 Checking username availability: "$username"');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/users/check-username/${Uri.encodeComponent(username)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Username check result: ${data['available'] ? 'available' : 'taken'}');
        return {
          'success': true,
          'available': data['available'] ?? false,
        };
      } else {
        print('❌ Username check failed: ${response.statusCode}');
        return {
          'success': false,
          'available': false,
        };
      }
    } catch (e) {
      print('❌ Error checking username: $e');
      return {
        'success': false,
        'available': false,
        'error': e.toString(),
      };
    }
  }

  /// Search users by username or fullName
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      print('🔍 Searching users for: "$query"');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/users/search?q=${Uri.encodeComponent(query)}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['users'] != null) {
          final List<dynamic> users = data['users'];
          print('✅ Found ${users.length} users for query: "$query"');
          return users.map((u) => Map<String, dynamic>.from(u)).toList();
        }
        return [];
      } else {
        print('❌ User search failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error searching users: $e');
      return [];
    }
  }

  /// Block a user
  Future<bool> blockUser(String targetUserId, {String? currentUserId}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/block/$targetUserId'),
        headers: {'Content-Type': 'application/json'},
        body: currentUserId != null ? jsonEncode({'userId': currentUserId}) : null,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('❌ Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String targetUserId, {String? currentUserId}) async {
    try {
      final request = http.Request('DELETE', Uri.parse('$_baseUrl/users/block/$targetUserId'));
      request.headers['Content-Type'] = 'application/json';
      if (currentUserId != null) {
        request.body = jsonEncode({'userId': currentUserId});
      }
      
      final streamedResponse = await request.send();
      return streamedResponse.statusCode == 200;
    } catch (e) {
      print('❌ Error unblocking user: $e');
      return false;
    }
  }

  /// Get list of blocked users
  Future<List<Map<String, dynamic>>> getBlockedUsers(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/blocked/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
        return [];
      }
      return [];
    } catch (e) {
      print('❌ Error getting blocked users: $e');
      return [];
    }
  }

  /// Check if a user is blocked
  Future<bool> isUserBlocked(String userId, String targetUserId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/blocked/$userId/check/$targetUserId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isBlocked'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error checking blocked status: $e');
      return false;
    }
  }

  // ============= USER SETTINGS METHODS =============

  /// Get user settings
  Future<Map<String, dynamic>> getUserSettings(String token) async {
    try {
      final url = '$_baseUrl/users/settings';
      print('🌐 Calling getUserSettings API: $url');
      print('   Token: ${token.substring(0, 20)}...');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📥 getUserSettings response status: ${response.statusCode}');
      print('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('✅ Decoded response: $decoded');
        return decoded;
      } else {
        print('⚠️ Failed to get user settings: ${response.statusCode}');
        print('   Response body: ${response.body}');
        return {'success': false};
      }
    } catch (e, stackTrace) {
      print('❌ Error getting user settings: $e');
      print('   Stack trace: $stackTrace');
      return {'success': false};
    }
  }

  /// Update user settings
  Future<Map<String, dynamic>> updateUserSettings(
    String token,
    Map<String, dynamic> settings,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(settings),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('⚠️ Failed to update user settings: ${response.statusCode}');
        return {'success': false};
      }
    } catch (e) {
      print('❌ Error updating user settings: $e');
      return {'success': false};
    }
  }

  // ============= ACCOUNT LINKING (TikTok-style) =============

  /// Get full account info with linked accounts
  Future<Map<String, dynamic>> getAccountInfo(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/account-info'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Không thể lấy thông tin tài khoản',
        };
      }
    } catch (e) {
      print('❌ Error getting account info: $e');
      return {'success': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  /// Send OTP to link email to account
  Future<Map<String, dynamic>> sendLinkEmailOtp(String token, String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/link/email/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Không thể gửi mã xác nhận',
        };
      }
    } catch (e) {
      print('❌ Error sending link email OTP: $e');
      return {'success': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  /// Verify OTP and link email to account (password optional - for phone users who want email login)
  Future<Map<String, dynamic>> verifyAndLinkEmail(String token, String email, String otp, {String? password}) async {
    try {
      final body = {'email': email, 'otp': otp};
      if (password != null && password.isNotEmpty) {
        body['password'] = password;
      }
      
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/link/email/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Xác minh thất bại',
        };
      }
    } catch (e) {
      print('❌ Error verifying link email: $e');
      return {'success': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  /// Link phone to account using Firebase token
  Future<Map<String, dynamic>> linkPhone(String token, String firebaseIdToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/link/phone'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'firebaseIdToken': firebaseIdToken}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Liên kết số điện thoại thất bại',
        };
      }
    } catch (e) {
      print('❌ Error linking phone: $e');
      return {'success': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  /// Check if phone is available for linking (not used by another account)
  Future<Map<String, dynamic>> checkPhoneForLink(String token, String phone) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/link/phone/check?phone=${Uri.encodeComponent(phone)}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final body = jsonDecode(response.body);
        return {
          'available': false,
          'message': body['message'] ?? 'Không thể kiểm tra số điện thoại',
        };
      }
    } catch (e) {
      print('❌ Error checking phone for link: $e');
      return {'available': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  // ============= TWO-FACTOR AUTHENTICATION =============

  /// Get 2FA settings
  Future<Map<String, dynamic>> get2FASettings(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/2fa/settings'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'enabled': false, 'methods': []};
    } catch (e) {
      print('❌ Error getting 2FA settings: $e');
      return {'enabled': false, 'methods': []};
    }
  }

  /// Update 2FA settings
  Future<Map<String, dynamic>> update2FASettings(String token, bool enabled, List<String> methods) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/2fa/settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'enabled': enabled, 'methods': methods}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...jsonDecode(response.body)};
      }
      final body = jsonDecode(response.body);
      return {'success': false, 'message': body['message'] ?? 'Cập nhật 2FA thất bại'};
    } catch (e) {
      print('❌ Error updating 2FA settings: $e');
      return {'success': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  /// Send 2FA OTP
  Future<Map<String, dynamic>> send2FAOtp(int userId, String method) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/2fa/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'method': method}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...jsonDecode(response.body)};
      }
      final body = jsonDecode(response.body);
      return {'success': false, 'message': body['message'] ?? 'Gửi mã xác thực thất bại'};
    } catch (e) {
      print('❌ Error sending 2FA OTP: $e');
      return {'success': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  /// Verify 2FA OTP
  Future<Map<String, dynamic>> verify2FAOtp(int userId, String otp, String method) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/2fa/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'otp': otp, 'method': method}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...jsonDecode(response.body)};
      }
      final body = jsonDecode(response.body);
      return {'success': false, 'message': body['message'] ?? 'Xác thực thất bại'};
    } catch (e) {
      print('❌ Error verifying 2FA: $e');
      return {'success': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  /// Send OTP for 2FA settings change (enable/disable)
  Future<Map<String, dynamic>> send2FASettingsOtp(String token, String method) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/2fa/send-settings-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'method': method}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...jsonDecode(response.body)};
      }
      final body = jsonDecode(response.body);
      return {'success': false, 'message': body['message'] ?? 'Gửi mã xác thực thất bại'};
    } catch (e) {
      print('❌ Error sending 2FA settings OTP: $e');
      return {'success': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  /// Verify OTP and update 2FA settings
  Future<Map<String, dynamic>> verify2FASettings(
    String token,
    String otp,
    String method,
    bool enabled,
    List<String> methods,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/2fa/verify-settings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'otp': otp,
          'method': method,
          'enabled': enabled,
          'methods': methods,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...jsonDecode(response.body)};
      }
      final body = jsonDecode(response.body);
      return {'success': false, 'message': body['message'] ?? 'Xác thực thất bại'};
    } catch (e) {
      print('❌ Error verifying 2FA settings: $e');
      return {'success': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  // ============= FORGOT PASSWORD WITH PHONE =============

  /// Check if phone exists for password reset
  Future<Map<String, dynamic>> checkPhoneForPasswordReset(String phone) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/forgot-password/check-phone?phone=$phone'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return {'success': true, ...jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Số điện thoại không tồn tại',
        };
      }
    } catch (e) {
      print('❌ Error checking phone for reset: $e');
      return {'success': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  /// Reset password with phone (after Firebase verification)
  Future<Map<String, dynamic>> resetPasswordWithPhone({
    required String phone,
    required String firebaseIdToken,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/forgot-password/phone/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': phone,
          'firebaseIdToken': firebaseIdToken,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, ...jsonDecode(response.body)};
      } else {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'message': body['message'] ?? 'Đặt lại mật khẩu thất bại',
        };
      }
    } catch (e) {
      print('❌ Error resetting password with phone: $e');
      return {'success': false, 'message': 'Không thể kết nối đến server'};
    }
  }

  /// Format phone number to Vietnamese display format (0xxx xxx xxx)
  static String formatPhoneForDisplay(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    
    // Remove +84 and replace with 0
    String formatted = phone;
    if (formatted.startsWith('+84')) {
      formatted = '0${formatted.substring(3)}';
    }
    
    // Format as 0xxx xxx xxx
    if (formatted.length == 10) {
      return '${formatted.substring(0, 4)} ${formatted.substring(4, 7)} ${formatted.substring(7)}';
    }
    
    return formatted;
  }

  /// Parse Vietnamese phone display format to E.164 format (+84...)
  static String parsePhoneToE164(String phone) {
    // Remove spaces and special characters
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // If starts with 0, replace with +84
    if (cleaned.startsWith('0')) {
      cleaned = '+84${cleaned.substring(1)}';
    }
    
    // If doesn't start with +, add +84
    if (!cleaned.startsWith('+')) {
      cleaned = '+84$cleaned';
    }
    
    return cleaned;
  }

  // ==================== CATEGORIES & INTERESTS ====================

  /// Get all available categories from video service
  Future<Map<String, dynamic>> getCategories() async {
    try {
      final url = Uri.parse('$_videoServiceBaseUrl/categories');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': body['data'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to load categories',
        };
      }
    } catch (e) {
      print('❌ Error fetching categories: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Get user's interests
  Future<Map<String, dynamic>> getUserInterests(int userId) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$userId/interests');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': body['data'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to load interests',
        };
      }
    } catch (e) {
      print('❌ Error fetching user interests: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Check if user has selected interests
  Future<bool> hasSelectedInterests(int userId) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$userId/interests/check');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);
      return body['hasInterests'] == true;
    } catch (e) {
      print('❌ Error checking user interests: $e');
      return false;
    }
  }

  /// Set user's interests (replaces existing)
  Future<Map<String, dynamic>> setUserInterests(
    int userId,
    List<int> categoryIds,
    String token,
  ) async {
    try {
      final url = Uri.parse('$_baseUrl/users/$userId/interests');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'categoryIds': categoryIds}),
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': body['data'] ?? [],
          'message': body['message'],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to save interests',
        };
      }
    } catch (e) {
      print('❌ Error setting user interests: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  // ==================== RECOMMENDATIONS ====================

  /// Get personalized video recommendations for a user
  Future<Map<String, dynamic>> getRecommendedVideos(int userId, {int limit = 50}) async {
    try {
      final url = Uri.parse('$_videoServiceBaseUrl/recommendation/for-you/$userId?limit=$limit');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': body['data'] ?? [],
          'count': body['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to load recommendations',
        };
      }
    } catch (e) {
      print('❌ Error fetching recommendations: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Get trending videos (for new users or discovery)
  Future<Map<String, dynamic>> getTrendingVideos({int limit = 50}) async {
    try {
      final url = Uri.parse('$_videoServiceBaseUrl/recommendation/trending?limit=$limit');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': body['data'] ?? [],
          'count': body['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to load trending videos',
        };
      }
    } catch (e) {
      print('❌ Error fetching trending videos: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Get videos by category
  Future<Map<String, dynamic>> getVideosByCategory(int categoryId, {int limit = 50}) async {
    try {
      final url = Uri.parse('$_videoServiceBaseUrl/recommendation/category/$categoryId?limit=$limit');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': body['data'] ?? [],
          'count': body['count'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to load videos',
        };
      }
    } catch (e) {
      print('❌ Error fetching videos by category: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Get categories for a specific video
  Future<Map<String, dynamic>> getVideoCategories(String videoId) async {
    try {
      final url = Uri.parse('$_videoServiceBaseUrl/categories/video/$videoId');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': body['data'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to load video categories',
        };
      }
    } catch (e) {
      print('❌ Error fetching video categories: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  // ========== WATCH HISTORY APIs ==========

  /// Record watch time when user views a video
  /// This is crucial for the recommendation algorithm to learn user preferences
  Future<Map<String, dynamic>> recordWatchTime({
    required String userId,
    required String videoId,
    required int watchDuration, // seconds
    required int videoDuration, // total video duration in seconds
  }) async {
    try {
      final url = Uri.parse('$_videoServiceBaseUrl/watch-history');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'videoId': videoId,
          'watchDuration': watchDuration,
          'videoDuration': videoDuration,
        }),
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': body['data'],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to record watch time',
        };
      }
    } catch (e) {
      // Silent fail - don't disrupt user experience for analytics
      print('⚠️ Error recording watch time: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Get user's watch history
  Future<Map<String, dynamic>> getWatchHistory(String userId, {int limit = 50, int offset = 0}) async {
    try {
      final url = Uri.parse('$_videoServiceBaseUrl/watch-history/$userId?limit=$limit&offset=$offset');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': body['data'] ?? [],
          'total': body['total'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to load watch history',
        };
      }
    } catch (e) {
      print('❌ Error fetching watch history: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Get user's interests based on watch time (for debugging/display)
  Future<Map<String, dynamic>> getWatchTimeInterests(String userId) async {
    try {
      final url = Uri.parse('$_videoServiceBaseUrl/watch-history/$userId/interests');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': body['data'] ?? [],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to load watch interests',
        };
      }
    } catch (e) {
      print('❌ Error fetching watch interests: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Get user's watch stats
  Future<Map<String, dynamic>> getWatchStats(String userId) async {
    try {
      final url = Uri.parse('$_videoServiceBaseUrl/watch-history/$userId/stats');
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': body['data'],
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to load watch stats',
        };
      }
    } catch (e) {
      print('❌ Error fetching watch stats: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  /// Clear watch history
  Future<Map<String, dynamic>> clearWatchHistory(String userId) async {
    try {
      final url = Uri.parse('$_videoServiceBaseUrl/watch-history/$userId');
      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      final body = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'deletedCount': body['deletedCount'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': body['message'] ?? 'Failed to clear history',
        };
      }
    } catch (e) {
      print('❌ Error clearing watch history: $e');
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }
}
