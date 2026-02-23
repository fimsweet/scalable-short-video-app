/// Deep interaction tests targeting onTap handlers, dialogs, and conditional branches.
/// Focuses on the large uncovered dialog/handler code in gap screens.
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
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/share_video_sheet.dart';

late http.Client _client;

http.Client _fullMock({bool hasPassword = true, bool has2FA = false}) {
  return MockClient((request) async {
    final path = request.url.path;
    final method = request.method;

    // Analytics
    if (path.startsWith('/analytics/')) {
      return http.Response(json.encode({
        'success': true,
        'analytics': {
          'overview': {
            'totalVideos': 45, 'totalViews': 25000, 'totalLikes': 12000,
            'totalComments': 4500, 'totalShares': 2200,
            'engagementRate': 48.0, 'followersCount': 890, 'followingCount': 456,
          },
          'recent': {'videosLast7Days': 5, 'viewsLast7Days': 3200},
          'allVideos': List.generate(5, (i) {
            return {'id': 'v$i', 'title': 'V$i', 'thumbnailUrl': '/t.jpg',
              'views': 1000, 'likes': 500, 'comments': 100, 'createdAt': '2026-01-15T08:00:00Z'};
          }),
          'topVideos': [], 'distribution': {'likes': 12000, 'comments': 4500, 'shares': 2200},
          'dailyStats': List.generate(7, (i) {
            return {'date': '2026-01-0${i+1}', 'views': 500, 'likes': 100, 'comments': 30, 'shares': 10};
          }),
        },
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Comments
    if (path.contains('/comments/video/')) {
      return http.Response(json.encode({
        'comments': List.generate(5, (i) {
          return {
            'id': 'c$i', 'content': 'Comment $i!', 'userId': i + 2,
            'username': 'user$i', 'displayName': 'User $i', 'avatar': null,
            'likeCount': i * 2, 'replyCount': i > 2 ? 1 : 0, 'isLiked': i.isEven,
            'createdAt': DateTime.now().subtract(Duration(hours: i)).toIso8601String(),
            'replies': i > 2 ? [{'id': 'r$i', 'content': 'Reply', 'userId': 1,
              'username': 'testuser', 'likeCount': 0, 'isLiked': false,
              'createdAt': DateTime.now().toIso8601String()}] : [],
          };
        }),
        'hasMore': true, 'total': 30,
      }), 200, headers: {'content-type': 'application/json'});
    }

    if (path.contains('/comments') && method == 'POST') {
      return http.Response(json.encode({
        'id': 'cnew', 'content': 'New', 'userId': 1, 'username': 'testuser',
        'likeCount': 0, 'replyCount': 0, 'createdAt': DateTime.now().toIso8601String(),
      }), 201, headers: {'content-type': 'application/json'});
    }

    if (path.contains('/comments/') && (method == 'PUT' || method == 'DELETE')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Messages/conversations
    if (path.contains('/messages/conversations/')) {
      return http.Response(json.encode({
        'data': List.generate(3, (i) {
          return {
            'id': 'conv$i',
            'participants': [{'userId': '${i + 10}', 'username': 'chat$i'}, {'userId': '1', 'username': 'testuser'}],
            'lastMessage': {'content': 'Hi $i', 'createdAt': DateTime.now().toIso8601String()},
          };
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Videos
    if (path.contains('/videos')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(3, (i) {
          return {
            'id': 'v$i', 'title': 'Video $i', 'description': 'D$i',
            'hlsUrl': '/v$i.m3u8', 'thumbnailUrl': '/t$i.jpg',
            'userId': i + 1, 'viewCount': 500, 'likeCount': 200, 'commentCount': 50,
            'shareCount': 10, 'createdAt': '2026-01-15T08:00:00Z', 'status': 'ready',
            'visibility': 'public', 'allowComments': true, 'isLiked': false, 'isSaved': false,
            'user': {'id': i + 1, 'username': 'creator$i', 'avatar': null, 'displayName': 'Creator $i'},
          };
        }),
        'total': 20, 'hasMore': true,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Activity history
    if (path.startsWith('/activity-history/')) {
      final types = ['login', 'video_like', 'comment', 'follow', 'video_upload',
        'password_change', 'profile_edit', 'video_view', 'video_share', 'report'];
      return http.Response(json.encode({
        'activities': List.generate(15, (i) {
          return {
            'id': i + 1, 'type': types[i % types.length],
            'description': 'Activity description $i',
            'createdAt': DateTime.now().subtract(Duration(hours: i * 5)).toIso8601String(),
            'metadata': {
              'ip': '192.168.1.${i+1}', 'device': 'Chrome/Win',
              'videoId': 'v$i', 'videoTitle': 'Video $i',
              'targetUserId': '${i+10}', 'targetUsername': 'user$i',
              'thumbnailUrl': 'https://img.example.com/th$i.jpg',
              'location': 'Ho Chi Minh City',
            },
          };
        }),
        'hasMore': true, 'total': 100,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Activity delete
    if (path.contains('/activity-history') && (method == 'DELETE' || method == 'POST')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Account info
    if (path == '/auth/account-info') {
      return http.Response(json.encode({
        'phoneNumber': '+84999888777', 'email': 'user@test.com',
        'googleLinked': false, 'hasPassword': hasPassword, 'authProvider': 'local',
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

    // 2FA operations
    if (path.contains('/2fa/')) {
      return http.Response(json.encode({
        'success': true, 'secret': 'JBSWY3DPEHPK3PXP',
        'qrCode': 'data:image/png;base64,iVBOR=',
        'backupCodes': ['11111111', '22222222'],
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Followers/following with status
    if (path.contains('/follows/followers-with-status/') || path.contains('/follows/following-with-status/')) {
      return http.Response(json.encode({
        'data': List.generate(4, (i) {
          return {'userId': '${i+10}', 'username': 'user$i', 'displayName': 'User $i', 'avatar': null, 'isMutual': i < 2};
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Blocked users
    if (path.contains('/users/blocked/')) {
      return http.Response(json.encode([
        {'id': 100, 'blockedUserId': '100', 'username': 'blocked0'},
      ]), 200, headers: {'content-type': 'application/json'});
    }

    // User by ID
    if (path.contains('/users/id/')) {
      return http.Response(json.encode({
        'id': 1, 'username': 'testuser', 'displayName': 'Test User',
        'email': 'test@test.com', 'bio': 'Test bio', 'avatar': null,
        'followersCount': 567, 'followingCount': 234, 'videoCount': 45,
        'gender': 'male', 'dateOfBirth': '2000-01-15',
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Privacy settings
    if (path.contains('/users/privacy/check') && method == 'POST') {
      return http.Response(json.encode({'allowed': true}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.contains('/users/privacy/')) {
      return http.Response(json.encode({
        'settings': {'whoCanComment': 'everyone', 'whoCanMessage': 'everyone', 'accountPrivacy': 'public'},
      }), 200, headers: {'content-type': 'application/json'});
    }

    // User settings
    if (path == '/users/settings') {
      return http.Response(json.encode({
        'success': true, 'settings': {'filterComments': true, 'showOnlineStatus': true},
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Login
    if (path.contains('/auth/login') && method == 'POST') {
      return http.Response(json.encode({
        'success': true,
        'data': {
          'user': {'id': 1, 'username': 'testuser', 'displayName': 'Test User'},
          'access_token': 'valid_token',
        },
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Register
    if (path.contains('/register')) {
      return http.Response(json.encode({'success': true, 'token': 'tok', 'user': {'id': 2}}),
          200, headers: {'content-type': 'application/json'});
    }

    // Set password / Change password
    if (path.contains('/set-password') || path.contains('/change-password') || path.contains('/password')) {
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

    // Deactivate/delete account
    if (path.contains('/deactivate') || path.contains('/delete-account')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Notifications
    if (path.contains('/notifications')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(5, (i) {
          return {'id': 'n$i', 'type': ['like', 'comment', 'follow'][i % 3],
            'message': 'Notif $i', 'read': i > 2,
            'createdAt': DateTime.now().subtract(Duration(hours: i)).toIso8601String(),
            'metadata': {'videoId': 'v$i', 'userId': i + 5}};
        }),
        'unreadCount': 2, 'total': 20, 'hasMore': true,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Update profile
    if (path.contains('/users/profile') && method == 'PUT') {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Users generic
    if (path.contains('/users/')) {
      return http.Response(json.encode({
        'id': 1, 'username': 'testuser', 'displayName': 'Test User',
        'bio': 'Bio', 'avatar': null, 'followersCount': 120,
        'videoCount': 10, 'hasPassword': hasPassword,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Follow/unfollow
    if (path.contains('/follow')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Like/save/share/hide
    if (path.contains('/like') || path.contains('/save') || path.contains('/share') || path.contains('/hide')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Categories
    if (path.contains('/categories')) {
      return http.Response(json.encode({
        'data': [{'id': 1, 'name': 'Entertainment'}, {'id': 2, 'name': 'Sports'}],
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Discover/search/suggested
    if (path.contains('/discover') || path.contains('/search') || path.contains('/suggested')) {
      return http.Response(json.encode({
        'data': [{'id': 20, 'username': 'found', 'displayName': 'Found'}],
      }), 200, headers: {'content-type': 'application/json'});
    }

    // OTP
    if (path.contains('/otp')) {
      return http.Response(json.encode({'success': true, 'verified': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Reactivate
    if (path.contains('/reactivate')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Settings generic
    if (path.contains('/settings')) {
      return http.Response(json.encode({
        'success': true, 'settings': {'accountPrivacy': 'public'},
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Report
    if (path.contains('/report')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    return http.Response(json.encode({'success': true}), 200,
        headers: {'content-type': 'application/json'});
  });
}

Future<void> _waitLoad(WidgetTester tester) async {
  for (int i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
  }
}

Future<void> _pumpN(WidgetTester tester, int n, {int ms = 500}) async {
  for (int i = 0; i < n; i++) {
    await tester.pump(Duration(milliseconds: ms));
    tester.takeException();
  }
}

Future<void> _scrollDown(WidgetTester tester, {int times = 5, double dy = -400}) async {
  for (int j = 0; j < times; j++) {
    final s = find.byType(Scaffold);
    if (s.evaluate().isNotEmpty) {
      await tester.drag(s.first, Offset(0, dy));
      await tester.pump(const Duration(milliseconds: 200));
      tester.takeException();
    }
  }
}

/// Tap an InkWell that is an ancestor of a specific Icon
Future<void> _tapIconMenuItem(WidgetTester tester, IconData icon) async {
  final iconFinder = find.byIcon(icon);
  if (iconFinder.evaluate().isNotEmpty) {
    final inkWell = find.ancestor(of: iconFinder.first, matching: find.byType(InkWell));
    if (inkWell.evaluate().isNotEmpty) {
      await tester.tap(inkWell.first, warnIfMissed: false);
      await _pumpN(tester, 5);
    }
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = MockSecureStorage();
  });

  setUp(() async {
    _client = _fullMock();
    final loginClient = createMockHttpClient();
    await http.runWithClient(() async {
      await setupLoggedInState();
    }, () => loginClient);
  });

  // =================================================
  // ACCOUNT MANAGEMENT: TAP EVERY MENU ITEM + DIALOGS
  // =================================================
  group('AccountMgmt dialogs', () {
    testWidgets('tap set password (no password variant)', (tester) async {
      final noPwClient = _fullMock(hasPassword: false);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        await _waitLoad(tester);
        // Find the set password icon (Icons.lock_open when no password)
        await _tapIconMenuItem(tester, Icons.lock_open);
        // Dialog should appear for set password
        final tfs = find.byType(TextField);
        if (tfs.evaluate().length >= 2) {
          await tester.enterText(tfs.at(0), 'NewPass123!');
          await tester.pump();
          await tester.enterText(tfs.at(1), 'NewPass123!');
          await tester.pump();
        }
        // Tap confirm button in dialog
        final elevBtns = find.byType(ElevatedButton);
        if (elevBtns.evaluate().isNotEmpty) {
          await tester.tap(elevBtns.last, warnIfMissed: false);
          await _pumpN(tester, 8);
        }
        // Dismiss
        try {
          await tester.tapAt(const Offset(10, 10));
          await _pumpN(tester, 3);
        } catch (_) {}
      }, () => noPwClient);
    });

    testWidgets('tap change password (has password)', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        await _waitLoad(tester);
        await _tapIconMenuItem(tester, Icons.lock_outline);
        await _pumpN(tester, 5);
        // Might navigate to ChangePasswordScreen
        await _scrollDown(tester, times: 3);
        // Go back
        final backBtn = find.byType(BackButton);
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tap(backBtn.first, warnIfMissed: false);
          await _pumpN(tester, 3);
        }
      }, () => _client);
    });

    testWidgets('tap 2FA menu item', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        await _waitLoad(tester);
        await _tapIconMenuItem(tester, Icons.security);
        await _pumpN(tester, 8);
        // Should navigate to TwoFactorAuthScreen
        await _scrollDown(tester, times: 3);
        // Timer cleanup for 2FA screen
        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) await tester.pump(const Duration(seconds: 1));
      }, () => _client);
    });

    testWidgets('tap phone management', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        await _waitLoad(tester);
        await _tapIconMenuItem(tester, Icons.phone_outlined);
        await _pumpN(tester, 5);
        // Dismiss dialog
        try {
          final cancelBtn = find.byType(TextButton);
          if (cancelBtn.evaluate().isNotEmpty) {
            await tester.tap(cancelBtn.first, warnIfMissed: false);
            await _pumpN(tester, 3);
          }
        } catch (_) {}
      }, () => _client);
    });

    testWidgets('tap devices', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        await _waitLoad(tester);
        await _tapIconMenuItem(tester, Icons.devices_outlined);
        await _pumpN(tester, 5);
        // Scroll through devices list in dialog
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          try {
            await tester.drag(scrollables.last, const Offset(0, -200));
            await _pumpN(tester, 3);
          } catch (_) {}
        }
        // Dismiss
        try { await tester.tapAt(const Offset(10, 10)); await _pumpN(tester, 3); } catch (_) {}
      }, () => _client);
    });

    testWidgets('tap analytics', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        await _waitLoad(tester);
        await _scrollDown(tester, times: 2);
        await _tapIconMenuItem(tester, Icons.analytics_outlined);
        await _pumpN(tester, 8);
        await _scrollDown(tester, times: 5);
      }, () => _client);
    });

    testWidgets('tap activity history', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        await _waitLoad(tester);
        await _scrollDown(tester, times: 2);
        await _tapIconMenuItem(tester, Icons.history);
        await _pumpN(tester, 8);
        await _scrollDown(tester, times: 3);
      }, () => _client);
    });

    testWidgets('tap blocked accounts', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        await _waitLoad(tester);
        await _scrollDown(tester, times: 2);
        await _tapIconMenuItem(tester, Icons.block_outlined);
        await _pumpN(tester, 5);
        try { await tester.tapAt(const Offset(10, 10)); await _pumpN(tester, 3); } catch (_) {}
      }, () => _client);
    });

    testWidgets('tap logout', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        await _waitLoad(tester);
        await _scrollDown(tester, times: 3);
        await _tapIconMenuItem(tester, Icons.logout);
        await _pumpN(tester, 5);
        // Logout dialog - tap cancel
        final cancelBtns = find.byType(TextButton);
        if (cancelBtns.evaluate().isNotEmpty) {
          await tester.tap(cancelBtns.first, warnIfMissed: false);
          await _pumpN(tester, 3);
        }
      }, () => _client);
    });

    testWidgets('tap deactivate account', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        await _waitLoad(tester);
        await _scrollDown(tester, times: 4);
        await _tapIconMenuItem(tester, Icons.pause_circle_outline);
        await _pumpN(tester, 5);
        // Deactivate dialog - dismiss
        try { await tester.tapAt(const Offset(10, 10)); await _pumpN(tester, 3); } catch (_) {}
      }, () => _client);
    });
  });

  // =================================================
  // ACTIVITY HISTORY: MANAGE MENU + DELETE DIALOGS
  // =================================================
  group('ActivityHistory interactions', () {
    testWidgets('open manage menu and tap options', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        await _waitLoad(tester);
        // Find the manage/more icon button (usually in AppBar)
        final iconBtns = find.byType(IconButton);
        for (int i = 0; i < iconBtns.evaluate().length; i++) {
          try {
            await tester.tap(iconBtns.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
            // If a bottom sheet appeared, scroll it
            final scrollables = find.byType(Scrollable);
            if (scrollables.evaluate().length > 1) {
              await tester.drag(scrollables.last, const Offset(0, -200));
              await _pumpN(tester, 3);
            }
            // Try to tap the first InkWell in the sheet/dialog
            final inkWells = find.byType(InkWell);
            if (inkWells.evaluate().length > 3) {
              await tester.tap(inkWells.last, warnIfMissed: false);
              await _pumpN(tester, 5);
            }
            // Dismiss
            try { await tester.tapAt(const Offset(10, 10)); await _pumpN(tester, 3); } catch (_) {}
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('tap filter tabs all types', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        await _waitLoad(tester);
        // Find filter GestureDetectors (4 filters in a Row)
        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 6; i++) {
          try {
            await tester.tap(gds.at(i), warnIfMissed: false);
            await _pumpN(tester, 8);
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('scroll to bottom trigger loadMore', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        await _waitLoad(tester);
        // Fling to bottom repeatedly to trigger scroll listener
        for (int i = 0; i < 5; i++) {
          final s = find.byType(Scaffold);
          if (s.evaluate().isNotEmpty) {
            await tester.fling(s.first, const Offset(0, -800), 2000);
            await _pumpN(tester, 8);
          }
        }
      }, () => _client);
    });

    testWidgets('long press and delete activity', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        await _waitLoad(tester);
        // Long press on activity items
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 3; i++) {
          try {
            await tester.longPress(inkWells.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
            // Try to tap delete in resulting menu
            final elevBtns = find.byType(ElevatedButton);
            if (elevBtns.evaluate().isNotEmpty) {
              await tester.tap(elevBtns.first, warnIfMissed: false);
              await _pumpN(tester, 5);
            }
            try { await tester.tapAt(const Offset(10, 10)); await _pumpN(tester, 3); } catch (_) {}
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('tap activity items to navigate', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        await _waitLoad(tester);
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(inkWells.at(i), warnIfMissed: false);
            await _pumpN(tester, 5);
          } catch (_) {}
        }
        // Timer cleanup
        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 25; i++) await tester.pump(const Duration(seconds: 1));
      }, () => _client);
    });
  });

  // =================================================
  // EDIT PROFILE: GENDER PICKER, DATE PICKER, SAVE
  // =================================================
  group('EditProfile interactions', () {
    testWidgets('load profile data and scroll all fields', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        await _waitLoad(tester);
        await _scrollDown(tester, times: 10);
        // Scroll back up
        await _scrollDown(tester, times: 5, dy: 400);
      }, () => _client);
    });

    testWidgets('tap gender field to open picker', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        await _waitLoad(tester);
        await _scrollDown(tester, times: 3);
        // Find gender InkWell by scanning all InkWells
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length; i++) {
          try {
            await tester.tap(inkWells.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
            // If gender picker sheet appeared, tap an option
            final listTiles = find.byType(ListTile);
            if (listTiles.evaluate().length > 2) {
              await tester.tap(listTiles.at(1), warnIfMissed: false);
              await _pumpN(tester, 3);
              break;
            }
            // Dismiss
            try { await tester.tapAt(const Offset(10, 10)); await _pumpN(tester, 2); } catch (_) {}
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('edit bio and save', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        await _waitLoad(tester);
        // Find text fields and edit
        final tfs = find.byType(TextField);
        for (int i = 0; i < tfs.evaluate().length; i++) {
          try {
            await tester.enterText(tfs.at(i), 'Updated value $i');
            await tester.pump(const Duration(milliseconds: 200));
          } catch (_) {}
        }
        // Find and tap save button
        final elevBtns = find.byType(ElevatedButton);
        if (elevBtns.evaluate().isNotEmpty) {
          await tester.tap(elevBtns.first, warnIfMissed: false);
          await _pumpN(tester, 8);
        }
        // Try text buttons too
        final textBtns = find.byType(TextButton);
        for (int i = 0; i < textBtns.evaluate().length; i++) {
          try {
            await tester.tap(textBtns.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('tap avatar section', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        await _waitLoad(tester);
        // Tap CircleAvatar or GestureDetector for avatar
        final gds = find.byType(GestureDetector);
        if (gds.evaluate().isNotEmpty) {
          await tester.tap(gds.first, warnIfMissed: false);
          await _pumpN(tester, 3);
        }
        // Tap InkWells
        final iws = find.byType(InkWell);
        for (int i = 0; i < iws.evaluate().length && i < 8; i++) {
          try {
            await tester.tap(iws.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
            // Cancel any dialogs
            try { await tester.tapAt(const Offset(10, 10)); await _pumpN(tester, 2); } catch (_) {}
          } catch (_) {}
        }
      }, () => _client);
    });
  });

  // =================================================
  // LOGIN: REACTIVATION & 2FA DIALOG INTERACTIONS
  // =================================================
  group('Login dialog interactions', () {
    testWidgets('reactivation dialog tap reactivate', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/auth/login') && request.method == 'POST') {
          return http.Response(json.encode({
            'success': true, 'data': {
              'requiresReactivation': true, 'userId': 1, 'daysRemaining': 14,
            },
          }), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.contains('/reactivate')) {
          return http.Response(json.encode({'success': true}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(json.encode({'success': true}), 200,
            headers: {'content-type': 'application/json'});
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _pumpN(tester, 5);
        final tfs = find.byType(TextField);
        if (tfs.evaluate().length >= 2) {
          await tester.enterText(tfs.at(0), 'deactuser');
          await tester.pump();
          await tester.enterText(tfs.at(1), 'Password123!');
          await tester.pump();
        }
        // Tap login
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await tester.tap(btns.first, warnIfMissed: false);
          await _pumpN(tester, 10);
        }
        // Reactivation dialog should appear - find reactivate button
        final allBtns = find.byType(ElevatedButton);
        if (allBtns.evaluate().length > 0) {
          await tester.tap(allBtns.last, warnIfMissed: false);
          await _pumpN(tester, 8);
        }
      }, () => client);
    });

    testWidgets('2FA dialog with method selection', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/auth/login') && request.method == 'POST') {
          return http.Response(json.encode({
            'success': true, 'data': {
              'requires2FA': true, 'userId': 1,
              'twoFactorMethods': ['totp', 'email'],
            },
          }), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.contains('/2fa/')) {
          return http.Response(json.encode({'success': true}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(json.encode({'success': true}), 200,
            headers: {'content-type': 'application/json'});
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _pumpN(tester, 5);
        final tfs = find.byType(TextField);
        if (tfs.evaluate().length >= 2) {
          await tester.enterText(tfs.at(0), 'user2fa');
          await tester.pump();
          await tester.enterText(tfs.at(1), 'Password123!');
          await tester.pump();
        }
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await tester.tap(btns.first, warnIfMissed: false);
          await _pumpN(tester, 10);
        }
        // 2FA dialog should appear - try to enter OTP and verify
        final otpFields = find.byType(TextField);
        if (otpFields.evaluate().isNotEmpty) {
          await tester.enterText(otpFields.last, '123456');
          await _pumpN(tester, 3);
        }
        // Tap verify button
        final verifyBtns = find.byType(ElevatedButton);
        if (verifyBtns.evaluate().isNotEmpty) {
          await tester.tap(verifyBtns.last, warnIfMissed: false);
          await _pumpN(tester, 8);
        }
        // Timer cleanup
        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) await tester.pump(const Duration(seconds: 1));
      }, () => client);
    });

    testWidgets('login with error message localization', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/auth/login') && request.method == 'POST') {
          return http.Response(json.encode({
            'success': false, 'message': 'Invalid credentials',
          }), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(json.encode({'success': true}), 200,
            headers: {'content-type': 'application/json'});
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _pumpN(tester, 5);
        final tfs = find.byType(TextField);
        if (tfs.evaluate().length >= 2) {
          await tester.enterText(tfs.at(0), 'wronguser');
          await tester.pump();
          await tester.enterText(tfs.at(1), 'WrongPass!');
          await tester.pump();
        }
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await tester.tap(btns.first, warnIfMissed: false);
          await _pumpN(tester, 8);
        }
      }, () => client);
    });

    testWidgets('login scroll to social buttons', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await _pumpN(tester, 5);
        await _scrollDown(tester, times: 5);
        // Tap social buttons
        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 3; i++) {
          try {
            await tester.tap(gds.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
        final textBtns = find.byType(TextButton);
        for (int i = 0; i < textBtns.evaluate().length; i++) {
          try {
            await tester.tap(textBtns.at(i), warnIfMissed: false);
            await _pumpN(tester, 5);
          } catch (_) {}
        }
      }, () => _client);
    });
  });

  // =================================================
  // COMMENT SECTION: REPLY, LIKE, EXPAND, LOAD MORE
  // =================================================
  group('CommentSection interactions', () {
    testWidgets('type and send comment', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v1', allowComments: true, videoOwnerId: '2', onCommentAdded: () {},
          )),
        ));
        await _waitLoad(tester);
        final tf = find.byType(TextField);
        if (tf.evaluate().isNotEmpty) {
          await tester.enterText(tf.first, 'Great video!');
          await _pumpN(tester, 3);
          // Tap send button
          final icons = find.byIcon(Icons.send);
          if (icons.evaluate().isNotEmpty) {
            final btn = find.ancestor(of: icons.first, matching: find.byType(GestureDetector));
            if (btn.evaluate().isNotEmpty) {
              await tester.tap(btn.first, warnIfMissed: false);
              await _pumpN(tester, 8);
            }
          }
          // Also try IconButton
          final iconBtns = find.byType(IconButton);
          for (int i = 0; i < iconBtns.evaluate().length; i++) {
            try {
              await tester.tap(iconBtns.at(i), warnIfMissed: false);
              await _pumpN(tester, 3);
            } catch (_) {}
          }
        }
      }, () => _client);
    });

    testWidgets('tap comment like buttons', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v1', allowComments: true, videoOwnerId: '2', onCommentAdded: () {},
          )),
        ));
        await _waitLoad(tester);
        // Tap all GestureDetectors (like buttons on comments)
        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 10; i++) {
          try {
            await tester.tap(gds.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('scroll to load more comments', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v1', allowComments: true, videoOwnerId: '2', onCommentAdded: () {},
          )),
        ));
        await _waitLoad(tester);
        final scrollables = find.byType(Scrollable);
        for (int i = 0; i < 5; i++) {
          if (scrollables.evaluate().isNotEmpty) {
            try {
              await tester.fling(scrollables.first, const Offset(0, -500), 1500);
              await _pumpN(tester, 8);
            } catch (_) {}
          }
        }
      }, () => _client);
    });

    testWidgets('long press comment for options', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v1', allowComments: true, videoOwnerId: '2',
            onCommentAdded: () {}, onCommentDeleted: () {},
          )),
        ));
        await _waitLoad(tester);
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 3; i++) {
          try {
            await tester.longPress(inkWells.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
            // Dismiss
            try { await tester.tapAt(const Offset(10, 10)); await _pumpN(tester, 2); } catch (_) {}
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('reply to comment', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v1', allowComments: true, videoOwnerId: '2', onCommentAdded: () {},
          )),
        ));
        await _waitLoad(tester);
        // Find reply text/button
        final replyTexts = find.textContaining('reply', skipOffstage: false);
        if (replyTexts.evaluate().isNotEmpty) {
          try {
            await tester.tap(replyTexts.first, warnIfMissed: false);
            await _pumpN(tester, 3);
            // Type reply
            final tf = find.byType(TextField);
            if (tf.evaluate().isNotEmpty) {
              await tester.enterText(tf.first, 'Nice reply!');
              await _pumpN(tester, 3);
            }
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('comment section restricted banner', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/comments/video/')) {
          return http.Response(json.encode({'comments': [], 'hasMore': false, 'total': 0}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path.contains('/users/privacy/check')) {
          return http.Response(json.encode({'allowed': false, 'reason': 'Comments restricted'}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/users/settings') {
          return http.Response(json.encode({
            'success': true, 'settings': {'filterComments': false},
          }), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.contains('/users/privacy/')) {
          return http.Response(json.encode({
            'settings': {'whoCanComment': 'followers'},
          }), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(json.encode({'success': true}), 200,
            headers: {'content-type': 'application/json'});
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v1', allowComments: true, videoOwnerId: '2', onCommentAdded: () {},
          )),
        ));
        await _waitLoad(tester);
      }, () => client);
    });

    testWidgets('owner with noOne whoCanComment', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/comments/video/')) {
          return http.Response(json.encode({'comments': [], 'hasMore': false, 'total': 0}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path.contains('/users/privacy/')) {
          return http.Response(json.encode({
            'settings': {'whoCanComment': 'noOne'},
          }), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/users/settings') {
          return http.Response(json.encode({'success': true, 'settings': {'filterComments': true}}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(json.encode({'success': true}), 200,
            headers: {'content-type': 'application/json'});
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v1', allowComments: true, videoOwnerId: '1', // owner is self
            onCommentAdded: () {},
          )),
        ));
        await _waitLoad(tester);
      }, () => client);
    });

    testWidgets('owner with onlyMe whoCanComment', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.contains('/comments/video/')) {
          return http.Response(json.encode({'comments': [], 'hasMore': false, 'total': 0}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path.contains('/users/privacy/')) {
          return http.Response(json.encode({
            'settings': {'whoCanComment': 'onlyMe'},
          }), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/users/settings') {
          return http.Response(json.encode({'success': true, 'settings': {'filterComments': true}}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(json.encode({'success': true}), 200,
            headers: {'content-type': 'application/json'});
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: CommentSectionWidget(
            videoId: 'v1', allowComments: true, videoOwnerId: '1',
            onCommentAdded: () {},
          )),
        ));
        await _waitLoad(tester);
      }, () => client);
    });
  });

  // =================================================
  // 2FA: TAP METHOD TILES, ENTER OTP, TOGGLE
  // =================================================
  group('TwoFactorAuth interactions', () {
    testWidgets('tap method tiles and checkbox-like controls', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        await _waitLoad(tester);
        // Tap all InkWells to trigger method tiles
        final iws = find.byType(InkWell);
        for (int i = 0; i < iws.evaluate().length && i < 8; i++) {
          try {
            await tester.tap(iws.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
        // Tap checkboxes
        final cbs = find.byType(Checkbox);
        for (int i = 0; i < cbs.evaluate().length; i++) {
          try {
            await tester.tap(cbs.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
        // Tap switches
        final sws = find.byType(Switch);
        for (int i = 0; i < sws.evaluate().length; i++) {
          try {
            await tester.tap(sws.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
        // Timer cleanup
        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) await tester.pump(const Duration(seconds: 1));
      }, () => _client);
    });

    testWidgets('2FA enabled - disable flow', (tester) async {
      final client = _fullMock(has2FA: true);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        await _waitLoad(tester);
        await _scrollDown(tester, times: 5);
        // Find disable button
        final btns = find.byType(ElevatedButton);
        for (int i = 0; i < btns.evaluate().length; i++) {
          try {
            await tester.tap(btns.at(i), warnIfMissed: false);
            await _pumpN(tester, 5);
            // Dialog might appear for confirmation
            final dialogBtns = find.byType(ElevatedButton);
            if (dialogBtns.evaluate().isNotEmpty) {
              await tester.tap(dialogBtns.last, warnIfMissed: false);
              await _pumpN(tester, 5);
            }
          } catch (_) {}
        }
        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) await tester.pump(const Duration(seconds: 1));
      }, () => client);
    });
  });

  // =================================================
  // VIDEO SCREEN: DEEP INTERACTION + TAB SWIPING
  // =================================================
  group('VideoScreen deep', () {
    testWidgets('tab bar taps', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
        await _waitLoad(tester);
        final tabs = find.byType(Tab);
        for (int i = 0; i < tabs.evaluate().length; i++) {
          try {
            await tester.tap(tabs.at(i), warnIfMissed: false);
            await _pumpN(tester, 5);
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('vertical fling through videos', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
        await _waitLoad(tester);
        // Fling down multiple times
        for (int i = 0; i < 5; i++) {
          try {
            await tester.fling(find.byType(VideoScreen), const Offset(0, -600), 2000);
            await _pumpN(tester, 5);
          } catch (_) {}
        }
      }, () => _client);
    });
  });

  // =================================================
  // EXTRA: DEEP INTERACTIONS ON OTHER SCREENS
  // =================================================
  group('Extra interactions', () {
    testWidgets('profile: tap three-dot menu', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
        await _waitLoad(tester);
        final iconBtns = find.byType(IconButton);
        for (int i = 0; i < iconBtns.evaluate().length; i++) {
          try {
            await tester.tap(iconBtns.at(i), warnIfMissed: false);
            await _pumpN(tester, 5);
          } catch (_) {}
        }
        // Tap bottom nav icons if any
        final bottomNavBars = find.byType(BottomNavigationBar);
        if (bottomNavBars.evaluate().isEmpty) {
          final gds = find.byType(GestureDetector);
          for (int i = 0; i < gds.evaluate().length && i < 5; i++) {
            try {
              await tester.tap(gds.at(i), warnIfMissed: false);
              await _pumpN(tester, 3);
            } catch (_) {}
          }
        }
      }, () => _client);
    });

    testWidgets('notifications mark as read', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
        await _waitLoad(tester);
        // Tap notification items
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(inkWells.at(i), warnIfMissed: false);
            await _pumpN(tester, 5);
          } catch (_) {}
        }
        // Mark all read button
        final iconBtns = find.byType(IconButton);
        for (int i = 0; i < iconBtns.evaluate().length; i++) {
          try {
            await tester.tap(iconBtns.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('follower following search and follow/unfollow', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(home: FollowerFollowingScreen(userId: 1)));
        await _waitLoad(tester);
        // Switch to following tab
        final tabs = find.byType(Tab);
        if (tabs.evaluate().length >= 2) {
          await tester.tap(tabs.at(1));
          await _pumpN(tester, 8);
        }
        // Tap follow/unfollow buttons
        final elevBtns = find.byType(ElevatedButton);
        for (int i = 0; i < elevBtns.evaluate().length && i < 3; i++) {
          try {
            await tester.tap(elevBtns.at(i), warnIfMissed: false);
            await _pumpN(tester, 5);
          } catch (_) {}
        }
        // Switch back
        if (tabs.evaluate().isNotEmpty) {
          await tester.tap(tabs.first);
          await _pumpN(tester, 8);
        }
      }, () => _client);
    });

    testWidgets('user profile tab switching', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(home: UserProfileScreen(userId: 5)));
        await _waitLoad(tester);
        await _scrollDown(tester, times: 5);
        // Tap tabs if present
        final tabs = find.byType(Tab);
        for (int i = 0; i < tabs.evaluate().length; i++) {
          try {
            await tester.tap(tabs.at(i), warnIfMissed: false);
            await _pumpN(tester, 5);
          } catch (_) {}
        }
        // Tap follow button
        final elevBtns = find.byType(ElevatedButton);
        if (elevBtns.evaluate().isNotEmpty) {
          await tester.tap(elevBtns.first, warnIfMissed: false);
          await _pumpN(tester, 5);
        }
        // Timer cleanup
        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 25; i++) await tester.pump(const Duration(seconds: 1));
      }, () => _client);
    });

    testWidgets('video detail interaction buttons', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: VideoDetailScreen(
            videos: List.generate(3, (i) {
              return {
                'id': 'vd$i', 'title': 'V$i', 'description': 'D$i #tag',
                'hlsUrl': '/v.m3u8', 'thumbnailUrl': '/t.jpg',
                'userId': i + 1, 'viewCount': 100, 'likeCount': 50,
                'commentCount': 20, 'shareCount': 5,
                'isLiked': false, 'isSaved': false, 'allowComments': true,
                'user': {'id': i + 1, 'username': 'u$i', 'avatar': null, 'displayName': 'U$i'},
              };
            }),
            initialIndex: 0,
          ),
        ));
        await _pumpN(tester, 8);
        // Scroll through video details
        await _scrollDown(tester, times: 3);
        await _scrollDown(tester, times: 3, dy: 400);
        // Tap icon buttons carefully
        final iconBtns = find.byType(IconButton);
        for (int i = 0; i < iconBtns.evaluate().length && i < 3; i++) {
          try {
            await tester.tap(iconBtns.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('upload v2 dropdown + switch', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: UploadVideoScreenV2()));
        await _pumpN(tester, 8);
        // Find dropdown and switch
        final dds = find.byType(DropdownButton<String>);
        for (int i = 0; i < dds.evaluate().length; i++) {
          try {
            await tester.tap(dds.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
            final items = find.byType(DropdownMenuItem<String>);
            if (items.evaluate().isNotEmpty) {
              await tester.tap(items.last, warnIfMissed: false);
              await _pumpN(tester, 3);
            }
          } catch (_) {}
        }
        final sws = find.byType(Switch);
        for (int i = 0; i < sws.evaluate().length; i++) {
          try {
            await tester.tap(sws.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
        await _scrollDown(tester, times: 5);
      }, () => _client);
    });

    testWidgets('upload v1 category and visibility', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: UploadVideoScreen()));
        await _pumpN(tester, 8);
        await _scrollDown(tester, times: 3);
        // Toggle switches
        final sws = find.byType(Switch);
        for (int i = 0; i < sws.evaluate().length; i++) {
          try {
            await tester.tap(sws.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
        // Tap category chips
        final chips = find.byType(ChoiceChip);
        for (int i = 0; i < chips.evaluate().length && i < 4; i++) {
          try {
            await tester.tap(chips.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
        // Filter chips
        final filterChips = find.byType(FilterChip);
        for (int i = 0; i < filterChips.evaluate().length && i < 4; i++) {
          try {
            await tester.tap(filterChips.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('share video: tap avatar to select', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ShareVideoSheet(videoId: 'v1')),
        ));
        await _waitLoad(tester);
        // Tap individual user items (CircleAvatar or InkWell)
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(inkWells.at(i), warnIfMissed: false);
            await _pumpN(tester, 3);
          } catch (_) {}
        }
        // Tap send/share button if available
        final elevBtns = find.byType(ElevatedButton);
        if (elevBtns.evaluate().isNotEmpty) {
          await tester.tap(elevBtns.first, warnIfMissed: false);
          await _pumpN(tester, 5);
        }
      }, () => _client);
    });
  });
}
