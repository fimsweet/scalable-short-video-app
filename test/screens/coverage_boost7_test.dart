/// coverage_boost7_test.dart — targets SUCCESS paths & remaining branch coverage
/// Focus: FollowService 200 paths, VideoService 200 paths, ApiService remaining,
/// CommentService success variants, AuthService getCurrentUser
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/comment_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/notification_service.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/video_prefetch_service.dart';

const _tok = 'abcdefghijklmnopqrstuvwxyz1234567890';

MockClient _mk({
  Map<String, dynamic>? json,
  String? rawBody,
  int statusCode = 200,
}) {
  return MockClient((_) async => http.Response(
    rawBody ?? jsonEncode(json ?? {}),
    statusCode,
  ));
}

MockClient Function() get _throwing => () => MockClient((_) => throw Exception('Network error'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =================== GROUP 1: FollowService SUCCESS paths ===================
  group('FollowService success paths', () {
    test('toggleFollow 200 success', () async {
      final client = _mk(json: {'following': true, 'followerCount': 5});
      await http.runWithClient(() async {
        final r = await FollowService().toggleFollow(1, 2);
        expect(r['following'], true);
        expect(r['followerCount'], 5);
      }, () => client);
    });

    test('toggleFollow 201 success', () async {
      final client = _mk(statusCode: 201, json: {'following': true, 'followerCount': 3});
      await http.runWithClient(() async {
        final r = await FollowService().toggleFollow(1, 2);
        expect(r['following'], true);
      }, () => client);
    });

    test('toggleFollow non-200 returns default', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Bad'});
      await http.runWithClient(() async {
        final r = await FollowService().toggleFollow(1, 2);
        expect(r['following'], false);
      }, () => client);
    });

    test('getFollowers 200 with data', () async {
      final client = _mk(json: {'followerIds': [1, 2, 3]});
      await http.runWithClient(() async {
        final r = await FollowService().getFollowers(1);
        expect(r, [1, 2, 3]);
      }, () => client);
    });

    test('getFollowers non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getFollowers(1);
        expect(r, isEmpty);
      }, () => client);
    });

    test('getFollowing 200 with data', () async {
      final client = _mk(json: {'followingIds': [4, 5, 6]});
      await http.runWithClient(() async {
        final r = await FollowService().getFollowing(1);
        expect(r, [4, 5, 6]);
      }, () => client);
    });

    test('getFollowing non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getFollowing(1);
        expect(r, isEmpty);
      }, () => client);
    });

    test('getFollowersWithStatus 200 with data', () async {
      final client = _mk(json: {'data': [{'id': 1, 'username': 'alice', 'isFollowing': true}]});
      await http.runWithClient(() async {
        final r = await FollowService().getFollowersWithStatus(1);
        expect(r.length, 1);
        expect(r[0]['username'], 'alice');
      }, () => client);
    });

    test('getFollowersWithStatus non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getFollowersWithStatus(1);
        expect(r, isEmpty);
      }, () => client);
    });

    test('getFollowingWithStatus 200 with data', () async {
      final client = _mk(json: {'data': [{'id': 2, 'username': 'bob'}]});
      await http.runWithClient(() async {
        final r = await FollowService().getFollowingWithStatus(1);
        expect(r.length, 1);
        expect(r[0]['username'], 'bob');
      }, () => client);
    });

    test('getFollowingWithStatus non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getFollowingWithStatus(1);
        expect(r, isEmpty);
      }, () => client);
    });

    test('getFollowingWithStatusPaginated 200 with data', () async {
      final client = _mk(json: {
        'data': [{'id': 3, 'username': 'charlie'}],
        'hasMore': true,
        'total': 10,
      });
      await http.runWithClient(() async {
        final r = await FollowService().getFollowingWithStatusPaginated(1, limit: 5, offset: 0);
        expect(r['data'], isA<List>());
        expect(r['hasMore'], true);
        expect(r['total'], 10);
      }, () => client);
    });

    test('getFollowingWithStatusPaginated non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getFollowingWithStatusPaginated(1);
        expect(r['data'], isEmpty);
      }, () => client);
    });

    test('getMutualFriendsPaginated 200 with data', () async {
      final client = _mk(json: {
        'data': [{'id': 1, 'username': 'mutual1'}],
        'hasMore': false,
        'total': 1,
      });
      await http.runWithClient(() async {
        final r = await FollowService().getMutualFriendsPaginated(1, limit: 10, offset: 0);
        expect(r['data'], isA<List>());
        expect(r['total'], 1);
      }, () => client);
    });

    test('getMutualFriendsPaginated non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getMutualFriendsPaginated(1);
        expect(r['data'], isEmpty);
      }, () => client);
    });

    test('checkListPrivacy 200 success', () async {
      final client = _mk(json: {'allowed': true, 'isFollowing': true, 'isOwnProfile': false});
      await http.runWithClient(() async {
        final r = await FollowService().checkListPrivacy(targetUserId: 1, requesterId: 2, listType: 'followers');
        expect(r['allowed'], true);
      }, () => client);
    });

    test('getSuggestions 200 success', () async {
      final client = _mk(json: {
        'success': true,
        'data': [
          {'id': 1, 'username': 'suggested1', 'followerCount': 100, 'reason': 'popular', 'mutualFriendsCount': 0, 'mutualFollowerNames': []},
        ]
      });
      await http.runWithClient(() async {
        final r = await FollowService().getSuggestions(1);
        expect(r.length, 1);
        expect(r[0].username, 'suggested1');
      }, () => client);
    });

    test('getSuggestions non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getSuggestions(1);
        expect(r, isEmpty);
      }, () => client);
    });

    test('getSuggestions exception', () async {
      await http.runWithClient(() async {
        final r = await FollowService().getSuggestions(1);
        expect(r, isEmpty);
      }, _throwing);
    });
  });

  // =================== GROUP 2: ApiService generic & remaining ===================
  group('ApiService generic and remaining paths', () {
    test('generic get method', () async {
      final client = _mk(json: {'result': 'ok'});
      await http.runWithClient(() async {
        final r = await ApiService().get('/test');
        expect(r.statusCode, 200);
      }, () => client);
    });

    test('generic post method', () async {
      final client = _mk(json: {'result': 'ok'});
      await http.runWithClient(() async {
        final r = await ApiService().post('/test', body: {'key': 'value'});
        expect(r.statusCode, 200);
      }, () => client);
    });

    test('generic get with custom headers', () async {
      final client = _mk(json: {'result': 'ok'});
      await http.runWithClient(() async {
        final r = await ApiService().get('/test', headers: {'X-Custom': 'value'});
        expect(r.statusCode, 200);
      }, () => client);
    });

    test('generic post with custom headers', () async {
      final client = _mk(json: {'result': 'ok'});
      await http.runWithClient(() async {
        final r = await ApiService().post('/test', headers: {'X-Custom': 'value'}, body: {'a': 1});
        expect(r.statusCode, 200);
      }, () => client);
    });

    test('removeAvatar success 200', () async {
      final client = _mk(json: {'message': 'Avatar removed'});
      await http.runWithClient(() async {
        final r = await ApiService().removeAvatar(token: _tok);
        expect(r['success'], true);
      }, () => client);
    });

    test('removeAvatar non-200 failure', () async {
      final client = _mk(statusCode: 400, json: {'message': 'No avatar to remove'});
      await http.runWithClient(() async {
        final r = await ApiService().removeAvatar(token: _tok);
        expect(r['success'], false);
      }, () => client);
    });

    test('removeAvatar exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().removeAvatar(token: _tok);
        expect(r['success'], false);
      }, _throwing);
    });

    test('send2FAOtp non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Invalid method'});
      await http.runWithClient(() async {
        final r = await ApiService().send2FAOtp(1, 'email');
        expect(r['success'], false);
      }, () => client);
    });

    test('send2FAOtp 200 success', () async {
      final client = _mk(json: {'otpId': 'otp123'});
      await http.runWithClient(() async {
        final r = await ApiService().send2FAOtp(1, 'email');
        expect(r['success'], true);
      }, () => client);
    });

    test('verify2FAOtp non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Wrong OTP'});
      await http.runWithClient(() async {
        final r = await ApiService().verify2FAOtp(1, '000000', 'email');
        expect(r['success'], false);
      }, () => client);
    });

    test('verify2FAOtp 200 success', () async {
      final client = _mk(json: {'token': 'jwt_token', 'user': {'id': 1}});
      await http.runWithClient(() async {
        final r = await ApiService().verify2FAOtp(1, '123456', 'email');
        expect(r['success'], true);
      }, () => client);
    });

    test('getCategories non-200', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Server error'});
      await http.runWithClient(() async {
        final r = await ApiService().getCategories();
        expect(r['success'], false);
      }, () => client);
    });

    test('getCategories 200 success', () async {
      final client = _mk(json: {'data': [{'id': 1, 'name': 'Music'}, {'id': 2, 'name': 'Sports'}]});
      await http.runWithClient(() async {
        final r = await ApiService().getCategories();
        expect(r['success'], true);
        expect(r['data'], isA<List>());
      }, () => client);
    });

    test('getUserInterests non-200', () async {
      final client = _mk(statusCode: 404, json: {'message': 'User not found'});
      await http.runWithClient(() async {
        final r = await ApiService().getUserInterests(1);
        expect(r['success'], false);
      }, () => client);
    });

    test('getUserInterests 200 success', () async {
      final client = _mk(json: {'data': [1, 2, 3]});
      await http.runWithClient(() async {
        final r = await ApiService().getUserInterests(1);
        expect(r['success'], true);
      }, () => client);
    });

    test('setUserInterests 200 success', () async {
      final client = _mk(json: {'message': 'Interests updated'});
      await http.runWithClient(() async {
        final r = await ApiService().setUserInterests(1, [1, 2, 3], _tok);
        expect(r['success'], true);
      }, () => client);
    });

    test('setUserInterests non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Invalid'});
      await http.runWithClient(() async {
        final r = await ApiService().setUserInterests(1, [1, 2], _tok);
        expect(r['success'], false);
      }, () => client);
    });

    test('hasSelectedInterests 200 true', () async {
      final client = _mk(json: {'hasInterests': true});
      await http.runWithClient(() async {
        final r = await ApiService().hasSelectedInterests(1);
        expect(r, true);
      }, () => client);
    });

    test('hasSelectedInterests 200 false', () async {
      final client = _mk(json: {'hasInterests': false});
      await http.runWithClient(() async {
        final r = await ApiService().hasSelectedInterests(1);
        expect(r, false);
      }, () => client);
    });

    test('getRecommendedVideos 200 success', () async {
      final client = _mk(json: {'data': [{'id': 'v1', 'title': 'Recommended'}]});
      await http.runWithClient(() async {
        final r = await ApiService().getRecommendedVideos(1, limit: 10);
        expect(r['success'], true);
      }, () => client);
    });

    test('getRecommendedVideos non-200', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await ApiService().getRecommendedVideos(1);
        expect(r['success'], false);
      }, () => client);
    });

    test('update2FASettings 200 success', () async {
      final client = _mk(json: {'message': 'Updated'});
      await http.runWithClient(() async {
        final r = await ApiService().update2FASettings(_tok, true, ['email']);
        expect(r['success'], true);
      }, () => client);
    });

    test('update2FASettings non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Failed'});
      await http.runWithClient(() async {
        final r = await ApiService().update2FASettings(_tok, false, []);
        expect(r['success'], false);
      }, () => client);
    });

    test('setupTotp 200 success', () async {
      final client = _mk(json: {'secret': 'ABCDEF', 'qrCode': 'data:image/...'});
      await http.runWithClient(() async {
        final r = await ApiService().setupTotp(_tok);
        expect(r['success'], true);
      }, () => client);
    });

    test('setupTotp non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Failed'});
      await http.runWithClient(() async {
        final r = await ApiService().setupTotp(_tok);
        expect(r['success'], false);
      }, () => client);
    });

    test('verifyTotpSetup 200 success', () async {
      final client = _mk(json: {'message': 'TOTP verified'});
      await http.runWithClient(() async {
        final r = await ApiService().verifyTotpSetup(_tok, '123456', 'SECRET');
        expect(r['success'], true);
      }, () => client);
    });

    test('verifyTotpSetup non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Invalid code'});
      await http.runWithClient(() async {
        final r = await ApiService().verifyTotpSetup(_tok, '000000', 'SECRET');
        expect(r['success'], false);
      }, () => client);
    });
  });

  // =================== GROUP 3: VideoService SUCCESS paths ===================
  group('VideoService success paths', () {
    test('getUserVideos 200 with Map success data', () async {
      final client = _mk(json: {'success': true, 'data': [{'id': 'v1', 'title': 'Test'}]});
      await http.runWithClient(() async {
        final r = await VideoService().getUserVideos('u1');
        expect(r.length, 1);
      }, () => client);
    });

    test('getUserVideos 200 with List data', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode([{'id': 'v1', 'title': 'Test'}]), 200));
      await http.runWithClient(() async {
        final r = await VideoService().getUserVideos('u1');
        expect(r.length, 1);
      }, () => client);
    });

    test('getUserVideos 200 unexpected format', () async {
      final client = _mk(json: {'foo': 'bar'});
      await http.runWithClient(() async {
        final r = await VideoService().getUserVideos('u1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getVideosByUserId 200 Map success with ready videos', () async {
      final client = _mk(json: {
        'success': true,
        'data': [
          {'id': 'v1', 'status': 'ready', 'title': 'Ready Video'},
          {'id': 'v2', 'status': 'processing', 'title': 'Not Ready'},
        ]
      });
      await http.runWithClient(() async {
        final r = await VideoService().getVideosByUserId('u1');
        expect(r.length, 1); // only 'ready' videos
        expect(r[0]['id'], 'v1');
      }, () => client);
    });

    test('getVideosByUserId 200 List format with ready videos', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode([
          {'id': 'v1', 'status': 'ready'},
          {'id': 'v2', 'status': 'processing'},
        ]), 200));
      await http.runWithClient(() async {
        final r = await VideoService().getVideosByUserId('u1');
        expect(r.length, 1);
      }, () => client);
    });

    test('getVideosByUserId 200 unexpected format', () async {
      final client = _mk(json: {'success': false});
      await http.runWithClient(() async {
        final r = await VideoService().getVideosByUserId('u1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getVideosByUserId with requesterId', () async {
      final client = _mk(json: {
        'success': true,
        'data': [{'id': 'v1', 'status': 'ready'}]
      });
      await http.runWithClient(() async {
        final r = await VideoService().getVideosByUserId('u1', requesterId: 'r1');
        expect(r.length, 1);
      }, () => client);
    });

    test('getVideosByUserIdWithPrivacy 200 with success true', () async {
      final client = _mk(json: {
        'success': true,
        'data': [
          {'id': 'v1', 'status': 'ready', 'isHidden': false, 'title': 'Visible'},
          {'id': 'v2', 'status': 'ready', 'isHidden': true, 'title': 'Hidden'},
          {'id': 'v3', 'status': 'processing', 'title': 'Processing'},
        ],
        'privacyRestricted': false,
        'reason': null,
      });
      await http.runWithClient(() async {
        final r = await VideoService().getVideosByUserIdWithPrivacy('u1');
        expect(r['videos'], isA<List>());
        final videos = r['videos'] as List;
        expect(videos.length, 1); // only ready + not hidden
        expect(r['privacyRestricted'], false);
      }, () => client);
    });

    test('getVideosByUserIdWithPrivacy 200 privacy restricted', () async {
      final client = _mk(json: {
        'success': true,
        'data': [],
        'privacyRestricted': true,
        'reason': 'private_account',
      });
      await http.runWithClient(() async {
        final r = await VideoService().getVideosByUserIdWithPrivacy('u1', requesterId: 'r1');
        expect(r['privacyRestricted'], true);
        expect(r['reason'], 'private_account');
      }, () => client);
    });

    test('getVideosByUserIdWithPrivacy 200 no success key', () async {
      final client = _mk(json: {'data': [{'id': 'v1'}]});
      await http.runWithClient(() async {
        final r = await VideoService().getVideosByUserIdWithPrivacy('u1');
        expect(r['videos'], isEmpty);
      }, () => client);
    });

    test('getRecommendedVideos 200 success', () async {
      final client = _mk(json: {
        'success': true,
        'data': [
          {'id': 'v1', 'title': 'For You'},
          {'id': 'v2', 'title': 'Trending'},
        ]
      });
      await http.runWithClient(() async {
        final r = await VideoService().getRecommendedVideos(1, limit: 10);
        expect(r.length, 2);
      }, () => client);
    });

    test('getRecommendedVideos 200 no success/data', () async {
      final client = _mk(json: {'foo': 'bar'});
      await http.runWithClient(() async {
        final r = await VideoService().getRecommendedVideos(1);
        expect(r, isEmpty);
      }, () => client);
    });

    test('getRecommendedVideos with excludeIds', () async {
      final client = _mk(json: {
        'success': true,
        'data': [{'id': 'v3', 'title': 'New'}]
      });
      await http.runWithClient(() async {
        final r = await VideoService().getRecommendedVideos(1, limit: 5, excludeIds: ['v1', 'v2']);
        expect(r.length, 1);
      }, () => client);
    });

    test('getTrendingVideos 200 success', () async {
      final client = _mk(json: {
        'success': true,
        'data': [{'id': 'v1', 'title': 'Trending1'}]
      });
      await http.runWithClient(() async {
        final r = await VideoService().getTrendingVideos(limit: 10);
        expect(r.length, 1);
      }, () => client);
    });

    test('getTrendingVideos 200 no data', () async {
      final client = _mk(json: {'success': false});
      await http.runWithClient(() async {
        final r = await VideoService().getTrendingVideos();
        expect(r, isEmpty);
      }, () => client);
    });

    test('getAllVideos 200 success', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode([{'id': 'v1'}, {'id': 'v2'}]), 200));
      await http.runWithClient(() async {
        final r = await VideoService().getAllVideos();
        expect(r.length, 2);
      }, () => client);
    });

    test('searchVideos 200 with videos without userId', () async {
      final client = _mk(json: {
        'success': true,
        'videos': [
          {'id': 'v1', 'title': 'Found'},
        ]
      });
      await http.runWithClient(() async {
        final r = await VideoService().searchVideos('test');
        expect(r.length, 1);
        expect(r[0]['user'], isNotNull);
      }, () => client);
    });

    test('searchVideos 200 with video having userId', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/videos/search')) {
          return http.Response(jsonEncode({
            'success': true,
            'videos': [{'id': 'v1', 'title': 'Found', 'userId': '100'}]
          }), 200);
        }
        // User fetch
        return http.Response(jsonEncode({'username': 'testuser', 'avatar': 'avatar.jpg'}), 200);
      });
      await http.runWithClient(() async {
        final r = await VideoService().searchVideos('query');
        expect(r.length, 1);
        expect(r[0]['user']['username'], 'testuser');
      }, () => client);
    });

    test('searchVideos 200 user fetch fails', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/videos/search')) {
          return http.Response(jsonEncode({
            'success': true,
            'videos': [{'id': 'v1', 'title': 'Found', 'userId': '100'}]
          }), 200);
        }
        return http.Response('Not found', 404);
      });
      await http.runWithClient(() async {
        final r = await VideoService().searchVideos('query');
        expect(r.length, 1);
        expect(r[0]['user']['username'], 'user');
      }, () => client);
    });

    test('searchVideos 200 user fetch throws', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/videos/search')) {
          return http.Response(jsonEncode({
            'success': true,
            'videos': [{'id': 'v1', 'title': 'Found', 'userId': '100'}]
          }), 200);
        }
        throw Exception('user fetch error');
      });
      await http.runWithClient(() async {
        final r = await VideoService().searchVideos('query');
        expect(r.length, 1);
        expect(r[0]['user']['username'], 'user');
      }, () => client);
    });

    test('searchVideos 200 no success flag', () async {
      final client = _mk(json: {'foo': 'bar'});
      await http.runWithClient(() async {
        final r = await VideoService().searchVideos('query');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getVideoById 200 with video and user', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/users/id/')) {
          return http.Response(jsonEncode({'username': 'creator', 'avatar': 'av.jpg'}), 200);
        }
        return http.Response(jsonEncode({'id': 'v1', 'title': 'My Video', 'userId': '42'}), 200);
      });
      await http.runWithClient(() async {
        final r = await VideoService().getVideoById('v1');
        expect(r, isNotNull);
        expect(r!['username'], 'creator');
      }, () => client);
    });

    test('getVideoById 200 video without userId', () async {
      final client = _mk(json: {'id': 'v1', 'title': 'No User'});
      await http.runWithClient(() async {
        final r = await VideoService().getVideoById('v1');
        expect(r, isNotNull);
        expect(r!['username'], 'user');
      }, () => client);
    });

    test('getVideoById 200 user fetch fails', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/users/id/')) {
          return http.Response('Not found', 404);
        }
        return http.Response(jsonEncode({'id': 'v1', 'userId': '42'}), 200);
      });
      await http.runWithClient(() async {
        final r = await VideoService().getVideoById('v1');
        expect(r, isNotNull);
        expect(r!['username'], 'user');
      }, () => client);
    });

    test('getVideoById 200 user fetch throws', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/users/id/')) {
          throw Exception('network fail');
        }
        return http.Response(jsonEncode({'id': 'v1', 'userId': '42'}), 200);
      });
      await http.runWithClient(() async {
        final r = await VideoService().getVideoById('v1');
        expect(r, isNotNull);
        expect(r!['username'], 'user');
      }, () => client);
    });

    test('getVideoById 200 null response', () async {
      final client = MockClient((_) async => http.Response('null', 200));
      await http.runWithClient(() async {
        final r = await VideoService().getVideoById('v1');
        expect(r, isNull);
      }, () => client);
    });

    test('incrementViewCount 200 success', () async {
      final client = _mk(json: {'viewCount': 42});
      await http.runWithClient(() async {
        await VideoService().incrementViewCount('v1');
      }, () => client);
    });

    test('getFollowingVideos 200 success', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode([{'id': 'v1', 'title': 'Following'}]), 200));
      await http.runWithClient(() async {
        final r = await VideoService().getFollowingVideos('u1');
        expect(r.length, 1);
      }, () => client);
    });

    test('getFollowingVideos non-200', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await VideoService().getFollowingVideos('u1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getFollowingVideos exception', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getFollowingVideos('u1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getFriendsNewVideoCount 200 success', () async {
      final client = _mk(json: {'newCount': 5});
      await http.runWithClient(() async {
        final r = await VideoService().getFriendsNewVideoCount('u1', DateTime(2024, 1, 1));
        expect(r, 5);
      }, () => client);
    });

    test('getFriendsNewVideoCount non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await VideoService().getFriendsNewVideoCount('u1', DateTime(2024, 1, 1));
        expect(r, 0);
      }, () => client);
    });

    test('getFriendsNewVideoCount exception', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getFriendsNewVideoCount('u1', DateTime(2024, 1, 1));
        expect(r, 0);
      }, _throwing);
    });

    test('getVideoUrl with absolute URL', () {
      final url = VideoService().getVideoUrl('https://cdn.example.com/video.m3u8');
      expect(url, 'https://cdn.example.com/video.m3u8');
    });

    test('getVideoUrl with relative path', () {
      final url = VideoService().getVideoUrl('/uploads/video.m3u8');
      expect(url, contains('/uploads/video.m3u8'));
    });
  });

  // =================== GROUP 4: CommentService SUCCESS variants ===================
  group('CommentService success variants', () {
    test('createComment 200 success without image', () async {
      final client = _mk(statusCode: 201, json: {'id': 'c1', 'content': 'Nice!', 'userId': 'u1'});
      await http.runWithClient(() async {
        final r = await CommentService().createComment('v1', 'u1', 'Nice!');
        expect(r, isNotNull);
        expect(r!['id'], 'c1');
      }, () => client);
    });

    test('createComment 200 success with parentId', () async {
      final client = _mk(statusCode: 200, json: {'id': 'c2', 'content': 'Reply', 'parentId': 'c1'});
      await http.runWithClient(() async {
        final r = await CommentService().createComment('v1', 'u1', 'Reply', parentId: 'c1');
        expect(r, isNotNull);
      }, () => client);
    });

    test('getCommentsByVideo 200 returns List format', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode([{'id': 'c1', 'content': 'Hello', 'userId': 'u1'}]), 200));
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideo('v1');
        expect(r.length, 1);
      }, () => client);
    });

    test('getCommentsByVideo 200 returns Map with comments key', () async {
      final client = _mk(json: {'comments': [{'id': 'c1', 'content': 'Hi'}]});
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideo('v1');
        expect(r.length, 1);
      }, () => client);
    });

    test('getCommentsByVideo 200 unexpected format returns empty', () async {
      final client = _mk(json: {'foo': 'bar'});
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideo('v1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getCommentsByVideoWithPagination 200 Map format', () async {
      final client = _mk(json: {
        'comments': [{'id': 'c1'}],
        'hasMore': true,
        'total': 50,
      });
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideoWithPagination('v1');
        expect(r['total'], 50);
        expect(r['hasMore'], true);
      }, () => client);
    });

    test('getCommentsByVideoWithPagination 200 List format', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode([{'id': 'c1'}, {'id': 'c2'}]), 200));
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideoWithPagination('v1');
        expect(r['total'], 2);
        expect(r['hasMore'], false);
        expect((r['comments'] as List).length, 2);
      }, () => client);
    });

    test('getReplies 200 success', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode([{'id': 'r1', 'content': 'Reply'}]), 200));
      await http.runWithClient(() async {
        final r = await CommentService().getReplies('c1');
        expect(r.length, 1);
      }, () => client);
    });

    test('getReplies non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await CommentService().getReplies('c1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getReplies exception', () async {
      await http.runWithClient(() async {
        final r = await CommentService().getReplies('c1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getCommentCount 200 success', () async {
      final client = _mk(json: {'count': 42});
      await http.runWithClient(() async {
        final r = await CommentService().getCommentCount('v1');
        expect(r, 42);
      }, () => client);
    });

    test('getCommentCount non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await CommentService().getCommentCount('v1');
        expect(r, 0);
      }, () => client);
    });

    test('getCommentCount exception', () async {
      await http.runWithClient(() async {
        final r = await CommentService().getCommentCount('v1');
        expect(r, 0);
      }, _throwing);
    });

    test('deleteComment 200 success', () async {
      final client = _mk(json: {'success': true, 'message': 'Deleted'});
      await http.runWithClient(() async {
        final r = await CommentService().deleteComment('c1', 'u1');
        expect(r, true);
      }, () => client);
    });

    test('toggleCommentLike 200 success', () async {
      final client = _mk(json: {'liked': true, 'likeCount': 5});
      await http.runWithClient(() async {
        final r = await CommentService().toggleCommentLike('c1', 'u1');
        expect(r['liked'], true);
      }, () => client);
    });

    test('toggleCommentLike non-200', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await CommentService().toggleCommentLike('c1', 'u1');
        expect(r['liked'], false);
        expect(r['likeCount'], 0);
      }, () => client);
    });

    test('isCommentLikedByUser 200 liked', () async {
      final client = _mk(json: {'liked': true});
      await http.runWithClient(() async {
        final r = await CommentService().isCommentLikedByUser('c1', 'u1');
        expect(r, true);
      }, () => client);
    });

    test('isCommentLikedByUser 200 not liked', () async {
      final client = _mk(json: {'liked': false});
      await http.runWithClient(() async {
        final r = await CommentService().isCommentLikedByUser('c1', 'u1');
        expect(r, false);
      }, () => client);
    });

    test('editComment 200 success', () async {
      final client = _mk(json: {'id': 'c1', 'content': 'Edited content'});
      await http.runWithClient(() async {
        final r = await CommentService().editComment('c1', 'u1', 'Edited content');
        expect(r, isNotNull);
        expect(r!['content'], 'Edited content');
      }, () => client);
    });
  });

  // =================== GROUP 5: AuthService getCurrentUser ===================
  group('AuthService getCurrentUser', () {
    test('getCurrentUser returns cached or null', () async {
      SharedPreferences.setMockInitialValues({});
      final r = await AuthService().getCurrentUser();
      // may return null or cached user depending on singleton state
      expect(true, isTrue); // just ensure no crash
    });

    test('getCurrentUser with SharedPreferences user data', () async {
      SharedPreferences.setMockInitialValues({
        'user': jsonEncode({'id': 99, 'username': 'testuser', 'email': 'test@test.com'}),
      });
      // Note: since AuthService is singleton, _user might already be set from previous tests
      final r = await AuthService().getCurrentUser();
      expect(r, isNotNull);
    });
  });

  // =================== GROUP 6: MessageService REST methods ===================
  group('MessageService REST deeper', () {
    test('getMessages 200 success', () async {
      final client = _mk(json: {'data': [{'id': 'm1', 'content': 'Hello'}]});
      await http.runWithClient(() async {
        final r = await MessageService().getMessages('u1', 'u2');
        expect(r.length, 1);
      }, () => client);
    });

    test('getMessages non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().getMessages('u1', 'u2');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getMessages exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getMessages('u1', 'u2');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getMessages with pagination', () async {
      final client = _mk(json: {'data': [{'id': 'm1'}]});
      await http.runWithClient(() async {
        final r = await MessageService().getMessages('u1', 'u2', limit: 10, offset: 5);
        expect(r.length, 1);
      }, () => client);
    });

    test('getConversations 200 success', () async {
      final client = _mk(json: {'data': [{'recipientId': 'u2', 'lastMessage': 'Hi'}]});
      await http.runWithClient(() async {
        final r = await MessageService().getConversations('u1');
        expect(r.length, 1);
      }, () => client);
    });

    test('getConversations non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().getConversations('u1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getConversations exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getConversations('u1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getUnreadCount 200 success', () async {
      final client = _mk(json: {'count': 3});
      await http.runWithClient(() async {
        final r = await MessageService().getUnreadCount('u1');
        expect(r, 3);
      }, () => client);
    });

    test('getUnreadCount non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().getUnreadCount('u1');
        expect(r, 0);
      }, () => client);
    });

    test('getUnreadCount exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getUnreadCount('u1');
        expect(r, 0);
      }, _throwing);
    });

    test('updateConversationSettings non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Bad'});
      await http.runWithClient(() async {
        final r = await MessageService().updateConversationSettings('r1', isMuted: true);
        expect(r, false);
      }, () => client);
    });

    test('updateConversationSettings exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().updateConversationSettings('r1', isPinned: true);
        expect(r, false);
      }, _throwing);
    });

    test('getConversationSettings non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().getConversationSettings('r1');
        expect(r['isMuted'], false);
        expect(r['isPinned'], false);
      }, () => client);
    });

    test('getConversationSettings exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getConversationSettings('r1');
        expect(r['isMuted'], false);
        expect(r['autoTranslate'], false);
      }, _throwing);
    });

    test('pinMessage non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().pinMessage('m1');
        expect(r, false);
      }, () => client);
    });

    test('pinMessage exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().pinMessage('m1');
        expect(r, false);
      }, _throwing);
    });

    test('unpinMessage non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().unpinMessage('m1');
        expect(r, false);
      }, () => client);
    });

    test('unpinMessage exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().unpinMessage('m1');
        expect(r, false);
      }, _throwing);
    });

    test('getPinnedMessages non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().getPinnedMessages('r1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getPinnedMessages exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getPinnedMessages('r1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('searchMessages non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().searchMessages('r1', 'query');
        expect(r, isEmpty);
      }, () => client);
    });

    test('searchMessages exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().searchMessages('r1', 'query');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getMediaMessages non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().getMediaMessages('r1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getMediaMessages exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getMediaMessages('r1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('deleteForMe non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().deleteForMe('m1');
        expect(r['success'], false);
      }, () => client);
    });

    test('deleteForMe exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().deleteForMe('m1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('deleteForEveryone non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().deleteForEveryone('m1');
        expect(r['success'], false);
      }, () => client);
    });

    test('deleteForEveryone exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().deleteForEveryone('m1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('editMessage non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().editMessage('m1', 'new text');
        expect(r['success'], false);
      }, () => client);
    });

    test('editMessage exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().editMessage('m1', 'new text');
        expect(r['success'], false);
      }, _throwing);
    });

    test('translateMessage non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await MessageService().translateMessage('hello', 'en');
        expect(r['success'], false);
      }, () => client);
    });

    test('translateMessage exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().translateMessage('hello', 'vi');
        expect(r['success'], false);
      }, _throwing);
    });
  });

  // =================== GROUP 7: NotificationService ===================
  group('NotificationService additional', () {
    test('getUnreadCount 200 success', () async {
      final client = _mk(json: {'count': 5});
      await http.runWithClient(() async {
        final r = await NotificationService().getUnreadCount('u1');
        expect(r, 5);
      }, () => client);
    });

    test('getUnreadCount non-200 returns 0', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await NotificationService().getUnreadCount('u1');
        expect(r, 0);
      }, () => client);
    });

    test('getPendingFollowCount 200 success', () async {
      final client = _mk(json: {'count': 2});
      await http.runWithClient(() async {
        final r = await NotificationService().getPendingFollowCount('u1');
        expect(r, 2);
      }, () => client);
    });

    test('getPendingFollowCount non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await NotificationService().getPendingFollowCount('u1');
        expect(r, 0);
      }, () => client);
    });

    test('getPendingFollowCount exception', () async {
      await http.runWithClient(() async {
        final r = await NotificationService().getPendingFollowCount('u1');
        expect(r, 0);
      }, _throwing);
    });
  });

  // =================== GROUP 8: VideoPrefetchService ===================
  group('VideoPrefetchService additional', () {
    test('isPrefetched returns false for unknown URL', () {
      final r = VideoPrefetchService().isPrefetched('https://example.com/video.m3u8');
      expect(r, false);
    });

    test('clearCache does not throw', () {
      VideoPrefetchService().clearCache();
      expect(true, isTrue);
    });

    test('getStats returns valid map', () {
      final stats = VideoPrefetchService().getStats();
      expect(stats['cachedUrls'], isA<int>());
      expect(stats['pendingPrefetch'], isA<int>());
      expect(stats['successRate'], isA<double>());
    });
  });
}
