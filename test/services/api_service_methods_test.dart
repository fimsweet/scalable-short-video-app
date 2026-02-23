/// Comprehensive API service tests using runWithClient + MockClient.
/// Tests all 87 public methods of ApiService against mock HTTP responses.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import '../helpers/test_setup.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';

late ApiService _api;

http.Client _createApiMock() {
  return MockClient((request) async {
    final path = request.url.path;
    final method = request.method;
    final query = request.url.queryParameters;

    // Auth
    if (path == '/auth/register' && method == 'POST') {
      return http.Response(jsonEncode({'success': true, 'user': {'id': 1, 'username': 'newuser'}, 'token': 'tok'}), 201, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/register/phone' && method == 'POST') {
      return http.Response(jsonEncode({'success': true, 'user': {'id': 2}, 'token': 'tok'}), 201, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/login/phone' && method == 'POST') {
      return http.Response(jsonEncode({'success': true, 'user': {'id': 3}, 'token': 'tok'}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.startsWith('/auth/check-phone') && method == 'GET') {
      return http.Response(jsonEncode({'exists': false}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/login' && method == 'POST') {
      return http.Response(jsonEncode({'success': true, 'user': {'id': 1, 'username': 'testuser'}, 'token': 'tok'}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/profile' && method == 'GET') {
      return http.Response(jsonEncode({'id': 1, 'username': 'testuser', 'email': 'test@example.com'}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/account-info' && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'email': 'test@example.com', 'phone': '+1234567890', 'authProvider': 'email'}), 200, headers: {'content-type': 'application/json'});
    }

    // 2FA
    if (path == '/auth/2fa/settings' && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'enabled': false, 'methods': []}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/2fa/settings' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/2fa/send-otp' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/2fa/verify' && method == 'POST') {
      return http.Response(jsonEncode({'success': true, 'token': 'tok'}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/2fa/send-settings-otp' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/2fa/verify-settings' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/2fa/totp/setup' && method == 'POST') {
      return http.Response(jsonEncode({'success': true, 'secret': 'ABCD1234', 'qrCodeUrl': 'otpauth://totp/test'}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/2fa/totp/verify-setup' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // Email linking  
    if (path == '/auth/link/email/send-otp' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/link/email/verify' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // Phone linking
    if (path == '/auth/link/phone' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.startsWith('/auth/link/phone/check') && method == 'GET') {
      return http.Response(jsonEncode({'available': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/unlink/phone' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // Forgot password phone
    if (path.startsWith('/auth/forgot-password/check-phone') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'exists': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/auth/forgot-password/phone/reset' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // User profile
    if (path.startsWith('/users/id/') && method == 'GET') {
      return http.Response(jsonEncode({'id': 1, 'username': 'testuser', 'fullName': 'Test User', 'avatar': null, 'bio': 'Test bio'}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/heartbeat') && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/online-status') && method == 'GET') {
      return http.Response(jsonEncode({'isOnline': true, 'lastSeen': '2026-01-15T08:00:00Z'}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/profile' && method == 'PUT') {
      return http.Response(jsonEncode({'success': true, 'user': {'id': 1}}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/display-name-change-info' && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'changesRemaining': 2, 'nextChangeDate': null}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/change-display-name' && method == 'PUT') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/remove-display-name' && method == 'PUT') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/username-change-info' && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'changesRemaining': 1, 'nextChangeDate': null}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/change-username' && method == 'PUT') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // Password
    if (path == '/users/change-password' && method == 'PUT') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/has-password' && method == 'GET') {
      return http.Response(jsonEncode({'hasPassword': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/set-password' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // Avatar
    if (path == '/users/avatar' && method == 'DELETE') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // Deactivation
    if (path == '/users/deactivate' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/reactivate' && method == 'POST') {
      return http.Response(jsonEncode({'success': true, 'user': {'id': 1}, 'token': 'tok'}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.startsWith('/users/check-deactivated/') && method == 'GET') {
      return http.Response(jsonEncode({'isDeactivated': false}), 200, headers: {'content-type': 'application/json'});
    }

    // Sessions
    if (path == '/sessions' && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'sessions': [{'id': 1, 'deviceInfo': 'Chrome', 'ipAddress': '127.0.0.1', 'createdAt': '2026-01-15T08:00:00Z', 'isCurrent': true}]}), 200, headers: {'content-type': 'application/json'});
    }
    if (RegExp(r'/sessions/\d+').hasMatch(path) && method == 'DELETE') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/sessions/logout-others' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/sessions/logout-all' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // Password reset / OTP
    if (path == '/users/forgot-password' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/verify-otp' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/reset-password' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // Follows
    if (path.contains('/follows/followers-with-status/') && method == 'GET') {
      return http.Response(jsonEncode([{'id': 2, 'username': 'follower1', 'avatar': null, 'followStatus': 'accepted'}]), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/follows/following-with-status/') && method == 'GET') {
      return http.Response(jsonEncode([{'id': 3, 'username': 'following1', 'avatar': null, 'followStatus': 'accepted'}]), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/follows/followers/') && method == 'GET') {
      return http.Response(jsonEncode([{'id': 2, 'username': 'follower1'}]), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/follows/following/') && method == 'GET') {
      return http.Response(jsonEncode([{'id': 3, 'username': 'following1'}]), 200, headers: {'content-type': 'application/json'});
    }

    // Search
    if (path.startsWith('/users/check-username/') && method == 'GET') {
      return http.Response(jsonEncode({'available': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.startsWith('/users/search') && method == 'GET') {
      return http.Response(jsonEncode([{'id': 5, 'username': 'found_user'}]), 200, headers: {'content-type': 'application/json'});
    }

    // Blocking
    if (path.contains('/users/block/') && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/users/block/') && method == 'DELETE') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/users/blocked/') && path.contains('/check/') && method == 'GET') {
      return http.Response(jsonEncode({'isBlocked': false}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/users/blocked/') && method == 'GET') {
      return http.Response(jsonEncode([]), 200, headers: {'content-type': 'application/json'});
    }

    // Reports
    if (path == '/reports' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 201, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/reports/count/') && method == 'GET') {
      return http.Response(jsonEncode({'count': 0}), 200, headers: {'content-type': 'application/json'});
    }

    // Settings
    if (path == '/users/settings' && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'settings': {'accountPrivacy': 'public', 'showOnlineStatus': true, 'language': 'en'}}), 200, headers: {'content-type': 'application/json'});
    }
    if (path == '/users/settings' && method == 'PUT') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // Privacy
    if (path == '/users/privacy/check' && method == 'POST') {
      return http.Response(jsonEncode({'allowed': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/users/privacy/') && method == 'GET') {
      return http.Response(jsonEncode({'accountPrivacy': 'public'}), 200, headers: {'content-type': 'application/json'});
    }

    // Categories & interests
    if (path == '/categories' && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'categories': [{'id': 1, 'name': 'Music'}, {'id': 2, 'name': 'Comedy'}]}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/interests/check') && method == 'GET') {
      return http.Response(jsonEncode({'hasSelected': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/interests') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'interests': [1, 2]}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/interests') && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // Recommendations
    if (path.contains('/recommendation/for-you/') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'videos': []}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/recommendation/trending') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'videos': []}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/recommendation/category/') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'videos': []}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/categories/video/') && path.contains('/with-ai-info') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'categories': []}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/categories/video/') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'categories': []}), 200, headers: {'content-type': 'application/json'});
    }

    // Watch history
    if (path == '/watch-history' && method == 'POST') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/watch-history/') && path.contains('/interests') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'interests': []}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/watch-history/') && path.contains('/stats') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'totalWatchTime': 3600}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/watch-history/') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'history': []}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/watch-history/') && method == 'DELETE') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }

    // Activity history
    if (path.contains('/activity-history/') && path.contains('/count/') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'count': 10}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/activity-history/') && path.contains('/all') && method == 'DELETE') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/activity-history/') && path.contains('/type/') && method == 'DELETE') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/activity-history/') && path.contains('/range/') && method == 'DELETE') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/activity-history/') && method == 'DELETE') {
      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    }
    if (path.contains('/activity-history/') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'activities': [{'id': 1, 'action': 'login', 'timestamp': '2026-01-15T08:00:00Z'}], 'total': 1}), 200, headers: {'content-type': 'application/json'});
    }

    // Analytics
    if (path.contains('/analytics/') && method == 'GET') {
      return http.Response(jsonEncode({'success': true, 'totalViews': 1000, 'totalLikes': 200, 'totalComments': 50}), 200, headers: {'content-type': 'application/json'});
    }

    // Default
    return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = MockSecureStorage();
  });

  setUp(() async {
    _api = ApiService();
    await setupLoggedInState();
  });

  // ===== Auth Methods =====
  group('ApiService Auth', () {
    test('register succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.register(
          username: 'newuser',
          email: 'new@example.com',
          password: 'pass123',
          fullName: 'New User',
        );
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('register with optional params', () async {
      await http.runWithClient(() async {
        final result = await _api.register(
          username: 'user2',
          email: 'u2@example.com',
          password: 'pass',
          phoneNumber: '+1234567890',
          dateOfBirth: '2000-01-01',
          gender: 'male',
          language: 'en',
        );
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('registerWithPhone succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.registerWithPhone(
          firebaseIdToken: 'firebase-token',
          username: 'phoneuser',
        );
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('loginWithPhone succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.loginWithPhone('firebase-token');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('checkPhone succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.checkPhone('+1234567890');
        expect(result['exists'], isFalse);
      }, _createApiMock);
    });

    test('login succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.login(
          username: 'testuser',
          password: 'pass123',
        );
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('login with deviceInfo', () async {
      await http.runWithClient(() async {
        final result = await _api.login(
          username: 'testuser',
          password: 'pass123',
          deviceInfo: {'os': 'Android', 'model': 'Pixel 6'},
        );
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getProfile succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getProfile('test-token');
        expect(result, isA<Map<String, dynamic>>());
      }, _createApiMock);
    });

    test('getAccountInfo succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getAccountInfo('test-token');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== 2FA Methods =====
  group('ApiService 2FA', () {
    test('get2FASettings succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.get2FASettings('test-token');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('update2FASettings succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.update2FASettings('test-token', true, ['email']);
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('send2FAOtp succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.send2FAOtp(1, 'email');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('verify2FAOtp succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.verify2FAOtp(1, '123456', 'email');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('send2FASettingsOtp succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.send2FASettingsOtp('test-token', 'email');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('verify2FASettings succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.verify2FASettings('test-token', '123456', 'email', true, ['email']);
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('setupTotp succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.setupTotp('test-token');
        expect(result['success'], isTrue);
        expect(result['secret'], 'ABCD1234');
      }, _createApiMock);
    });

    test('verifyTotpSetup succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.verifyTotpSetup('test-token', '123456', 'ABCD1234');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== User Profile Methods =====
  group('ApiService User Profile', () {
    test('getUserById succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getUserById('1');
        expect(result, isNotNull);
        expect(result!['username'], 'testuser');
      }, _createApiMock);
    });

    test('sendHeartbeat succeeds', () async {
      await http.runWithClient(() async {
        await _api.sendHeartbeat('1');
        // No exception means success
      }, _createApiMock);
    });

    test('getOnlineStatus succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getOnlineStatus('1');
        expect(result['isOnline'], isTrue);
      }, _createApiMock);
    });

    test('getOnlineStatus with requesterId', () async {
      await http.runWithClient(() async {
        final result = await _api.getOnlineStatus('1', requesterId: '2');
        expect(result['isOnline'], isTrue);
      }, _createApiMock);
    });

    test('updateProfile succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.updateProfile(
          token: 'test-token',
          bio: 'Updated bio',
          gender: 'female',
          dateOfBirth: '1999-05-15',
          fullName: 'Updated Name',
        );
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getDisplayNameChangeInfo succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getDisplayNameChangeInfo(token: 'test-token');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('changeDisplayName succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.changeDisplayName(token: 'test-token', newDisplayName: 'New Name');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('removeDisplayName succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.removeDisplayName(token: 'test-token');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getUsernameChangeInfo succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getUsernameChangeInfo(token: 'test-token');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('changeUsername succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.changeUsername(token: 'test-token', newUsername: 'newuser');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Password Methods =====
  group('ApiService Password', () {
    test('changePassword succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.changePassword(token: 'tok', currentPassword: 'old', newPassword: 'new');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('hasPassword succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.hasPassword('tok');
        expect(result['hasPassword'], isTrue);
      }, _createApiMock);
    });

    test('setPassword succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.setPassword(token: 'tok', newPassword: 'newpass');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('forgotPassword succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.forgotPassword('test@example.com');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('verifyOtp succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.verifyOtp(email: 'test@example.com', otp: '123456');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('resetPassword succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.resetPassword(email: 'test@example.com', otp: '123456', newPassword: 'newpass');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Avatar Methods =====
  group('ApiService Avatar', () {
    test('getAvatarUrl returns correct url', () {
      final url = _api.getAvatarUrl('/uploads/avatar.jpg');
      expect(url.contains('avatar.jpg'), isTrue);
    });

    test('getAvatarUrl handles null', () {
      final url = _api.getAvatarUrl(null);
      expect(url, isA<String>());
    });

    test('getCommentImageUrl returns correct url', () {
      final url = _api.getCommentImageUrl('/uploads/img.jpg');
      expect(url.contains('img.jpg'), isTrue);
    });

    test('removeAvatar succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.removeAvatar(token: 'tok');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Phone Methods =====
  group('ApiService Phone', () {
    test('linkPhone succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.linkPhone(token: 'tok', firebaseIdToken: 'firebase-tok');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('checkPhoneForLink succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.checkPhoneForLink(token: 'tok', phone: '+1234567890');
        expect(result['available'], isTrue);
      }, _createApiMock);
    });

    test('unlinkPhone succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.unlinkPhone(token: 'tok', password: 'secret');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('checkPhoneForPasswordReset succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.checkPhoneForPasswordReset('+1234567890');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('resetPasswordWithPhone succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.resetPasswordWithPhone(phone: '+1234567890', firebaseIdToken: 'tok', newPassword: 'newpass');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Account Methods =====
  group('ApiService Account', () {
    test('deactivateAccount succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.deactivateAccount(token: 'tok', password: 'pass');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('reactivateAccount succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.reactivateAccount(email: 'test@example.com', password: 'pass');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('reactivateAccount with username', () async {
      await http.runWithClient(() async {
        final result = await _api.reactivateAccount(username: 'testuser', password: 'pass');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('checkDeactivatedStatus succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.checkDeactivatedStatus('testuser');
        expect(result['isDeactivated'], isFalse);
      }, _createApiMock);
    });
  });

  // ===== Session Methods =====
  group('ApiService Sessions', () {
    test('getSessions succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getSessions(token: 'tok');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('logoutSession succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.logoutSession(token: 'tok', sessionId: 1);
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('logoutOtherSessions succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.logoutOtherSessions(token: 'tok');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('logoutAllSessions succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.logoutAllSessions(token: 'tok');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Follow Methods =====
  group('ApiService Follows', () {
    test('getFollowers succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getFollowers('1');
        expect(result, isA<List>());
      }, _createApiMock);
    });

    test('getFollowing succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getFollowing('1');
        expect(result, isA<List>());
      }, _createApiMock);
    });

    test('getFollowersWithStatus succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getFollowersWithStatus('1');
        expect(result, isA<List>());
      }, _createApiMock);
    });

    test('getFollowersWithStatus with pagination', () async {
      await http.runWithClient(() async {
        final result = await _api.getFollowersWithStatus('1', limit: 50, offset: 10);
        expect(result, isA<List>());
      }, _createApiMock);
    });

    test('getFollowingWithStatus succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getFollowingWithStatus('1');
        expect(result, isA<List>());
      }, _createApiMock);
    });
  });

  // ===== Search & Username =====
  group('ApiService Search', () {
    test('checkUsernameAvailability succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.checkUsernameAvailability('newuser');
        expect(result['available'], isTrue);
      }, _createApiMock);
    });

    test('searchUsers succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.searchUsers('test');
        expect(result, isA<List>());
      }, _createApiMock);
    });
  });

  // ===== Blocking =====
  group('ApiService Blocking', () {
    test('blockUser succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.blockUser('5');
        expect(result, isTrue);
      }, _createApiMock);
    });

    test('blockUser with currentUserId', () async {
      await http.runWithClient(() async {
        final result = await _api.blockUser('5', currentUserId: '1');
        expect(result, isTrue);
      }, _createApiMock);
    });

    test('unblockUser succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.unblockUser('5');
        expect(result, isTrue);
      }, _createApiMock);
    });

    test('getBlockedUsers succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getBlockedUsers('1');
        expect(result, isA<List>());
      }, _createApiMock);
    });

    test('isUserBlocked succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.isUserBlocked('1', '5');
        expect(result, isFalse);
      }, _createApiMock);
    });
  });

  // ===== Reports =====
  group('ApiService Reports', () {
    test('reportUser succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.reportUser(
          reporterId: '1',
          reportedUserId: '5',
          reason: 'spam',
        );
        expect(result, isTrue);
      }, _createApiMock);
    });

    test('reportUser with description', () async {
      await http.runWithClient(() async {
        final result = await _api.reportUser(
          reporterId: '1',
          reportedUserId: '5',
          reason: 'harassment',
          description: 'Detailed description',
        );
        expect(result, isTrue);
      }, _createApiMock);
    });

    test('getReportCount succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getReportCount('1');
        expect(result, 0);
      }, _createApiMock);
    });
  });

  // ===== Settings =====
  group('ApiService Settings', () {
    test('getUserSettings succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getUserSettings('tok');
        expect(result, isA<Map<String, dynamic>>());
      }, _createApiMock);
    });

    test('updateUserSettings succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.updateUserSettings('tok', {'showOnlineStatus': false});
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Privacy =====
  group('ApiService Privacy', () {
    test('checkPrivacyPermission succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.checkPrivacyPermission('1', '5', 'view');
        expect(result['allowed'], isTrue);
      }, _createApiMock);
    });

    test('getPrivacySettings succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getPrivacySettings('1');
        expect(result, isA<Map<String, dynamic>>());
      }, _createApiMock);
    });
  });

  // ===== Email Linking =====
  group('ApiService Email Linking', () {
    test('sendLinkEmailOtp succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.sendLinkEmailOtp('tok', 'new@example.com');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('verifyAndLinkEmail succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.verifyAndLinkEmail('tok', 'new@example.com', '123456');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('verifyAndLinkEmail with password', () async {
      await http.runWithClient(() async {
        final result = await _api.verifyAndLinkEmail('tok', 'new@example.com', '123456', password: 'pass');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Categories & Interests =====
  group('ApiService Categories', () {
    test('getCategories succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getCategories();
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getUserInterests succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getUserInterests(1);
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('hasSelectedInterests succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.hasSelectedInterests(1);
        expect(result, isA<bool>());
      }, _createApiMock);
    });

    test('setUserInterests succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.setUserInterests(1, [1, 2], 'tok');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Recommendations =====
  group('ApiService Recommendations', () {
    test('getRecommendedVideos succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getRecommendedVideos(1);
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getRecommendedVideos with limit', () async {
      await http.runWithClient(() async {
        final result = await _api.getRecommendedVideos(1, limit: 10);
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getTrendingVideos succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getTrendingVideos();
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getVideosByCategory succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getVideosByCategory(1);
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getVideoCategories succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getVideoCategories('vid-1');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getVideoCategoriesWithAiInfo succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getVideoCategoriesWithAiInfo('vid-1');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Watch History =====
  group('ApiService Watch History', () {
    test('recordWatchTime succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.recordWatchTime(
          userId: '1',
          videoId: 'vid-1',
          watchDuration: 30,
          videoDuration: 60,
        );
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getWatchHistory succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getWatchHistory('1');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getWatchHistory with pagination', () async {
      await http.runWithClient(() async {
        final result = await _api.getWatchHistory('1', limit: 20, offset: 10);
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getWatchTimeInterests succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getWatchTimeInterests('1');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getWatchStats succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getWatchStats('1');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('clearWatchHistory succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.clearWatchHistory('1');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Activity History =====
  group('ApiService Activity History', () {
    test('getActivityHistory succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getActivityHistory('1');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getActivityHistory with filter', () async {
      await http.runWithClient(() async {
        final result = await _api.getActivityHistory('1', page: 2, limit: 10, filter: 'login');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('deleteActivity succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.deleteActivity('1', 1);
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('deleteAllActivities succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.deleteAllActivities('1');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('deleteActivitiesByType succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.deleteActivitiesByType('1', 'login');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('deleteActivitiesByTimeRange succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.deleteActivitiesByTimeRange('1', '7d');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('deleteActivitiesByTimeRange with filter', () async {
      await http.runWithClient(() async {
        final result = await _api.deleteActivitiesByTimeRange('1', '30d', filter: 'login');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getActivityCount succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getActivityCount('1', '7d');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });

    test('getActivityCount with filter', () async {
      await http.runWithClient(() async {
        final result = await _api.getActivityCount('1', '30d', filter: 'login');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Analytics =====
  group('ApiService Analytics', () {
    test('getAnalytics succeeds', () async {
      await http.runWithClient(() async {
        final result = await _api.getAnalytics('1');
        expect(result['success'], isTrue);
      }, _createApiMock);
    });
  });

  // ===== Utility Methods =====
  group('ApiService Utility', () {
    test('formatPhoneForDisplay formats correctly', () {
      final result = ApiService.formatPhoneForDisplay('+84901234567');
      expect(result, isNotEmpty);
    });

    test('formatPhoneForDisplay handles null', () {
      final result = ApiService.formatPhoneForDisplay(null);
      expect(result, isA<String>());
    });

    test('parsePhoneToE164 formats correctly', () {
      final result = ApiService.parsePhoneToE164('0901234567');
      expect(result.startsWith('+'), isTrue);
    });

    test('generic get method', () async {
      await http.runWithClient(() async {
        final response = await _api.get('/users/settings');
        expect(response.statusCode, 200);
      }, _createApiMock);
    });

    test('generic post method', () async {
      await http.runWithClient(() async {
        final response = await _api.post('/auth/login', body: {'username': 'test', 'password': 'test'});
        expect(response.statusCode, 200);
      }, _createApiMock);
    });
  });
}
