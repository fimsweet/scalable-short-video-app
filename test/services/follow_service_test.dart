import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';

void main() {
  group('FollowService', () {
    late FollowService service;

    setUp(() {
      service = FollowService();
    });

    test('singleton returns same instance', () {
      final a = FollowService();
      final b = FollowService();
      expect(identical(a, b), true);
    });

    group('toggleFollow', () {
      test('handles network error gracefully', () async {
        final result = await service.toggleFollow(1, 2);
        expect(result, isA<Map<String, dynamic>>());
        expect(result['following'], false);
      });
    });

    group('isFollowing', () {
      test('handles network error gracefully', () async {
        final result = await service.isFollowing(1, 2);
        expect(result, false);
      });
    });

    group('getStats', () {
      test('handles network error gracefully', () async {
        final stats = await service.getStats(1);
        expect(stats, isA<Map<String, int>>());
        expect(stats['followerCount'], 0);
        expect(stats['followingCount'], 0);
      });
    });

    group('getFollowers', () {
      test('handles network error gracefully', () async {
        final followers = await service.getFollowers(1);
        expect(followers, isEmpty);
      });
    });

    group('getFollowing', () {
      test('handles network error gracefully', () async {
        final following = await service.getFollowing(1);
        expect(following, isEmpty);
      });
    });

    group('getFollowersWithStatus', () {
      test('handles network error gracefully', () async {
        final result = await service.getFollowersWithStatus(1);
        expect(result, isEmpty);
      });
    });

    group('getFollowersWithStatusPaginated', () {
      test('handles network error gracefully', () async {
        final result = await service.getFollowersWithStatusPaginated(1);
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('getFollowingWithStatus', () {
      test('handles network error gracefully', () async {
        final result = await service.getFollowingWithStatus(1);
        expect(result, isEmpty);
      });
    });

    group('getFollowingWithStatusPaginated', () {
      test('handles network error gracefully', () async {
        final result = await service.getFollowingWithStatusPaginated(1);
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('isMutualFollow', () {
      test('handles network error gracefully', () async {
        final result = await service.isMutualFollow(1, 2);
        expect(result, false);
      });
    });

    group('getMutualFriendsPaginated', () {
      test('handles network error gracefully', () async {
        final result = await service.getMutualFriendsPaginated(1);
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('checkListPrivacy', () {
      test('handles network error gracefully', () async {
        final result = await service.checkListPrivacy(
          targetUserId: 1,
          requesterId: 2,
          listType: 'followers',
        );
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('getSuggestions', () {
      test('handles network error gracefully', () async {
        final result = await service.getSuggestions(1);
        expect(result, isEmpty);
      });
    });

    group('getFollowStatus', () {
      test('handles network error gracefully', () async {
        final result = await service.getFollowStatus(1, 2);
        expect(result, 'none');
      });
    });

    group('getPendingRequests', () {
      test('handles network error gracefully', () async {
        final result = await service.getPendingRequests(1);
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('getPendingRequestCount', () {
      test('handles network error gracefully', () async {
        final result = await service.getPendingRequestCount(1);
        expect(result, 0);
      });
    });

    group('approveFollowRequest', () {
      test('handles network error gracefully', () async {
        final result = await service.approveFollowRequest(1, 2);
        expect(result, false);
      });
    });

    group('rejectFollowRequest', () {
      test('handles network error gracefully', () async {
        final result = await service.rejectFollowRequest(1, 2);
        expect(result, false);
      });
    });
  });

  group('SuggestedUser', () {
    test('creates from JSON', () {
      final json = {
        'id': 1,
        'username': 'testuser',
        'fullName': 'Test User',
        'avatar': 'https://example.com/avatar.jpg',
        'followerCount': 100,
        'mutualFriendsCount': 5,
        'reason': 'mutual_friends',
        'mutualFollowerNames': ['Alice', 'Bob'],
      };
      final user = SuggestedUser.fromJson(json);
      expect(user.id, 1);
      expect(user.username, 'testuser');
      expect(user.fullName, 'Test User');
      expect(user.avatar, 'https://example.com/avatar.jpg');
      expect(user.followerCount, 100);
      expect(user.mutualFriendsCount, 5);
      expect(user.reason, 'mutual_friends');
      expect(user.mutualFollowerNames, ['Alice', 'Bob']);
    });

    test('creates from JSON with minimal data', () {
      final json = {
        'id': 2,
        'username': 'minuser',
      };
      final user = SuggestedUser.fromJson(json);
      expect(user.id, 2);
      expect(user.username, 'minuser');
      expect(user.fullName, isNull);
      expect(user.avatar, isNull);
      expect(user.followerCount, 0);
      expect(user.mutualFriendsCount, 0);
    });

    test('creates from JSON with int types', () {
      final json = {
        'id': 3,
        'username': 'numuser',
        'followerCount': 50,
        'mutualFriendsCount': 3,
        'reason': 'popular',
      };
      final user = SuggestedUser.fromJson(json);
      expect(user.followerCount, 50);
      expect(user.mutualFriendsCount, 3);
    });

    group('getReasonText', () {
      test('returns mutual friends text in Vietnamese', () {
        final user = SuggestedUser.fromJson({
          'id': 1,
          'username': 'test',
          'reason': 'mutual_friends',
          'mutualFriendsCount': 3,
          'mutualFollowerNames': ['Alice'],
        });
        final text = user.getReasonText((key) => key, isVietnamese: true);
        expect(text, isNotEmpty);
      });

      test('returns popular text', () {
        final user = SuggestedUser.fromJson({
          'id': 1,
          'username': 'test',
          'reason': 'popular',
          'followerCount': 1000,
        });
        final text = user.getReasonText((key) => key, isVietnamese: true);
        expect(text, isNotEmpty);
      });

      test('returns similar taste text', () {
        final user = SuggestedUser.fromJson({
          'id': 1,
          'username': 'test',
          'reason': 'similar_taste',
        });
        final text = user.getReasonText((key) => key, isVietnamese: true);
        expect(text, isNotEmpty);
      });

      test('returns liked their content text', () {
        final user = SuggestedUser.fromJson({
          'id': 1,
          'username': 'test',
          'reason': 'liked_their_content',
        });
        final text = user.getReasonText((key) => key, isVietnamese: true);
        expect(text, isNotEmpty);
      });

      test('returns friends and similar taste text', () {
        final user = SuggestedUser.fromJson({
          'id': 1,
          'username': 'test',
          'reason': 'friends_and_similar_taste',
          'mutualFriendsCount': 2,
        });
        final text = user.getReasonText((key) => key, isVietnamese: true);
        expect(text, isNotEmpty);
      });

      test('returns default text for unknown reason', () {
        final user = SuggestedUser.fromJson({
          'id': 1,
          'username': 'test',
          'reason': 'unknown_reason',
        });
        final text = user.getReasonText((key) => key, isVietnamese: true);
        expect(text, isNotEmpty);
      });

      test('returns text in English', () {
        final user = SuggestedUser.fromJson({
          'id': 1,
          'username': 'test',
          'reason': 'mutual_friends',
          'mutualFriendsCount': 5,
          'mutualFollowerNames': ['Alice', 'Bob'],
        });
        final text = user.getReasonText((key) => key, isVietnamese: false);
        expect(text, isNotEmpty);
      });
    });
  });
}
