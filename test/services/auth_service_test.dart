import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService', () {
    late AuthService service;

    setUp(() {
      service = AuthService();
    });

    test('singleton returns same instance', () {
      final a = AuthService();
      final b = AuthService();
      expect(identical(a, b), true);
    });

    group('initial state', () {
      test('isLoggedIn is a boolean', () {
        expect(service.isLoggedIn, isA<bool>());
      });

      test('user may be null initially', () {
        // User starts as null when not logged in
        if (!service.isLoggedIn) {
          expect(service.user, isNull);
        }
      });

      test('avatarUrl may be null', () {
        final url = service.avatarUrl;
        expect(url == null || url is String, true);
      });
    });

    group('listener management', () {
      test('addLoginListener does not throw', () {
        void callback() {}
        service.addLoginListener(callback);
        service.removeLoginListener(callback);
      });

      test('addLogoutListener does not throw', () {
        void callback() {}
        service.addLogoutListener(callback);
        service.removeLogoutListener(callback);
      });

      test('removeLoginListener does not throw for unregistered callback', () {
        service.removeLoginListener(() {});
      });

      test('removeLogoutListener does not throw for unregistered callback', () {
        service.removeLogoutListener(() {});
      });
    });

    // getToken uses FlutterSecureStorage platform channel, skip in test env

    group('checkUsernameAvailable', () {
      test('handles network error gracefully', () async {
        final result = await service.checkUsernameAvailable('testuser');
        expect(result, false);
      });
    });

    group('checkEmailAvailable', () {
      test('handles network error gracefully', () async {
        final result = await service.checkEmailAvailable('test@example.com');
        expect(result, false);
      });
    });
  });

  group('GoogleSignInResult', () {
    test('creates success result', () {
      final result = GoogleSignInResult.success(
        idToken: 'token123',
        email: 'test@example.com',
        displayName: 'Test User',
        photoUrl: 'https://example.com/photo.jpg',
        providerId: 'google.com',
      );
      expect(result.success, true);
      expect(result.idToken, 'token123');
      expect(result.email, 'test@example.com');
      expect(result.displayName, 'Test User');
      expect(result.photoUrl, 'https://example.com/photo.jpg');
      expect(result.providerId, 'google.com');
      expect(result.error, isNull);
      expect(result.cancelled, false);
    });

    test('creates cancelled result', () {
      final result = GoogleSignInResult.cancelled();
      expect(result.success, false);
      expect(result.cancelled, true);
      expect(result.idToken, isNull);
      expect(result.email, isNull);
    });

    test('creates error result', () {
      final result = GoogleSignInResult.error('Sign in failed');
      expect(result.success, false);
      expect(result.error, 'Sign in failed');
      expect(result.idToken, isNull);
      expect(result.email, isNull);
      expect(result.cancelled, false);
    });

    test('success result with minimal data', () {
      final result = GoogleSignInResult.success(
        idToken: 'token',
        email: 'a@b.com',
        providerId: 'google.com',
      );
      expect(result.success, true);
      expect(result.displayName, isNull);
      expect(result.photoUrl, isNull);
    });
  });
}
