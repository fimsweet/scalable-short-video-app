import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class FollowService {
  static final FollowService _instance = FollowService._internal();
  factory FollowService() => _instance;
  FollowService._internal();

  String get _baseUrl => AppConfig.userServiceUrl;

  Future<Map<String, dynamic>> toggleFollow(int followerId, int followingId) async {
    try {
      print('📤 Toggle follow: followerId=$followerId, followingId=$followingId');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/follows/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'followerId': followerId, 'followingId': followingId}),
      );

      print('📥 Toggle follow response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'following': false, 'followerCount': 0};
    } catch (e) {
      print('❌ Error toggling follow: $e');
      return {'following': false, 'followerCount': 0};
    }
  }

  Future<bool> isFollowing(int followerId, int followingId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/check/$followerId/$followingId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['following'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error checking follow: $e');
      return false;
    }
  }

  Future<Map<String, int>> getStats(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/stats/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'followerCount': data['followerCount'] ?? 0,
          'followingCount': data['followingCount'] ?? 0,
        };
      }
      return {'followerCount': 0, 'followingCount': 0};
    } catch (e) {
      print('❌ Error getting stats: $e');
      return {'followerCount': 0, 'followingCount': 0};
    }
  }

  Future<List<int>> getFollowers(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/followers/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<int>.from(data['followerIds'] ?? []);
      }
      return [];
    } catch (e) {
      print('❌ Error getting followers: $e');
      return [];
    }
  }

  Future<List<int>> getFollowing(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/following/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<int>.from(data['followingIds'] ?? []);
      }
      return [];
    } catch (e) {
      print('❌ Error getting following: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFollowersWithStatus(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/followers-with-status/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('❌ Error getting followers with status: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getFollowingWithStatus(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/following-with-status/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return [];
    } catch (e) {
      print('❌ Error getting following with status: $e');
      return [];
    }
  }

  Future<bool> isMutualFollow(int userId1, int userId2) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/check-mutual/$userId1/$userId2'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['isMutual'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ Error checking mutual follow: $e');
      return false;
    }
  }
}
