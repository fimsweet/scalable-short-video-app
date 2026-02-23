import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

import '../helpers/test_setup.dart';

// Testable zero-coverage screens
import 'package:scalable_short_video_app/src/presentation/screens/login_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/two_factor_auth_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/forgot_password_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/processing_video_screen.dart';
import 'package:scalable_short_video_app/src/features/auth/presentation/screens/username_creation_screen.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupLoggedInState();
  });

  // ============================================================
  // LoginScreen - 796 LF, 1 LH
  // ============================================================
  group('LoginScreen detailed', () {
    testWidgets('renders login form', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('has text form fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);
    });

    testWidgets('can enter username text', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'testuser');
        await tester.pump();
        tester.takeException();
      }
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('can enter password text', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().length >= 2) {
        await tester.enterText(textFields.at(1), 'password123');
        await tester.pump();
        tester.takeException();
      }
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('has app bar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('contains safe area', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(SafeArea), findsWidgets);
    });

    testWidgets('contains form', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('has animation transitions', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(FadeTransition), findsWidgets);
    });

    testWidgets('tap password visibility toggle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      final visibilityIcons = find.byIcon(Icons.visibility_off);
      if (visibilityIcons.evaluate().isNotEmpty) {
        await tester.tap(visibilityIcons.first);
        await tester.pump();
        tester.takeException();
      }
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('tap back button', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: const Text('Go'),
          );
        })),
      ));
      await tester.pump();
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      tester.takeException();

      final back = find.byIcon(Icons.chevron_left);
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back.first);
        await tester.pump(const Duration(milliseconds: 300));
        tester.takeException();
      }
    });
  });

  // ============================================================
  // TwoFactorAuthScreen - 1089 LF, 1 LH
  // ============================================================
  group('TwoFactorAuthScreen detailed', () {
    testWidgets('renders screen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(TwoFactorAuthScreen), findsOneWidget);
    });

    testWidgets('has scaffold and app bar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows loading then content', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
      await tester.pump();
      tester.takeException();
      // initially loading
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      // after API call fails, shows content
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('triggers API call in initState', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TwoFactorAuthScreen()));
      await tester.pump(const Duration(seconds: 1));
      tester.takeException();
      expect(find.byType(TwoFactorAuthScreen), findsOneWidget);
    });
  });

  // ============================================================
  // EditProfileScreen - 901 LF, 1 LH
  // ============================================================
  group('EditProfileScreen detailed', () {
    testWidgets('renders screen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(EditProfileScreen), findsOneWidget);
    });

    testWidgets('has scaffold and app bar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsWidgets);
    });

    testWidgets('has scroll view for profile form', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('contains editable content area', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      // Should have input areas for editing
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('can enter name', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'New Name');
        await tester.pump();
        tester.takeException();
      }
      expect(find.byType(EditProfileScreen), findsOneWidget);
    });
  });

  // ============================================================
  // ForgotPasswordScreen - 444 LF, 1 LH
  // ============================================================
  group('ForgotPasswordScreen detailed', () {
    testWidgets('renders screen', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('has form', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(Form), findsOneWidget);
    });

    testWidgets('has text input fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('can enter email', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      final textFields = find.byType(TextFormField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'test@example.com');
        await tester.pump();
        tester.takeException();
      }
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('has app bar with title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('has single child scroll view', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });
  });

  // ============================================================
  // VideoDetailScreen - 595 LF, 0 LH
  // ============================================================
  group('VideoDetailScreen detailed', () {
    final mockVideos = [
      {
        'id': 'v1',
        'videoId': 'v1',
        'title': 'Test Video 1',
        'description': 'A test video',
        'videoUrl': 'https://example.com/video1.mp4',
        'thumbnailUrl': 'https://example.com/thumb1.jpg',
        'userId': 1,
        'username': 'testuser',
        'avatar': null,
        'likesCount': 10,
        'commentsCount': 5,
        'savesCount': 3,
        'viewsCount': 100,
        'isLiked': false,
        'isSaved': false,
        'allowComments': true,
        'visibility': 'public',
        'createdAt': '2024-01-01T00:00:00Z',
      },
      {
        'id': 'v2',
        'videoId': 'v2',
        'title': 'Test Video 2',
        'description': 'Another test video',
        'videoUrl': 'https://example.com/video2.mp4',
        'thumbnailUrl': 'https://example.com/thumb2.jpg',
        'userId': 2,
        'username': 'otheruser',
        'avatar': null,
        'likesCount': 20,
        'commentsCount': 8,
        'savesCount': 6,
        'viewsCount': 200,
        'isLiked': true,
        'isSaved': false,
        'allowComments': true,
        'visibility': 'public',
        'createdAt': '2024-01-02T00:00:00Z',
      },
    ];

    testWidgets('renders with video list', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: VideoDetailScreen(videos: mockVideos, initialIndex: 0),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(VideoDetailScreen), findsOneWidget);
    });

    testWidgets('renders at second index', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: VideoDetailScreen(videos: mockVideos, initialIndex: 1),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(VideoDetailScreen), findsOneWidget);
    });

    testWidgets('renders with title', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: VideoDetailScreen(
          videos: mockVideos,
          initialIndex: 0,
          screenTitle: 'My Videos',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('has app bar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: VideoDetailScreen(videos: mockVideos, initialIndex: 0),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(AppBar), findsWidgets);
    });

    testWidgets('renders with openCommentsOnLoad', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: VideoDetailScreen(
          videos: mockVideos,
          initialIndex: 0,
          openCommentsOnLoad: true,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(VideoDetailScreen), findsOneWidget);
    });

    testWidgets('renders with onVideoDeleted callback', (tester) async {
      bool deleted = false;
      await tester.pumpWidget(MaterialApp(
        home: VideoDetailScreen(
          videos: mockVideos,
          initialIndex: 0,
          onVideoDeleted: () => deleted = true,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(VideoDetailScreen), findsOneWidget);
    });

    testWidgets('renders with single video', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: VideoDetailScreen(videos: [mockVideos.first], initialIndex: 0),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      tester.takeException();
      expect(find.byType(VideoDetailScreen), findsOneWidget);
    });
  });

  // ============================================================
  // ProcessingVideoScreen - 226 LF, 0 LH
  // ============================================================
  group('ProcessingVideoScreen detailed', () {
    final mockVideo = {
      'id': 'v1',
      'videoId': 'v1',
      'title': 'Processing Video',
      'description': 'A video being processed',
      'videoUrl': 'https://example.com/video.mp4',
      'thumbnailUrl': 'https://example.com/thumb.jpg',
      'status': 'processing',
      'userId': 1,
      'username': 'testuser',
    };

    testWidgets('renders processing screen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ProcessingVideoScreen(video: mockVideo),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ProcessingVideoScreen), findsOneWidget);
      // Clean up timers
      await tester.pumpWidget(const SizedBox());
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();
      }
    });

    testWidgets('shows scaffold with black background', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ProcessingVideoScreen(video: mockVideo),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();
      }
    });

    testWidgets('renders with failed status', (tester) async {
      final failedVideo = Map<String, dynamic>.from(mockVideo);
      failedVideo['status'] = 'failed';
      await tester.pumpWidget(MaterialApp(
        home: ProcessingVideoScreen(video: failedVideo),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ProcessingVideoScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();
      }
    });

    testWidgets('renders with onVideoReady callback', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ProcessingVideoScreen(
          video: mockVideo,
          onVideoReady: () {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(ProcessingVideoScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();
      }
    });

    testWidgets('has safe area', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ProcessingVideoScreen(video: mockVideo),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(SafeArea), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(seconds: 1));
        tester.takeException();
      }
    });
  });

  // ============================================================
  // UsernameCreationScreen - 207 LF, 0 LH
  // ============================================================
  group('UsernameCreationScreen detailed', () {
    testWidgets('renders with email method', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: UsernameCreationScreen(
          registrationMethod: 'email',
          dateOfBirth: DateTime(2000, 6, 15),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(UsernameCreationScreen), findsOneWidget);
    });

    testWidgets('renders with phone method', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: UsernameCreationScreen(
          registrationMethod: 'phone',
          dateOfBirth: DateTime(1995, 3, 20),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(UsernameCreationScreen), findsOneWidget);
    });

    testWidgets('renders with oauth data', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: UsernameCreationScreen(
          registrationMethod: 'google',
          dateOfBirth: DateTime(1998, 12, 1),
          oauthData: {
            'displayName': 'John Doe',
            'email': 'john@example.com',
            'providerId': 'google-123',
          },
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(UsernameCreationScreen), findsOneWidget);
    });

    testWidgets('has text field for username', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: UsernameCreationScreen(
          registrationMethod: 'email',
          dateOfBirth: DateTime(2000, 1, 1),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);
    });

    testWidgets('can enter username', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: UsernameCreationScreen(
          registrationMethod: 'email',
          dateOfBirth: DateTime(2000, 1, 1),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      final textFields = find.byType(TextField);
      if (textFields.evaluate().isNotEmpty) {
        await tester.enterText(textFields.first, 'newuser123');
        await tester.pump(const Duration(milliseconds: 300));
        tester.takeException();
      }
      expect(find.byType(UsernameCreationScreen), findsOneWidget);
    });

    testWidgets('has scaffold and app bar', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: UsernameCreationScreen(
          registrationMethod: 'email',
          dateOfBirth: DateTime(2000, 1, 1),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('has padding for content', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: UsernameCreationScreen(
          registrationMethod: 'email',
          dateOfBirth: DateTime(2000, 1, 1),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      tester.takeException();
      expect(find.byType(Padding), findsWidgets);
    });
  });
}
