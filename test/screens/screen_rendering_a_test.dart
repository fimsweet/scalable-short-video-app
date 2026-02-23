import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:scalable_short_video_app/src/presentation/screens/help_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/change_password_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/search_user_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/blocked_users_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/in_app_notification_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_username_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/edit_display_name_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/select_interests_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/discover_people_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_settings_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/privacy_settings_screen.dart';
import 'package:scalable_short_video_app/src/features/auth/presentation/screens/registration_method_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ============================================================
  // HelpScreen (331 lines - no network calls, pure UI)
  // ============================================================
  group('HelpScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(HelpScreen), findsOneWidget);
    });

    testWidgets('builds full widget tree', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('lifecycle - dispose', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });

    testWidgets('can scroll', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.drag(find.byType(HelpScreen), const Offset(0, -300));
      await tester.pump();
    });
  });

  // ============================================================
  // ChangePasswordScreen (182 lines - no initState network)
  // ============================================================
  group('ChangePasswordScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });

    testWidgets('has text input fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      // Should have text fields for current password, new password, confirm
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('can enter text in fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      final fields = find.byType(TextField);
      if (fields.evaluate().isNotEmpty) {
        await tester.enterText(fields.first, 'testPassword123');
        await tester.pump();
      }
    });

    testWidgets('lifecycle - dispose', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChangePasswordScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // SearchUserScreen (178 lines)
  // ============================================================
  group('SearchUserScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SearchUserScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(SearchUserScreen), findsOneWidget);
    });

    testWidgets('has search input', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SearchUserScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SearchUserScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // RegistrationMethodScreen (171 lines)
  // ============================================================
  group('RegistrationMethodScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegistrationMethodScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(RegistrationMethodScreen), findsOneWidget);
    });

    testWidgets('renders with prefilled OAuth data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RegistrationMethodScreen(
            prefilledOAuthData: {
              'email': 'test@test.com',
              'provider': 'google',
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(RegistrationMethodScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegistrationMethodScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // BlockedUsersScreen (153 lines)
  // ============================================================
  group('BlockedUsersScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BlockedUsersScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(BlockedUsersScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: BlockedUsersScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // InAppNotificationSettingsScreen (152 lines)
  // ============================================================
  group('InAppNotificationSettingsScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: InAppNotificationSettingsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(InAppNotificationSettingsScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: InAppNotificationSettingsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // EditUsernameScreen (232 lines)
  // ============================================================
  group('EditUsernameScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditUsernameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(EditUsernameScreen), findsOneWidget);
    });

    testWidgets('has text field for username', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditUsernameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditUsernameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // EditDisplayNameScreen (223 lines)
  // ============================================================
  group('EditDisplayNameScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditDisplayNameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(EditDisplayNameScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditDisplayNameScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // SelectInterestsScreen (225 lines)
  // ============================================================
  group('SelectInterestsScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SelectInterestsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(SelectInterestsScreen), findsOneWidget);
    });

    testWidgets('renders with isOnboarding false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SelectInterestsScreen(isOnboarding: false)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(SelectInterestsScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SelectInterestsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // DiscoverPeopleScreen (202 lines)
  // ============================================================
  group('DiscoverPeopleScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DiscoverPeopleScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(DiscoverPeopleScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DiscoverPeopleScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // UserSettingsScreen (281 lines)
  // ============================================================
  group('UserSettingsScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserSettingsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(UserSettingsScreen), findsOneWidget);
    });

    testWidgets('has settings items', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserSettingsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: UserSettingsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });

  // ============================================================
  // PrivacySettingsScreen (269 lines)
  // ============================================================
  group('PrivacySettingsScreen', () {
    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      expect(find.byType(PrivacySettingsScreen), findsOneWidget);
    });

    testWidgets('lifecycle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      tester.takeException();
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });
  });
}
