import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/fcm_service.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal(ApiService());
  factory AuthService() => _instance;

  final ApiService _apiService;
  AuthService._internal(this._apiService);

  final _storage = const FlutterSecureStorage();
  
  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  bool _isLoggedIn = false;
  Map<String, dynamic>? _user;
  String? _username;
  String? _fullName;
  int? _userId;
  String? _email;
  String? _phoneNumber;
  String? _authProvider;
  String? _avatarUrl;
  String? _token; // ignore: unused_field

  bool get isLoggedIn => _isLoggedIn;
  String? get username => _username;
  String? get fullName => _fullName;
  Map<String, dynamic>? get user => _user;
  String? get avatarUrl => _avatarUrl;
  String? get bio => _user?['bio'] as String?;
  int? get userId => _userId;
  String? get phoneNumber => _phoneNumber;
  String? get email => _email;
  String? get authProvider => _authProvider;

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
    _fullName = userData['fullName'];
    _userId = userData['id'];
    _email = userData['email'];
    _phoneNumber = userData['phoneNumber'];
    _authProvider = userData['authProvider'];
    _avatarUrl = userData['avatar'];
    _isLoggedIn = true;

    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'username', value: _username);
    await _storage.write(key: 'fullName', value: _fullName ?? '');
    await _storage.write(key: 'userId', value: _userId.toString());
    await _storage.write(key: 'email', value: _email);
    await _storage.write(key: 'phoneNumber', value: _phoneNumber ?? '');
    await _storage.write(key: 'authProvider', value: _authProvider ?? '');
    await _storage.write(key: 'avatarUrl', value: _avatarUrl ?? '');
    
    // Save user data to SharedPreferences for bio
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', json.encode(userData));
    
    print('Login successful - notifying ${_loginListeners.length} listeners');
    
    // Register FCM token for push notifications
    try {
      final fcmRegistered = await FcmService().registerToken();
      print('FCM token registration: ${fcmRegistered ? 'SUCCESS' : 'FAILED'}');
    } catch (e) {
      print('Failed to register FCM token: $e');
    }
    
    // Notify all login listeners with error handling
    int listenerIndex = 0;
    for (var listener in List.from(_loginListeners)) { // Create copy to avoid modification during iteration
      try {
        print('   Calling listener #$listenerIndex...');
        listener();
        print('   ✅ Listener #$listenerIndex completed');
      } catch (e, stackTrace) {
        print('Error calling login listener #$listenerIndex: $e');
        print('   Stack trace: $stackTrace');
      }
      listenerIndex++;
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
    _fullName = null;
    _userId = null;
    _email = null;
    _phoneNumber = null;
    _authProvider = null;
    _avatarUrl = null;
    _isLoggedIn = false;

    // Clear secure storage
    await _storage.deleteAll();
    
    print('Logging out - clearing all cached data');
    print('Logout complete - isLoggedIn: $_isLoggedIn');
    
    // Notify all listeners with error handling
    print('Notifying ${_logoutListeners.length} logout listeners');
    for (var listener in List.from(_logoutListeners)) { // Create copy to avoid modification during iteration
      try {
        listener();
      } catch (e) {
        print('Error calling logout listener: $e');
      }
    }
  }

  Future<bool> tryAutoLogin() async {
    final token = await _storage.read(key: 'token');
    final username = await _storage.read(key: 'username');
    final fullName = await _storage.read(key: 'fullName');
    final userId = await _storage.read(key: 'userId');
    final email = await _storage.read(key: 'email');
    final avatarUrl = await _storage.read(key: 'avatarUrl');
    final phoneNumber = await _storage.read(key: 'phoneNumber');
    final authProvider = await _storage.read(key: 'authProvider');
    
    // Try to load user data with bio
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user');

    if (token != null && username != null && userId != null && email != null) {
      _username = username;
      _fullName = (fullName != null && fullName.isNotEmpty) ? fullName : null;
      _userId = int.tryParse(userId);
      _email = email;
      _avatarUrl = avatarUrl;
      _phoneNumber = phoneNumber;
      _authProvider = authProvider;
      _isLoggedIn = true;
      _token = token;

      if (userJson != null) {
        _user = json.decode(userJson);
      } else {
        _user = {
          'username': username,
          'id': _userId,
          'email': email,
          'avatar': avatarUrl,
          'phoneNumber': phoneNumber,
          'authProvider': authProvider,
        };
      }
      
      print('Auto-login successful - notifying ${_loginListeners.length} listeners');
      
      // Register FCM token for push notifications
      try {
        final fcmRegistered = await FcmService().registerToken();
        print('FCM token registration after auto-login: ${fcmRegistered ? 'SUCCESS' : 'FAILED'}');
      } catch (e) {
        print('Failed to register FCM token: $e');
      }
      
      // Notify all login listeners with error handling
      for (var listener in List.from(_loginListeners)) {
        try {
          listener();
        } catch (e) {
          print('Error calling login listener: $e');
        }
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
    
    print('Bio updated in AuthService: $bio');
  }

  /// Update display name (fullName) in local storage and memory
  Future<void> updateFullName(String? fullName) async {
    _fullName = fullName;
    await _storage.write(key: 'fullName', value: fullName ?? '');
    
    if (_user != null) {
      _user!['fullName'] = fullName;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', json.encode(_user));
    }
    
    print('FullName updated in AuthService: $fullName');
  }

  /// Update username in local storage and memory
  Future<void> updateUsername(String username) async {
    _username = username;
    await _storage.write(key: 'username', value: username);
    
    // Update in-memory user object
    if (_user != null) {
      _user!['username'] = username;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', json.encode(_user));
    }
    
    print('Username updated in AuthService: $username');
  }

  /// Update phone number in local storage and memory
  Future<void> updatePhoneNumber(String? phoneNumber) async {
    await _storage.write(key: 'phoneNumber', value: phoneNumber);
    
    // Update in-memory user object
    if (_user != null) {
      _user!['phoneNumber'] = phoneNumber;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', json.encode(_user));
    }
    
    print('PhoneNumber updated in AuthService: $phoneNumber');
  }

  // ============= Google OAuth Methods =============

  /// Sign in with Google and get ID token
  /// Returns GoogleSignInAuthentication containing idToken
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      // Sign out first to ensure user can choose account
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return GoogleSignInResult.cancelled();
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        return GoogleSignInResult.error('Failed to get Google ID token');
      }

      return GoogleSignInResult.success(
        idToken: idToken,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        providerId: account.id,
      );
    } catch (e) {
      print('Google Sign-In error: $e');
      return GoogleSignInResult.error(e.toString());
    }
  }

  /// Authenticate with backend using Google ID token
  /// Returns: {needsRegistration: bool, user?: userData, token?: jwt}
  Future<Map<String, dynamic>> googleAuthWithBackend(String idToken) async {
    try {
      final response = await _apiService.post(
        '/auth/oauth/google',
        body: {
          'provider': 'google',
          'idToken': idToken,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Google auth failed');
      }
    } catch (e) {
      print('Backend Google auth error: $e');
      rethrow;
    }
  }

  /// Complete OAuth registration with additional user data
  Future<Map<String, dynamic>> completeOAuthRegistration({
    required String provider,
    required String providerId,
    required String email,
    required String username,
    required DateTime dateOfBirth,
    String? fullName,
    String? avatar,
  }) async {
    try {
      final response = await _apiService.post(
        '/auth/register/oauth',
        body: {
          'provider': provider,
          'providerId': providerId,
          'email': email,
          'username': username,
          'dateOfBirth': dateOfBirth.toIso8601String(),
          if (fullName != null) 'fullName': fullName,
          if (avatar != null) 'avatar': avatar,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      print('OAuth registration error: $e');
      rethrow;
    }
  }

  /// Register with email and password (TikTok-style)
  Future<Map<String, dynamic>> emailRegister({
    required String email,
    required String password,
    required String username,
    required DateTime dateOfBirth,
    String? fullName,
  }) async {
    try {
      final response = await _apiService.post(
        '/auth/register/email',
        body: {
          'email': email,
          'password': password,
          'username': username,
          'dateOfBirth': dateOfBirth.toIso8601String(),
          if (fullName != null) 'fullName': fullName,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      print('Email registration error: $e');
      rethrow;
    }
  }

  /// Check if username is available
  Future<bool> checkUsernameAvailable(String username) async {
    try {
      final response = await _apiService.get('/auth/check-username?username=$username');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['available'] == true;
      }
      return false;
    } catch (e) {
      print('Check username error: $e');
      return false;
    }
  }

  /// Check if email is available
  Future<bool> checkEmailAvailable(String email) async {
    try {
      final response = await _apiService.get('/auth/check-email?email=$email');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['available'] == true;
      }
      return false;
    } catch (e) {
      print('Check email error: $e');
      return false;
    }
  }

  /// Sign out from Google
  Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Google sign out error: $e');
    }
  }
}

/// Result class for Google Sign-In
class GoogleSignInResult {
  final bool success;
  final bool cancelled;
  final String? error;
  final String? idToken;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? providerId;

  GoogleSignInResult._({
    required this.success,
    this.cancelled = false,
    this.error,
    this.idToken,
    this.email,
    this.displayName,
    this.photoUrl,
    this.providerId,
  });

  factory GoogleSignInResult.success({
    required String idToken,
    required String email,
    String? displayName,
    String? photoUrl,
    required String providerId,
  }) {
    return GoogleSignInResult._(
      success: true,
      idToken: idToken,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      providerId: providerId,
    );
  }

  factory GoogleSignInResult.cancelled() {
    return GoogleSignInResult._(success: false, cancelled: true);
  }

  factory GoogleSignInResult.error(String message) {
    return GoogleSignInResult._(success: false, error: message);
  }
}
