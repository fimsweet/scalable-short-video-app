import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Creates a MockClient that returns success responses for known API patterns.
/// This allows screens to render data states (not just loading/error states),
/// dramatically increasing code coverage.
http.Client createMockHttpClient() {
  return MockClient((request) async {
    final path = request.url.path;
    final method = request.method;

    // ========================
    // USER SERVICE ENDPOINTS
    // ========================

    // GET /users/id/{id}
    if (path.contains('/users/id/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'id': 1,
          'username': 'testuser',
          'fullName': 'Test User',
          'avatar': null,
          'bio': 'Test bio',
          'gender': 'male',
          'dateOfBirth': '2000-01-01T00:00:00.000Z',
          'isDeactivated': false,
          'phoneNumber': '+1234567890',
          'authProvider': 'email',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /users/has-password
    if (path.contains('/users/has-password') && method == 'GET') {
      return http.Response(
        jsonEncode({'hasPassword': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /users/settings
    if (path.contains('/users/settings') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'success': true,
          'settings': {
            'accountPrivacy': 'public',
            'requireFollowApproval': false,
            'showOnlineStatus': true,
            'language': 'en',
            'whoCanSendMessages': 'everyone',
            'whoCanComment': 'everyone',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // PUT /users/settings
    if (path.contains('/users/settings') && method == 'PUT') {
      return http.Response(
        jsonEncode({'success': true, 'message': 'Settings updated'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /users/search
    if (path.contains('/users/search') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'success': true,
          'users': [
            {
              'id': 2,
              'username': 'searchuser',
              'avatar': null,
              'displayName': 'Search User',
              'fullName': 'Search User',
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /users/blocked/{id}/check/{id}
    if (path.contains('/users/blocked/') &&
        path.contains('/check/') &&
        method == 'GET') {
      return http.Response(
        jsonEncode({'isBlocked': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /users/{id}/online-status
    if (path.contains('/online-status') && method == 'GET') {
      return http.Response(
        jsonEncode({'isOnline': true, 'statusText': 'Online'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /users/privacy/check
    if (path.contains('/users/privacy/check') && method == 'POST') {
      return http.Response(
        jsonEncode({'allowed': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /users/blocked
    if (path.contains('/users/blocked') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'data': <Map<String, dynamic>>[],
          'total': 0,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // AUTH ENDPOINTS
    // ========================

    // POST /auth/login
    if (path.contains('/auth/login') && method == 'POST') {
      return http.Response(
        jsonEncode({
          'user': {
            'id': 1,
            'username': 'testuser',
            'email': 'test@example.com',
            'avatar': null,
            'bio': 'Test bio',
            'fullName': 'Test User',
          },
          'access_token': 'fake-jwt-token',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /auth/register
    if (path.contains('/auth/register') && method == 'POST') {
      return http.Response(
        jsonEncode({
          'user': {
            'id': 1,
            'username': 'newuser',
            'email': 'new@example.com',
          },
          'access_token': 'fake-jwt-token',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /auth/account-info
    if (path.contains('/auth/account-info') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'email': 'test@example.com',
          'phoneNumber': '+1234567890',
          'authProvider': 'email',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /auth/2fa/settings
    if (path.contains('/auth/2fa/settings') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'enabled': false,
          'methods': ['email'],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /auth/2fa/*
    if (path.contains('/auth/2fa/') && method == 'POST') {
      return http.Response(
        jsonEncode({'success': true, 'message': '2FA action completed'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /auth/forgot-password
    if (path.contains('/auth/forgot-password') && method == 'POST') {
      return http.Response(
        jsonEncode({'success': true, 'message': 'OTP sent'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /auth/verify-reset-otp
    if (path.contains('/auth/verify-reset-otp') && method == 'POST') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /auth/reset-password
    if (path.contains('/auth/reset-password') && method == 'POST') {
      return http.Response(
        jsonEncode({'success': true, 'message': 'Password reset'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /auth/change-password
    if (path.contains('/auth/change-password') && method == 'POST') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /auth/check-username
    if (path.contains('/auth/check-username') && method == 'POST') {
      return http.Response(
        jsonEncode({'available': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /auth/check-email
    if (path.contains('/auth/check-email') && method == 'POST') {
      return http.Response(
        jsonEncode({'available': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // FOLLOW ENDPOINTS
    // ========================

    // GET /follows/stats/{userId}
    if (path.contains('/follows/stats/') && method == 'GET') {
      return http.Response(
        jsonEncode({'followerCount': 100, 'followingCount': 50}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /follows/status/{id}/{id}
    if (path.contains('/follows/status/') && method == 'GET') {
      return http.Response(
        jsonEncode({'status': 'none'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /follows/check/
    if (path.contains('/follows/check/') && method == 'GET') {
      return http.Response(
        jsonEncode({'following': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /follows/check-mutual/
    if (path.contains('/follows/check-mutual/') && method == 'GET') {
      return http.Response(
        jsonEncode({'isMutual': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /follows/pending-count/{id}
    if (path.contains('/follows/pending-count/') && method == 'GET') {
      return http.Response(
        jsonEncode({'count': 0}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /follows/pending-requests/{id}
    if (path.contains('/follows/pending-requests/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'data': <Map<String, dynamic>>[],
          'hasMore': false,
          'total': 0,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /follows/followers-with-status/{id}
    if (path.contains('/follows/followers-with-status/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 2,
              'username': 'follower1',
              'avatar': null,
              'isFollowingBack': true,
            }
          ],
          'hasMore': false,
          'total': 1,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /follows/following-with-status/{id}
    if (path.contains('/follows/following-with-status/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 3,
              'username': 'following1',
              'avatar': null,
            }
          ],
          'hasMore': false,
          'total': 1,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /follows/mutual-friends/{id}
    if (path.contains('/follows/mutual-friends/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'data': <Map<String, dynamic>>[],
          'hasMore': false,
          'total': 0,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /follows/check-list-privacy/
    if (path.contains('/follows/check-list-privacy/') && method == 'GET') {
      return http.Response(
        jsonEncode({'allowed': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /follows
    if (path.contains('/follows') && method == 'POST') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // DELETE /follows
    if (path.contains('/follows') && method == 'DELETE') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // SESSION ENDPOINTS
    // ========================

    // GET /sessions
    if (path.contains('/sessions') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 1,
              'deviceName': 'Windows PC',
              'platform': 'windows',
              'ipAddress': '127.0.0.1',
              'isCurrent': true,
              'lastActive': '2026-01-01T00:00:00.000Z',
              'createdAt': '2026-01-01T00:00:00.000Z',
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // ACTIVITY HISTORY
    // ========================

    // GET /activity-history/{id}
    if (path.contains('/activity-history/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'activities': [
            {
              'id': 1,
              'actionType': 'like',
              'targetId': 'vid-1',
              'targetType': 'video',
              'createdAt': '2026-02-20T10:00:00Z',
            },
            {
              'id': 2,
              'actionType': 'comment',
              'targetId': 'vid-2',
              'targetType': 'video',
              'createdAt': '2026-02-19T10:00:00Z',
            },
          ],
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // REPORT ENDPOINTS
    // ========================
    if (path.contains('/reports') && method == 'POST') {
      return http.Response(
        jsonEncode({'success': true, 'message': 'Report submitted'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // VIDEO SERVICE ENDPOINTS
    // ========================

    // GET /analytics/{userId}
    if (path.contains('/analytics/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'success': true,
          'analytics': {
            'totalViews': 1500,
            'totalLikes': 320,
            'totalComments': 45,
            'totalVideos': 10,
            'followerCount': 100,
            'followingCount': 50,
            'videos': [
              {
                'id': 'vid-1',
                'title': 'My Video',
                'viewCount': 500,
                'likeCount': 100,
                'createdAt': '2026-01-15T08:00:00Z',
              }
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /videos/{id}/view
    if (path.contains('/videos/') &&
        path.endsWith('/view') &&
        method == 'POST') {
      return http.Response(
        jsonEncode({'viewCount': 123}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /videos/user/{userId}
    if (path.contains('/videos/user/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 'vid-1',
              'userId': 1,
              'title': 'Test Video',
              'hlsUrl': '/uploads/processed_videos/vid-1/playlist.m3u8',
              'thumbnailUrl': '/uploads/thumbnails/vid-1.jpg',
              'status': 'ready',
              'isHidden': false,
              'likeCount': 10,
              'commentCount': 5,
              'viewCount': 100,
              'createdAt': '2026-01-15T08:00:00Z',
            }
          ],
          'privacyRestricted': false,
          'reason': null,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /videos/feed/all or /videos/feed/following or /videos/feed/friends
    if (path.contains('/videos/feed/') && method == 'GET') {
      return http.Response(
        jsonEncode([
          {
            'id': 'vid-1',
            'title': 'Feed Video',
            'hlsUrl': '/uploads/processed_videos/vid-1/playlist.m3u8',
            'thumbnailUrl': '/uploads/thumbnails/vid-1.jpg',
            'userId': 1,
            'viewCount': 100,
            'likeCount': 20,
            'commentCount': 5,
            'createdAt': '2026-02-20T10:00:00Z',
          }
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /videos/search
    if (path.contains('/videos/search') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'success': true,
          'videos': [
            {
              'id': 'vid-1',
              'title': 'Search Result Video',
              'userId': 1,
              'viewCount': 100,
              'likeCount': 20,
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /videos/trending
    if (path.contains('/videos/trending') && method == 'GET') {
      return http.Response(
        jsonEncode([
          {
            'id': 'vid-t1',
            'title': 'Trending',
            'hlsUrl': '/uploads/processed_videos/vid-t1/playlist.m3u8',
            'userId': 1,
            'viewCount': 1000,
            'likeCount': 200,
          }
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /videos/recommended
    if (path.contains('/videos/recommended') && method == 'GET') {
      return http.Response(
        jsonEncode([
          {
            'id': 'vid-r1',
            'title': 'Recommended',
            'hlsUrl': '/uploads/processed_videos/vid-r1/playlist.m3u8',
            'userId': 1,
            'viewCount': 500,
            'likeCount': 100,
          }
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /videos/{id} - single video
    if (RegExp(r'/videos/[^/]+$').hasMatch(path) && method == 'GET') {
      return http.Response(
        jsonEncode({
          'id': 'vid-1',
          'title': 'Single Video',
          'hlsUrl': '/uploads/processed_videos/vid-1/playlist.m3u8',
          'userId': 1,
          'viewCount': 100,
          'status': 'ready',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // PUT/PATCH /videos/{id}
    if (path.contains('/videos/') &&
        (method == 'PUT' || method == 'PATCH')) {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // DELETE /videos/{id}
    if (path.contains('/videos/') && method == 'DELETE') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // LIKES ENDPOINTS
    // ========================

    // GET /likes/check/{videoId}/{userId}
    if (path.contains('/likes/check/') && method == 'GET') {
      return http.Response(
        jsonEncode({'liked': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /likes/received/{userId}
    if (path.contains('/likes/received/') && method == 'GET') {
      return http.Response(
        jsonEncode({'count': 42}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /likes
    if (path.contains('/likes') && method == 'POST') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // DELETE /likes
    if (path.contains('/likes') && method == 'DELETE') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // COMMENTS ENDPOINTS
    // ========================

    // GET /comments/{videoId}
    if (path.contains('/comments/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 'c1',
              'userId': 2,
              'username': 'commenter',
              'avatar': null,
              'content': 'Nice video!',
              'createdAt': '2026-02-20T10:00:00Z',
              'likeCount': 5,
              'replyCount': 1,
            }
          ],
          'total': 1,
          'hasMore': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /comments
    if (path.contains('/comments') && method == 'POST') {
      return http.Response(
        jsonEncode({
          'id': 'c-new',
          'content': 'Test comment',
          'userId': 1,
          'createdAt': '2026-02-20T10:00:00Z',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // SAVED VIDEOS ENDPOINTS
    // ========================

    // GET /saved-videos/check/{videoId}/{userId}
    if (path.contains('/saved-videos/check/') && method == 'GET') {
      return http.Response(
        jsonEncode({'saved': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /saved-videos/{userId}
    if (path.contains('/saved-videos/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'data': <Map<String, dynamic>>[],
          'total': 0,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // NOTIFICATIONS ENDPOINTS
    // ========================

    // GET /notifications/unread/{userId}
    if (path.contains('/notifications/unread/') && method == 'GET') {
      return http.Response(
        jsonEncode({'count': 0}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /notifications/{userId}
    if (path.contains('/notifications/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 'notif-1',
              'type': 'like',
              'message': 'Someone liked your video',
              'userId': 2,
              'videoId': 'vid-1',
              'read': false,
              'createdAt': '2026-02-22T12:00:00Z',
            }
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // PUT /notifications (mark as read)
    if (path.contains('/notifications') && method == 'PUT') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // MESSAGES ENDPOINTS
    // ========================

    // GET /messages/settings/{recipientId}
    if (path.contains('/messages/settings/') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'isMuted': false,
          'isPinned': false,
          'themeColor': null,
          'nickname': null,
          'autoTranslate': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /messages/pinned/
    if (path.contains('/messages/pinned/') && method == 'GET') {
      return http.Response(
        jsonEncode({'data': <Map<String, dynamic>>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /messages/conversation/
    if (path.contains('/messages/conversation/') && method == 'GET') {
      return http.Response(
        jsonEncode({'data': <Map<String, dynamic>>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /messages/unread/{userId}
    if (path.contains('/messages/unread/') && method == 'GET') {
      return http.Response(
        jsonEncode({'count': 0}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /messages/conversations
    if (path.contains('/messages/conversations') && method == 'GET') {
      return http.Response(
        jsonEncode({'data': <Map<String, dynamic>>[], 'total': 0}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // GET /messages/media/
    if (path.contains('/messages/media/') && method == 'GET') {
      return http.Response(
        jsonEncode({'data': <Map<String, dynamic>>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // POST /messages
    if (path.contains('/messages') && method == 'POST') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // CATEGORIES / INTERESTS
    // ========================
    if (path.contains('/categories') && method == 'GET') {
      return http.Response(
        jsonEncode({
          'data': [
            {'id': 1, 'name': 'Music', 'icon': 'music'},
            {'id': 2, 'name': 'Sports', 'icon': 'sports'},
            {'id': 3, 'name': 'Comedy', 'icon': 'comedy'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // INTERACTION TRACKING
    // ========================
    if (path.contains('/interactions') && method == 'POST') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // SHARE
    // ========================
    if (path.contains('/shares') && method == 'POST') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // ========================
    // DEFAULT - return 200 with empty JSON
    // ========================
    return http.Response(
      jsonEncode({'success': true}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}
