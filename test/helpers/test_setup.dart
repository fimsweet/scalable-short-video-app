import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

/// Mock implementation of FlutterSecureStorage platform interface.
/// Uses MockPlatformInterfaceMixin to bypass platform interface token verification.
class MockSecureStorage extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterSecureStoragePlatform {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    _store.clear();
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.from(_store);

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _store.containsKey(key);
}

/// Sets up common test environment with mocked storage and SharedPreferences.
Future<void> setupLoggedInState() async {
  // Mock SharedPreferences
  SharedPreferences.setMockInitialValues({});

  // Mock FlutterSecureStorage
  FlutterSecureStoragePlatform.instance = MockSecureStorage();

  // Log in the AuthService singleton
  await AuthService().login(
    {
      'id': 1,
      'username': 'testuser',
      'email': 'test@example.com',
      'fullName': 'Test User',
      'avatar': null,
      'phoneNumber': '+1234567890',
      'authProvider': 'email',
      'bio': 'Test bio',
    },
    'fake-token-for-testing',
  );
}
