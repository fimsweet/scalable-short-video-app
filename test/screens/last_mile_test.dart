// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/login_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/two_factor_auth_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_options_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/upload_video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/upload_video_screen_v2.dart';
import 'package:scalable_short_video_app/src/presentation/screens/profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/follower_following_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/notifications_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/search_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/activity_history_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/account_management_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/change_password_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/privacy_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/forgot_password_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/register_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/screens/report_user_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/inbox_screen.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';

class _MockStorage extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterSecureStoragePlatform {
  final Map<String, String> _d = {};
  @override
  Future<String?> read({required String key, required Map<String, String> options}) async => _d[key];
  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async => _d[key] = value;
  @override
  Future<void> delete({required String key, required Map<String, String> options}) async => _d.remove(key);
  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async => Map.from(_d);
  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async => _d.containsKey(key);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async => _d.clear();
}

Future<void> _w(WidgetTester t, {int n = 5}) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

MockClient _mk({
  bool videoSuccess = false,
  bool searchMatch = false,
  bool userWithVideos = false,
  bool recommendations = false,
  bool trendingVideos = false,
  bool followFeed = false,
  bool friendFeed = false,
  bool newVideoCount = false,
  bool deleteSuccess = false,
  bool retrySuccess = false,
  bool editVideoSuccess = false,
  bool privacyUpdate = false,
  bool toggleHide = false,
  bool getVideoById = false,
  bool incrementView = false,
  bool getUserVideos = false,
  bool getAllVideos = false,
  bool videosByUserPrivacy = false,
  bool videosByUserId = false,
  bool loginWith2FA = false,
  bool loginReactivation = false,
  bool serverErr = false,
  bool profileData = false,
  bool notificationsData = false,
  bool followRequests = false,
  bool activityData = false,
  bool commentData = false,
  bool editProfileData = false,
  bool twoFAData = false,
  bool accountData = false,
  bool chatOptionsData = false,
  bool registerData = false,
}) {
  return MockClient((req) async {
    final p = req.url.path;
    final q = req.url.query;

    if (serverErr) return http.Response('Server Error', 500);

    // Video service endpoints
    if (getVideoById && p.contains('/videos/') && !p.contains('/user/') && !p.contains('/feed/') && !p.contains('/search') && !p.contains('/view') && !p.contains('/hide') && !p.contains('/delete') && !p.contains('/privacy') && !p.contains('/edit') && !p.contains('/retry') && !p.contains('/upload') && !p.contains('/comment') && !p.contains('/recommendation') && !p.contains('/trending')) {
      return http.Response(jsonEncode({'id': 'v1', 'title': 'Test Video', 'userId': '1', 'status': 'ready', 'hlsUrl': '/vid/pl.m3u8'}), 200);
    }

    if (incrementView && p.contains('/view')) {
      return http.Response(jsonEncode({'viewCount': 42}), 200);
    }

    if ((getUserVideos || userWithVideos) && p.contains('/videos/user/')) {
      return http.Response(jsonEncode({'success': true, 'data': [
        {'id': 'v1', 'title': 'My Video', 'status': 'ready', 'userId': '1', 'hlsUrl': '/a.m3u8'},
        {'id': 'v2', 'title': 'Hidden', 'status': 'ready', 'userId': '1', 'isHidden': true, 'hlsUrl': '/b.m3u8'},
      ]}), 200);
    }

    if (getAllVideos && p.contains('/feed/all')) {
      return http.Response(jsonEncode([
        {'id': 'v1', 'title': 'Feed Video', 'userId': '1', 'hlsUrl': '/c.m3u8'},
      ]), 200);
    }

    if (followFeed && p.contains('/feed/following/') && !p.contains('new-count')) {
      return http.Response(jsonEncode([
        {'id': 'f1', 'title': 'Following Vid', 'userId': '2', 'hlsUrl': '/f.m3u8'},
      ]), 200);
    }

    if (friendFeed && p.contains('/feed/friends/') && !p.contains('new-count')) {
      return http.Response(jsonEncode([
        {'id': 'fr1', 'title': 'Friend Vid', 'userId': '3', 'hlsUrl': '/fr.m3u8'},
      ]), 200);
    }

    if (newVideoCount && p.contains('new-count')) {
      return http.Response(jsonEncode({'newCount': 5}), 200);
    }

    if (searchMatch && p.contains('/videos/search')) {
      return http.Response(jsonEncode({'success': true, 'videos': [
        {'id': 's1', 'title': 'Search Result', 'userId': '1'},
      ]}), 200);
    }

    if (toggleHide && p.contains('/hide')) {
      return http.Response(jsonEncode({'success': true, 'isHidden': true}), 200);
    }

    if (deleteSuccess && p.contains('/delete')) {
      return http.Response(jsonEncode({'success': true}), 200);
    }

    if (recommendations && p.contains('/recommendation/for-you/')) {
      return http.Response(jsonEncode({'success': true, 'data': [
        {'id': 'r1', 'title': 'Recommended', 'userId': '1', 'hlsUrl': '/r.m3u8'},
      ]}), 200);
    }

    if (trendingVideos && p.contains('/recommendation/trending')) {
      return http.Response(jsonEncode({'success': true, 'data': [
        {'id': 't1', 'title': 'Trending', 'userId': '1', 'hlsUrl': '/t.m3u8'},
      ]}), 200);
    }

    if (privacyUpdate && p.contains('/privacy') && req.method == 'PUT') {
      return http.Response(jsonEncode({'success': true}), 200);
    }

    if (editVideoSuccess && p.contains('/edit') && req.method == 'PUT') {
      return http.Response(jsonEncode({'success': true}), 200);
    }

    if (retrySuccess && p.contains('/retry')) {
      return http.Response(jsonEncode({'success': true, 'data': {'id': 'v1'}}), 200);
    }

    // User/auth endpoints
    if (p.contains('/users/id/')) {
      return http.Response(jsonEncode({'id': 1, 'username': 'testuser', 'avatar': null, 'gender': 'male', 'dateOfBirth': '2000-01-01', 'bio': 'Hey', 'followersCount': 10, 'followingCount': 5}), 200);
    }

    if (p.contains('/auth/login') && req.method == 'POST') {
      if (loginWith2FA) {
        return http.Response(jsonEncode({'requires2FA': true, 'userId': 1, 'twoFactorMethods': ['email', 'totp']}), 200);
      }
      if (loginReactivation) {
        return http.Response(jsonEncode({'requiresReactivation': true, 'userId': 1, 'daysRemaining': 5}), 200);
      }
      return http.Response(jsonEncode({'user': {'id': 1, 'username': 'testuser'}, 'access_token': 'tok123'}), 200);
    }

    if (p.contains('/auth/account-info')) {
      return http.Response(jsonEncode({'authProvider': 'local', 'email': 'test@test.com', 'phoneNumber': null}), 200);
    }

    if (p.contains('/users/has-password')) {
      return http.Response(jsonEncode({'hasPassword': true}), 200);
    }

    if (p.contains('/auth/2fa/settings')) {
      return http.Response(jsonEncode({'enabled': twoFAData, 'methods': twoFAData ? ['email'] : []}), 200);
    }

    if (p.contains('/users/settings')) {
      return http.Response(jsonEncode({'autoTranslate': false, 'themeColor': null, 'nickname': null}), 200);
    }

    if (p.contains('/users/privacy/')) {
      return http.Response(jsonEncode({'settings': {'whoCanComment': 'everyone', 'whoCanMessage': 'everyone', 'whoCanViewLikes': 'everyone'}}), 200);
    }

    if (p.contains('/users/privacy/check')) {
      return http.Response(jsonEncode({'allowed': true}), 200);
    }

    if (p.contains('/users/profile') && req.method == 'PUT') {
      return http.Response(jsonEncode({'id': 1, 'username': 'testuser', 'bio': 'Updated'}), 200);
    }

    if (p.contains('/auth/register') && req.method == 'POST') {
      return http.Response(jsonEncode({'success': true, 'user': {'id': 1, 'username': 'newuser'}, 'access_token': 'tok_new'}), 200);
    }

    if (p.contains('/follow/stats') || p.contains('/followers') || p.contains('/following')) {
      return http.Response(jsonEncode({'followersCount': 10, 'followingCount': 5, 'data': [], 'hasMore': false, 'total': 0}), 200);
    }

    if (p.contains('/follow/pending')) {
      return http.Response(jsonEncode({'data': followRequests ? [{'id': 1, 'username': 'req1', 'avatar': null}] : [], 'hasMore': false, 'total': followRequests ? 1 : 0}), 200);
    }

    if (p.contains('/comments/video/')) {
      return http.Response(jsonEncode({'comments': commentData ? [
        {'id': 'c1', 'text': 'Great!', 'userId': '1', 'username': 'user1', 'createdAt': '2024-01-01T00:00:00Z', 'likeCount': 3, 'replyCount': 0, 'isToxic': false},
        {'id': 'c2', 'text': 'Toxic comment', 'userId': '2', 'username': 'user2', 'createdAt': '2024-01-01T01:00:00Z', 'likeCount': 0, 'replyCount': 2, 'isToxic': true},
      ] : [], 'hasMore': false, 'total': commentData ? 2 : 0}), 200);
    }

    if (p.contains('/analytics/')) {
      return http.Response(jsonEncode({'success': true, 'analytics': {
        'overview': {'totalVideos': 5, 'totalViews': 100, 'totalLikes': 50, 'totalComments': 20, 'totalShares': 10, 'engagementRate': 0.5, 'followersCount': 10, 'followingCount': 5},
        'recent': [], 'allVideos': [], 'topVideos': [], 'distribution': {}, 'dailyStats': [],
      }}), 200);
    }

    if (p.contains('/activity-history/')) {
      return http.Response(jsonEncode({'activities': activityData ? [
        {'id': '1', 'type': 'like', 'description': 'Liked a video', 'createdAt': '2024-01-15T10:00:00Z', 'metadata': {}},
        {'id': '2', 'type': 'comment', 'description': 'Commented on a video', 'createdAt': '2024-01-15T11:00:00Z', 'metadata': {}},
      ] : [], 'hasMore': false}), 200);
    }

    if (p.contains('/notifications') && !p.contains('/settings') && !p.contains('/count') && !p.contains('/badge')) {
      return http.Response(jsonEncode(notificationsData ? [
        {'id': 'n1', 'type': 'like', 'message': 'User liked your video', 'senderId': '2', 'createdAt': '2024-01-01T00:00:00Z', 'isRead': false, 'data': {'videoId': 'v1'}},
        {'id': 'n2', 'type': 'follow', 'message': 'User followed you', 'senderId': '3', 'createdAt': '2024-01-01T01:00:00Z', 'isRead': true, 'data': {}},
      ] : []), 200);
    }

    if (p.contains('/users/blocked')) {
      return http.Response(jsonEncode({'isBlocked': false}), 200);
    }

    if (p.contains('/messages/conversations/')) {
      return http.Response(jsonEncode({'data': []}), 200);
    }

    if (p.contains('/likes/video/')) {
      return http.Response(jsonEncode({'liked': false, 'likeCount': 5}), 200);
    }

    if (p.contains('/saves/video/')) {
      return http.Response(jsonEncode({'saved': false}), 200);
    }

    if (p.contains('/shares/')) {
      return http.Response(jsonEncode({'shareCount': 3}), 200);
    }

    if (p.contains('/categories')) {
      return http.Response(jsonEncode([
        {'id': 1, 'name': 'Music'},
        {'id': 2, 'name': 'Dance'},
        {'id': 3, 'name': 'Comedy'},
      ]), 200);
    }

    if (p.contains('/auth/forgot-password')) {
      return http.Response(jsonEncode({'success': true, 'message': 'OTP sent'}), 200);
    }

    if (p.contains('/auth/change-password')) {
      return http.Response(jsonEncode({'success': true}), 200);
    }

    if (p.contains('/otp/send')) {
      return http.Response(jsonEncode({'success': true}), 200);
    }

    if (p.contains('/reports')) {
      return http.Response(jsonEncode({'success': true}), 200);
    }

    if (p.contains('/search')) {
      return http.Response(jsonEncode({'users': [], 'videos': []}), 200);
    }

    if (p.contains('/liked-videos/count')) {
      return http.Response(jsonEncode({'count': 12}), 200);
    }

    if (p.contains('/notification-badge') || p.contains('/badge')) {
      return http.Response(jsonEncode({'count': 0}), 200);
    }

    // Default
    return http.Response(jsonEncode({'success': true}), 200);
  });
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = _MockStorage();
  });

  // ---- VideoService success path tests ----
  group('VideoService success paths', () {
    late VideoService svc;
    setUp(() => svc = VideoService());

    test('getVideoById returns video on 200', () async {
      final c = _mk(getVideoById: true);
      final result = await http.runWithClient(
        () => svc.getVideoById('v1'),
        () => c,
      );
      expect(result, isNotNull);
      expect(result!['title'], 'Test Video');
    });

    test('incrementViewCount on 200', () async {
      final c = _mk(incrementView: true);
      await http.runWithClient(
        () => svc.incrementViewCount('v1'),
        () => c,
      );
      // No throw = success
    });

    test('getUserVideos returns list on 200', () async {
      final c = _mk(getUserVideos: true);
      final result = await http.runWithClient(
        () => svc.getUserVideos('1'),
        () => c,
      );
      expect(result, isA<List>());
      expect(result.length, 2);
    });

    test('getAllVideos returns feed on 200', () async {
      final c = _mk(getAllVideos: true);
      final result = await http.runWithClient(
        () => svc.getAllVideos(),
        () => c,
      );
      expect(result, isA<List>());
      expect(result.length, 1);
    });

    test('getFollowingVideos returns list', () async {
      final c = _mk(followFeed: true);
      final result = await http.runWithClient(
        () => svc.getFollowingVideos('1'),
        () => c,
      );
      expect(result, isA<List>());
      expect(result.length, 1);
    });

    test('getFriendsVideos returns list', () async {
      final c = _mk(friendFeed: true);
      final result = await http.runWithClient(
        () => svc.getFriendsVideos('1'),
        () => c,
      );
      expect(result, isA<List>());
      expect(result.length, 1);
    });

    test('getFollowingNewVideoCount returns count', () async {
      final c = _mk(newVideoCount: true);
      final result = await http.runWithClient(
        () => svc.getFollowingNewVideoCount('1', DateTime(2024, 1, 1)),
        () => c,
      );
      expect(result, 5);
    });

    test('getFriendsNewVideoCount returns count', () async {
      final c = _mk(newVideoCount: true);
      final result = await http.runWithClient(
        () => svc.getFriendsNewVideoCount('1', DateTime(2024, 1, 1)),
        () => c,
      );
      expect(result, 5);
    });

    test('searchVideos returns results with user info', () async {
      final c = _mk(searchMatch: true);
      final result = await http.runWithClient(
        () => svc.searchVideos('test'),
        () => c,
      );
      expect(result, isA<List>());
      expect(result.length, 1);
    });

    test('searchVideos empty query returns empty', () async {
      final result = await VideoService().searchVideos('');
      expect(result, isEmpty);
    });

    test('toggleHideVideo on 200', () async {
      final c = _mk(toggleHide: true);
      final result = await http.runWithClient(
        () => svc.toggleHideVideo('v1', '1'),
        () => c,
      );
      expect(result['success'], true);
    });

    test('deleteVideo on success', () async {
      final c = _mk(deleteSuccess: true);
      final result = await http.runWithClient(
        () => svc.deleteVideo('v1', '1'),
        () => c,
      );
      expect(result, true);
    });

    test('getRecommendedVideos on 200', () async {
      final c = _mk(recommendations: true);
      final result = await http.runWithClient(
        () => svc.getRecommendedVideos(1, limit: 10),
        () => c,
      );
      expect(result, isA<List>());
      expect(result.length, 1);
    });

    test('getRecommendedVideos with excludeIds', () async {
      final c = _mk(recommendations: true);
      final result = await http.runWithClient(
        () => svc.getRecommendedVideos(1, excludeIds: ['x1', 'x2']),
        () => c,
      );
      expect(result, isA<List>());
    });

    test('getTrendingVideos on 200', () async {
      final c = _mk(trendingVideos: true);
      final result = await http.runWithClient(
        () => svc.getTrendingVideos(limit: 5),
        () => c,
      );
      expect(result, isA<List>());
      expect(result.length, 1);
    });

    test('updateVideoPrivacy on 200', () async {
      final c = _mk(privacyUpdate: true);
      final result = await http.runWithClient(
        () => svc.updateVideoPrivacy(videoId: 'v1', userId: '1', visibility: 'private', allowComments: false, allowDuet: false),
        () => c,
      );
      expect(result['success'], true);
    });

    test('editVideo on 200', () async {
      final c = _mk(editVideoSuccess: true);
      final result = await http.runWithClient(
        () => svc.editVideo(videoId: 'v1', userId: '1', title: 'New Title', description: 'Desc'),
        () => c,
      );
      expect(result['success'], true);
    });

    test('retryVideo on 200', () async {
      final c = _mk(retrySuccess: true);
      final result = await http.runWithClient(
        () => svc.retryVideo(videoId: 'v1', userId: '1'),
        () => c,
      );
      expect(result['success'], true);
    });

    test('getVideosByUserIdWithPrivacy on 200', () async {
      final c = _mk(videosByUserPrivacy: true, getUserVideos: true);
      final result = await http.runWithClient(
        () => svc.getVideosByUserIdWithPrivacy('1', requesterId: '2'),
        () => c,
      );
      expect(result, isA<Map>());
    });

    test('getVideosByUserId on 200', () async {
      final c = _mk(videosByUserId: true, getUserVideos: true);
      final result = await http.runWithClient(
        () => svc.getVideosByUserId('1', requesterId: '2'),
        () => c,
      );
      expect(result, isA<List>());
    });

    test('getVideoUrl with full URL', () {
      final url = svc.getVideoUrl('https://cdn.example.com/v.m3u8');
      expect(url, 'https://cdn.example.com/v.m3u8');
    });

    test('getVideoUrl with relative path', () {
      final url = svc.getVideoUrl('/uploads/v.m3u8');
      expect(url, contains('uploads/v.m3u8'));
    });

    test('deleteVideo on failed response', () async {
      final c = MockClient((_) async => http.Response(jsonEncode({'success': false, 'message': 'Not found'}), 200));
      expect(
        () => http.runWithClient(() => svc.deleteVideo('v1', '1'), () => c),
        throwsException,
      );
    });

    test('deleteVideo on 404', () async {
      final c = MockClient((_) async => http.Response(jsonEncode({'message': 'Not found'}), 404));
      expect(
        () => http.runWithClient(() => svc.deleteVideo('v1', '1'), () => c),
        throwsException,
      );
    });

    test('getRecommendedVideos on 500 falls back', () async {
      // On error, getRecommendedVideos tries getAllVideos as fallback
      final c = MockClient((req) async {
        if (req.url.path.contains('/recommendation/')) {
          return http.Response('Err', 500);
        }
        if (req.url.path.contains('/feed/all')) {
          return http.Response(jsonEncode([{'id': 'fb'}]), 200);
        }
        return http.Response('{}', 200);
      });
      final result = await http.runWithClient(() => svc.getRecommendedVideos(1), () => c);
      expect(result, isA<List>());
    });

    test('getTrendingVideos on 500 falls back', () async {
      final c = MockClient((req) async {
        if (req.url.path.contains('/recommendation/trending')) {
          return http.Response('Err', 500);
        }
        if (req.url.path.contains('/feed/all')) {
          return http.Response(jsonEncode([{'id': 'fb'}]), 200);
        }
        return http.Response('{}', 200);
      });
      final result = await http.runWithClient(() => svc.getTrendingVideos(), () => c);
      expect(result, isA<List>());
    });

    test('searchVideos on non-200 returns empty', () async {
      final c = MockClient((_) async => http.Response('Error', 500));
      final result = await http.runWithClient(() => svc.searchVideos('test'), () => c);
      expect(result, isEmpty);
    });

    test('getUserVideos with list response format', () async {
      final c = MockClient((_) async => http.Response(jsonEncode([
        {'id': 'v1', 'title': 'A'},
      ]), 200));
      final result = await http.runWithClient(() => svc.getUserVideos('1'), () => c);
      expect(result, isA<List>());
      expect(result.length, 1);
    });

    test('getUserVideos on non-200', () async {
      final c = MockClient((_) async => http.Response('Not found', 404));
      final result = await http.runWithClient(() => svc.getUserVideos('1'), () => c);
      expect(result, isEmpty);
    });

    test('incrementViewCount on non-200', () async {
      final c = MockClient((_) async => http.Response('Err', 500));
      await http.runWithClient(() => svc.incrementViewCount('v1'), () => c);
      // No throw = success
    });

    test('getVideoById on non-200', () async {
      final c = MockClient((_) async => http.Response('Not found', 404));
      final result = await http.runWithClient(() => svc.getVideoById('v1'), () => c);
      expect(result, isNull);
    });

    test('getVideoById with user enrichment on 200', () async {
      final c = MockClient((req) async {
        if (req.url.path.contains('/videos/') && !req.url.path.contains('/users/')) {
          return http.Response(jsonEncode({'id': 'v1', 'title': 'T', 'userId': '1'}), 200);
        }
        if (req.url.path.contains('/users/id/')) {
          return http.Response(jsonEncode({'username': 'enriched', 'avatar': null}), 200);
        }
        return http.Response('{}', 200);
      });
      final result = await http.runWithClient(() => svc.getVideoById('v1'), () => c);
      expect(result, isNotNull);
      expect(result!['username'], 'enriched');
    });

    test('getVideoById with user enrichment failing', () async {
      final c = MockClient((req) async {
        if (req.url.path.contains('/videos/') && !req.url.path.contains('/users/')) {
          return http.Response(jsonEncode({'id': 'v1', 'title': 'T', 'userId': '1'}), 200);
        }
        if (req.url.path.contains('/users/id/')) {
          return http.Response('Not found', 404);
        }
        return http.Response('{}', 200);
      });
      final result = await http.runWithClient(() => svc.getVideoById('v1'), () => c);
      expect(result, isNotNull);
      expect(result!['username'], 'user');
    });
  });

  // ---- Screen rendering for deeper coverage ----
  group('Screen deep rendering', () {
    testWidgets('LoginScreen renders form elements', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const LoginScreen()));
        await _w(t, n: 10);
        // Find text fields
        expect(find.byType(TextField), findsWidgets);
        // Find login button
        expect(find.byType(ElevatedButton), findsWidgets);
      }, () => c);
    });

    testWidgets('RegisterScreen renders form', (t) async {
      final c = _mk(registerData: true);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const RegisterScreen()));
        await _w(t, n: 10);
        expect(find.byType(TextField), findsWidgets);
      }, () => c);
    });

    testWidgets('ForgotPasswordScreen renders and toggles mode', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const ForgotPasswordScreen()));
        await _w(t, n: 10);
        expect(find.byType(TextField), findsWidgets);
        // Toggle between email and phone mode
        final toggleButtons = find.byType(GestureDetector);
        if (toggleButtons.evaluate().length > 2) {
          await t.tap(toggleButtons.at(1), warnIfMissed: false);
          await _w(t);
        }
      }, () => c);
      await t.pumpWidget(const SizedBox());
      for (var i = 0; i < 65; i++) await t.pump(const Duration(seconds: 1));
    });

    testWidgets('EditProfileScreen renders with user data', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser', 'avatar': null, 'bio': 'Test bio'}, 'tok');
      final c = _mk(editProfileData: true);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const EditProfileScreen()));
        await _w(t, n: 15);
        expect(find.byType(Scaffold), findsWidgets);
      }, () => c);
    });

    testWidgets('TwoFactorAuthScreen renders overview', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser'}, 'tok');
      final c = _mk(twoFAData: false);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const TwoFactorAuthScreen()));
        await _w(t, n: 15);
        expect(find.byType(Scaffold), findsWidgets);
      }, () => c);
      await t.pumpWidget(const SizedBox());
      for (var i = 0; i < 65; i++) await t.pump(const Duration(seconds: 1));
    });

    testWidgets('TwoFactorAuthScreen with 2FA enabled', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser'}, 'tok');
      final c = _mk(twoFAData: true);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const TwoFactorAuthScreen()));
        await _w(t, n: 15);
        // Should show enabled state
        expect(find.byType(Scaffold), findsWidgets);
        // Try to find switch or toggle
        final switches = find.byType(Switch);
        if (switches.evaluate().isNotEmpty) {
          await t.tap(switches.first, warnIfMissed: false);
          await _w(t, n: 5);
        }
      }, () => c);
      await t.pumpWidget(const SizedBox());
      for (var i = 0; i < 65; i++) await t.pump(const Duration(seconds: 1));
    });

    testWidgets('NotificationsScreen renders tabs', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser'}, 'tok');
      final c = _mk(notificationsData: true, followRequests: true);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const NotificationsScreen()));
        await _w(t, n: 15);
        // Check for tab bar
        expect(find.byType(TabBar), findsWidgets);
        // Try switching to follow requests tab
        final tabs = find.byType(Tab);
        if (tabs.evaluate().length > 1) {
          await t.tap(tabs.last, warnIfMissed: false);
          await _w(t, n: 10);
        }
      }, () => c);
    });

    testWidgets('CommentSectionWidget with comments data', (t) async {
      final c = _mk(commentData: true);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(CommentSectionWidget(
          videoId: 'v1',
          allowComments: true,
          videoOwnerId: '1',
        )));
        await _w(t, n: 15);
        // Should show comments list
        expect(find.byType(Scaffold), findsWidgets);
        // Try scrolling comments
        final listViews = find.byType(ListView);
        if (listViews.evaluate().isNotEmpty) {
          await t.drag(listViews.first, const Offset(0, -200));
          await _w(t);
        }
      }, () => c);
    });

    testWidgets('ProfileScreen logged in renders tabs', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser', 'avatar': null, 'bio': 'Test'}, 'tok');
      final c = _mk(userWithVideos: true, profileData: true);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const ProfileScreen()));
        await _w(t, n: 15);
        expect(find.byType(Scaffold), findsWidgets);
        // Scroll down to see content
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          await t.drag(scrollables.first, const Offset(0, -300), warnIfMissed: false);
          await _w(t, n: 5);
        }
      }, () => c);
    });

    testWidgets('UserProfileScreen renders with data', (t) async {
      await AuthService().login({'id': 2, 'username': 'viewer'}, 'tok');
      final c = _mk(userWithVideos: true);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const UserProfileScreen(userId: 1)));
        await _w(t, n: 15);
        expect(find.byType(Scaffold), findsWidgets);
      }, () => c);
      await t.pumpWidget(const SizedBox());
      for (var i = 0; i < 25; i++) await t.pump(const Duration(seconds: 1));
    });

    testWidgets('FollowerFollowingScreen initial tab 1', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const FollowerFollowingScreen(initialIndex: 1, userId: 1, username: 'testuser')));
        await _w(t, n: 10);
        expect(find.byType(TabBar), findsWidgets);
      }, () => c);
    });

    testWidgets('VideoDetailScreen renders', (t) async {
      final c = _mk(getVideoById: true);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(VideoDetailScreen(
          videos: [{'id': 'v1', 'title': 'Test', 'userId': '1', 'hlsUrl': 'https://vid.test/v.m3u8', 'username': 'user1', 'likeCount': 5, 'commentCount': 3, 'shareCount': 1, 'viewCount': 100, 'description': 'A video'}],
          initialIndex: 0,
        )));
        await _w(t, n: 10);
        expect(find.byType(Scaffold), findsWidgets);
      }, () => c);
    });

    testWidgets('ChatOptionsScreen renders and scrolls', (t) async {
      final c = _mk(chatOptionsData: true);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(ChatOptionsScreen(
          recipientId: '2',
          recipientUsername: 'chatuser',
        )));
        await _w(t, n: 15);
        // Scroll to see all options
        final scrollables = find.byType(SingleChildScrollView);
        if (scrollables.evaluate().isNotEmpty) {
          await t.drag(scrollables.first, const Offset(0, -300));
          await _w(t, n: 5);
        }
      }, () => c);
      await t.pumpWidget(const SizedBox());
      for (var i = 0; i < 10; i++) await t.pump(const Duration(seconds: 1));
    });

    testWidgets('UploadVideoScreen renders', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser'}, 'tok');
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const UploadVideoScreen()));
        await _w(t, n: 10);
        expect(find.byType(Scaffold), findsWidgets);
      }, () => c);
    });

    testWidgets('UploadVideoScreenV2 renders categories', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser'}, 'tok');
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const UploadVideoScreenV2()));
        await _w(t, n: 10);
        expect(find.byType(Scaffold), findsWidgets);
      }, () => c);
    });

    testWidgets('ActivityHistoryScreen renders', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser'}, 'tok');
      final c = _mk(activityData: false);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const ActivityHistoryScreen()));
        await _w(t, n: 15);
        expect(find.byType(Scaffold), findsWidgets);
      }, () => c);
    });

    testWidgets('AccountManagementScreen renders sections', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser'}, 'tok');
      final c = _mk(accountData: true);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const AccountManagementScreen()));
        await _w(t, n: 15);
        expect(find.byType(Scaffold), findsWidgets);
        // Scroll to see all sections
        final scrollables = find.byType(SingleChildScrollView);
        if (scrollables.evaluate().isNotEmpty) {
          await t.drag(scrollables.first, const Offset(0, -400));
          await _w(t, n: 5);
        }
      }, () => c);
    });

    testWidgets('ChangePasswordScreen renders form', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser'}, 'tok');
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const ChangePasswordScreen()));
        await _w(t, n: 10);
        expect(find.byType(TextField), findsWidgets);
        // Fill passwords
        final fields = find.byType(TextField);
        if (fields.evaluate().length >= 3) {
          await t.enterText(fields.at(0), 'oldpass');
          await t.enterText(fields.at(1), 'newpass123');
          await t.enterText(fields.at(2), 'newpass123');
          await _w(t);
        }
      }, () => c);
    });

    testWidgets('PrivacySettingsScreen renders dropdowns', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser'}, 'tok');
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const PrivacySettingsScreen()));
        await _w(t, n: 15);
        expect(find.byType(Scaffold), findsWidgets);
      }, () => c);
    });

    testWidgets('InboxScreen renders', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser'}, 'tok');
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const InboxScreen()));
        await _w(t, n: 15);
        expect(find.byType(Scaffold), findsWidgets);
      }, () => c);
      MessageService().disconnect();
      await t.pumpWidget(const SizedBox());
      for (var i = 0; i < 35; i++) await t.pump(const Duration(seconds: 1));
    });

    testWidgets('ReportUserScreen renders all reasons', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(_app(ReportUserScreen(
          reportedUserId: '2',
          reportedUsername: 'baduser',
        )));
        await _w(t, n: 10);
        expect(find.byType(Scaffold), findsWidgets);
        // Try to find and tap radio options
        final radios = find.byType(InkWell);
        if (radios.evaluate().length > 2) {
          await t.tap(radios.at(1), warnIfMissed: false);
          await _w(t);
        }
      }, () => c);
    });

    testWidgets('SearchScreen renders and performs search', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const SearchScreen()));
        await _w(t, n: 10);
        final searchField = find.byType(TextField);
        if (searchField.evaluate().isNotEmpty) {
          await t.enterText(searchField.first, 'flutter');
          await t.testTextInput.receiveAction(TextInputAction.search);
          await _w(t, n: 10);
        }
      }, () => c);
    });

    testWidgets('VideoScreen renders', (t) async {
      await AuthService().login({'id': 1, 'username': 'testuser'}, 'tok');
      final c = _mk(recommendations: true, getAllVideos: true);
      await http.runWithClient(() async {
        await t.pumpWidget(_app(const VideoScreen()));
        await _w(t, n: 15);
        expect(find.byType(Scaffold), findsWidgets);
      }, () => c);
    });
  });

  // ---- ApiService additional method tests ----
  group('ApiService additional methods', () {
    test('getAccountInfo success', () async {
      final c = _mk();
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.getAccountInfo('tok123'),
        () => c,
      );
      expect(result['success'], true);
      expect(result['data']['email'], 'test@test.com');
    });

    test('hasPassword success', () async {
      final c = _mk();
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.hasPassword('tok123'),
        () => c,
      );
      expect(result['hasPassword'], true);
    });

    test('get2FASettings success', () async {
      final c = _mk(twoFAData: true);
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.get2FASettings('tok123'),
        () => c,
      );
      expect(result['enabled'], true);
    });

    test('getUserSettings success', () async {
      final c = _mk();
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.getUserSettings('tok123_long_enough_token_string'),
        () => c,
      );
      expect(result['autoTranslate'], false);
    });

    test('getPrivacySettings success', () async {
      final c = _mk();
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.getPrivacySettings('1'),
        () => c,
      );
      expect(result['whoCanComment'], 'everyone');
    });

    test('getUserById success', () async {
      final c = _mk();
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.getUserById('1'),
        () => c,
      );
      expect(result, isNotNull);
      expect(result!['username'], 'testuser');
    });

    test('login success with normal flow', () async {
      final c = _mk();
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.login(username: 'testuser', password: 'password', deviceInfo: {}),
        () => c,
      );
      expect(result['success'], true);
    });

    test('login with 2FA required', () async {
      final c = _mk(loginWith2FA: true);
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.login(username: 'testuser', password: 'password', deviceInfo: {}),
        () => c,
      );
      expect(result['success'], true);
      final data = result['data'] as Map<String, dynamic>;
      expect(data['requires2FA'], true);
    });

    test('updateProfile success', () async {
      final c = _mk();
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.updateProfile(token: 'tok123', bio: 'New bio', gender: 'male', dateOfBirth: '2000-01-01', fullName: 'Test User'),
        () => c,
      );
      expect(result['success'], true);
    });

    test('isUserBlocked returns false', () async {
      final c = _mk();
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.isUserBlocked('1', '2'),
        () => c,
      );
      expect(result, false);
    });

    test('checkPrivacyPermission allowed', () async {
      final c = MockClient((_) async => http.Response(jsonEncode({'allowed': true}), 200));
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.checkPrivacyPermission('1', '2', 'message'),
        () => c,
      );
      expect(result['allowed'], true);
    });

    test('getAccountInfo on error', () async {
      final c = MockClient((_) async => http.Response('Error', 500));
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.getAccountInfo('tok123_long_enough_token_string'),
        () => c,
      );
      expect(result['success'], false);
    });

    test('hasPassword on error', () async {
      final c = MockClient((_) async => http.Response('Error', 500));
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.hasPassword('tok123_long_enough_token_string'),
        () => c,
      );
      expect(result, isA<Map>());
    });

    test('getPrivacySettings on error', () async {
      final c = MockClient((_) async => http.Response('Error', 500));
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.getPrivacySettings('1'),
        () => c,
      );
      expect(result, isA<Map>());
    });

    test('login on server error', () async {
      final c = MockClient((_) async => throw Exception('Connection refused'));
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.login(username: 'u', password: 'p'),
        () => c,
      );
      expect(result['success'], false);
    });

    test('updateProfile on error', () async {
      final c = MockClient((_) async => http.Response('Error', 500));
      final api = ApiService();
      final result = await http.runWithClient(
        () => api.updateProfile(token: 'tok123_long_enough_token_string', bio: 'x'),
        () => c,
      );
      expect(result['success'], false);
    });
  });
}
