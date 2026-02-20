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
      print('Toggle follow: followerId=$followerId, followingId=$followingId');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/follows/toggle'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'followerId': followerId, 'followingId': followingId}),
      );

      print('Toggle follow response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'following': false, 'followerCount': 0};
    } catch (e) {
      print('Error toggling follow: $e');
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
      print('Error checking follow: $e');
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
      print('Error getting stats: $e');
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
      print('Error getting followers: $e');
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
      print('Error getting following: $e');
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
      print('Error getting followers with status: $e');
      return [];
    }
  }

  /// Get followers with pagination support
  Future<Map<String, dynamic>> getFollowersWithStatusPaginated(
    int userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/followers-with-status/$userId?limit=$limit&offset=$offset'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'data': List<Map<String, dynamic>>.from(data['data'] ?? []),
          'hasMore': data['hasMore'] ?? false,
          'total': data['total'] ?? 0,
        };
      }
      return {'data': [], 'hasMore': false, 'total': 0};
    } catch (e) {
      print('Error getting followers with status (paginated): $e');
      return {'data': [], 'hasMore': false, 'total': 0};
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
      print('Error getting following with status: $e');
      return [];
    }
  }

  /// Get following with pagination support
  Future<Map<String, dynamic>> getFollowingWithStatusPaginated(
    int userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/following-with-status/$userId?limit=$limit&offset=$offset'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'data': List<Map<String, dynamic>>.from(data['data'] ?? []),
          'hasMore': data['hasMore'] ?? false,
          'total': data['total'] ?? 0,
        };
      }
      return {'data': [], 'hasMore': false, 'total': 0};
    } catch (e) {
      print('Error getting following with status (paginated): $e');
      return {'data': [], 'hasMore': false, 'total': 0};
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
      print('Error checking mutual follow: $e');
      return false;
    }
  }

  /// Get mutual friends (users who follow each other)
  /// This represents the "Friends" relationship like TikTok
  Future<Map<String, dynamic>> getMutualFriendsPaginated(
    int userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/mutual-friends/$userId?limit=$limit&offset=$offset'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'data': List<Map<String, dynamic>>.from(data['data'] ?? []),
          'hasMore': data['hasMore'] ?? false,
          'total': data['total'] ?? 0,
        };
      }
      return {'data': [], 'hasMore': false, 'total': 0};
    } catch (e) {
      print('Error getting mutual friends: $e');
      return {'data': [], 'hasMore': false, 'total': 0};
    }
  }

  /// Check if requester can view target user's followers/following/liked list
  /// Returns { allowed: bool, reason?: string }
  Future<Map<String, dynamic>> checkListPrivacy({
    required int targetUserId,
    required int requesterId,
    required String listType, // 'followers', 'following', or 'likedVideos'
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/check-list-privacy/$targetUserId?requesterId=$requesterId&listType=$listType'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'allowed': false, 'reason': 'Error checking privacy'};
    } catch (e) {
      print('Error checking list privacy: $e');
      return {'allowed': false, 'reason': 'Error checking privacy'};
    }
  }

  /// Get suggested users to follow
  /// Returns users based on mutual friends, similar taste, liked content, popularity, etc.
  Future<List<SuggestedUser>> getSuggestions(int userId, {int limit = 15}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/suggestions/$userId?limit=$limit'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((item) => SuggestedUser.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error getting suggestions: $e');
      return [];
    }
  }

  /// Get follow status between two users
  /// Returns: 'none', 'pending', 'following'
  Future<String> getFollowStatus(int followerId, int followingId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/status/$followerId/$followingId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] ?? 'none';
      }
      return 'none';
    } catch (e) {
      print('Error getting follow status: $e');
      return 'none';
    }
  }

  /// Get pending incoming follow requests for a user (paginated)
  Future<Map<String, dynamic>> getPendingRequests(int userId, {int limit = 20, int offset = 0}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/pending-requests/$userId?limit=$limit&offset=$offset'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'data': List<Map<String, dynamic>>.from(data['data'] ?? []),
          'hasMore': data['hasMore'] ?? false,
          'total': data['total'] ?? 0,
        };
      }
      return {'data': [], 'hasMore': false, 'total': 0};
    } catch (e) {
      print('Error getting pending requests: $e');
      return {'data': [], 'hasMore': false, 'total': 0};
    }
  }

  /// Get count of pending follow requests
  Future<int> getPendingRequestCount(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/follows/pending-count/$userId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['count'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting pending count: $e');
      return 0;
    }
  }

  /// Approve a follow request
  Future<bool> approveFollowRequest(int followerId, int followingId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/follows/approve'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'followerId': followerId, 'followingId': followingId}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error approving follow request: $e');
      return false;
    }
  }

  /// Reject a follow request
  Future<bool> rejectFollowRequest(int followerId, int followingId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/follows/reject'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'followerId': followerId, 'followingId': followingId}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error rejecting follow request: $e');
      return false;
    }
  }
}

/// Model for suggested user
class SuggestedUser {
  final int id;
  final String username;
  final String? fullName;
  final String? avatar;
  final int followerCount;
  final int mutualFriendsCount;
  final String reason;
  final List<String> mutualFollowerNames;

  SuggestedUser({
    required this.id,
    required this.username,
    this.fullName,
    this.avatar,
    required this.followerCount,
    required this.mutualFriendsCount,
    required this.reason,
    this.mutualFollowerNames = const [],
  });

  factory SuggestedUser.fromJson(Map<String, dynamic> json) {
    return SuggestedUser(
      id: json['id'] as int,
      username: json['username'] as String,
      fullName: json['fullName'] as String?,
      avatar: json['avatar'] as String?,
      followerCount: json['followerCount'] as int? ?? 0,
      mutualFriendsCount: json['mutualFriendsCount'] as int? ?? 0,
      reason: json['reason'] as String? ?? 'suggested',
      mutualFollowerNames: json['mutualFollowerNames'] != null
          ? List<String>.from(json['mutualFollowerNames'])
          : [],
    );
  }

  /// Get localized reason text (Instagram-style)
  String getReasonText(String Function(String) localize, {bool isVietnamese = true}) {
    switch (reason) {
      case 'mutual_friends':
        if (mutualFollowerNames.isNotEmpty) {
          final firstName = mutualFollowerNames.first;
          if (mutualFollowerNames.length == 1) {
            return isVietnamese 
                ? 'Được $firstName theo dõi'
                : 'Followed by $firstName';
          }
          final othersCount = mutualFollowerNames.length - 1;
          return isVietnamese
              ? 'Được $firstName +$othersCount người theo dõi'
              : 'Followed by $firstName +$othersCount';
        }
        if (mutualFriendsCount == 1) {
          return localize('has_mutual_friend');
        }
        return '$mutualFriendsCount ${localize('mutual_friends')}';
      case 'popular':
        return localize('popular_account');
      case 'similar_taste':
        return isVietnamese ? 'Sở thích tương tự' : 'Similar taste';
      case 'liked_their_content':
        return isVietnamese 
            ? 'Bạn đã thích video của họ'
            : 'You liked their videos';
      case 'friends_and_similar_taste':
        if (mutualFollowerNames.isNotEmpty) {
          final firstName = mutualFollowerNames.first;
          return isVietnamese
              ? 'Được $firstName theo dõi & sở thích chung'
              : 'Followed by $firstName & similar taste';
        }
        return localize('friends_and_similar_taste');
      default:
        return localize('suggested_for_you');
    }
  }
}
