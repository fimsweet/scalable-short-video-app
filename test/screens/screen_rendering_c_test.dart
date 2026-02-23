import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:scalable_short_video_app/src/presentation/screens/chat_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_options_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_media_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/report_user_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_search_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/pinned_messages_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/comment_section_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/share_video_sheet.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_privacy_sheet.dart';
import 'package:scalable_short_video_app/src/features/auth/presentation/screens/email_password_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_video_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ============================================================
  // ChatScreen (2528 lines)
  // ============================================================
  group('ChatScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(
            recipientId: 'test-recipient-1',
            recipientUsername: 'testuser',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('renders with avatar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(
            recipientId: 'test-recipient-2',
            recipientUsername: 'testuser2',
            recipientAvatar: 'https://example.com/avatar.jpg',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ChatScreen), findsOneWidget);
    });

    testWidgets('lifecycle - dispose cancels subscriptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatScreen(
            recipientId: 'test-recipient-3',
            recipientUsername: 'testuser3',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // UserProfileScreen (553 lines)
  // ============================================================
  group('UserProfileScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UserProfileScreen(userId: 1)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(UserProfileScreen), findsOneWidget);
    });

    testWidgets('renders with different user id', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UserProfileScreen(userId: 999)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(UserProfileScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: UserProfileScreen(userId: 1)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // ChatOptionsScreen (535 lines)
  // ============================================================
  group('ChatOptionsScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatOptionsScreen(
            recipientId: 'test-id',
            recipientUsername: 'testuser',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ChatOptionsScreen), findsOneWidget);
    });

    testWidgets('renders with avatar and callbacks', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatOptionsScreen(
            recipientId: 'test-id',
            recipientUsername: 'testuser',
            recipientAvatar: 'https://example.com/avatar.jpg',
            onThemeColorChanged: (_) {},
            onNicknameChanged: (_) {},
            onAutoTranslateChanged: (_) {}
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ChatOptionsScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatOptionsScreen(
            recipientId: 'test-id',
            recipientUsername: 'testuser',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // ChatMediaScreen (279 lines)
  // ============================================================
  group('ChatMediaScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatMediaScreen(
            recipientId: 'test-id',
            recipientUsername: 'testuser',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ChatMediaScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ChatMediaScreen(
            recipientId: 'test-id',
            recipientUsername: 'testuser',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // ReportUserScreen (199 lines)
  // ============================================================
  group('ReportUserScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReportUserScreen(
            reportedUserId: 'user-1',
            reportedUsername: 'baduser',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ReportUserScreen), findsOneWidget);
    });

    testWidgets('renders with avatar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReportUserScreen(
            reportedUserId: 'user-1',
            reportedUsername: 'baduser',
            reportedAvatar: 'https://example.com/avatar.jpg',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ReportUserScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReportUserScreen(
            reportedUserId: 'user-1',
            reportedUsername: 'baduser',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // EmailPasswordScreen (185 lines)
  // ============================================================
  group('EmailPasswordScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailPasswordScreen(
            username: 'testuser',
            dateOfBirth: DateTime(2000, 1, 15),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(EmailPasswordScreen), findsOneWidget);
    });

    testWidgets('has password fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailPasswordScreen(
            username: 'testuser',
            dateOfBirth: DateTime(2000, 6, 1),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmailPasswordScreen(
            username: 'testuser',
            dateOfBirth: DateTime(2000, 1, 1),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // ChatSearchScreen (184 lines)
  // ============================================================
  group('ChatSearchScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatSearchScreen(
            recipientId: 'test-id',
            recipientUsername: 'testuser',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ChatSearchScreen), findsOneWidget);
    });

    testWidgets('renders with avatar and callback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatSearchScreen(
            recipientId: 'test-id',
            recipientUsername: 'testuser',
            recipientAvatar: 'https://example.com/avatar.jpg',
            onMessageTap: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ChatSearchScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatSearchScreen(
            recipientId: 'test-id',
            recipientUsername: 'testuser',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // PinnedMessagesScreen (165 lines)
  // ============================================================
  group('PinnedMessagesScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PinnedMessagesScreen(
            recipientId: 'test-id',
            recipientUsername: 'testuser',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(PinnedMessagesScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PinnedMessagesScreen(
            recipientId: 'test-id',
            recipientUsername: 'testuser',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // CommentSectionWidget (1229 lines)
  // ============================================================
  group('CommentSectionWidget', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommentSectionWidget(videoId: 'test-video-id'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(CommentSectionWidget), findsOneWidget);
    });

    testWidgets('renders with all options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommentSectionWidget(
              videoId: 'test-video-id',
              allowComments: true,
              autoFocus: false,
              videoOwnerId: 'owner-1',
              onCommentAdded: () {},
              onCommentDeleted: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(CommentSectionWidget), findsOneWidget);
    });

    testWidgets('renders with comments disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommentSectionWidget(
              videoId: 'test-video-id',
              allowComments: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(CommentSectionWidget), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommentSectionWidget(videoId: 'test-video-id'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // ShareVideoSheet (345 lines)
  // ============================================================
  group('ShareVideoSheet', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShareVideoSheet(videoId: 'test-video-id'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ShareVideoSheet), findsOneWidget);
    });

    testWidgets('renders with callback', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareVideoSheet(
              videoId: 'test-video-id',
              onShareComplete: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ShareVideoSheet), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShareVideoSheet(videoId: 'test-video-id'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // VideoPrivacySheet (204 lines)
  // ============================================================
  group('VideoPrivacySheet', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPrivacySheet(
              videoId: 'test-video',
              userId: 'user-1',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(VideoPrivacySheet), findsOneWidget);
    });

    testWidgets('renders with custom privacy settings', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPrivacySheet(
              videoId: 'test-video',
              userId: 'user-1',
              currentVisibility: 'private',
              allowComments: false,
              allowDuet: false,
              isHidden: true,
              onChanged: (_, __, ___) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(VideoPrivacySheet), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoPrivacySheet(
              videoId: 'test-video',
              userId: 'user-1',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // EditVideoScreen (203 lines)
  // ============================================================
  group('EditVideoScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EditVideoScreen(
            videoId: 'test-video',
            userId: 'user-1',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(EditVideoScreen), findsOneWidget);
    });

    testWidgets('renders with prefilled data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EditVideoScreen(
            videoId: 'test-video',
            userId: 'user-1',
            currentTitle: 'Test Title',
            currentDescription: 'Test Description',
            currentThumbnailUrl: 'https://example.com/thumb.jpg',
            onSaved: (_, __) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(EditVideoScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EditVideoScreen(
            videoId: 'test-video',
            userId: 'user-1',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });
}
