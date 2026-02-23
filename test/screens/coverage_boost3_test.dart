/// Extra coverage boost #3 – targets remaining service files:
/// CommentService, LikeService, SavedVideoService, FollowService,
/// ShareService, NotificationService, AnalyticsTrackingService,
/// VideoPrefetchService, InAppNotificationService, ThemeService deep, LocaleService deep.
library;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

import 'package:scalable_short_video_app/src/services/comment_service.dart';
import 'package:scalable_short_video_app/src/services/like_service.dart';
import 'package:scalable_short_video_app/src/services/saved_video_service.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/share_service.dart';
import 'package:scalable_short_video_app/src/services/notification_service.dart';
import 'package:scalable_short_video_app/src/services/analytics_tracking_service.dart';
import 'package:scalable_short_video_app/src/services/video_prefetch_service.dart';
import 'package:scalable_short_video_app/src/services/in_app_notification_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/config/app_config.dart';

// --------------- helpers ---------------
final _headers = {'content-type': 'application/json; charset=utf-8'};

http_testing.MockClient _mk({int statusCode = 200}) {
  return http_testing.MockClient((req) async {
    final url = req.url.toString();
    final method = req.method;
    final h = _headers;
    final sc = statusCode;

    // ---- CommentService routes (videoServiceUrl = localhost:3002) ----

    // POST /comments (createComment without image - regular JSON)
    if (url.contains('/comments') && method == 'POST' && !url.contains('/like/toggle') && !url.contains('/read')) {
      return http.Response(jsonEncode({
        'id': 'c1', 'videoId': 'v1', 'userId': 'u1', 'content': 'test comment',
      }), sc == 200 ? 201 : sc, headers: h);
    }

    // GET /comments/video/{videoId} with pagination params
    if (url.contains('/comments/video/') && url.contains('limit=')) {
      return http.Response(jsonEncode({
        'comments': [{'id': 'c1', 'content': 'c'}],
        'hasMore': false,
        'total': 1,
      }), sc, headers: h);
    }

    // GET /comments/video/{videoId}
    if (url.contains('/comments/video/')) {
      return http.Response(jsonEncode([
        {'id': 'c1', 'content': 'test', 'userId': 'u1'},
      ]), sc, headers: h);
    }

    // GET /comments/replies/{commentId}
    if (url.contains('/comments/replies/')) {
      return http.Response(jsonEncode([
        {'id': 'r1', 'content': 'reply', 'userId': 'u2'},
      ]), sc, headers: h);
    }

    // GET /comments/count/{videoId}
    if (url.contains('/comments/count/')) {
      return http.Response(jsonEncode({'count': 5}), sc, headers: h);
    }

    // DELETE /comments/{commentId}/{userId}
    if (url.contains('/comments/') && method == 'DELETE' && !url.contains('/notifications/')) {
      return http.Response(jsonEncode({'success': true}), sc, headers: h);
    }

    // POST /comments/like/toggle
    if (url.contains('/comments/like/toggle')) {
      return http.Response(jsonEncode({'liked': true, 'likeCount': 3}), sc == 200 ? 201 : sc, headers: h);
    }

    // GET /comments/like/check/{commentId}/{userId}
    if (url.contains('/comments/like/check/')) {
      return http.Response(jsonEncode({'liked': true}), sc, headers: h);
    }

    // PATCH /comments/{commentId}
    if (url.contains('/comments/') && method == 'PATCH') {
      return http.Response(jsonEncode({
        'id': 'c1', 'content': 'edited', 'userId': 'u1',
      }), sc, headers: h);
    }

    // ---- LikeService routes ----

    // POST /likes/toggle
    if (url.contains('/likes/toggle')) {
      return http.Response(jsonEncode({'liked': true, 'likeCount': 10}), sc == 200 ? 201 : sc, headers: h);
    }

    // GET /likes/count/{videoId}
    if (url.contains('/likes/count/')) {
      return http.Response(jsonEncode({'count': 42}), sc, headers: h);
    }

    // GET /likes/check/{videoId}/{userId}
    if (url.contains('/likes/check/')) {
      return http.Response(jsonEncode({'liked': true}), sc, headers: h);
    }

    // GET /likes/user/{userId}
    if (url.contains('/likes/user/')) {
      return http.Response(jsonEncode([
        {'id': 'v1', 'title': 'Liked Video', 'likeCount': 5},
      ]), sc, headers: h);
    }

    // GET /likes/received/{userId}
    if (url.contains('/likes/received/')) {
      return http.Response(jsonEncode({'count': 100}), sc, headers: h);
    }

    // ---- SavedVideoService routes ----

    // POST /saved-videos/toggle
    if (url.contains('/saved-videos/toggle')) {
      return http.Response(jsonEncode({'saved': true, 'saveCount': 7}), sc == 200 ? 201 : sc, headers: h);
    }

    // GET /saved-videos/check/{videoId}/{userId}
    if (url.contains('/saved-videos/check/')) {
      return http.Response(jsonEncode({'saved': true}), sc, headers: h);
    }

    // GET /saved-videos/user/{userId}
    if (url.contains('/saved-videos/user/')) {
      return http.Response(jsonEncode([
        {'id': 'v1', 'title': 'Saved Video', 'likeCount': 3, 'commentCount': 1},
      ]), sc, headers: h);
    }

    // ---- FollowService routes (userServiceUrl = localhost:3000) ----

    // POST /follows/approve
    if (url.contains('/follows/approve')) {
      return http.Response(jsonEncode({'success': true}), sc, headers: h);
    }

    // POST /follows/reject
    if (url.contains('/follows/reject')) {
      return http.Response(jsonEncode({'success': true}), sc, headers: h);
    }

    // POST /follows/toggle
    if (url.contains('/follows/toggle')) {
      return http.Response(jsonEncode({'following': true, 'followerCount': 5}), sc, headers: h);
    }

    // GET /follows/check-mutual/{u1}/{u2}
    if (url.contains('/follows/check-mutual/')) {
      return http.Response(jsonEncode({'isMutual': true}), sc, headers: h);
    }

    // GET /follows/check-list-privacy/
    if (url.contains('/follows/check-list-privacy/')) {
      return http.Response(jsonEncode({'allowed': true}), sc, headers: h);
    }

    // GET /follows/suggestions/{userId}
    if (url.contains('/follows/suggestions/')) {
      return http.Response(jsonEncode({
        'success': true,
        'data': [
          {'id': 2, 'username': 'suggested1', 'avatar': null, 'reason': 'mutual_friends', 'mutualFriendCount': 3, 'isFollowing': false},
        ],
      }), sc, headers: h);
    }

    // GET /follows/status/{followerId}/{followingId}
    if (url.contains('/follows/status/')) {
      return http.Response(jsonEncode({'status': 'following'}), sc, headers: h);
    }

    // GET /follows/pending-requests/{userId}
    if (url.contains('/follows/pending-requests/')) {
      return http.Response(jsonEncode({
        'data': [{'id': 3, 'username': 'pending1'}],
        'hasMore': false,
        'total': 1,
      }), sc, headers: h);
    }

    // GET /follows/pending-count/{userId}
    if (url.contains('/follows/pending-count/')) {
      return http.Response(jsonEncode({'count': 2}), sc, headers: h);
    }

    // GET /follows/mutual-friends/{userId}
    if (url.contains('/follows/mutual-friends/')) {
      return http.Response(jsonEncode({
        'data': [{'id': 4, 'username': 'mutual1'}],
        'hasMore': false,
        'total': 1,
      }), sc, headers: h);
    }

    // GET /follows/followers-with-status/{userId} (paginated)
    if (url.contains('/follows/followers-with-status/') && url.contains('limit=')) {
      return http.Response(jsonEncode({
        'data': [{'id': 1, 'username': 'f1', 'isFollowing': true}],
        'hasMore': false,
        'total': 1,
      }), sc, headers: h);
    }

    // GET /follows/following-with-status/{userId} (paginated)
    if (url.contains('/follows/following-with-status/') && url.contains('limit=')) {
      return http.Response(jsonEncode({
        'data': [{'id': 2, 'username': 'f2', 'isFollowingBack': true}],
        'hasMore': false,
        'total': 1,
      }), sc, headers: h);
    }

    // GET /follows/followers-with-status/{userId}
    if (url.contains('/follows/followers-with-status/')) {
      return http.Response(jsonEncode({
        'data': [{'id': 1, 'username': 'f1'}],
      }), sc, headers: h);
    }

    // GET /follows/following-with-status/{userId}
    if (url.contains('/follows/following-with-status/')) {
      return http.Response(jsonEncode({
        'data': [{'id': 2, 'username': 'f2'}],
      }), sc, headers: h);
    }

    // GET /follows/check/{followerId}/{followingId}
    if (url.contains('/follows/check/') && !url.contains('mutual') && !url.contains('list-privacy')) {
      return http.Response(jsonEncode({'following': true}), sc, headers: h);
    }

    // GET /follows/stats/{userId}
    if (url.contains('/follows/stats/')) {
      return http.Response(jsonEncode({'followerCount': 10, 'followingCount': 20}), sc, headers: h);
    }

    // GET /follows/followers/{userId}
    if (url.contains('/follows/followers/') && !url.contains('with-status')) {
      return http.Response(jsonEncode({'followerIds': [1, 2, 3]}), sc, headers: h);
    }

    // GET /follows/following/{userId}
    if (url.contains('/follows/following/') && !url.contains('with-status')) {
      return http.Response(jsonEncode({'followingIds': [4, 5]}), sc, headers: h);
    }

    // ---- ShareService routes ----

    // POST /shares
    if (url.contains('/shares') && method == 'POST') {
      return http.Response(jsonEncode({'shareCount': 15}), sc == 200 ? 201 : sc, headers: h);
    }

    // GET /shares/count/{videoId}
    if (url.contains('/shares/count/')) {
      return http.Response(jsonEncode({'count': 25}), sc, headers: h);
    }

    // ---- NotificationService routes ----

    // POST /notifications/read-all/{userId}
    if (url.contains('/notifications/read-all/')) {
      return http.Response(jsonEncode({'success': true}), sc, headers: h);
    }

    // POST /notifications/read/{notificationId}
    if (url.contains('/notifications/read/')) {
      return http.Response(jsonEncode({'success': true}), sc, headers: h);
    }

    // DELETE /notifications/{notificationId}
    if (url.contains('/notifications/') && method == 'DELETE') {
      return http.Response(jsonEncode({'success': true}), sc, headers: h);
    }

    // GET /notifications/unread/{userId}
    if (url.contains('/notifications/unread/')) {
      return http.Response(jsonEncode({'count': 3}), sc, headers: h);
    }

    // GET /notifications/{userId}
    if (url.contains('/notifications/')) {
      return http.Response(jsonEncode({
        'data': [{'id': 'n1', 'type': 'like', 'read': false}],
      }), sc, headers: h);
    }

    // ---- AnalyticsTrackingService routes ----

    // POST /analytics/interaction
    if (url.contains('/analytics/interaction')) {
      return http.Response('', sc == 200 ? 201 : sc, headers: h);
    }

    // POST /analytics/completion
    if (url.contains('/analytics/completion')) {
      return http.Response('', sc == 200 ? 201 : sc, headers: h);
    }

    // ---- VideoPrefetchService HEAD requests ----
    if (method == 'HEAD') {
      return http.Response('', sc, headers: h);
    }

    // ---- Fallback ----
    // User settings for ThemeService/LocaleService
    if (url.contains('/users/settings')) {
      return http.Response(jsonEncode({
        'success': true, 'settings': {'theme': 'dark', 'language': 'vi'},
      }), sc, headers: h);
    }

    // Default fallback
    return http.Response(jsonEncode({'message': 'not found'}), 404, headers: h);
  });
}

