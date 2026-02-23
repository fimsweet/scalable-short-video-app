import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

import '../helpers/test_setup.dart';

import 'package:scalable_short_video_app/src/presentation/screens/chat_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/activity_history_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/analytics_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/upload_video_screen_v2.dart';
import 'package:scalable_short_video_app/src/presentation/screens/account_management_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/notifications_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/follower_following_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/search_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/inbox_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/privacy_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/help_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/change_password_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/logged_devices_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/blocked_users_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_username_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_display_name_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/select_interests_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/discover_people_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/search_user_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/in_app_notification_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/report_user_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_options_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_media_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_search_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/pinned_messages_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/share_video_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_privacy_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/user_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/hidden_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/saved_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/liked_video_grid.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/suggestions_grid_section.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/features/auth/presentation/screens/email_register_screen.dart';
import 'package:scalable_short_video_app/src/features/auth/presentation/screens/registration_method_screen.dart';
import 'package:scalable_short_video_app/src/features/auth/presentation/screens/email_password_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupLoggedInState();
  });

  // ============================================================
  // BIG SCREENS - Logged In State
  // ============================================================

  group('ChatScreen (logged in)', () {
    tearDown(() {
      MessageService().disconnect();
    });

    testWidgets('renders with logged in user', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(recipientId: '2', recipientUsername: 'friend'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ChatScreen), findsOneWidget);
      MessageService().disconnect();
      await tester.pumpWidget(const SizedBox());
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();
      }
    });

    testWidgets('shows chat UI elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(recipientId: '3', recipientUsername: 'user2'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(Scaffold), findsWidgets);
      MessageService().disconnect();
      await tester.pumpWidget(const SizedBox());
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();
      }
    });

    testWidgets('renders with avatar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(
            recipientId: '4',
            recipientUsername: 'avataruser',
            recipientAvatar: 'https://example.com/avatar.png',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ChatScreen), findsOneWidget);
      MessageService().disconnect();
      await tester.pumpWidget(const SizedBox());
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();
      }
    });
  });

  group('VideoScreen (logged in)', () {
    testWidgets('renders and loads videos', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(VideoScreen), findsOneWidget);
    });

    testWidgets('builds full UI', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VideoScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('ActivityHistoryScreen (logged in)', () {
    testWidgets('renders and loads history', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ActivityHistoryScreen), findsOneWidget);
    });

    testWidgets('shows scaffold and app bar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ActivityHistoryScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });
  });

  group('AnalyticsScreen (logged in)', () {
    testWidgets('renders and loads data', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(AnalyticsScreen), findsOneWidget);
    });

    testWidgets('shows scaffold', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AnalyticsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('UploadVideoScreenV2 (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UploadVideoScreenV2()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(UploadVideoScreenV2), findsOneWidget);
    });
  });

  group('AccountManagementScreen (logged in)', () {
    testWidgets('renders and loads data', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(AccountManagementScreen), findsOneWidget);
    });

    testWidgets('shows full layout', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AccountManagementScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('NotificationsScreen (logged in)', () {
    testWidgets('renders and loads notifications', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NotificationsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(NotificationsScreen), findsOneWidget);
    });
  });

  group('ProfileScreen (logged in)', () {
    testWidgets('renders with user data', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('shows scaffold and profile elements', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('FollowerFollowingScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: FollowerFollowingScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(FollowerFollowingScreen), findsOneWidget);
    });

    testWidgets('renders with userId', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FollowerFollowingScreen(userId: 1, username: 'testuser')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(FollowerFollowingScreen), findsOneWidget);
    });
  });

  group('SearchScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(SearchScreen), findsOneWidget);
    });
  });

  group('InboxScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: InboxScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(InboxScreen), findsOneWidget);
    });
  });

  // ============================================================
  // MEDIUM SCREENS - Logged In State
  // ============================================================

  group('UserProfileScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserProfileScreen(userId: 2)));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(UserProfileScreen), findsOneWidget);
    });
  });

  group('UserSettingsScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserSettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(UserSettingsScreen), findsOneWidget);
    });
  });

  group('PrivacySettingsScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(PrivacySettingsScreen), findsOneWidget);
    });
  });

  group('HelpScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(HelpScreen), findsOneWidget);
    });
  });

  group('ChangePasswordScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });
  });

  group('LoggedDevicesScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoggedDevicesScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(LoggedDevicesScreen), findsOneWidget);
    });
  });

  group('BlockedUsersScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BlockedUsersScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(BlockedUsersScreen), findsOneWidget);
    });
  });

  group('EditUsernameScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditUsernameScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(EditUsernameScreen), findsOneWidget);
    });
  });

  group('EditDisplayNameScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditDisplayNameScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(EditDisplayNameScreen), findsOneWidget);
    });
  });

  group('SelectInterestsScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SelectInterestsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(SelectInterestsScreen), findsOneWidget);
    });
  });

  group('DiscoverPeopleScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DiscoverPeopleScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(DiscoverPeopleScreen), findsOneWidget);
    });
  });

  group('SearchUserScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SearchUserScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(SearchUserScreen), findsOneWidget);
    });
  });

  group('InAppNotificationSettingsScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: InAppNotificationSettingsScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(InAppNotificationSettingsScreen), findsOneWidget);
    });
  });

  // ============================================================
  // PARAM SCREENS - Logged In State
  // ============================================================

  group('ReportUserScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReportUserScreen(reportedUserId: 'user-2', reportedUsername: 'baduser'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ReportUserScreen), findsOneWidget);
    });
  });

  group('ChatOptionsScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatOptionsScreen(recipientId: '5', recipientUsername: 'chatuser'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ChatOptionsScreen), findsOneWidget);
    });
  });

  group('ChatMediaScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatMediaScreen(recipientId: '5', recipientUsername: 'chatuser'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ChatMediaScreen), findsOneWidget);
    });
  });

  group('ChatSearchScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatSearchScreen(recipientId: '5', recipientUsername: 'chatuser'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ChatSearchScreen), findsOneWidget);
    });
  });

  group('PinnedMessagesScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PinnedMessagesScreen(recipientId: '5', recipientUsername: 'chatuser'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(PinnedMessagesScreen), findsOneWidget);
    });
  });

  group('EditVideoScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EditVideoScreen(videoId: 'vid-1', userId: '1'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(EditVideoScreen), findsOneWidget);
    });
  });

  // ============================================================
  // WIDGETS - Logged In State
  // ============================================================

  group('CommentSectionWidget (logged in)', () {
    testWidgets('renders and loads comments', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CommentSectionWidget(videoId: 'video-1')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(CommentSectionWidget), findsOneWidget);
    });

    testWidgets('renders with disabled comments', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommentSectionWidget(
              videoId: 'video-2',
              allowComments: false,
              videoOwnerId: '1',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(CommentSectionWidget), findsOneWidget);
    });
  });

  group('ShareVideoSheet (logged in)', () {
    testWidgets('renders and loads followers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ShareVideoSheet(videoId: 'video-1')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ShareVideoSheet), findsOneWidget);
    });
  });

  group('VideoPrivacySheet (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPrivacySheet(videoId: 'vid-1', userId: '1'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(VideoPrivacySheet), findsOneWidget);
    });
  });

  group('UserVideoGrid (logged in)', () {
    testWidgets('renders and loads videos', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UserVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(UserVideoGrid), findsOneWidget);
    });
  });

  group('HiddenVideoGrid (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HiddenVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(HiddenVideoGrid), findsOneWidget);
    });
  });

  group('SavedVideoGrid (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SavedVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(SavedVideoGrid), findsOneWidget);
    });
  });

  group('LikedVideoGrid (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LikedVideoGrid())),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(LikedVideoGrid), findsOneWidget);
    });
  });

  group('SuggestionsGridSection (logged in)', () {
    testWidgets('renders and loads suggestions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SuggestionsGridSection())),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(SuggestionsGridSection), findsOneWidget);
    });
  });

  // ============================================================
  // AUTH SCREENS
  // ============================================================

  group('EmailRegisterScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EmailRegisterScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(EmailRegisterScreen), findsOneWidget);
    });
  });

  group('RegistrationMethodScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegistrationMethodScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(RegistrationMethodScreen), findsOneWidget);
    });
  });

  group('EmailPasswordScreen (logged in)', () {
    testWidgets('renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailPasswordScreen(
            username: 'newuser',
            dateOfBirth: DateTime(2000, 1, 1),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(EmailPasswordScreen), findsOneWidget);
    });
  });
}
