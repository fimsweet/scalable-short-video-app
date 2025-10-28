import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Add this import for VoidCallback

class AuthService {
  static final AuthService _instance = AuthService._internal(ApiService());
  factory AuthService() => _instance;

  final ApiService _apiService;
  AuthService._internal(this._apiService);

  final _storage = const FlutterSecureStorage();

  bool _isLoggedIn = false;
  Map<String, dynamic>? _user;
  String? _username;
  int? _userId;
  String? _email;
  String? _avatarUrl;
  String? _token;

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  Map<String, dynamic>? get user => _user;
  String? get avatarUrl => _avatarUrl;

  Future<void> login(Map<String, dynamic> userData, String token) async {
    _user = userData;
    _username = userData['username'];
    _userId = userData['id'];
    _email = userData['email'];
    _avatarUrl = userData['avatar'];
    _isLoggedIn = true;

    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'username', value: _username);
    await _storage.write(key: 'userId', value: _userId.toString());
    await _storage.write(key: 'email', value: _email);
    await _storage.write(key: 'avatarUrl', value: _avatarUrl ?? '');
  }

  // Add callback list
  final List<VoidCallback> _logoutListeners = [];

  void addLogoutListener(VoidCallback listener) {
    _logoutListeners.add(listener);
  }

  void removeLogoutListener(VoidCallback listener) {
    _logoutListeners.remove(listener);
  }

  Future<void> logout() async {
    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    
    // Clear all in-memory state
    _token = null;
    _user = null;
    _username = null;
    _userId = null;
    _email = null;
    _avatarUrl = null;
    _isLoggedIn = false;

    // Clear secure storage
    await _storage.deleteAll();
    
    print('🚪 Logging out - clearing all cached data');
    print('✅ Logout complete - isLoggedIn: $_isLoggedIn');
    
    // Notify all listeners
    for (var listener in _logoutListeners) {
      listener();
    }
  }

  Future<bool> tryAutoLogin() async {
    final token = await _storage.read(key: 'token');
    final username = await _storage.read(key: 'username');
    final userId = await _storage.read(key: 'userId');
    final email = await _storage.read(key: 'email');
    final avatarUrl = await _storage.read(key: 'avatarUrl');

    if (token != null && username != null && userId != null && email != null) {
      _username = username;
      _userId = int.tryParse(userId);
      _email = email;
      _avatarUrl = avatarUrl;
      _isLoggedIn = true;

      _user = {
        'username': username,
        'id': _userId,
        'email': email,
        'avatar': avatarUrl,
      };
    }
    return _isLoggedIn;
  }

  Future<void> updateAvatar(String? avatarPath) async {
    _avatarUrl = avatarPath;
    await _storage.write(key: 'avatarUrl', value: _avatarUrl ?? '');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }
}
