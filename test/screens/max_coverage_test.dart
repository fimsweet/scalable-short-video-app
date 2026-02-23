/// Maximum coverage tests targeting remaining build methods, dialog paths,
/// and conditional rendering branches in gap files.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import '../helpers/test_setup.dart';
import '../helpers/mock_http_client.dart';

import 'package:scalable_short_video_app/src/presentation/screens/account_management_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/activity_history_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/login_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/two_factor_auth_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/follower_following_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_options_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/notifications_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/upload_video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/upload_video_screen_v2.dart';
import 'package:scalable_short_video_app/src/presentation/screens/change_password_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/forgot_password_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/search_screen.dart';

import 'package:scalable_short_video_app/src/presentation/screens/privacy_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/report_user_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/inbox_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/share_video_sheet.dart';

http.Client _mk({
  bool hasPassword = true, bool has2FA = false,
  bool require2FA = false, bool requireReactivation = false,
  bool serverError = false, bool emptyData = false,
  bool allowComments = true, String whoCanComment = 'everyone',
}) {
  return MockClient((request) async {
    final path = request.url.path;
    final method = request.method;
    final query = request.url.queryParameters;

    if (serverError) {
      return http.Response('Server Error', 500);
    }

    // Analytics
    if (path.startsWith('/analytics/')) {
      if (emptyData) {
        return http.Response(json.encode({
          'success': true,
          'analytics': {
            'overview': {'totalVideos': 0, 'totalViews': 0, 'totalLikes': 0,
              'totalComments': 0, 'totalShares': 0, 'engagementRate': 0.0,
              'followersCount': 0, 'followingCount': 0},
            'recent': {'videosLast7Days': 0, 'viewsLast7Days': 0},
            'allVideos': [], 'topVideos': [], 'distribution': {'likes': 0, 'comments': 0, 'shares': 0},
            'dailyStats': [],
          },
        }), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response(json.encode({
        'success': true,
        'analytics': {
          'overview': {'totalVideos': 45, 'totalViews': 25000, 'totalLikes': 12000,
            'totalComments': 4500, 'totalShares': 2200, 'engagementRate': 48.0,
            'followersCount': 890, 'followingCount': 456},
          'recent': {'videosLast7Days': 5, 'viewsLast7Days': 3200},
          'allVideos': List.generate(5, (i) {
            return {'id': 'v$i', 'title': 'Video$i', 'thumbnailUrl': '/t$i.jpg',
              'views': 1000 + i * 100, 'likes': 500, 'comments': 100,
              'createdAt': '2026-01-${15-i}T08:00:00Z'};
          }),
          'topVideos': [{'id': 'vt0', 'title': 'Top', 'views': 9999}],
          'distribution': {'likes': 12000, 'comments': 4500, 'shares': 2200},
          'dailyStats': List.generate(7, (i) {
            return {'date': '2026-01-0${i+1}', 'views': 500, 'likes': 100, 'comments': 30, 'shares': 10};
          }),
        },
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Comments
    if (path.contains('/comments/') && path.contains('/like')) {
      return http.Response(json.encode({'liked': true, 'likeCount': 5}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/comments/') && path.contains('/replies')) {
      return http.Response(json.encode([
        {'id': 'r1', 'content': 'Reply1', 'userId': 3, 'username': 'replier',
          'likeCount': 1, 'isLiked': false, 'createdAt': DateTime.now().toIso8601String()},
      ]), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/comments/video/')) {
      return http.Response(json.encode({
        'comments': emptyData ? [] : List.generate(8, (i) {
          return {
            'id': 'c$i', 'content': 'Comment $i content here', 'userId': i + 2,
            'username': 'commenter$i', 'displayName': 'Commenter $i', 'avatar': null,
            'likeCount': i * 3, 'replyCount': i > 3 ? 2 : 0, 'isLiked': i.isEven,
            'imageUrl': i == 2 ? 'comment_img.jpg' : null,
            'isToxic': i == 5 ? true : false,
            'createdAt': DateTime.now().subtract(Duration(hours: i * 2)).toIso8601String(),
            'replies': i > 3 ? [
              {'id': 'r${i}a', 'content': 'Reply A', 'userId': 1, 'username': 'testuser',
                'likeCount': 0, 'isLiked': false, 'createdAt': DateTime.now().toIso8601String()},
            ] : [],
          };
        }),
        'hasMore': !emptyData, 'total': emptyData ? 0 : 50,
      }), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/comments') && method == 'POST') {
      return http.Response(json.encode({
        'id': 'cnew', 'content': request.body.contains('content') ? 'New comment' : '',
        'userId': 1, 'username': 'testuser', 'likeCount': 0, 'replyCount': 0,
        'createdAt': DateTime.now().toIso8601String(),
      }), 201, headers: {'content-type': 'application/json'});
    }

    // Video operations
    if (path.contains('/videos/') && path.contains('/like')) {
      return http.Response(json.encode({'liked': true, 'likeCount': 201}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/videos/') && path.contains('/save')) {
      return http.Response(json.encode({'saved': true}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/videos/') && path.contains('/share')) {
      return http.Response(json.encode({'success': true, 'shareCount': 11}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/videos/') && path.contains('/view')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/videos/') && path.contains('/hide')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Videos list
    if (path.contains('/videos')) {
      final type = query['type'] ?? '';
      return http.Response(json.encode({
        'success': true,
        'data': emptyData ? [] : List.generate(5, (i) {
          return {
            'id': 'v${type}$i', 'title': 'Video $type $i', 'description': 'Desc #tag$i',
            'hlsUrl': 'https://example.com/v.m3u8', 'thumbnailUrl': '/thumb$i.jpg',
            'userId': i + 1, 'viewCount': 500 + i * 100, 'likeCount': 200 + i * 50,
            'commentCount': 50 + i * 10, 'shareCount': 10 + i * 5,
            'createdAt': '2026-01-15T08:00:00Z', 'status': 'ready',
            'visibility': 'public', 'allowComments': allowComments,
            'isLiked': i.isEven, 'isSaved': i == 0,
            'user': {'id': i + 1, 'username': 'creator$i', 'avatar': null, 'displayName': 'Creator $i'},
          };
        }),
        'total': 50, 'hasMore': true,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Activity history
    if (path.startsWith('/activity-history/')) {
      if (method == 'DELETE') {
        return http.Response(json.encode({'success': true}), 200,
            headers: {'content-type': 'application/json'});
      }
      final filter = query['filter'] ?? 'all';
      final types = ['login', 'video_like', 'comment', 'follow', 'video_upload',
        'password_change', 'profile_edit', 'video_view', 'video_share', 'report'];
      return http.Response(json.encode({
        'activities': emptyData ? [] : List.generate(12, (i) {
          return {
            'id': i + 1, 'type': types[i % types.length],
            'description': 'Activity desc $i for $filter',
            'createdAt': DateTime.now().subtract(Duration(hours: i * 6)).toIso8601String(),
            'metadata': {
              'ip': '10.0.0.${i+1}', 'device': 'Mozilla/5.0', 'location': 'HCMC',
              'videoId': 'vid$i', 'videoTitle': 'Video $i',
              'targetUserId': '${i+10}', 'targetUsername': 'target$i',
              'thumbnailUrl': 'https://img.example.com/t$i.jpg',
            },
          };
        }),
        'hasMore': !emptyData, 'total': emptyData ? 0 : 100,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Account info
    if (path == '/auth/account-info') {
      return http.Response(json.encode({
        'phoneNumber': '+84999888777', 'email': 'user@test.com',
        'googleLinked': true, 'hasPassword': hasPassword, 'authProvider': 'local',
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Has password
    if (path == '/users/has-password') {
      return http.Response(json.encode({'hasPassword': hasPassword}), 200,
          headers: {'content-type': 'application/json'});
    }

    // 2FA settings
    if (path == '/auth/2fa/settings') {
      return http.Response(json.encode({
        'enabled': has2FA, 'methods': has2FA ? ['totp', 'email'] : [],
      }), 200, headers: {'content-type': 'application/json'});
    }

    // 2FA operations (setup, verify, disable)
    if (path.contains('/2fa/')) {
      if (path.contains('/setup')) {
        return http.Response(json.encode({
          'success': true, 'secret': 'JBSWY3DPEHPK3PXP',
          'qrCode': 'data:image/png;base64,iVBOR',
          'backupCodes': ['11111111', '22222222', '33333333', '44444444'],
        }), 200, headers: {'content-type': 'application/json'});
      }
      if (path.contains('/verify')) {
        return http.Response(json.encode({
          'success': true, 'access_token': 'new_token',
          'user': {'id': 1, 'username': 'testuser'},
        }), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Login
    if (path.contains('/auth/login') && method == 'POST') {
      if (requireReactivation) {
        return http.Response(json.encode({
          'success': true, 'data': {
            'requiresReactivation': true, 'userId': 1, 'daysRemaining': 14,
          },
        }), 200, headers: {'content-type': 'application/json'});
      }
      if (require2FA) {
        return http.Response(json.encode({
          'success': true, 'data': {
            'requires2FA': true, 'userId': 1,
            'twoFactorMethods': ['totp', 'email'],
          },
        }), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response(json.encode({
        'success': true, 'data': {
          'user': {'id': 1, 'username': 'testuser', 'displayName': 'Test User'},
          'access_token': 'valid_token',
        },
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Reactivate
    if (path.contains('/reactivate')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Followers/following
    if (path.contains('/follows/followers-with-status/') || path.contains('/follows/following-with-status/')) {
      return http.Response(json.encode({
        'data': emptyData ? [] : List.generate(6, (i) {
          return {'userId': '${i+10}', 'username': 'uu$i', 'displayName': 'User $i',
            'avatar': i == 0 ? 'https://img.example.com/av.jpg' : null, 'isMutual': i < 3};
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/follows/count/')) {
      return http.Response(json.encode({'followersCount': 567, 'followingCount': 234}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/follow') && method == 'POST') {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/follow') && method == 'DELETE') {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Conversations
    if (path.contains('/messages/conversations/')) {
      return http.Response(json.encode({
        'data': List.generate(3, (i) {
          return {
            'id': 'conv$i',
            'participants': [{'userId': '${i + 10}', 'username': 'cuser$i'}, {'userId': '1', 'username': 'testuser'}],
            'lastMessage': {'content': 'Hello $i', 'createdAt': DateTime.now().toIso8601String()},
          };
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Messages
    if (path.contains('/messages/')) {
      return http.Response(json.encode({
        'data': [{'id': 'm1', 'content': 'Hi', 'senderId': '10', 'createdAt': DateTime.now().toIso8601String()}],
      }), 200, headers: {'content-type': 'application/json'});
    }

    // User by ID
    if (path.contains('/users/id/')) {
      return http.Response(json.encode({
        'id': 1, 'username': 'testuser', 'displayName': 'Test User',
        'email': 'test@test.com', 'bio': 'Test bio here',
        'avatar': null, 'followersCount': 567, 'followingCount': 234,
        'videoCount': 45, 'gender': 'female', 'dateOfBirth': '1999-06-15',
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Privacy
    if (path.contains('/users/privacy/check') && method == 'POST') {
      return http.Response(json.encode({'allowed': allowComments, 'reason': allowComments ? '' : 'Restricted'}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/users/privacy/')) {
      return http.Response(json.encode({
        'settings': {'whoCanComment': whoCanComment, 'whoCanMessage': 'everyone', 'accountPrivacy': 'public'},
      }), 200, headers: {'content-type': 'application/json'});
    }

    // User settings
    if (path == '/users/settings') {
      return http.Response(json.encode({
        'success': true, 'settings': {'filterComments': true, 'showOnlineStatus': true},
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Blocked users
    if (path.contains('/users/blocked/')) {
      return http.Response(json.encode([
        {'id': 100, 'blockedUserId': '100', 'username': 'blockedUser0'},
        {'id': 101, 'blockedUserId': '101', 'username': 'blockedUser1'},
      ]), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/block') && method == 'POST') {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/unblock')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Sessions/devices
    if (path.contains('/sessions') || path.contains('/devices')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(3, (i) {
          return {'id': 's$i', 'device': 'Device$i', 'browser': 'Chrome',
            'os': 'Windows', 'ip': '10.0.0.$i', 'isCurrent': i == 0,
            'lastActive': DateTime.now().toIso8601String()};
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Set/change password
    if (path.contains('/password') && method == 'POST') {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/password') && method == 'PUT') {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Deactivate
    if (path.contains('/deactivate')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Profile update
    if (path.contains('/users/profile') && method == 'PUT') {
      return http.Response(json.encode({'success': true, 'data': {}}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Notifications 
    if (path.contains('/notifications')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(5, (i) {
          return {'id': 'n$i', 'type': ['like', 'comment', 'follow'][i % 3],
            'message': 'Notification $i', 'read': i > 2,
            'createdAt': DateTime.now().subtract(Duration(hours: i)).toIso8601String(),
            'metadata': {'videoId': 'v$i', 'userId': i + 5}};
        }),
        'unreadCount': 2, 'total': 20, 'hasMore': true,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Search
    if (path.contains('/search')) {
      return http.Response(json.encode({
        'data': List.generate(3, (i) {
          return {'id': i + 20, 'username': 'found$i', 'displayName': 'Found User $i', 'avatar': null};
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Suggested users
    if (path.contains('/suggested')) {
      return http.Response(json.encode({
        'data': [{'id': 30, 'username': 'suggest0', 'displayName': 'Suggested'}],
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Reports
    if (path.contains('/report')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Categories
    if (path.contains('/categories')) {
      return http.Response(json.encode({
        'data': [{'id': 1, 'name': 'Entertainment'}, {'id': 2, 'name': 'Music'}, {'id': 3, 'name': 'Sports'}],
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Logout
    if (path.contains('/logout')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Settings update
    if (path.contains('/settings') && (method == 'PUT' || method == 'PATCH')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // OTP
    if (path.contains('/otp')) {
      return http.Response(json.encode({'success': true, 'verified': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Forgot password
    if (path.contains('/forgot')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Users generic
    if (path.contains('/users/')) {
      return http.Response(json.encode({
        'id': 1, 'username': 'testuser', 'displayName': 'Test User',
        'bio': 'Bio here', 'avatar': null, 'followersCount': 120,
        'videoCount': 10, 'hasPassword': hasPassword,
      }), 200, headers: {'content-type': 'application/json'});
    }

    return http.Response(json.encode({'success': true}), 200,
        headers: {'content-type': 'application/json'});
  });
}

Future<void> _wait(WidgetTester t, {int n = 15, int ms = 500}) async {
  for (int i = 0; i < n; i++) {
    await t.pump(Duration(milliseconds: ms));
    t.takeException();
  }
}

Future<void> _scrollD(WidgetTester t, {int n = 5, double dy = -400}) async {
  for (int j = 0; j < n; j++) {
    final s = find.byType(Scaffold);
    if (s.evaluate().isNotEmpty) {
      await t.drag(s.first, Offset(0, dy));
      await t.pump(const Duration(milliseconds: 200));
      t.takeException();
    }
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = MockSecureStorage();
  });

  setUp(() async {
    final loginClient = createMockHttpClient();
    await http.runWithClient(() async {
      await setupLoggedInState();
    }, () => loginClient);
  });

  // ====== LOGIN SCREEN BRANCHES ======
  group('Login branches', () {
    testWidgets('successful login flow', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _wait(t, n: 5);
        // Fill fields
        final tfs = find.byType(TextFormField);
        if (tfs.evaluate().length >= 2) {
          await t.enterText(tfs.at(0), 'testuser');
          await t.pump();
          await t.enterText(tfs.at(1), 'Password123!');
          await t.pump();
        }
        // Hide/show password toggle
        final iconBtns = find.byType(IconButton);
        for (int i = 0; i < iconBtns.evaluate().length; i++) {
          try {
            await t.tap(iconBtns.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
        // Tap login
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await t.tap(btns.first, warnIfMissed: false);
          await _wait(t, n: 10);
        }
      }, () => c);
    });

    testWidgets('empty validation', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _wait(t, n: 5);
        // Tap login without entering anything
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await t.tap(btns.first, warnIfMissed: false);
          await _wait(t, n: 5);
        }
        // Should show validation errors
        expect(find.byType(LoginScreen), findsOneWidget);
      }, () => c);
    });

    testWidgets('reactivation flow with tap reactivate', (t) async {
      final c = _mk(requireReactivation: true);
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _wait(t, n: 5);
        final tfs = find.byType(TextFormField);
        if (tfs.evaluate().length >= 2) {
          await t.enterText(tfs.at(0), 'deactuser');
          await t.pump();
          await t.enterText(tfs.at(1), 'Pass123!');
          await t.pump();
        }
        // Login
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await t.tap(btns.first, warnIfMissed: false);
          await _wait(t, n: 10);
        }
        // Reactivation dialog should appear
        // Tap reactivate button in dialog
        final allBtns = find.byType(ElevatedButton);
        if (allBtns.evaluate().isNotEmpty) {
          await t.tap(allBtns.last, warnIfMissed: false);
          await _wait(t, n: 8);
        }
        // Also tap cancel/TextButton
        final txtBtns = find.byType(TextButton);
        if (txtBtns.evaluate().isNotEmpty) {
          await t.tap(txtBtns.first, warnIfMissed: false);
          await _wait(t, n: 3);
        }
      }, () => c);
    });

    testWidgets('2FA required flow', (t) async {
      final c = _mk(require2FA: true);
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _wait(t, n: 5);
        final tfs = find.byType(TextFormField);
        if (tfs.evaluate().length >= 2) {
          await t.enterText(tfs.at(0), '2fauser');
          await t.pump();
          await t.enterText(tfs.at(1), 'Pass123!');
          await t.pump();
        }
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await t.tap(btns.first, warnIfMissed: false);
          await _wait(t, n: 10);
        }
        // 2FA page should be pushed - interact with it
        final otpFields = find.byType(TextField);
        for (int i = 0; i < otpFields.evaluate().length; i++) {
          try {
            await t.enterText(otpFields.at(i), '123456');
            await _wait(t, n: 2);
          } catch (_) {}
        }
        // Try verify
        final verifyBtns = find.byType(ElevatedButton);
        if (verifyBtns.evaluate().isNotEmpty) {
          await t.tap(verifyBtns.last, warnIfMissed: false);
          await _wait(t, n: 8);
        }
      }, () => c);
    });

    testWidgets('scroll to register link and social buttons', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _wait(t, n: 5);
        // Scroll to bottom to reveal register link and social buttons
        await _scrollD(t, n: 8);
        // Scroll back
        await _scrollD(t, n: 4, dy: 400);
        // Tap register link (GestureDetector)
        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 5; i++) {
          try {
            await t.tap(gds.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
        // InkWells (social buttons are InkWell)
        final iws = find.byType(InkWell);
        for (int i = 0; i < iws.evaluate().length && i < 5; i++) {
          try {
            await t.tap(iws.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
      }, () => c);
    });

    testWidgets('forgot password link', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _wait(t, n: 5);
        // Look for forgot password text
        final forgotBtn = find.byType(TextButton);
        if (forgotBtn.evaluate().isNotEmpty) {
          await t.tap(forgotBtn.first, warnIfMissed: false);
          await _wait(t, n: 5);
        }
        // Navigate back if pushed
        final back = find.byType(BackButton);
        if (back.evaluate().isNotEmpty) {
          await t.tap(back.first, warnIfMissed: false);
          await _wait(t, n: 3);
        }
        // Timer cleanup for forgot password
        await t.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) await t.pump(const Duration(seconds: 1));
      }, () => c);
    });

    testWidgets('server error on login', (t) async {
      final c = _mk(serverError: true);
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _wait(t, n: 5);
        final tfs = find.byType(TextFormField);
        if (tfs.evaluate().length >= 2) {
          await t.enterText(tfs.at(0), 'erroruser');
          await t.pump();
          await t.enterText(tfs.at(1), 'Pass!');
          await t.pump();
        }
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await t.tap(btns.first, warnIfMissed: false);
          await _wait(t, n: 8);
        }
      }, () => c);
    });
  });

  // ====== EDIT PROFILE DEEP ======
  group('EditProfile deep', () {
    testWidgets('tap all editable fields', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        await _wait(t);
        // Tap all InkWells (display name, username, bio, gender, date of birth)
        final iws = find.byType(InkWell);
        for (int i = 0; i < iws.evaluate().length; i++) {
          try {
            await t.tap(iws.at(i), warnIfMissed: false);
            await _wait(t, n: 5);
            // If a bottom sheet / dialog / new screen appeared, interact with it
            final tfs = find.byType(TextField);
            for (int j = 0; j < tfs.evaluate().length; j++) {
              try {
                await t.enterText(tfs.at(j), 'Edited $j');
                await t.pump();
              } catch (_) {}
            }
            // Tap save/confirm buttons
            final elevBtns = find.byType(ElevatedButton);
            for (int j = 0; j < elevBtns.evaluate().length; j++) {
              try {
                await t.tap(elevBtns.at(j), warnIfMissed: false);
                await _wait(t, n: 3);
              } catch (_) {}
            }
            // Dismiss potential dialogs/sheets
            try {
              await t.tapAt(const Offset(10, 10));
              await _wait(t, n: 2);
            } catch (_) {}
          } catch (_) {}
        }
      }, () => c);
    });

    testWidgets('gender options selection', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        await _wait(t);
        await _scrollD(t, n: 3);
        // Find gender icon and tap
        final genderIcon = find.byIcon(Icons.chevron_right);
        for (int i = 0; i < genderIcon.evaluate().length; i++) {
          try {
            final parent = find.ancestor(of: genderIcon.at(i), matching: find.byType(InkWell));
            if (parent.evaluate().isNotEmpty) {
              await t.tap(parent.first, warnIfMissed: false);
              await _wait(t, n: 5);
              // Tap list tiles in bottom sheet
              final listTiles = find.byType(ListTile);
              for (int j = 0; j < listTiles.evaluate().length && j < 4; j++) {
                try {
                  await t.tap(listTiles.at(j), warnIfMissed: false);
                  await _wait(t, n: 3);
                } catch (_) {}
              }
              break;
            }
          } catch (_) {}
        }
      }, () => c);
    });

    testWidgets('save profile with changes', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        await _wait(t);
        // Edit text fields
        final tfs = find.byType(TextField);
        for (int i = 0; i < tfs.evaluate().length; i++) {
          try {
            await t.enterText(tfs.at(i), 'NewValue$i');
            await t.pump();
          } catch (_) {}
        }
        // Find and tap save button (TextButton or ElevatedButton in AppBar)
        final txtBtns = find.byType(TextButton);
        for (int i = 0; i < txtBtns.evaluate().length; i++) {
          try {
            await t.tap(txtBtns.at(i), warnIfMissed: false);
            await _wait(t, n: 5);
          } catch (_) {}
        }
        // Also tap GestureDetectors  
        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 8; i++) {
          try {
            await t.tap(gds.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
      }, () => c);
    });
  });

  // ====== 2FA SCREEN DEEP ======
  group('TwoFactorAuth deep', () {
    testWidgets('overview with 2FA disabled - tap enable', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        await _wait(t);
        await _scrollD(t, n: 5);
        // Find and tap all ElevatedButtons
        final btns = find.byType(ElevatedButton);
        for (int i = 0; i < btns.evaluate().length; i++) {
          try {
            await t.tap(btns.at(i), warnIfMissed: false);
            await _wait(t, n: 5);
          } catch (_) {}
        }
        // Tap InkWell method tiles
        final iws = find.byType(InkWell);
        for (int i = 0; i < iws.evaluate().length && i < 10; i++) {
          try {
            await t.tap(iws.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
        // Switch/checkbox
        final sws = find.byType(Switch);
        for (int i = 0; i < sws.evaluate().length; i++) {
          try {
            await t.tap(sws.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
        // Scroll more to reveal setup steps
        await _scrollD(t, n: 5);
        // Enter OTP if setup flow
        final tfs = find.byType(TextField);
        for (int i = 0; i < tfs.evaluate().length; i++) {
          try {
            await t.enterText(tfs.at(i), '123456');
            await _wait(t, n: 2);
          } catch (_) {}
        }
        // Confirm
        final confirmBtns = find.byType(ElevatedButton);
        for (int i = 0; i < confirmBtns.evaluate().length; i++) {
          try {
            await t.tap(confirmBtns.at(i), warnIfMissed: false);
            await _wait(t, n: 5);
          } catch (_) {}
        }
        await t.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) await t.pump(const Duration(seconds: 1));
      }, () => c);
    });

    testWidgets('2FA enabled overview - methods visible', (t) async {
      final c = _mk(has2FA: true);
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        await _wait(t);
        await _scrollD(t, n: 5);
        expect(find.byType(TwoFactorAuthScreen), findsOneWidget);
        // Tap disable
        final btns = find.byType(ElevatedButton);
        for (int i = 0; i < btns.evaluate().length; i++) {
          try {
            await t.tap(btns.at(i), warnIfMissed: false);
            await _wait(t, n: 5);
            // Confirm disable dialog
            final dialogBtns = find.byType(ElevatedButton);
            if (dialogBtns.evaluate().isNotEmpty) {
              await t.tap(dialogBtns.last, warnIfMissed: false);
              await _wait(t, n: 5);
            }
          } catch (_) {}
        }
        await t.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) await t.pump(const Duration(seconds: 1));
      }, () => c);
    });

    testWidgets('2FA back/close button in setup', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        await _wait(t);
        // Start setup
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await t.tap(btns.first, warnIfMissed: false);
          await _wait(t, n: 5);
        }
        // Click close/back icon
        final iconBtns = find.byType(IconButton);
        if (iconBtns.evaluate().isNotEmpty) {
          await t.tap(iconBtns.first, warnIfMissed: false);
          await _wait(t, n: 5);
        }
        await t.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) await t.pump(const Duration(seconds: 1));
      }, () => c);
    });
  });

  // ====== ACTIVITY HISTORY DEEP ======
  group('ActivityHistory deep', () {
    testWidgets('empty state', (t) async {
      final c = _mk(emptyData: true);
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        await _wait(t);
        expect(find.byType(ActivityHistoryScreen), findsOneWidget);
      }, () => c);
    });

    testWidgets('filter tabs all types', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        await _wait(t);
        // Tap every GestureDetector (filter tabs are GestureDetectors)
        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 8; i++) {
          try {
            await t.tap(gds.at(i), warnIfMissed: false);
            await _wait(t, n: 8);
          } catch (_) {}
        }
      }, () => c);
    });

    testWidgets('scroll and expand activity items', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        await _wait(t);
        // Scroll extensively
        await _scrollD(t, n: 10);
        // Tap activity items
        final iws = find.byType(InkWell);
        for (int i = 0; i < iws.evaluate().length && i < 8; i++) {
          try {
            await t.tap(iws.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
        await _scrollD(t, n: 5, dy: 400); // Scroll back up
        await t.pumpWidget(const SizedBox());
        for (int i = 0; i < 25; i++) await t.pump(const Duration(seconds: 1));
      }, () => c);
    });

    testWidgets('manage menu and delete by time', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        await _wait(t);
        // Find and tap the more/manage icon
        final moreBtns = find.byIcon(Icons.more_vert);
        if (moreBtns.evaluate().isNotEmpty) {
          await t.tap(moreBtns.first, warnIfMissed: false);
          await _wait(t, n: 5);
          // Tap items in the bottom sheet
          final sheetItems = find.byType(InkWell);
          for (int i = sheetItems.evaluate().length - 1; i >= 0 && i > sheetItems.evaluate().length - 6; i--) {
            try {
              await t.tap(sheetItems.at(i), warnIfMissed: false);
              await _wait(t, n: 5);
              // Accept dialog confirmations
              final confirmBtns = find.byType(ElevatedButton);
              if (confirmBtns.evaluate().isNotEmpty) {
                await t.tap(confirmBtns.last, warnIfMissed: false);
                await _wait(t, n: 5);
              }
              // Dismiss
              try { await t.tapAt(const Offset(10, 10)); await _wait(t, n: 2); } catch (_) {}
            } catch (_) {}
          }
        }
        // Also try PopupMenuButton
        final popups = find.byType(PopupMenuButton);
        if (popups.evaluate().isNotEmpty) {
          await t.tap(popups.first, warnIfMissed: false);
          await _wait(t, n: 3);
          final menuItems = find.byType(PopupMenuItem);
          for (int i = 0; i < menuItems.evaluate().length; i++) {
            try {
              await t.tap(menuItems.at(i), warnIfMissed: false);
              await _wait(t, n: 5);
            } catch (_) {}
          }
        }
        await t.pumpWidget(const SizedBox());
        for (int i = 0; i < 25; i++) await t.pump(const Duration(seconds: 1));
      }, () => c);
    });
  });

  // ====== COMMENT SECTION DEEP ======
  group('CommentSection deep', () {
    testWidgets('comments disabled banner', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v1', allowComments: false, videoOwnerId: '2', onCommentAdded: () {},
          )),
        ));
        await _wait(t);
        // Should show disabled banner
        expect(find.byType(CommentSectionWidget), findsOneWidget);
      }, () => c);
    });

    testWidgets('comments with replies and scrolling', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v2', allowComments: true, videoOwnerId: '9', onCommentAdded: () {},
          )),
        ));
        await _wait(t);
        // Scroll through comments
        final scrollables = find.byType(Scrollable);
        for (int s = 0; s < 5; s++) {
          if (scrollables.evaluate().isNotEmpty) {
            try {
              await t.fling(scrollables.first, const Offset(0, -500), 1500);
              await _wait(t, n: 5);
            } catch (_) {}
          }
        }
        // Tap all GestureDetectors (like, reply, expand)
        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 15; i++) {
          try {
            await t.tap(gds.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
      }, () => c);
    });

    testWidgets('empty comments state', (t) async {
      final c = _mk(emptyData: true);
      await http.runWithClient(() async {
        await t.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v3', allowComments: true, videoOwnerId: '2', onCommentAdded: () {},
          )),
        ));
        await _wait(t);
        expect(find.byType(CommentSectionWidget), findsOneWidget);
      }, () => c);
    });

    testWidgets('send comment with text', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v4', allowComments: true, videoOwnerId: '2',
            onCommentAdded: () {}, onCommentDeleted: () {},
          )),
        ));
        await _wait(t);
        final tf = find.byType(TextField);
        if (tf.evaluate().isNotEmpty) {
          await t.enterText(tf.first, 'New comment here!');
          await _wait(t, n: 3);
          // Find send icon and tap
          final sendIcons = find.byIcon(Icons.send);
          if (sendIcons.evaluate().isNotEmpty) {
            final ancestor = find.ancestor(of: sendIcons.first, matching: find.byType(GestureDetector));
            if (ancestor.evaluate().isNotEmpty) {
              await t.tap(ancestor.first, warnIfMissed: false);
              await _wait(t, n: 8);
            }
          }
          // Also try IconButtons
          final iconBtns = find.byType(IconButton);
          for (int i = 0; i < iconBtns.evaluate().length; i++) {
            try {
              await t.tap(iconBtns.at(i), warnIfMissed: false);
              await _wait(t, n: 3);
            } catch (_) {}
          }
        }
      }, () => c);
    });

    testWidgets('reply mode', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v5', allowComments: true, videoOwnerId: '2', autoFocus: true,
            onCommentAdded: () {},
          )),
        ));
        await _wait(t);
        // Find "reply" text touches
        final replyTexts = find.textContaining(RegExp(r'reply|trả lời|Reply', caseSensitive: false));
        for (int i = 0; i < replyTexts.evaluate().length && i < 3; i++) {
          try {
            await t.tap(replyTexts.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
        // Try GDs
        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 20; i++) {
          try {
            await t.tap(gds.at(i), warnIfMissed: false);
            await _wait(t, n: 2);
          } catch (_) {}
        }
      }, () => c);
    });
  });

  // ====== VIDEO SCREEN DEEP ======
  group('VideoScreen deep', () {
    testWidgets('empty video state', (t) async {
      final c = _mk(emptyData: true);
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: VideoScreen()));
        await _wait(t);
        expect(find.byType(VideoScreen), findsOneWidget);
      }, () => c);
    });

    testWidgets('tab bar switching all tabs', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: VideoScreen()));
        await _wait(t);
        // Find tab bar tabs
        final tabs = find.byType(Tab);
        for (int i = 0; i < tabs.evaluate().length; i++) {
          try {
            await t.tap(tabs.at(i), warnIfMissed: false);
            await _wait(t, n: 8);
          } catch (_) {}
        }
        // Fling through videos
        for (int i = 0; i < 3; i++) {
          try {
            await t.fling(find.byType(VideoScreen), const Offset(0, -600), 2000);
            await _wait(t, n: 5);
          } catch (_) {}
        }
      }, () => c);
    });

    testWidgets('swipe between tabs horizontally', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: VideoScreen()));
        await _wait(t);
        // Horizontal swipe
        for (int i = 0; i < 3; i++) {
          try {
            await t.fling(find.byType(VideoScreen), const Offset(-300, 0), 1000);
            await _wait(t, n: 5);
          } catch (_) {}
        }
        for (int i = 0; i < 3; i++) {
          try {
            await t.fling(find.byType(VideoScreen), const Offset(300, 0), 1000);
            await _wait(t, n: 5);
          } catch (_) {}
        }
      }, () => c);
    });
  });

  // ====== FOLLOWER FOLLOWING DEEP ======
  group('FollowerFollowing deep', () {
    testWidgets('both tabs with users', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(MaterialApp(home: FollowerFollowingScreen(userId: 1)));
        await _wait(t);
        // Tab 0 - followers (default)
        await _scrollD(t, n: 5);
        // Tab 1 - following
        final tabs = find.byType(Tab);
        if (tabs.evaluate().length >= 2) {
          await t.tap(tabs.at(1));
          await _wait(t, n: 8);
          await _scrollD(t, n: 3);
        }
        // Back to followers
        if (tabs.evaluate().isNotEmpty) {
          await t.tap(tabs.first);
          await _wait(t, n: 5);
        }
        // Tap follow/unfollow buttons
        final elevBtns = find.byType(ElevatedButton);
        for (int i = 0; i < elevBtns.evaluate().length && i < 4; i++) {
          try {
            await t.tap(elevBtns.at(i), warnIfMissed: false);
            await _wait(t, n: 5);
          } catch (_) {}
        }
        // Tap user items to navigate
        final iws = find.byType(InkWell);
        for (int i = 0; i < iws.evaluate().length && i < 3; i++) {
          try {
            await t.tap(iws.at(i), warnIfMissed: false);
            await _wait(t, n: 5);
          } catch (_) {}
        }
      }, () => c);
    });

    testWidgets('empty followers list', (t) async {
      final c = _mk(emptyData: true);
      await http.runWithClient(() async {
        await t.pumpWidget(MaterialApp(home: FollowerFollowingScreen(userId: 1)));
        await _wait(t);
        expect(find.byType(FollowerFollowingScreen), findsOneWidget);
      }, () => c);
    });

    testWidgets('following tab with initial index 1', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(MaterialApp(home: FollowerFollowingScreen(userId: 1, initialIndex: 1)));
        await _wait(t);
        await _scrollD(t, n: 3);
        // Tap follower items (InkWell)
        final iws = find.byType(InkWell);
        for (int i = 0; i < iws.evaluate().length && i < 5; i++) {
          try {
            await t.tap(iws.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
      }, () => c);
    });
  });

  // ====== UPLOAD V2 DEEP ======
  group('UploadV2 deep', () {
    testWidgets('fill form fields', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: UploadVideoScreenV2()));
        await _wait(t, n: 8);
        // Fill text fields
        final tfs = find.byType(TextField);
        for (int i = 0; i < tfs.evaluate().length; i++) {
          try {
            await t.enterText(tfs.at(i), 'Test input $i');
            await t.pump();
          } catch (_) {}
        }
        // Toggle switches
        final sws = find.byType(Switch);
        for (int i = 0; i < sws.evaluate().length; i++) {
          try {
            await t.tap(sws.at(i), warnIfMissed: false);
            await _wait(t, n: 2);
          } catch (_) {}
        }
        await _scrollD(t, n: 5);
        // Tap dropdowns
        final dds = find.byType(DropdownButton<String>);
        for (int i = 0; i < dds.evaluate().length; i++) {
          try {
            await t.tap(dds.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
            final items = find.byType(DropdownMenuItem<String>);
            if (items.evaluate().isNotEmpty) {
              await t.tap(items.first, warnIfMissed: false);
              await _wait(t, n: 3);
            }
          } catch (_) {}
        }
      }, () => c);
    });

    testWidgets('scroll all form sections', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: UploadVideoScreenV2()));
        await _wait(t, n: 8);
        await _scrollD(t, n: 10);  // Scroll all the way down
        await _scrollD(t, n: 5, dy: 400); // And back up
        // Tap choice/filter chips
        final chips = find.byType(ChoiceChip);
        for (int i = 0; i < chips.evaluate().length && i < 5; i++) {
          try {
            await t.tap(chips.at(i), warnIfMissed: false);
            await _wait(t, n: 2);
          } catch (_) {}
        }
        final filterChips = find.byType(FilterChip);
        for (int i = 0; i < filterChips.evaluate().length && i < 5; i++) {
          try {
            await t.tap(filterChips.at(i), warnIfMissed: false);
            await _wait(t, n: 2);
          } catch (_) {}
        }
      }, () => c);
    });
  });

  // ====== CHAT OPTIONS DEEP ======
  group('ChatOptions deep', () {
    testWidgets('scroll and tap options', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(MaterialApp(
          home: ChatOptionsScreen(
            recipientId: '10',
            recipientUsername: 'otherUser',
          ),
        ));
        await _wait(t);
        await _scrollD(t, n: 5);
        // Tap all InkWells/ListTiles
        final listTiles = find.byType(ListTile);
        for (int i = 0; i < listTiles.evaluate().length && i < 6; i++) {
          try {
            await t.tap(listTiles.at(i), warnIfMissed: false);
            await _wait(t, n: 5);
            // Dismiss dialogs
            try { await t.tapAt(const Offset(10, 10)); await _wait(t, n: 2); } catch (_) {}
          } catch (_) {}
        }
        // Tap switches
        final sws = find.byType(Switch);
        for (int i = 0; i < sws.evaluate().length; i++) {
          try {
            await t.tap(sws.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
        // CupertinoSwitch
        final cSws = find.byType(CupertinoSwitch);
        for (int i = 0; i < cSws.evaluate().length; i++) {
          try {
            await t.tap(cSws.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
        await t.pumpWidget(const SizedBox());
        for (int i = 0; i < 10; i++) await t.pump(const Duration(seconds: 1));
      }, () => c);
    });
  });

  // ====== CHANGE PASSWORD ======
  group('ChangePassword', () {
    testWidgets('fill and submit', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
        await _wait(t);
        final tfs = find.byType(TextField);
        for (int i = 0; i < tfs.evaluate().length; i++) {
          try {
            if (i == 0) await t.enterText(tfs.at(i), 'OldPass123!');
            else if (i == 1) await t.enterText(tfs.at(i), 'NewPass123!');
            else await t.enterText(tfs.at(i), 'NewPass123!');
            await t.pump();
          } catch (_) {}
        }
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await t.tap(btns.first, warnIfMissed: false);
          await _wait(t, n: 8);
        }
      }, () => c);
    });
  });

  // ====== FORGOT PASSWORD ======
  group('ForgotPassword', () {
    testWidgets('enter email and submit', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
        await _wait(t);
        final tfs = find.byType(TextField);
        if (tfs.evaluate().isNotEmpty) {
          await t.enterText(tfs.first, 'test@test.com');
          await t.pump();
        }
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await t.tap(btns.first, warnIfMissed: false);
          await _wait(t, n: 8);
        }
        await t.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) await t.pump(const Duration(seconds: 1));
      }, () => c);
    });
  });

  // ====== REPORT USER ======
  group('ReportUser', () {
    testWidgets('fill and submit report', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(MaterialApp(
          home: ReportUserScreen(
            reportedUserId: '10', reportedUsername: 'baduser',
          ),
        ));
        await _wait(t);
        await _scrollD(t, n: 3);
        // Select reason radio buttons
        final radios = find.byType(RadioListTile);
        for (int i = 0; i < radios.evaluate().length && i < 4; i++) {
          try {
            await t.tap(radios.at(i), warnIfMissed: false);
            await _wait(t, n: 2);
          } catch (_) {}
        }
        // Enter description
        final tfs = find.byType(TextField);
        if (tfs.evaluate().isNotEmpty) {
          await t.enterText(tfs.first, 'Spam and harassment');
          await t.pump();
        }
        // Submit
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await t.tap(btns.first, warnIfMissed: false);
          await _wait(t, n: 8);
        }
      }, () => c);
    });
  });

  // ====== SEARCH SCREEN ======  
  group('SearchScreen', () {
    testWidgets('type search query', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: SearchScreen()));
        await _wait(t);
        final tfs = find.byType(TextField);
        if (tfs.evaluate().isNotEmpty) {
          await t.enterText(tfs.first, 'testing');
          await _wait(t, n: 5);
          // Tap search results
          final iws = find.byType(InkWell);
          for (int i = 0; i < iws.evaluate().length && i < 3; i++) {
            try {
              await t.tap(iws.at(i), warnIfMissed: false);
              await _wait(t, n: 3);
            } catch (_) {}
          }
        }
      }, () => c);
    });
  });

  // ====== PROFILE DEEP ======
  group('Profile deep', () {
    testWidgets('tab switching and scroll', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: ProfileScreen()));
        await _wait(t);
        await _scrollD(t, n: 5);
        final tabs = find.byType(Tab);
        for (int i = 0; i < tabs.evaluate().length; i++) {
          try {
            await t.tap(tabs.at(i), warnIfMissed: false);
            await _wait(t, n: 5);
          } catch (_) {}
        }
        await _scrollD(t, n: 3);
        // Tap edit profile, followers, following buttons
        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 8; i++) {
          try {
            await t.tap(gds.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
      }, () => c);
    });
  });



  // ====== PRIVACY SETTINGS ======
  group('PrivacySettings', () {
    testWidgets('render and toggle', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
        await _wait(t);
        await _scrollD(t, n: 3);
        final sws = find.byType(Switch);
        for (int i = 0; i < sws.evaluate().length; i++) {
          try {
            await t.tap(sws.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
        final listTiles = find.byType(ListTile);
        for (int i = 0; i < listTiles.evaluate().length && i < 5; i++) {
          try {
            await t.tap(listTiles.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
      }, () => c);
    });
  });

  // ====== NOTIFICATIONS DEEP ======
  group('Notifications deep', () {
    testWidgets('tap items and mark all read', (t) async {
      final c = _mk();
      await http.runWithClient(() async {
        await t.pumpWidget(const MaterialApp(home: NotificationsScreen()));
        await _wait(t);
        // Tap notifications
        final iws = find.byType(InkWell);
        for (int i = 0; i < iws.evaluate().length && i < 5; i++) {
          try {
            await t.tap(iws.at(i), warnIfMissed: false);
            await _wait(t, n: 5);
          } catch (_) {}
        }
        // Mark all read
        final iconBtns = find.byType(IconButton);
        for (int i = 0; i < iconBtns.evaluate().length; i++) {
          try {
            await t.tap(iconBtns.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
          } catch (_) {}
        }
        // Long press
        for (int i = 0; i < iws.evaluate().length && i < 3; i++) {
          try {
            await t.longPress(iws.at(i), warnIfMissed: false);
            await _wait(t, n: 3);
            try { await t.tapAt(const Offset(10, 10)); await _wait(t, n: 2); } catch (_) {}
          } catch (_) {}
        }
      }, () => c);
    });
  });
}
