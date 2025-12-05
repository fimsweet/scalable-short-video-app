import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

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
  String? get bio => _user?['bio'] as String?;
  int? get userId => _userId;

  /// Get current user data as a Map
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_user != null) return _user;
    
    // Try to load from storage
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');
    if (userJson != null) {
      return json.decode(userJson);
    }
    
    // Build from individual fields
    if (_userId != null) {
      return {
        'id': _userId,
        'username': _username,
        'email': _email,
        'avatar': _avatarUrl,
      };
    }
    
    return null;
  }

  // Add callback list
  final List<VoidCallback> _logoutListeners = [];
  final List<VoidCallback> _loginListeners = []; // ADD THIS

  void addLogoutListener(VoidCallback listener) {
    _logoutListeners.add(listener);
  }

  void removeLogoutListener(VoidCallback listener) {
    _logoutListeners.remove(listener);
  }

  // ADD THESE METHODS
  void addLoginListener(VoidCallback listener) {
    _loginListeners.add(listener);
  }

  void removeLoginListener(VoidCallback listener) {
    _loginListeners.remove(listener);
  }

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
    
    // Save user data to SharedPreferences for bio
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', json.encode(userData));
    
    print('✅ Login successful - notifying ${_loginListeners.length} listeners');
    
    // Notify all login listeners with error handling
    for (var listener in List.from(_loginListeners)) { // Create copy to avoid modification during iteration
      try {
        listener();
      } catch (e) {
        print('❌ Error calling login listener: $e');
      }
    }
  }

  Future<void> logout() async {
    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await prefs.remove('user');
    
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
    
    // Notify all listeners with error handling
    print('📢 Notifying ${_logoutListeners.length} logout listeners');
    for (var listener in List.from(_logoutListeners)) { // Create copy to avoid modification during iteration
      try {
        listener();
      } catch (e) {
        print('❌ Error calling logout listener: $e');
      }
    }
  }

  Future<bool> tryAutoLogin() async {
    final token = await _storage.read(key: 'token');
    final username = await _storage.read(key: 'username');
    final userId = await _storage.read(key: 'userId');
    final email = await _storage.read(key: 'email');
    final avatarUrl = await _storage.read(key: 'avatarUrl');
    
    // Try to load user data with bio
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    if (token != null && username != null && userId != null && email != null) {
      _username = username;
      _userId = int.tryParse(userId);
      _email = email;
      _avatarUrl = avatarUrl;
      _isLoggedIn = true;

      if (userJson != null) {
        _user = json.decode(userJson);
      } else {
        _user = {
          'username': username,
          'id': _userId,
          'email': email,
          'avatar': avatarUrl,
        };
      }
    }
    return _isLoggedIn;
  }

  Future<void> updateAvatar(String? avatarPath) async {
    _avatarUrl = avatarPath;
    await _storage.write(key: 'avatarUrl', value: _avatarUrl ?? '');
    
    // Update user object and save to SharedPreferences
    if (_user != null) {
      _user!['avatar'] = avatarPath;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', json.encode(_user));
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<void> updateBio(String bio) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update in-memory user object
    if (_user != null) {
      _user!['bio'] = bio;
      await prefs.setString('user', json.encode(_user));
    } else {
      // Create user object if doesn't exist
      _user = {
        'username': _username,
        'id': _userId,
        'email': _email,
        'avatar': _avatarUrl,
        'bio': bio,
      };
      await prefs.setString('user', json.encode(_user));
    }
    
    print('✅ Bio updated in AuthService: $bio');
  }
}
