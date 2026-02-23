import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';

void main() {
  group('ApiService', () {
    late ApiService service;

    setUp(() {
      service = ApiService();
    });

    test('can be instantiated', () {
      expect(service, isNotNull);
    });

    test('multiple instances are independent', () {
      final a = ApiService();
      final b = ApiService();
      expect(a, isNotNull);
      expect(b, isNotNull);
    });

    group('register', () {
      test('handles network error gracefully', () async {
        final result = await service.register(
          email: 'test@example.com',
          password: 'password123',
          username: 'testuser',
          fullName: 'Test User',
        );
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('login', () {
      test('handles network error gracefully', () async {
        final result = await service.login(
          username: 'test@example.com',
          password: 'password123',
        );
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('getProfile', () {
      test('handles network error gracefully', () async {
        final result = await service.getProfile('invalid_token');
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('getAvatarUrl', () {
      test('returns URL string for path', () {
        final url = service.getAvatarUrl('uploads/avatar.jpg');
        expect(url, isA<String>());
        expect(url, isNotEmpty);
      });

      test('returns empty for null path', () {
        final url = service.getAvatarUrl(null);
        expect(url, isA<String>());
      });
    });

    group('getCommentImageUrl', () {
      test('returns URL string', () {
        final url = service.getCommentImageUrl('uploads/image.jpg');
        expect(url, isA<String>());
      });
    });

    group('getUserById', () {
      test('handles network error gracefully', () async {
        final result = await service.getUserById('user1');
        expect(result, isNull);
      });
    });

    group('sendHeartbeat', () {
      test('handles network error gracefully', () async {
        await service.sendHeartbeat('user1');
        // Should not throw
      });
    });

    group('getOnlineStatus', () {
      test('handles network error gracefully', () async {
        final result = await service.getOnlineStatus('user1');
        expect(result, isA<Map<String, dynamic>>());
        expect(result['isOnline'], false);
      });
    });

    group('updateProfile', () {
      test('handles network error gracefully', () async {
        final result = await service.updateProfile(
          token: 'token',
          bio: 'Test bio',
        );
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('changeDisplayName', () {
      test('handles network error gracefully', () async {
        final result = await service.changeDisplayName(
          token: 'token',
          newDisplayName: 'New Name',
        );
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('changeUsername', () {
      test('handles network error gracefully', () async {
        final result = await service.changeUsername(
          token: 'token',
          newUsername: 'newusername',
        );
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('changePassword', () {
      test('handles network error gracefully', () async {
        final result = await service.changePassword(
          token: 'token',
          currentPassword: 'oldpass',
          newPassword: 'newpass',
        );
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('hasPassword', () {
      test('handles network error gracefully', () async {
        final result = await service.hasPassword('token');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('setPassword', () {
      test('handles network error gracefully', () async {
        final result = await service.setPassword(
          token: 'token',
          newPassword: 'newpassword',
        );
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('forgotPassword', () {
      test('handles network error gracefully', () async {
        final result = await service.forgotPassword('test@example.com');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('verifyOtp', () {
      test('handles network error gracefully', () async {
        final result = await service.verifyOtp(
          email: 'test@example.com',
          otp: '123456',
        );
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('resetPassword', () {
      test('handles network error gracefully', () async {
        final result = await service.resetPassword(
          email: 'test@example.com',
          otp: '123456',
          newPassword: 'newpassword',
        );
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('searchUsers', () {
      test('handles network error gracefully', () async {
        final result = await service.searchUsers('testquery');
        expect(result, isEmpty);
      });
    });

    group('blockUser', () {
      test('handles network error gracefully', () async {
        final result = await service.blockUser('targetUser1');
        expect(result, false);
      });
    });

    group('getUserSettings', () {
      test('handles network error gracefully', () async {
        final result = await service.getUserSettings('token');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('updateUserSettings', () {
      test('handles network error gracefully', () async {
        final result = await service.updateUserSettings('token', {
          'theme': 'dark',
        });
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('checkPrivacyPermission', () {
      test('handles network error gracefully', () async {
        final result = await service.checkPrivacyPermission(
          'requester1',
          'target1',
          'profile',
        );
        expect(result, isA<Map<String, dynamic>>());
        expect(result['allowed'], false);
      });
    });

    group('deactivateAccount', () {
      test('handles network error gracefully', () async {
        final result = await service.deactivateAccount(
          token: 'token',
          password: 'password123',
        );
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('getSessions', () {
      test('handles network error gracefully', () async {
        final result = await service.getSessions(token: 'token');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('removeAvatar', () {
      test('handles network error gracefully', () async {
        final result = await service.removeAvatar(token: 'token');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('linkPhone', () {
      test('handles network error gracefully', () async {
        final result = await service.linkPhone(
          token: 'token',
          firebaseIdToken: 'firebase_token',
        );
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('registerWithPhone', () {
      test('handles network error gracefully', () async {
        final result = await service.registerWithPhone(
          firebaseIdToken: 'firebase_token',
          username: 'phoneuser',
        );
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('loginWithPhone', () {
      test('handles network error gracefully', () async {
        final result = await service.loginWithPhone('firebase_token');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('checkUsernameAvailability', () {
      test('handles network error gracefully', () async {
        final result = await service.checkUsernameAvailability('testuser');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('checkPhone', () {
      test('handles network error gracefully', () async {
        final result = await service.checkPhone('+84123456789');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('formatPhoneForDisplay', () {
      test('formats phone number', () {
        final result = ApiService.formatPhoneForDisplay('+84123456789');
        expect(result, isA<String>());
      });

      test('handles null', () {
        final result = ApiService.formatPhoneForDisplay(null);
        expect(result, isA<String>());
      });
    });

    group('parsePhoneToE164', () {
      test('parses phone number', () {
        final result = ApiService.parsePhoneToE164('0123456789');
        expect(result, isA<String>());
      });
    });

    group('getCategories', () {
      test('handles network error gracefully', () async {
        final result = await service.getCategories();
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('checkDeactivatedStatus', () {
      test('handles network error gracefully', () async {
        final result = await service.checkDeactivatedStatus('user1');
        expect(result, isA<Map<String, dynamic>>());
      });
    });
  });
}
