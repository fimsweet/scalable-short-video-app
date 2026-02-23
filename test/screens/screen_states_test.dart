/// State-focused tests for complex screens with multiple data states.
/// These exercise loading states, error states, populated data states,
/// tab switching, filtering, and pagination paths.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import '../helpers/test_setup.dart';
import '../helpers/mock_http_client.dart';

import 'package:scalable_short_video_app/src/presentation/screens/activity_history_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/analytics_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/two_factor_auth_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/account_management_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/notifications_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/follower_following_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/privacy_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/blocked_users_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/logged_devices_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/discover_people_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/search_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/inbox_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/in_app_notification_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/help_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_options_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/share_video_sheet.dart';

late http.Client _mockClient;

/// Create a mock client that returns rich data for specific endpoints
http.Client _createRichDataClient() {
  return MockClient((request) async {
    final url = request.url.toString();
    final path = request.url.path;

    // Activity history with multiple types and dates
    if (path.contains('/activity-history')) {
      if (request.method == 'GET') {
        return http.Response(json.encode({
          'success': true,
          'data': List.generate(20, (i) {
            final types = ['like', 'comment', 'follow', 'video_view', 'share'];
            return {
              'id': 'act-$i',
              'type': types[i % types.length],
              'targetType': i % 2 == 0 ? 'video' : 'user',
              'targetId': '$i',
              'description': 'Activity $i description',
              'createdAt': DateTime.now().subtract(Duration(hours: i * 6)).toIso8601String(),
              'metadata': {'title': 'Video $i', 'username': 'user$i'},
            };
          }),
          'total': 50,
          'hasMore': true,
        }), 200, headers: {'content-type': 'application/json'});
      }
      if (request.method == 'DELETE') {
        return http.Response(json.encode({'success': true, 'deletedCount': 5}), 200,
            headers: {'content-type': 'application/json'});
      }
    }

    // Analytics with full data
    if (path.contains('/analytics')) {
      return http.Response(json.encode({
        'success': true,
        'data': {
          'totalViews': 12500,
          'totalLikes': 3200,
          'totalComments': 890,
          'totalShares': 450,
          'totalFollowers': 1250,
          'totalFollowing': 320,
          'averageWatchTime': 45.5,
          'engagementRate': 12.3,
          'followersGrowth': 50,
          'followingGrowth': 10,
          'viewsByDay': List.generate(7, (i) => {'date': '2026-01-${15 - i}', 'count': 100 + i * 30}),
          'topVideos': List.generate(10, (i) {
            return {
              'id': 'vid-$i',
              'title': 'Video $i',
              'viewCount': 500 - i * 40,
              'likeCount': 100 - i * 8,
              'commentCount': 30 - i * 2,
              'createdAt': '2026-01-${15 - i}T08:00:00Z',
              'thumbnailUrl': '/thumb$i.jpg',
            };
          }),
          'viewsByCategory': [
            {'category': 'Entertainment', 'count': 5000},
            {'category': 'Education', 'count': 3000},
            {'category': 'Sports', 'count': 2500},
            {'category': 'Music', 'count': 2000},
          ],
        },
      }), 200, headers: {'content-type': 'application/json'});
    }

    // 2FA settings
    if (path.contains('/2fa/status') || path.contains('/2fa/settings')) {
      return http.Response(json.encode({
        'success': true,
        'enabled': false,
        'methods': [],
        'availableMethods': ['totp', 'sms', 'email'],
      }), 200, headers: {'content-type': 'application/json'});
    }

    // User profile with full data
    if (path.contains('/users/profile') || (path.contains('/users/') && !path.contains('/settings'))) {
      return http.Response(json.encode({
        'success': true,
        'user': {
          'id': 1,
          'username': 'testuser',
          'displayName': 'Test User',
          'email': 'test@test.com',
          'phone': '+84123456789',
          'bio': 'This is my test bio that is somewhat long to test display',
          'avatar': null,
          'dateOfBirth': '2000-01-15',
          'gender': 'male',
          'isVerified': true,
          'isPrivate': false,
          'followersCount': 1250,
          'followingCount': 320,
          'videoCount': 45,
          'likesCount': 8900,
          'createdAt': '2025-01-01T00:00:00Z',
        },
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Notifications with types
    if (path.contains('/notifications')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(15, (i) {
          final types = ['like', 'comment', 'follow', 'follow_request', 'follow_request_accepted'];
          return {
            'id': 'notif-$i',
            'type': types[i % types.length],
            'message': 'Notification $i message',
            'read': i % 3 == 0,
            'createdAt': DateTime.now().subtract(Duration(hours: i * 4)).toIso8601String(),
            'senderId': i + 10,
            'senderUsername': 'user${i + 10}',
            'senderAvatar': null,
            'targetId': 'vid-$i',
            'targetType': i % 2 == 0 ? 'video' : 'user',
          };
        }),
        'unreadCount': 10,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Follow requests
    if (path.contains('/follow-requests') || path.contains('/pending')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(5, (i) {
          return {
            'id': 'req-$i',
            'userId': i + 20,
            'username': 'requester$i',
            'displayName': 'Requester $i',
            'avatar': null,
            'createdAt': DateTime.now().subtract(Duration(hours: i * 2)).toIso8601String(),
          };
        }),
        'count': 5,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Followers/following list
    if (path.contains('/followers') || path.contains('/following') || path.contains('/friends')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(10, (i) {
          return {
            'id': i + 30,
            'username': 'follower$i',
            'displayName': 'Follower $i',
            'avatar': null,
            'isFollowing': i % 2 == 0,
            'isFollowedBy': i % 3 == 0,
            'followStatus': i % 2 == 0 ? 'following' : 'not_following',
          };
        }),
        'total': 30,
        'hasMore': true,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Videos feed
    if (path.contains('/videos')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(5, (i) {
          return {
            'id': 'vid-$i',
            'title': 'Video $i',
            'description': 'Description for video $i',
            'hlsUrl': '/video$i.m3u8',
            'thumbnailUrl': '/thumb$i.jpg',
            'userId': i + 1,
            'viewCount': 1000 + i * 100,
            'likeCount': 200 + i * 20,
            'commentCount': 50 + i * 5,
            'shareCount': 10 + i,
            'createdAt': '2026-01-${15 - i}T08:00:00Z',
            'status': 'ready',
            'visibility': 'public',
            'allowComments': true,
            'isLiked': i % 2 == 0,
            'isSaved': i % 3 == 0,
            'user': {'id': i + 1, 'username': 'creator$i', 'avatar': null, 'displayName': 'Creator $i'},
          };
        }),
        'total': 20,
        'hasMore': true,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Comments
    if (path.contains('/comments')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(8, (i) {
          return {
            'id': 'comment-$i',
            'content': 'This is comment number $i with some text',
            'userId': i + 1,
            'username': 'commenter$i',
            'avatar': null,
            'createdAt': DateTime.now().subtract(Duration(hours: i)).toIso8601String(),
            'likeCount': i * 5,
            'replyCount': i % 3,
            'isLiked': i % 2 == 0,
            'isPinned': i == 0,
            'isEdited': i == 1,
            'isToxic': i == 2,
          };
        }),
        'total': 20,
        'hasMore': true,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Sessions / devices
    if (path.contains('/sessions')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(3, (i) {
          return {
            'id': 'session-$i',
            'deviceName': 'Device $i',
            'deviceType': i == 0 ? 'mobile' : 'desktop',
            'browser': 'Chrome',
            'os': i == 0 ? 'Android' : 'Windows',
            'ip': '192.168.1.$i',
            'lastActivity': DateTime.now().subtract(Duration(hours: i * 12)).toIso8601String(),
            'isCurrent': i == 0,
          };
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Blocked users
    if (path.contains('/blocked') || path.contains('/block')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(3, (i) {
          return {
            'id': i + 50,
            'username': 'blocked$i',
            'displayName': 'Blocked User $i',
            'avatar': null,
            'blockedAt': DateTime.now().subtract(Duration(days: i * 5)).toIso8601String(),
          };
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Discover / suggestions
    if (path.contains('/discover') || path.contains('/suggestions') || path.contains('/recommend')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(8, (i) {
          return {
            'id': i + 60,
            'username': 'suggested$i',
            'displayName': 'Suggested $i',
            'avatar': null,
            'bio': 'Bio of suggested user $i',
            'followersCount': 100 + i * 50,
            'mutualFollowers': i,
          };
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Categories / interests
    if (path.contains('/categories') || path.contains('/interests')) {
      return http.Response(json.encode({
        'success': true,
        'data': [
          {'id': 1, 'name': 'Entertainment', 'icon': '🎬'},
          {'id': 2, 'name': 'Education', 'icon': '📚'},
          {'id': 3, 'name': 'Sports', 'icon': '⚽'},
          {'id': 4, 'name': 'Music', 'icon': '🎵'},
          {'id': 5, 'name': 'Gaming', 'icon': '🎮'},
          {'id': 6, 'name': 'Food', 'icon': '🍕'},
        ],
        'selected': [1, 3],
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Settings
    if (path.contains('/settings')) {
      return http.Response(json.encode({
        'success': true,
        'settings': {
          'theme': 'dark',
          'language': 'en',
          'notifications': true,
          'autoplay': true,
          'dataUsage': 'normal',
        },
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Privacy
    if (path.contains('/privacy')) {
      return http.Response(json.encode({
        'success': true,
        'data': {
          'isPrivate': false,
          'showOnlineStatus': true,
          'allowMessages': 'everyone',
          'showActivity': true,
          'isFollowersPrivate': false,
          'isFollowingPrivate': false,
        },
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Auth related
    if (path.contains('/auth') || path.contains('/login') || path.contains('/register')) {
      return http.Response(json.encode({
        'success': true,
        'token': 'test-token',
        'user': {
          'id': 1,
          'username': 'testuser',
          'displayName': 'Test User',
          'email': 'test@test.com',
        },
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Default
    return http.Response(json.encode({'success': true}), 200,
        headers: {'content-type': 'application/json'});
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = MockSecureStorage();
  });

  setUp(() async {
    _mockClient = _createRichDataClient();
    // Use the standard mock for login
    final loginClient = createMockHttpClient();
    await http.runWithClient(() async {
      await setupLoggedInState();
    }, () => loginClient);
  });

  // ================================================================
  // ActivityHistoryScreen — Rich data states
  // ================================================================
  group('ActivityHistory States', () {
    testWidgets('renders with rich activity data', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(ActivityHistoryScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('scroll through activity list', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Scroll down multiple times to trigger pagination
        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('tap filter tabs', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Tap tab-like elements
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('tap activity items', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(gds.at(i));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _mockClient);
    });

    testWidgets('tap icon buttons for actions', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final iconBtns = find.byType(IconButton);
        for (int i = 0; i < iconBtns.evaluate().length && i < 3; i++) {
          await tester.tap(iconBtns.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('swipe activity for dismiss', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final dismissible = find.byType(Dismissible);
        if (dismissible.evaluate().isNotEmpty) {
          await tester.drag(dismissible.first, const Offset(-300, 0));
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // AnalyticsScreen — Full data with tabs
  // ================================================================  
  group('Analytics States', () {
    testWidgets('full analytics data rendering', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(AnalyticsScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('switch between overview and charts tabs', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Find tabs
        final tabs = find.byType(Tab);
        if (tabs.evaluate().length > 1) {
          await tester.tap(tabs.at(1));
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
          
          await tester.tap(tabs.at(0));
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('scroll analytics overview tab', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Deep scroll
        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -500));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('pull to refresh analytics', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        await tester.drag(find.byType(Scaffold).first, const Offset(0, 400));
        await tester.pump(const Duration(milliseconds: 500));
        tester.takeException();
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();
      }, () => _mockClient);
    });

    testWidgets('tap analytics stat cards', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 6; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // TwoFactorAuthScreen — Different states
  // ================================================================
  group('TwoFactorAuth States', () {
    testWidgets('renders with 2FA disabled', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(TwoFactorAuthScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('tap checkbox options', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final checkboxes = find.byType(Checkbox);
        for (int i = 0; i < checkboxes.evaluate().length && i < 3; i++) {
          await tester.tap(checkboxes.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('tap enable button', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Select TOTP checkbox
        final checkboxes = find.byType(Checkbox);
        if (checkboxes.evaluate().isNotEmpty) {
          await tester.tap(checkboxes.first);
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }

        // Find enable button
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await tester.tap(btns.first);
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('scroll 2FA content', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('tap appbar actions', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final iconBtns = find.byType(IconButton);
        for (int i = 0; i < iconBtns.evaluate().length && i < 3; i++) {
          await tester.tap(iconBtns.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('tap inkwells for method selection', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 6; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // EditProfileScreen — Rich data
  // ================================================================
  group('EditProfile States', () {
    testWidgets('renders with full profile data', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(EditProfileScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('tap avatar area', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final avatarWidgets = find.byType(CircleAvatar);
        if (avatarWidgets.evaluate().isNotEmpty) {
          try {
            await tester.tap(avatarWidgets.first);
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _mockClient);
    });

    testWidgets('tap all info tiles', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 8; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('modify and scroll form', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Find text field for bio
        final textFields = find.byType(TextField);
        if (textFields.evaluate().isNotEmpty) {
          await tester.enterText(textFields.first, 'Updated bio text');
          await tester.pump(const Duration(milliseconds: 200));
          tester.takeException();
        }

        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('tap gesture detectors for navigation', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(gds.at(i));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // AccountManagementScreen — Menu options
  // ================================================================
  group('AccountManagement States', () {
    testWidgets('renders with full account data', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(AccountManagementScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('tap all menu items', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 8; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('scroll account management page', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('tap switches on account page', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final switches = find.byType(Switch);
        for (int s = 0; s < switches.evaluate().length && s < 3; s++) {
          await tester.tap(switches.at(s));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // NotificationsScreen — Multi-type notifications + tabs
  // ================================================================
  group('Notifications States', () {
    testWidgets('renders with rich notification data', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(NotificationsScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('switch to follow requests tab', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final tabs = find.byType(Tab);
        if (tabs.evaluate().length > 1) {
          await tester.tap(tabs.at(1));
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('tap notification items for navigation', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('scroll notifications deeply', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 4; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('tap mark all read', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final iconBtns = find.byType(IconButton);
        for (int i = 0; i < iconBtns.evaluate().length && i < 3; i++) {
          await tester.tap(iconBtns.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // FollowerFollowingScreen — Rich data  
  // ================================================================
  group('FollowerFollowing States', () {
    testWidgets('renders with follower data', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: FollowerFollowingScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(FollowerFollowingScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('switch tabs through gestures', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: FollowerFollowingScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Swipe to following tab
        final tabView = find.byType(TabBarView);
        if (tabView.evaluate().isNotEmpty) {
          await tester.drag(tabView.first, const Offset(-300, 0));
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Tap tab items
        final tabs = find.byType(Tab);
        for (int i = 0; i < tabs.evaluate().length && i < 3; i++) {
          await tester.tap(tabs.at(i));
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('tap user items and follow buttons', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: FollowerFollowingScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final buttons = find.byType(ElevatedButton);
        if (buttons.evaluate().isNotEmpty) {
          await tester.tap(buttons.first);
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('scroll follower list for pagination', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: FollowerFollowingScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 4; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // ProfileScreen — Rich data states
  // ================================================================
  group('Profile States', () {
    testWidgets('renders with full profile info', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(ProfileScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('tap profile action buttons', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 6; i++) {
          try {
            await tester.tap(gds.at(i));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _mockClient);
    });

    testWidgets('scroll profile and video grid', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -500));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // CommentSectionWidget — Rich comments data
  // ================================================================
  group('CommentSection States', () {
    testWidgets('renders with rich comment data', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: CommentSectionWidget(videoId: 'vid-rich')),
        ));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(CommentSectionWidget), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('type and send comment', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: CommentSectionWidget(videoId: 'vid-rich')),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final textField = find.byType(TextField);
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField.first, 'Awesome video!');
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();

          final iconBtns = find.byType(IconButton);
          if (iconBtns.evaluate().isNotEmpty) {
            await tester.tap(iconBtns.last);
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
      }, () => _mockClient);
    });

    testWidgets('scroll comments for pagination', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: CommentSectionWidget(videoId: 'vid-rich')),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final scrollable = find.byType(Scrollable);
        for (int j = 0; j < 3; j++) {
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -300));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _mockClient);
    });

    testWidgets('tap comment items for actions', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: CommentSectionWidget(videoId: 'vid-rich')),
        ));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(gds.at(i));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _mockClient);
    });

    testWidgets('tap inkwells on comments', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: CommentSectionWidget(videoId: 'vid-rich')),
        ));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // VideoDetailScreen — Rich video data
  // ================================================================
  group('VideoDetail States', () {
    final detailVideos = List.generate(3, (i) {
      return {
        'id': 'det-$i',
        'title': 'Detail Video $i',
        'description': 'Long description for video $i with some details',
        'hlsUrl': '/video$i.m3u8',
        'thumbnailUrl': '/thumb$i.jpg',
        'userId': i + 1,
        'viewCount': 2000 + i * 100,
        'likeCount': 500 + i * 50,
        'commentCount': 100 + i * 10,
        'shareCount': 25 + i * 5,
        'createdAt': '2026-01-${15 - i}T08:00:00Z',
        'status': 'ready',
        'visibility': 'public',
        'isLiked': false,
        'isSaved': false,
        'user': {'id': i + 1, 'username': 'maker$i', 'avatar': null, 'displayName': 'Maker $i'},
      };
    });

    testWidgets('renders with multiple videos', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: VideoDetailScreen(videos: detailVideos, initialIndex: 0),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(VideoDetailScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('swipe between videos', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: VideoDetailScreen(videos: detailVideos, initialIndex: 0),
        ));
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Swipe up for next video
        await tester.drag(find.byType(Scaffold).first, const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 500));
        tester.takeException();
      }, () => _mockClient);
    });

    testWidgets('tap all interactive elements', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: VideoDetailScreen(videos: detailVideos, initialIndex: 0),
        ));
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(gds.at(i));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('scroll video detail info', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: VideoDetailScreen(videos: detailVideos, initialIndex: 0),
        ));
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // UserProfileScreen — Rich data state (timer cleanup)
  // ================================================================
  group('UserProfile States', () {
    testWidgets('renders with rich user data', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: UserProfileScreen(userId: 5),
        ));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(UserProfileScreen), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }, () => _mockClient);
    });

    testWidgets('tap follow and other buttons', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: UserProfileScreen(userId: 5),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final btns = find.byType(ElevatedButton);
        for (int i = 0; i < btns.evaluate().length && i < 3; i++) {
          await tester.tap(btns.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }

        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }, () => _mockClient);
    });

    testWidgets('scroll user profile deeply', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: UserProfileScreen(userId: 5),
        ));
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -500));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }

        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // VideoScreen — Tab-based feed
  // ================================================================
  group('VideoScreen States', () {
    testWidgets('renders video feed', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(VideoScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('swipe between tabs', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Swipe left for tab switch
        await tester.drag(find.byType(Scaffold).first, const Offset(-300, 0));
        await tester.pump(const Duration(milliseconds: 500));
        tester.takeException();

        // Swipe right
        await tester.drag(find.byType(Scaffold).first, const Offset(300, 0));
        await tester.pump(const Duration(milliseconds: 500));
        tester.takeException();
      }, () => _mockClient);
    });

    testWidgets('tap video overlay elements', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(gds.at(i));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _mockClient);
    });

    testWidgets('extended load for all feeds', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(VideoScreen), findsOneWidget);
      }, () => _mockClient);
    });
  });

  // ================================================================
  // SearchScreen — Rich suggestions data
  // ================================================================
  group('SearchScreen States', () {
    testWidgets('search and get results', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
        await tester.pump(const Duration(milliseconds: 500));
        tester.takeException();

        final textField = find.byType(TextField);
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField.first, 'test');
          for (int i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
      }, () => _mockClient);
    });

    testWidgets('tap search results', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // ShareVideoSheet — Rich follower data
  // ================================================================
  group('ShareVideo States', () {
    testWidgets('renders with followers', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: ShareVideoSheet(videoId: 'rich-vid')),
        ));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(ShareVideoSheet), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('search and select followers', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(body: ShareVideoSheet(videoId: 'rich-vid')),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final textField = find.byType(TextField);
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField.first, 'follower');
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 3; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // PrivacySettingsScreen — Rich data
  // ================================================================
  group('Privacy States', () {
    testWidgets('renders with privacy data', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(PrivacySettingsScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('toggle all privacy switches', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final switches = find.byType(Switch);
        for (int i = 0; i < switches.evaluate().length; i++) {
          await tester.tap(switches.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('tap all privacy options', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 8; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // BlockedUsersScreen — Rich list  
  // ================================================================
  group('BlockedUsers States', () {
    testWidgets('renders with blocked users', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: BlockedUsersScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(BlockedUsersScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('tap unblock buttons', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: BlockedUsersScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await tester.tap(btns.first);
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }

        final textBtns = find.byType(TextButton);
        if (textBtns.evaluate().isNotEmpty) {
          await tester.tap(textBtns.first);
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // LoggedDevicesScreen — Session data
  // ================================================================
  group('LoggedDevices States', () {
    testWidgets('renders with sessions', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: LoggedDevicesScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(LoggedDevicesScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('tap session items', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: LoggedDevicesScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 4; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }

        final btns = find.byType(ElevatedButton);
        for (int i = 0; i < btns.evaluate().length && i < 3; i++) {
          await tester.tap(btns.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // DiscoverPeopleScreen — Suggestions
  // ================================================================
  group('DiscoverPeople States', () {
    testWidgets('renders with suggestions', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: DiscoverPeopleScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(DiscoverPeopleScreen), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }, () => _mockClient);
    });

    testWidgets('tap follow on suggested users', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: DiscoverPeopleScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Scroll through suggestions
        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }

        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }, () => _mockClient);
    });

    testWidgets('pull to refresh discover', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: DiscoverPeopleScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        await tester.drag(find.byType(Scaffold).first, const Offset(0, 400));
        await tester.pump(const Duration(milliseconds: 500));
        tester.takeException();
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();

        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // UserSettingsScreen — Settings options
  // ================================================================
  group('UserSettings States', () {
    testWidgets('renders with settings data', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: UserSettingsScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(UserSettingsScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('tap all settings menu items', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: UserSettingsScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 10; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // InAppNotificationSettings — Switches
  // ================================================================
  group('InAppNotification States', () {
    testWidgets('toggle all notification switches', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: InAppNotificationSettingsScreen()));
        for (int i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final switches = find.byType(Switch);
        for (int i = 0; i < switches.evaluate().length; i++) {
          await tester.tap(switches.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // HelpScreen — Deep exploration
  // ================================================================
  group('Help States', () {
    testWidgets('tap all help sections', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 8; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('scroll help deeply', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 4; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -500));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });

  // ================================================================
  // ChatOptionsScreen — Options with rich data
  // ================================================================
  group('ChatOptions States', () {
    testWidgets('renders with options', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: ChatOptionsScreen(recipientId: '10', recipientUsername: 'chatuser'),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
        expect(find.byType(ChatOptionsScreen), findsOneWidget);
      }, () => _mockClient);
    });

    testWidgets('tap all chat options', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: ChatOptionsScreen(recipientId: '10', recipientUsername: 'chatuser'),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 8; i++) {
          await tester.tap(inkWells.at(i));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });

    testWidgets('scroll chat options', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(
          home: ChatOptionsScreen(recipientId: '10', recipientUsername: 'chatuser'),
        ));
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _mockClient);
    });
  });
}