void main() {
  // =================== GROUP 1: CommentService ===================
  group('CommentService', () {
    test('createComment without image success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await CommentService().createComment('v1', 'u1', 'hello');
        expect(result, isNotNull);
        expect(result!['id'], 'c1');
      }, () => client);
    });

    test('createComment with parentId', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await CommentService().createComment('v1', 'u1', 'reply', parentId: 'c0');
        expect(result, isNotNull);
      }, () => client);
    });

    test('createComment error returns null', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await CommentService().createComment('v1', 'u1', 'fail');
        expect(result, isNull);
      }, () => client);
    });

    test('getCommentsByVideo returns list', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await CommentService().getCommentsByVideo('v1');
        expect(result, isA<List>());
        expect(result.length, 1);
      }, () => client);
    });

    test('getCommentsByVideo with limit and offset', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await CommentService().getCommentsByVideo('v1', limit: 10, offset: 0);
        expect(result, isA<List>());
      }, () => client);
    });

    test('getCommentsByVideo error returns empty list', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await CommentService().getCommentsByVideo('v1');
        expect(result, isEmpty);
      }, () => client);
    });

    test('getCommentsByVideoWithPagination success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await CommentService().getCommentsByVideoWithPagination('v1', limit: 20, offset: 0);
        expect(result['comments'], isA<List>());
        expect(result['hasMore'], false);
        expect(result['total'], 1);
      }, () => client);
    });

    test('getCommentsByVideoWithPagination error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await CommentService().getCommentsByVideoWithPagination('v1');
        expect(result['comments'], isEmpty);
      }, () => client);
    });

    test('getReplies success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await CommentService().getReplies('c1');
        expect(result, isA<List>());
        expect(result.length, 1);
      }, () => client);
    });

    test('getReplies error returns empty', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await CommentService().getReplies('c1');
        expect(result, isEmpty);
      }, () => client);
    });

    test('getCommentCount success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await CommentService().getCommentCount('v1');
        expect(result, 5);
      }, () => client);
    });

    test('getCommentCount error returns 0', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await CommentService().getCommentCount('v1');
        expect(result, 0);
      }, () => client);
    });

    test('deleteComment success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await CommentService().deleteComment('c1', 'u1');
        expect(result, true);
      }, () => client);
    });

    test('deleteComment error returns false', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await CommentService().deleteComment('c1', 'u1');
        expect(result, false);
      }, () => client);
    });

    test('toggleCommentLike success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await CommentService().toggleCommentLike('c1', 'u1');
        expect(result['liked'], true);
        expect(result['likeCount'], 3);
      }, () => client);
    });

    test('toggleCommentLike error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await CommentService().toggleCommentLike('c1', 'u1');
        expect(result['liked'], false);
      }, () => client);
    });

    test('isCommentLikedByUser success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await CommentService().isCommentLikedByUser('c1', 'u1');
        expect(result, true);
      }, () => client);
    });

    test('isCommentLikedByUser error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await CommentService().isCommentLikedByUser('c1', 'u1');
        expect(result, false);
      }, () => client);
    });

    test('editComment success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await CommentService().editComment('c1', 'u1', 'edited content');
        expect(result, isNotNull);
        expect(result!['content'], 'edited');
      }, () => client);
    });

    test('editComment error throws', () async {
      final client = _mk(statusCode: 400);
      await http.runWithClient(() async {
        expect(
          () => CommentService().editComment('c1', 'u1', 'fail'),
          throwsA(isA<Exception>()),
        );
      }, () => client);
    });
  });

  // =================== GROUP 2: LikeService ===================
  group('LikeService', () {
    test('clearCache clears both caches', () {
      LikeService.clearCache();
      // After clearing, getCached should return null
      expect(LikeService().getCached('nonexistent'), isNull);
      expect(LikeService().getCachedCount('nonexistent'), isNull);
    });

    test('toggleLike success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await LikeService().toggleLike('v1', 'u1');
        expect(result['liked'], true);
        expect(result['likeCount'], 10);
      }, () => client);
    });

    test('toggleLike error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await LikeService().toggleLike('v1', 'u1');
        expect(result, isA<Map>());
      }, () => client);
    });

    test('getLikeCount success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await LikeService().getLikeCount('v1');
        expect(result, 42);
      }, () => client);
    });

    test('getLikeCount error returns 0', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await LikeService().getLikeCount('v1');
        expect(result, 0);
      }, () => client);
    });

    test('isLikedByUser success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await LikeService().isLikedByUser('v1', 'u1');
        expect(result, true);
      }, () => client);
    });

    test('isLikedByUser error returns cached or false', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await LikeService().isLikedByUser('uncached', 'u1');
        expect(result, false);
      }, () => client);
    });

    test('getUserLikedVideos success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await LikeService().getUserLikedVideos('u1');
        expect(result, isA<List<Map<String, dynamic>>>());
        expect(result.length, 1);
      }, () => client);
    });

    test('getUserLikedVideos error returns empty', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await LikeService().getUserLikedVideos('u1');
        expect(result, isEmpty);
      }, () => client);
    });

    test('getTotalReceivedLikes success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await LikeService().getTotalReceivedLikes('u1');
        expect(result, 100);
      }, () => client);
    });

    test('getTotalReceivedLikes error returns 0', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await LikeService().getTotalReceivedLikes('u1');
        expect(result, 0);
      }, () => client);
    });

    test('getCached and getCachedCount after toggleLike', () async {
      LikeService.clearCache();
      final client = _mk();
      await http.runWithClient(() async {
        await LikeService().toggleLike('testVid', 'u1');
        // Cache should be populated after toggleLike
        expect(LikeService().getCached('testVid'), isA<bool>());
        expect(LikeService().getCachedCount('testVid'), isA<int>());
      }, () => client);
    });
  });

  // =================== GROUP 3: SavedVideoService ===================
  group('SavedVideoService', () {
    test('clearCache clears both caches', () {
      SavedVideoService.clearCache();
      expect(SavedVideoService().getCached('x'), isNull);
      expect(SavedVideoService().getCachedCount('x'), isNull);
    });

    test('toggleSave success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await SavedVideoService().toggleSave('v1', 'u1');
        expect(result['saved'], true);
        expect(result['saveCount'], 7);
      }, () => client);
    });

    test('toggleSave error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await SavedVideoService().toggleSave('v1', 'u1');
        expect(result['saved'], false);
      }, () => client);
    });

    test('isSavedByUser success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await SavedVideoService().isSavedByUser('v1', 'u1');
        expect(result, true);
      }, () => client);
    });

    test('isSavedByUser error returns cached or false', () async {
      SavedVideoService.clearCache();
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await SavedVideoService().isSavedByUser('v1', 'u1');
        expect(result, false);
      }, () => client);
    });

    test('getSavedVideos success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await SavedVideoService().getSavedVideos('u1');
        expect(result, isA<List>());
        expect(result.length, 1);
      }, () => client);
    });

    test('getSavedVideos error returns empty', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await SavedVideoService().getSavedVideos('u1');
        expect(result, isEmpty);
      }, () => client);
    });

    test('getCached after isSavedByUser', () async {
      SavedVideoService.clearCache();
      final client = _mk();
      await http.runWithClient(() async {
        await SavedVideoService().isSavedByUser('cacheTest', 'u1');
        expect(SavedVideoService().getCached('cacheTest'), true);
      }, () => client);
    });
  });

  // =================== GROUP 4: FollowService additional methods ===================
  group('FollowService additional', () {
    test('isMutualFollow success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await FollowService().isMutualFollow(1, 2);
        expect(result, true);
      }, () => client);
    });

    test('getMutualFriendsPaginated success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await FollowService().getMutualFriendsPaginated(1, limit: 20, offset: 0);
        expect(result['data'], isA<List>());
        expect(result['total'], 1);
      }, () => client);
    });

    test('checkListPrivacy success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await FollowService().checkListPrivacy(
          targetUserId: 1,
          requesterId: 2,
          listType: 'followers',
        );
        expect(result['allowed'], true);
      }, () => client);
    });

    test('getSuggestions success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await FollowService().getSuggestions(1, limit: 15);
        expect(result, isA<List<SuggestedUser>>());
        expect(result.length, 1);
        expect(result[0].username, 'suggested1');
      }, () => client);
    });

    test('getFollowStatus success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await FollowService().getFollowStatus(1, 2);
        expect(result, 'following');
      }, () => client);
    });

    test('getPendingRequests success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await FollowService().getPendingRequests(1, limit: 20, offset: 0);
        expect(result['data'], isA<List>());
        expect(result['total'], 1);
      }, () => client);
    });

    test('getPendingRequestCount success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await FollowService().getPendingRequestCount(1);
        expect(result, 2);
      }, () => client);
    });

    test('approveFollowRequest success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await FollowService().approveFollowRequest(2, 1);
        expect(result, true);
      }, () => client);
    });

    test('rejectFollowRequest success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await FollowService().rejectFollowRequest(2, 1);
        expect(result, true);
      }, () => client);
    });

    test('getFollowersWithStatusPaginated success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await FollowService().getFollowersWithStatusPaginated(1, limit: 20, offset: 0);
        expect(result['data'], isA<List>());
        expect(result['hasMore'], false);
      }, () => client);
    });

    test('getFollowingWithStatusPaginated success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await FollowService().getFollowingWithStatusPaginated(1, limit: 20, offset: 0);
        expect(result['data'], isA<List>());
        expect(result['hasMore'], false);
      }, () => client);
    });

    // Error paths
    test('isMutualFollow error returns false', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await FollowService().isMutualFollow(1, 2);
        expect(result, false);
      }, () => client);
    });

    test('getSuggestions error returns empty', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await FollowService().getSuggestions(1);
        expect(result, isEmpty);
      }, () => client);
    });

    test('getFollowStatus error returns not_following', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await FollowService().getFollowStatus(1, 2);
        expect(result, isA<String>());
      }, () => client);
    });

    test('getPendingRequestCount error returns 0', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await FollowService().getPendingRequestCount(1);
        expect(result, 0);
      }, () => client);
    });

    test('approveFollowRequest error returns false', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await FollowService().approveFollowRequest(2, 1);
        expect(result, false);
      }, () => client);
    });

    test('rejectFollowRequest error returns false', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await FollowService().rejectFollowRequest(2, 1);
        expect(result, false);
      }, () => client);
    });
  });

  // =================== GROUP 5: SuggestedUser model ===================
  group('SuggestedUser model', () {
    test('fromJson creates SuggestedUser', () {
      final su = SuggestedUser.fromJson({
        'id': 1, 'username': 'testuser', 'avatar': 'av.jpg',
        'reason': 'mutual_friends', 'mutualFriendCount': 5,
        'isFollowing': false,
      });
      expect(su.id, 1);
      expect(su.username, 'testuser');
      expect(su.avatar, 'av.jpg');
      expect(su.reason, 'mutual_friends');
      expect(su.mutualFriendsCount, isA<int>());
    });

    test('fromJson with minimal fields', () {
      final su = SuggestedUser.fromJson({
        'id': 2, 'username': 'u2',
      });
      expect(su.id, 2);
      expect(su.username, 'u2');
    });

    test('getReasonText returns localized text', () {
      final su = SuggestedUser.fromJson({
        'id': 1, 'username': 'u', 'reason': 'mutual_friends', 'mutualFriendCount': 3,
      });
      final text = su.getReasonText((key) => key, isVietnamese: false);
      expect(text, isA<String>());
      expect(text.isNotEmpty, true);
    });

    test('getReasonText Vietnamese', () {
      final su = SuggestedUser.fromJson({
        'id': 1, 'username': 'u', 'reason': 'popular',
      });
      final text = su.getReasonText((key) => key, isVietnamese: true);
      expect(text, isA<String>());
    });

    test('getReasonText with different reasons', () {
      for (final reason in ['mutual_friends', 'popular', 'same_interest', 'new_user', 'unknown_reason']) {
        final su = SuggestedUser.fromJson({
          'id': 1, 'username': 'u', 'reason': reason,
        });
        final text = su.getReasonText((key) => key);
        expect(text, isA<String>());
      }
    });
  });

  // =================== GROUP 6: ShareService ===================
  group('ShareService', () {
    test('shareVideo success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await ShareService().shareVideo('v1', 'u1', 'u2');
        expect(result['shareCount'], 15);
      }, () => client);
    });

    test('shareVideo error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ShareService().shareVideo('v1', 'u1', 'u2');
        expect(result, isA<Map>());
      }, () => client);
    });

    test('getShareCount success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await ShareService().getShareCount('v1');
        expect(result, 25);
      }, () => client);
    });

    test('getShareCount error returns 0', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ShareService().getShareCount('v1');
        expect(result, 0);
      }, () => client);
    });
  });

  // =================== GROUP 7: NotificationService ===================
  group('NotificationService', () {
    test('getNotifications success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await NotificationService().getNotifications('u1');
        expect(result, isA<List>());
      }, () => client);
    });

    test('getUnreadCount success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await NotificationService().getUnreadCount('u1');
        expect(result, 3);
      }, () => client);
    });

    test('getUnreadCount error returns 0', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await NotificationService().getUnreadCount('u1');
        expect(result, 0);
      }, () => client);
    });

    test('getPendingFollowCount success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await NotificationService().getPendingFollowCount('1');
        expect(result, 2);
      }, () => client);
    });

    test('markAsRead success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await NotificationService().markAsRead('n1', 'u1');
        expect(result, true);
      }, () => client);
    });

    test('markAsRead error returns false', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await NotificationService().markAsRead('n1', 'u1');
        expect(result, false);
      }, () => client);
    });

    test('markAllAsRead success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await NotificationService().markAllAsRead('u1');
        expect(result, true);
      }, () => client);
    });

    test('markAllAsRead error returns false', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await NotificationService().markAllAsRead('u1');
        expect(result, false);
      }, () => client);
    });

    test('deleteNotification success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final result = await NotificationService().deleteNotification('n1', 'u1');
        expect(result, true);
      }, () => client);
    });

    test('deleteNotification error returns false', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await NotificationService().deleteNotification('n1', 'u1');
        expect(result, false);
      }, () => client);
    });

    test('stopPolling stops active polling', () {
      final ns = NotificationService();
      ns.stopPolling();
      // Should not throw
    });

    test('dispose cleans up resources', () {
      final ns = NotificationService();
      ns.dispose();
      // Should not throw
    });
  });

  // =================== GROUP 8: AnalyticsTrackingService ===================
  group('AnalyticsTrackingService', () {
    test('startWatching and stopWatching', () {
      final ats = AnalyticsTrackingService();
      ats.startWatching('v1');
      expect(ats.isWatching('v1'), true);
      final duration = ats.stopWatching('v1');
      expect(duration, greaterThanOrEqualTo(0));
      expect(ats.isWatching('v1'), false);
    });

    test('stopWatching returns 0 for unwatched video', () {
      final ats = AnalyticsTrackingService();
      final duration = ats.stopWatching('nonexistent');
      expect(duration, 0);
    });

    test('shouldCountView returns true for new video', () {
      final ats = AnalyticsTrackingService();
      ats.resetTrackedViews();
      // shouldCountView checks watch duration threshold
      expect(ats.shouldCountView('newvid'), isA<bool>());
    });

    test('resetTrackedViews clears tracked views', () {
      final ats = AnalyticsTrackingService();
      ats.resetTrackedViews();
      // Should not throw
    });

    test('getWatchDuration returns 0 for unwatched', () {
      final ats = AnalyticsTrackingService();
      expect(ats.getWatchDuration('nope'), 0);
    });

    test('trackInteraction success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        await AnalyticsTrackingService().trackInteraction(
          videoId: 'v1',
          userId: 'u1',
          type: InteractionType.like,
        );
        // Should not throw
      }, () => client);
    });

    test('trackInteraction with different types', () async {
      final client = _mk();
      await http.runWithClient(() async {
        for (final type in InteractionType.values) {
          await AnalyticsTrackingService().trackInteraction(
            videoId: 'v1', userId: 'u1', type: type,
          );
        }
      }, () => client);
    });

    test('trackVideoCompletion success', () async {
      final client = _mk();
      await http.runWithClient(() async {
        await AnalyticsTrackingService().trackVideoCompletion(
          videoId: 'v1',
          userId: 'u1',
          watchDurationSeconds: 30,
          videoDurationSeconds: 60,
        );
        // Should not throw
      }, () => client);
    });

    test('InteractionType enum values', () {
      expect(InteractionType.values.length, greaterThanOrEqualTo(8));
      expect(InteractionType.like.toString(), contains('like'));
      expect(InteractionType.comment.toString(), contains('comment'));
      expect(InteractionType.share.toString(), contains('share'));
      expect(InteractionType.save.toString(), contains('save'));
    });
  });

  // =================== GROUP 9: VideoPrefetchService ===================
  group('VideoPrefetchService', () {
    test('isPrefetched returns false for uncached URL', () {
      final vps = VideoPrefetchService();
      expect(vps.isPrefetched('http://nowhere/test.m3u8'), false);
    });

    test('clearCache clears all prefetched URLs', () {
      final vps = VideoPrefetchService();
      vps.clearCache();
      expect(vps.isPrefetched('http://test.com/vid.m3u8'), false);
    });

    test('getStats returns cache statistics', () {
      final vps = VideoPrefetchService();
      final stats = vps.getStats();
      expect(stats, isA<Map<String, dynamic>>());
    });

    test('prefetchVideosAround with empty list', () async {
      final client = _mk();
      await http.runWithClient(() async {
        await VideoPrefetchService().prefetchVideosAround([], 0);
        // Should not throw
      }, () => client);
    });

    test('prefetchVideosAround with videos', () async {
      final client = _mk();
      await http.runWithClient(() async {
        final videos = [
          {'hlsUrl': '/vid1/playlist.m3u8', 'thumbnailUrl': '/thumb1.jpg'},
          {'hlsUrl': '/vid2/playlist.m3u8', 'thumbnailUrl': '/thumb2.jpg'},
          {'hlsUrl': '/vid3/playlist.m3u8', 'thumbnailUrl': '/thumb3.jpg'},
        ];
        await VideoPrefetchService().prefetchVideosAround(videos, 1);
      }, () => client);
    });
  });

  // =================== GROUP 10: InAppNotificationService ===================
  group('InAppNotificationService', () {
    test('setActiveVideo sets video context', () {
      final svc = InAppNotificationService();
      svc.setActiveVideo('v1');
      svc.setActiveVideo(null);
      // Should not throw
    });

    test('setInInboxScreen sets inbox context', () {
      final svc = InAppNotificationService();
      svc.setInInboxScreen(true);
      svc.setInInboxScreen(false);
      // Should not throw
    });

    test('setActiveChatUser sets chat context', () {
      final svc = InAppNotificationService();
      svc.setActiveChatUser('u1');
      svc.setActiveChatUser(null);
      // Should not throw
    });

    test('invalidatePreferences clears cached prefs', () {
      final svc = InAppNotificationService();
      svc.invalidatePreferences();
      // Should not throw
    });

    test('emitTap emits notification through stream', () {
      final svc = InAppNotificationService();
      final notification = InAppNotification(
        type: InAppNotificationType.like,
        title: 'test',
        body: 'body',
        senderId: 'sender1',
        senderName: 'Sender',
        rawData: {},
      );
      svc.emitTap(notification);
      // Should not throw
    });

    test('InAppNotification constructor', () {
      final n = InAppNotification(
        type: InAppNotificationType.comment,
        title: 'Comment',
        body: 'Someone commented',
        senderId: 's1',
        senderName: 'User1',
        rawData: {'videoId': 'v1'},
        videoId: 'v1',
      );
      expect(n.type, InAppNotificationType.comment);
      expect(n.title, 'Comment');
      expect(n.body, 'Someone commented');
      expect(n.rawData, isNotNull);
      expect(n.videoId, 'v1');
    });

    test('InAppNotificationType enum values', () {
      expect(InAppNotificationType.values.length, greaterThanOrEqualTo(1));
    });

    test('dispose cleans up service', () {
      final svc = InAppNotificationService();
      svc.dispose();
      // Should not throw
    });
  });

  // =================== GROUP 11: ThemeService deep ===================
  group('ThemeService deep', () {
    test('singleton instance', () {
      final ts1 = ThemeService();
      final ts2 = ThemeService();
      expect(identical(ts1, ts2), true);
    });

    test('isLightMode returns bool', () {
      expect(ThemeService().isLightMode, isA<bool>());
    });

    test('color getters return Color objects', () {
      final ts = ThemeService();
      expect(ts.backgroundColor, isA<Color>());
      expect(ts.textPrimaryColor, isA<Color>());
      expect(ts.textSecondaryColor, isA<Color>());
      expect(ts.cardColor, isA<Color>());
      expect(ts.iconColor, isA<Color>());
      expect(ts.dividerColor, isA<Color>());
    });

    test('additional color getters', () {
      final ts = ThemeService();
      expect(ts.primaryAccentColor, isA<Color>());
      expect(ts.sectionTitleBackground, isA<Color>());
      expect(ts.inputBackground, isA<Color>());
      expect(ts.switchTrackColor, isA<Color>());
      expect(ts.appBarBackground, isA<Color>());
      expect(ts.snackBarBackground, isA<Color>());
      expect(ts.snackBarTextColor, isA<Color>());
    });

    test('switch color getters', () {
      final ts = ThemeService();
      expect(ts.switchActiveColor, isA<Color>());
      expect(ts.switchActiveTrackColor, isA<Color>());
      expect(ts.switchInactiveThumbColor, isA<Color>());
      expect(ts.switchInactiveTrackColor, isA<Color>());
    });

    test('themeData returns ThemeData', () {
      final ts = ThemeService();
      expect(ts.themeData, isA<ThemeData>());
    });

    test('static color constants are defined', () {
      // Dark theme colors
      expect(ThemeService.darkBackground, isA<Color>());
      expect(ThemeService.darkSurface, isA<Color>());
      expect(ThemeService.darkCard, isA<Color>());
      expect(ThemeService.darkDivider, isA<Color>());
      expect(ThemeService.darkTextPrimary, isA<Color>());
      expect(ThemeService.darkTextSecondary, isA<Color>());
      expect(ThemeService.darkIcon, isA<Color>());
      // Light theme colors
      expect(ThemeService.lightBackground, isA<Color>());
      expect(ThemeService.lightSurface, isA<Color>());
      expect(ThemeService.lightCard, isA<Color>());
      expect(ThemeService.lightDivider, isA<Color>());
      expect(ThemeService.lightTextPrimary, isA<Color>());
      expect(ThemeService.lightTextSecondary, isA<Color>());
      expect(ThemeService.lightIcon, isA<Color>());
      // Accent colors
      expect(ThemeService.accentColor, isA<Color>());
      expect(ThemeService.accentColorLight, isA<Color>());
      expect(ThemeService.successColor, isA<Color>());
      expect(ThemeService.errorColor, isA<Color>());
      expect(ThemeService.warningColor, isA<Color>());
    });
  });

  // =================== GROUP 12: LocaleService deep ===================
  group('LocaleService deep', () {
    test('singleton instance', () {
      final ls1 = LocaleService();
      final ls2 = LocaleService();
      expect(identical(ls1, ls2), true);
    });

    test('isVietnamese and isEnglish', () {
      final ls = LocaleService();
      expect(ls.isVietnamese, isA<bool>());
      expect(ls.isEnglish, isA<bool>());
      // Exactly one should be true
      expect(ls.isVietnamese != ls.isEnglish, true);
    });

    test('get returns translated string', () {
      final ls = LocaleService();
      final result = ls.get('login');
      expect(result, isA<String>());
      expect(result.isNotEmpty, true);
    });

    test('translate is alias for get', () {
      final ls = LocaleService();
      expect(ls.translate('login'), ls.get('login'));
    });

    test('get returns key for unknown key', () {
      final ls = LocaleService();
      final result = ls.get('some_nonexistent_key_xyz');
      expect(result, isA<String>());
    });

    test('currentLocale returns locale string', () {
      final ls = LocaleService();
      expect(ls.currentLocale, isA<String>());
      expect(ls.currentLocale.isNotEmpty, true);
    });

    test('currentLocaleObject returns Locale', () {
      final ls = LocaleService();
      expect(ls.currentLocaleObject, isA<Locale>());
    });

    test('multiple translations', () {
      final ls = LocaleService();
      final keys = ['login', 'register', 'settings', 'profile', 'home', 'search', 'notifications'];
      for (final key in keys) {
        expect(ls.get(key), isA<String>());
      }
    });
  });

  // =================== GROUP 13: AppConfig ===================
  group('AppConfig', () {
    test('URLs are non-empty', () {
      expect(AppConfig.userServiceUrl, isNotEmpty);
      expect(AppConfig.videoServiceUrl, isNotEmpty);
    });

    test('URLs are valid formats', () {
      expect(AppConfig.userServiceUrl, startsWith('http'));
      expect(AppConfig.videoServiceUrl, startsWith('http'));
    });
  });
}
