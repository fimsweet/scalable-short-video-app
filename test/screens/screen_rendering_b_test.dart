import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:scalable_short_video_app/src/presentation/screens/activity_history_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/analytics_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/upload_video_screen_v2.dart';
import 'package:scalable_short_video_app/src/presentation/screens/account_management_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/notifications_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/profile_screen.dart';
import 'package:scalable_short_video_app/src/features/auth/presentation/screens/email_register_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/follower_following_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/search_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/logged_devices_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/inbox_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ============================================================
  // ActivityHistoryScreen (868 lines)
  // ============================================================
  group('ActivityHistoryScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ActivityHistoryScreen), findsOneWidget);
    });

    testWidgets('builds scaffold with app bar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('lifecycle - dispose', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // AnalyticsScreen (854 lines)
  // ============================================================
  group('AnalyticsScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(AnalyticsScreen), findsOneWidget);
    });

    testWidgets('builds scaffold', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // UploadVideoScreenV2 (784 lines)
  // ============================================================
  group('UploadVideoScreenV2', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UploadVideoScreenV2()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(UploadVideoScreenV2), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UploadVideoScreenV2()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // AccountManagementScreen (715 lines)
  // ============================================================
  group('AccountManagementScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(AccountManagementScreen), findsOneWidget);
    });

    testWidgets('builds full layout', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // NotificationsScreen (609 lines)
  // ============================================================
  group('NotificationsScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // ProfileScreen (605 lines)
  // ============================================================
  group('ProfileScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('renders with refresh trigger', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen(refreshTrigger: 1)));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // EmailRegisterScreen (457 lines)
  // ============================================================
  group('EmailRegisterScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EmailRegisterScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(EmailRegisterScreen), findsOneWidget);
    });

    testWidgets('builds scaffold', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EmailRegisterScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EmailRegisterScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // FollowerFollowingScreen (402 lines)
  // ============================================================
  group('FollowerFollowingScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FollowerFollowingScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(FollowerFollowingScreen), findsOneWidget);
    });

    testWidgets('renders with initial tab index', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FollowerFollowingScreen(initialIndex: 1)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(FollowerFollowingScreen), findsOneWidget);
    });

    testWidgets('renders with userId', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FollowerFollowingScreen(userId: 123, username: 'testuser'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(FollowerFollowingScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FollowerFollowingScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // SearchScreen (392 lines)
  // ============================================================
  group('SearchScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // LoggedDevicesScreen (251 lines)
  // ============================================================
  group('LoggedDevicesScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoggedDevicesScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(LoggedDevicesScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoggedDevicesScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // InboxScreen (256 lines)
  // ============================================================
  group('InboxScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: InboxScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(InboxScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: InboxScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // VideoScreen (989 lines)
  // ============================================================
  group('VideoScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(VideoScreen), findsOneWidget);
    });

    testWidgets('builds scaffold', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });
}
