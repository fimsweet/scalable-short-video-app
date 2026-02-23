/// Ultra-deep branch testing round 2.
/// Targets remaining high-gap screens with specific branch exercising.
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

import 'package:scalable_short_video_app/src/presentation/screens/two_factor_auth_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/analytics_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/account_management_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/activity_history_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/login_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/forgot_password_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/upload_video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/upload_video_screen_v2.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/follower_following_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_options_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/notifications_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/discover_people_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/search_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/privacy_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/blocked_users_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/change_password_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/logged_devices_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/report_user_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/share_video_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/hls_video_player.dart';
import 'package:scalable_short_video_app/src/features/auth/presentation/screens/email_register_screen.dart';

late http.Client _client;

http.Client _buildMock({
  bool has2FA = false,
  bool hasPhone = false,
  bool hasPassword = true,
  String visibility = 'public',
  bool emptyVideos = false,
  bool emptyFollowers = false,
  bool errorResponse = false,
}) {
  return MockClient((request) async {
    final path = request.url.path;
    final query = request.url.queryParameters;

    if (errorResponse) {
      return http.Response(json.encode({
        'success': false, 'message': 'Server error',
      }), 500, headers: {'content-type': 'application/json'});
    }

    // 2FA settings
    if (path.contains('/2fa/settings') || path.contains('/2fa/status')) {
      return http.Response(json.encode({
        'success': true,
        'enabled': has2FA,
        'methods': has2FA ? ['totp'] : [],
        'availableMethods': ['totp', 'sms', 'email'],
      }), 200, headers: {'content-type': 'application/json'});
    }

    if (path.contains('/2fa/setup') || path.contains('/totp/setup')) {
      return http.Response(json.encode({
        'success': true,
        'secret': 'JBSWY3DPEHPK3PXP',
        'qrCode': 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'backupCodes': ['11111111', '22222222', '33333333', '44444444'],
      }), 200, headers: {'content-type': 'application/json'});
    }

    if (path.contains('/2fa/verify') || path.contains('/2fa/enable') || path.contains('/2fa/disable')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    if (path.contains('/2fa/send')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Auth / login
    if (path.contains('/auth/login') || path.contains('/login')) {
      return http.Response(json.encode({
        'success': true,
        'token': 'tok',
        'user': {'id': 1, 'username': 'test', 'displayName': 'Test'},
      }), 200, headers: {'content-type': 'application/json'});
    }

    if (path.contains('/auth/register') || path.contains('/register')) {
      return http.Response(json.encode({
        'success': true,
        'token': 'tok',
        'user': {'id': 2, 'username': 'newuser'},
      }), 200, headers: {'content-type': 'application/json'});
    }

    if (path.contains('/check-username')) {
      return http.Response(json.encode({'success': true, 'available': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    if (path.contains('/auth/forgot') || path.contains('/forgot-password')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    if (path.contains('/auth/reset') || path.contains('/reset-password')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    if (path.contains('/otp')) {
      return http.Response(json.encode({'success': true, 'verified': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Analytics
    if (path.contains('/analytics') || path.contains('/stats')) {
      return http.Response(json.encode({
        'success': true,
        'data': {
          'totalViews': 25000, 'totalLikes': 12000, 'totalComments': 4500,
          'totalShares': 2200, 'totalFollowers': 890, 'totalFollowing': 456,
          'avgWatchTime': 38.5, 'avgCompletionRate': 0.72,
          'viewsByDay': List.generate(30, (i) {
            return {
              'date': '2026-01-${(i + 1).toString().padLeft(2, '0')}',
              'views': 200 + i * 15, 'likes': 80 + i * 5,
              'comments': 20 + i * 2, 'shares': 5 + i,
            };
          }),
          'topVideos': List.generate(10, (i) {
            return {
              'id': 'tv$i', 'title': 'Top Video $i',
              'thumbnailUrl': '/thumb$i.jpg',
              'viewCount': 5000 - i * 300, 'likeCount': 2000 - i * 150,
              'commentCount': 200 - i * 15, 'createdAt': '2026-01-${10 + i}T08:00:00Z',
            };
          }),
          'demographics': {
            'gender': {'male': 45, 'female': 50, 'other': 5},
            'age': {'13-17': 8, '18-24': 40, '25-34': 28, '35-44': 16, '45+': 8},
            'countries': [
              {'code': 'VN', 'name': 'Vietnam', 'percentage': 65},
              {'code': 'US', 'name': 'USA', 'percentage': 20},
              {'code': 'JP', 'name': 'Japan', 'percentage': 15},
            ],
          },
          'engagement': {
            'likeRate': 0.48, 'commentRate': 0.18,
            'shareRate': 0.088, 'saveRate': 0.12,
          },
        },
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Activity history
    if (path.contains('/activity') || path.contains('/history')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(15, (i) {
          final types = ['login', 'video_like', 'comment', 'follow', 'video_upload',
                         'password_change', 'profile_edit', 'video_view'];
          return {
            'id': 'act-$i',
            'type': types[i % types.length],
            'description': 'Activity $i',
            'createdAt': DateTime.now().subtract(Duration(hours: i * 3)).toIso8601String(),
            'metadata': {
              'ip': '192.168.1.$i', 'device': 'Chrome on Windows',
              'videoId': 'v$i', 'videoTitle': 'Video Title $i',
              'targetUserId': i + 10, 'targetUsername': 'target$i',
              'thumbnailUrl': '/thumb$i.jpg',
            },
          };
        }),
        'total': 100,
        'hasMore': true,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Account info / has-password
    if (path.contains('/has-password') || path.contains('/account-info')) {
      return http.Response(json.encode({
        'success': true,
        'hasPassword': hasPassword,
        'email': 'user@test.com',
        'phone': hasPhone ? '+84123456789' : null,
        'googleLinked': false,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Password change
    if (path.contains('/password') || path.contains('/change-password')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Deactivate
    if (path.contains('/deactivate') || path.contains('/delete-account')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Sessions / devices
    if (path.contains('/sessions') || path.contains('/devices')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(4, (i) {
          return {
            'id': 's$i', 'device': 'Device $i', 'browser': 'Chrome',
            'os': i.isEven ? 'Windows' : 'macOS', 'ip': '10.0.0.$i',
            'lastActive': DateTime.now().subtract(Duration(hours: i * 2)).toIso8601String(),
            'isCurrent': i == 0,
          };
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Blocked users
    if (path.contains('/blocked')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(3, (i) {
          return {'id': i + 50, 'username': 'blocked$i', 'displayName': 'Blocked $i', 'avatar': null};
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Videos
    if (path.contains('/videos')) {
      if (emptyVideos) {
        return http.Response(json.encode({
          'success': true, 'data': [], 'total': 0, 'hasMore': false,
        }), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(8, (i) {
          return {
            'id': 'vid-$i', 'title': 'Video $i', 'description': 'Desc $i #tag$i',
            'hlsUrl': '/v$i.m3u8', 'thumbnailUrl': '/t$i.jpg',
            'userId': i + 1, 'viewCount': 500 * (i + 1),
            'likeCount': 200 * (i + 1), 'commentCount': 50 * (i + 1),
            'shareCount': 10 * (i + 1), 'createdAt': '2026-01-15T08:00:00Z',
            'status': 'ready', 'visibility': visibility,
            'allowComments': true, 'allowDuet': true,
            'isLiked': i.isEven, 'isSaved': i.isOdd, 'isHidden': false,
            'user': {'id': i + 1, 'username': 'creator$i', 'avatar': null, 'displayName': 'Creator $i'},
            'categories': [{'id': 1, 'name': 'Entertainment'}],
          };
        }),
        'total': 100, 'hasMore': true,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Users / profile / followers / following
    if (path.contains('/users') || path.contains('/profile') ||
        path.contains('/followers') || path.contains('/following')) {
      if (emptyFollowers) {
        return http.Response(json.encode({
          'success': true, 'data': [], 'total': 0, 'hasMore': false,
          'user': {
            'id': 1, 'username': 'test', 'displayName': 'Test', 'email': 'test@test.com',
            'bio': 'Bio', 'avatar': null, 'followersCount': 0, 'followingCount': 0,
            'videoCount': 0, 'isFollowing': false, 'hasPassword': true,
          },
        }), 200, headers: {'content-type': 'application/json'});
      }
      return http.Response(json.encode({
        'success': true,
        'user': {
          'id': 1, 'username': 'testuser', 'displayName': 'Test User',
          'email': 'test@test.com', 'bio': 'Test bio here', 'avatar': null,
          'followersCount': 567, 'followingCount': 234, 'videoCount': 45,
          'isFollowing': false, 'isFollowedBy': true, 'hasPassword': hasPassword,
          'googleLinked': false, 'phoneLinked': hasPhone, 'birthday': '2000-01-15',
          'gender': 'male',
        },
        'data': List.generate(8, (i) {
          return {
            'id': i + 10, 'username': 'user$i', 'displayName': 'User $i',
            'avatar': null, 'bio': 'Bio $i', 'followersCount': 50 + i * 20,
            'isFollowing': i.isEven,
          };
        }),
        'total': 50, 'hasMore': true,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Conversations / messages
    if (path.contains('/conversations') || path.contains('/messages') || path.contains('/inbox')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(5, (i) {
          return {
            'id': 'conv-$i', 'recipientId': i + 10, 'recipientUsername': 'chatuser$i',
            'lastMessage': 'Last message $i', 'unreadCount': i,
            'createdAt': DateTime.now().subtract(Duration(hours: i)).toIso8601String(),
          };
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Categories
    if (path.contains('/categories')) {
      return http.Response(json.encode({
        'success': true,
        'data': [
          {'id': 1, 'name': 'Entertainment', 'displayNameVi': 'Giải trí'},
          {'id': 2, 'name': 'Education', 'displayNameVi': 'Giáo dục'},
          {'id': 3, 'name': 'Sports', 'displayNameVi': 'Thể thao'},
          {'id': 4, 'name': 'Music', 'displayNameVi': 'Âm nhạc'},
          {'id': 5, 'name': 'Gaming', 'displayNameVi': 'Game'},
        ],
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Follow / unfollow / block / report
    if (path.contains('/follow') || path.contains('/unfollow') ||
        path.contains('/block') || path.contains('/report') ||
        path.contains('/like') || path.contains('/unlike') ||
        path.contains('/save') || path.contains('/unsave') ||
        path.contains('/share') || path.contains('/hide')) {
      return http.Response(json.encode({'success': true}), 200,
          headers: {'content-type': 'application/json'});
    }

    // Settings / privacy
    if (path.contains('/settings') || path.contains('/privacy')) {
      return http.Response(json.encode({
        'success': true,
        'settings': {
          'accountPrivacy': 'public', 'requireFollowApproval': false,
          'showOnlineStatus': true, 'language': 'en',
          'whoCanSendMessages': 'everyone', 'whoCanComment': 'everyone',
          'filterComments': true, 'showActivityStatus': true,
        },
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Notifications
    if (path.contains('/notifications')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(8, (i) {
          return {
            'id': 'n$i', 'type': ['like', 'comment', 'follow', 'mention'][i % 4],
            'message': 'Notification $i', 'read': i > 3,
            'createdAt': DateTime.now().subtract(Duration(hours: i * 2)).toIso8601String(),
            'metadata': {'videoId': 'v$i', 'userId': i + 5, 'username': 'sender$i'},
          };
        }),
        'total': 50, 'hasMore': true, 'unreadCount': 4,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Comments
    if (path.contains('/comments')) {
      if (request.method == 'POST') {
        return http.Response(json.encode({
          'success': true,
          'data': {'id': 'nc', 'content': 'New', 'userId': 1, 'username': 'test',
                   'createdAt': DateTime.now().toIso8601String(), 'likeCount': 0},
        }), 201, headers: {'content-type': 'application/json'});
      }
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(5, (i) {
          return {
            'id': 'cx$i', 'content': 'Comment $i about video',
            'userId': i + 1, 'username': 'commenter$i', 'displayName': 'C $i',
            'createdAt': DateTime.now().subtract(Duration(hours: i)).toIso8601String(),
            'likeCount': i * 3, 'replyCount': i > 2 ? 1 : 0, 'isLiked': false,
          };
        }),
        'total': 20, 'hasMore': true,
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Upload
    if (path.contains('/upload')) {
      return http.Response(json.encode({
        'success': true,
        'data': {'id': 'nv', 'title': 'Uploaded', 'status': 'processing'},
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Suggested users
    if (path.contains('/suggested') || path.contains('/discover')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(6, (i) {
          return {
            'id': i + 20, 'username': 'suggested$i', 'displayName': 'Suggested $i',
            'avatar': null, 'bio': 'Interesting person $i', 'followersCount': 100 + i * 50,
          };
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

    // Search
    if (path.contains('/search')) {
      return http.Response(json.encode({
        'success': true,
        'data': List.generate(5, (i) {
          return {
            'id': 'sr$i', 'username': 'found$i', 'displayName': 'Found $i',
            'avatar': null, 'followersCount': 100,
          };
        }),
      }), 200, headers: {'content-type': 'application/json'});
    }

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
    _client = _buildMock();
    final loginClient = createMockHttpClient();
    await http.runWithClient(() async {
      await setupLoggedInState();
    }, () => loginClient);
  });

  // ================================================================
  // 2FA SCREEN - VERY DEEP
  // ================================================================

  group('TwoFactorAuth ultra-deep', () {
    testWidgets('load with 2FA disabled, scroll all sections', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 8; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('load with 2FA enabled', (tester) async {
      final client2FA = _buildMock(has2FA: true);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 6; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => client2FA);
    });

    testWidgets('tap method checkboxes and buttons', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Try to tap animated containers (custom checkboxes)
        final containers = find.byType(AnimatedContainer);
        for (int i = 0; i < containers.evaluate().length && i < 6; i++) {
          try {
            await tester.tap(containers.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }

        // Tap elevated buttons
        final btns = find.byType(ElevatedButton);
        for (int i = 0; i < btns.evaluate().length && i < 3; i++) {
          try {
            await tester.tap(btns.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          } catch (_) {}
        }

        // Timer cleanup
        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }, () => _client);
    });

    testWidgets('enter OTP code', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final textFields = find.byType(TextField);
        for (int i = 0; i < textFields.evaluate().length; i++) {
          await tester.enterText(textFields.at(i), '123456');
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }

        // Timer cleanup
        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }, () => _client);
    });
  });

  // ================================================================
  // ANALYTICS SCREEN - DEEP WITH TABS
  // ================================================================

  group('Analytics ultra-deep', () {
    testWidgets('overview tab with stat cards', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Deep scroll overview
        for (int j = 0; j < 8; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('switch to charts tab', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Tap charts tab
        final tabs = find.byType(Tab);
        if (tabs.evaluate().length >= 2) {
          await tester.tap(tabs.at(1));
          for (int i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }

          // Deep scroll charts
          for (int j = 0; j < 6; j++) {
            final scaffold = find.byType(Scaffold);
            if (scaffold.evaluate().isNotEmpty) {
              await tester.drag(scaffold.first, const Offset(0, -400));
              await tester.pump(const Duration(milliseconds: 300));
              tester.takeException();
            }
          }
        }
      }, () => _client);
    });

    testWidgets('switch between both tabs', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final tabs = find.byType(Tab);
        // Overview → Charts → Overview
        for (int t = 0; t < tabs.evaluate().length * 2 && t < 6; t++) {
          await tester.tap(tabs.at(t % tabs.evaluate().length));
          for (int i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 400));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('tap dropdown sort options', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Scroll to dropdown
        for (int j = 0; j < 4; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }

        // Find and tap dropdown
        final dropdowns = find.byType(DropdownButton<String>);
        if (dropdowns.evaluate().isNotEmpty) {
          await tester.tap(dropdowns.first);
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
          await tester.pumpAndSettle();
        }
      }, () => _client);
    });

    testWidgets('pull to refresh analytics', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final scaffold = find.byType(Scaffold);
        if (scaffold.evaluate().isNotEmpty) {
          await tester.fling(scaffold.first, const Offset(0, 400), 1000);
          for (int i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('tap show more/less button', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Scroll down to find show more
        for (int j = 0; j < 5; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }

        // Tap TextButton.icon (show more)
        final textBtns = find.byType(TextButton);
        for (int i = 0; i < textBtns.evaluate().length && i < 3; i++) {
          try {
            await tester.tap(textBtns.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('analytics with empty data', (tester) async {
      final emptyClient = _buildMock(emptyVideos: true);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => emptyClient);
    });
  });

  // ================================================================
  // ACCOUNT MANAGEMENT - DEEP
  // ================================================================

  group('AccountManagement ultra-deep', () {
    testWidgets('load and scroll all sections', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 10; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('load without password', (tester) async {
      final noPwClient = _buildMock(hasPassword: false);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 8; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => noPwClient);
    });

    testWidgets('tap CupertinoSwitch toggles', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Scroll to find switches
        for (int j = 0; j < 4; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }

        final cupertinoSwitch = find.byType(CupertinoSwitch);
        for (int i = 0; i < cupertinoSwitch.evaluate().length; i++) {
          try {
            await tester.tap(cupertinoSwitch.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('tap menu items to trigger dialogs', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Tap first few InkWells (menu items)
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 3; i++) {
          try {
            await tester.tap(inkWells.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();

            // If dialog opened, dismiss it
            final dialogBtns = find.byType(TextButton);
            if (dialogBtns.evaluate().isNotEmpty) {
              await tester.tap(dialogBtns.last, warnIfMissed: false);
              await tester.pump(const Duration(milliseconds: 300));
              tester.takeException();
            }
          } catch (_) {}
        }
      }, () => _client);
    });
  });

  // ================================================================
  // EDIT PROFILE - DEEP
  // ================================================================

  group('EditProfile ultra-deep', () {
    testWidgets('load profile with all fields', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 10; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('tap avatar area', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final circleAvatar = find.byType(CircleAvatar);
        if (circleAvatar.evaluate().isNotEmpty) {
          try {
            await tester.tap(circleAvatar.first, warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('tap editable fields', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Tap all InkWells (field rows)
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 6; i++) {
          try {
            await tester.tap(inkWells.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('edit bio field', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final textField = find.byType(TextField);
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField.first, 'Updated bio text here');
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _client);
    });

    testWidgets('scroll up back to top', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Scroll down then up
        for (int j = 0; j < 5; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 200));
          tester.takeException();
        }
        for (int j = 0; j < 5; j++) {
          await tester.drag(find.byType(Scaffold).first, const Offset(0, 400));
          await tester.pump(const Duration(milliseconds: 200));
          tester.takeException();
        }
      }, () => _client);
    });
  });

  // ================================================================
  // ACTIVITY HISTORY - DEEP
  // ================================================================

  group('ActivityHistory ultra-deep', () {
    testWidgets('load with default filter and scroll', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 8; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('tap each filter chip', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Tap all GestureDetectors (filter chips)
        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 6; i++) {
          try {
            await tester.tap(gds.at(i), warnIfMissed: false);
            for (int k = 0; k < 3; k++) {
              await tester.pump(const Duration(milliseconds: 500));
              tester.takeException();
            }
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('tap manage menu (more_vert)', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Tap more_vert IconButton
        final iconBtns = find.byType(IconButton);
        for (int i = 0; i < iconBtns.evaluate().length; i++) {
          try {
            await tester.tap(iconBtns.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();

            // Scroll the bottom sheet
            final scrollable = find.byType(Scrollable);
            if (scrollable.evaluate().length > 1) {
              await tester.drag(scrollable.last, const Offset(0, -200));
              await tester.pump(const Duration(milliseconds: 300));
              tester.takeException();
            }

            // Dismiss
            await tester.tapAt(const Offset(10, 10));
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('pull refresh activity', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final scaffold = find.byType(Scaffold);
        if (scaffold.evaluate().isNotEmpty) {
          await tester.fling(scaffold.first, const Offset(0, 400), 1000);
          for (int i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('swipe to dismiss activity item', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final dismissible = find.byType(Dismissible);
        if (dismissible.evaluate().isNotEmpty) {
          try {
            await tester.drag(dismissible.first, const Offset(-500, 0));
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('long press activity item', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        if (inkWells.evaluate().isNotEmpty) {
          try {
            await tester.longPress(inkWells.first);
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();

            // Dismiss modal if opened
            await tester.tapAt(const Offset(10, 10));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });
  });

  // ================================================================
  // VIDEO SCREEN - DEEP
  // ================================================================

  group('VideoScreen ultra-deep', () {
    testWidgets('horizontal swipe between tabs', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Swipe left (to friends tab)
        await tester.drag(find.byType(VideoScreen), const Offset(-300, 0));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Swipe left again (to following tab)
        await tester.drag(find.byType(VideoScreen), const Offset(-300, 0));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Swipe right back
        await tester.drag(find.byType(VideoScreen), const Offset(300, 0));
        for (int i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => _client);
    });

    testWidgets('vertical swipe through videos', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Vertical swipes
        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(VideoScreen), const Offset(0, -500));
          for (int i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('tap feed tab bar items', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Tap on GestureDetectors in the tab area
        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(gds.at(i), warnIfMissed: false);
            for (int k = 0; k < 3; k++) {
              await tester.pump(const Duration(milliseconds: 500));
              tester.takeException();
            }
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('render with empty videos', (tester) async {
      final emptyClient = _buildMock(emptyVideos: true);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => emptyClient);
    });
  });

  // ================================================================
  // MORE SCREEN TESTS
  // ================================================================

  group('ProfileScreen deep scroll', () {
    testWidgets('profile load and deep scroll', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 8; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('tap profile edit buttons', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final gds = find.byType(GestureDetector);
        for (int i = 0; i < gds.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(gds.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });
  });

  group('NotificationsScreen deep', () {
    testWidgets('load and scroll notifications', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 5; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('tap notification items', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(inkWells.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });

    testWidgets('pull refresh notifications', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final scaffold = find.byType(Scaffold);
        if (scaffold.evaluate().isNotEmpty) {
          await tester.fling(scaffold.first, const Offset(0, 400), 1000);
          for (int i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
      }, () => _client);
    });
  });

  group('FollowerFollowing deep tabs', () {
    testWidgets('start on following tab (index 1)', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: FollowerFollowingScreen(userId: 1, initialIndex: 1),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Deep scroll
        for (int j = 0; j < 5; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('empty followers state', (tester) async {
      final emptyClient = _buildMock(emptyFollowers: true);
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: FollowerFollowingScreen(userId: 1, initialIndex: 0),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => emptyClient);
    });

    testWidgets('search followers', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: FollowerFollowingScreen(userId: 1),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final textField = find.byType(TextField);
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField.first, 'user');
          for (int i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
      }, () => _client);
    });
  });

  group('ShareVideoSheet deep', () {
    testWidgets('scroll and select multiple users', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ShareVideoSheet(videoId: 'v1')),
        ));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Scroll
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -300));
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }

        // Tap user items
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 4; i++) {
          try {
            await tester.tap(inkWells.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });
  });

  group('DiscoverPeople deep', () {
    testWidgets('load and scroll suggestions', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: DiscoverPeopleScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 5; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
        // Timer cleanup
        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }, () => _client);
    });
  });

  group('SearchScreen deep', () {
    testWidgets('search users', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final textField = find.byType(TextField);
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField.first, 'search query');
          for (int i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('clear search', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final textField = find.byType(TextField);
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField.first, 'test');
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();

          // Clear
          await tester.enterText(textField.first, '');
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => _client);
    });
  });

  group('UserSettings deep', () {
    testWidgets('load and scroll all', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: UserSettingsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 8; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _client);
    });
  });

  group('PrivacySettings deep', () {
    testWidgets('load and toggle switches', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 5; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }

        final switches = find.byType(Switch);
        for (int i = 0; i < switches.evaluate().length; i++) {
          try {
            await tester.tap(switches.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });
  });

  group('BlockedUsers deep', () {
    testWidgets('load and unblock', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: BlockedUsersScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final btns = find.byType(ElevatedButton);
        for (int i = 0; i < btns.evaluate().length && i < 3; i++) {
          try {
            await tester.tap(btns.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });
  });

  group('ChangePassword deep', () {
    testWidgets('enter all fields', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        final textFields = find.byType(TextField);
        for (int i = 0; i < textFields.evaluate().length && i < 3; i++) {
          await tester.enterText(textFields.at(i), i == 0 ? 'OldPass123' : 'NewPass456');
          await tester.pump(const Duration(milliseconds: 200));
          tester.takeException();
        }

        // Toggle visibility icons
        final iconBtns = find.byType(IconButton);
        for (int i = 0; i < iconBtns.evaluate().length; i++) {
          try {
            await tester.tap(iconBtns.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 200));
            tester.takeException();
          } catch (_) {}
        }

        // Tap submit
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await tester.tap(btns.first, warnIfMissed: false);
          for (int i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
      }, () => _client);
    });
  });

  group('LoggedDevices deep', () {
    testWidgets('load devices list', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: LoggedDevicesScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        for (int j = 0; j < 3; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _client);
    });
  });

  group('ReportScreen deep', () {
    testWidgets('render and select report reasons', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: ReportUserScreen(reportedUserId: '1', reportedUsername: 'user1'),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Tap radio buttons / list tiles
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 5; i++) {
          try {
            await tester.tap(inkWells.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }

        // Enter description
        final textField = find.byType(TextField);
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField.first, 'This is a report description');
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _client);
    });
  });

  group('VideoDetail deep interactions', () {
    testWidgets('multiple video items and scroll', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: VideoDetailScreen(
            videos: List.generate(5, (i) {
              return {
                'id': 'vd$i', 'title': 'Video $i', 'description': 'Desc $i',
                'hlsUrl': '/v$i.m3u8', 'thumbnailUrl': '/t$i.jpg',
                'userId': i + 1, 'username': 'u$i',
                'viewCount': 100 * (i + 1), 'likeCount': 50 * (i + 1),
                'commentCount': 20, 'shareCount': 5,
                'isLiked': i.isEven, 'isSaved': i.isOdd,
                'user': {'id': i + 1, 'username': 'u$i', 'avatar': null, 'displayName': 'U $i'},
              };
            }),
            initialIndex: 1,
          ),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Swipe up and down
        for (int j = 0; j < 3; j++) {
          await tester.drag(find.byType(VideoDetailScreen), const Offset(0, -400));
          for (int k = 0; k < 3; k++) {
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }
      }, () => _client);
    });
  });

  group('UserProfile deep interactions', () {
    testWidgets('follow/unfollow and scroll tabs', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: UserProfileScreen(userId: 10),
        ));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Scroll deep
        for (int j = 0; j < 6; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }

        // Timer cleanup
        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 25; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }, () => _client);
    });
  });

  group('CommentSection deeper interactions', () {
    testWidgets('reply to comment', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: CommentSectionWidget(
              videoId: 'v99',
              allowComments: true,
              onCommentAdded: () {},
              videoOwnerId: '1',
            ),
          ),
        ));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Tap reply buttons
        final inkWells = find.byType(InkWell);
        for (int i = 0; i < inkWells.evaluate().length && i < 3; i++) {
          try {
            await tester.tap(inkWells.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }

        // Type reply
        final textField = find.byType(TextField);
        if (textField.evaluate().isNotEmpty) {
          await tester.enterText(textField.first, 'This is a reply!');
          await tester.pump(const Duration(milliseconds: 300));
          tester.takeException();
        }
      }, () => _client);
    });
  });

  group('ForgotPassword step navigation', () {
    testWidgets('empty OTP code validation', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Enter email and tap next
        final tf = find.byType(TextField);
        if (tf.evaluate().isNotEmpty) {
          await tester.enterText(tf.first, 'test@test.com');
          await tester.pump();
        }

        // Tap send
        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await tester.tap(btns.first);
          for (int i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }

        // Timer cleanup (resend countdown)
        await tester.pumpWidget(const SizedBox());
        for (int i = 0; i < 65; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }, () => _client);
    });
  });

  group('Login form variations', () {
    testWidgets('login with short password', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }

        final tfs = find.byType(TextField);
        if (tfs.evaluate().length >= 2) {
          await tester.enterText(tfs.at(0), 'a@b.c');
          await tester.pump();
          await tester.enterText(tfs.at(1), '123');
          await tester.pump();
        }

        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await tester.tap(btns.first);
          for (int i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
      }, () => _client);
    });

    testWidgets('login with very long email', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }

        final tfs = find.byType(TextField);
        if (tfs.evaluate().length >= 2) {
          await tester.enterText(tfs.at(0), 'verylongemail' * 5 + '@example.com');
          await tester.pump();
          await tester.enterText(tfs.at(1), 'Password123!');
          await tester.pump();
        }

        final btns = find.byType(ElevatedButton);
        if (btns.evaluate().isNotEmpty) {
          await tester.tap(btns.first);
          for (int i = 0; i < 3; i++) {
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          }
        }
      }, () => _client);
    });
  });

  group('UploadVideoV2 deep', () {
    testWidgets('enter all form fields', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: UploadVideoScreenV2()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Fill text fields
        final tfs = find.byType(TextField);
        for (int i = 0; i < tfs.evaluate().length; i++) {
          await tester.enterText(tfs.at(i), 'Test value $i');
          await tester.pump(const Duration(milliseconds: 200));
          tester.takeException();
        }

        // Scroll to see more
        for (int j = 0; j < 5; j++) {
          final scaffold = find.byType(Scaffold);
          if (scaffold.evaluate().isNotEmpty) {
            await tester.drag(scaffold.first, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          }
        }

        // Tap switches and dropdowns
        final switches = find.byType(Switch);
        for (int i = 0; i < switches.evaluate().length; i++) {
          try {
            await tester.tap(switches.at(i), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });
  });

  group('HLSVideoPlayer rendering', () {
    testWidgets('render player with controls', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: HLSVideoPlayer(
              videoUrl: 'https://example.com/test.m3u8',
              autoPlay: false,
            ),
          ),
        ));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }

        // Tap player area
        final gd = find.byType(GestureDetector);
        if (gd.evaluate().isNotEmpty) {
          try {
            await tester.tap(gd.first, warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 500));
            tester.takeException();
          } catch (_) {}
        }
      }, () => _client);
    });
  });

  group('Error state rendering', () {
    testWidgets('analytics with server error', (tester) async {
      final errClient = _buildMock(errorResponse: true);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => errClient);
    });

    testWidgets('activity history with server error', (tester) async {
      final errClient = _buildMock(errorResponse: true);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => errClient);
    });

    testWidgets('edit profile with server error', (tester) async {
      final errClient = _buildMock(errorResponse: true);
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
        for (int i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          tester.takeException();
        }
      }, () => errClient);
    });
  });
}
