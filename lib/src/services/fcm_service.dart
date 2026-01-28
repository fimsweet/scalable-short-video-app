import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📩 Handling a background message: ${message.messageId}');
  print('📩 Message data: ${message.data}');
  if (message.notification != null) {
    print('📩 Message notification: ${message.notification?.title}');
  }
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  
  String? _fcmToken;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  
  // Stream controller for login alerts
  final StreamController<RemoteMessage> _loginAlertController = 
      StreamController<RemoteMessage>.broadcast();
  
  Stream<RemoteMessage> get loginAlertStream => _loginAlertController.stream;
  
  String? get fcmToken => _fcmToken;

  /// Initialize push notifications
  Future<void> initialize() async {
    try {
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Request permission
      await requestPermission();
      
      // Get FCM token
      await _getToken();
      
      // Listen for token refresh
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
        print('🔄 FCM Token refreshed');
        _fcmToken = newToken;
        _sendTokenToServer(newToken);
      });
      
      // Handle foreground messages
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle when app is opened from notification
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      
      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
      
      print('✅ Push notifications initialized');
    } catch (e) {
      print('❌ Error initializing push notifications: $e');
    }
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final authorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      
      print('📱 Notification permission: ${settings.authorizationStatus}');
      return authorized;
    } catch (e) {
      print('❌ Error requesting permission: $e');
      return false;
    }
  }

  /// Get FCM token
  Future<String?> _getToken() async {
    try {
      // For web, you need to pass vapidKey
      if (kIsWeb) {
        // _fcmToken = await _messaging.getToken(vapidKey: 'YOUR_VAPID_KEY');
        print('⚠️ Web FCM not configured');
        return null;
      }
      
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        print('📱 FCM Token: ${_fcmToken!.substring(0, 20)}...');
      }
      return _fcmToken;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Send FCM token to server
  Future<bool> _sendTokenToServer(String token) async {
    try {
      final authToken = await _authService.getToken();
      if (authToken == null) {
        print('⚠️ No auth token available');
        return false;
      }
      
      final response = await _apiService.post(
        '/sessions/fcm-token',
        body: {'fcmToken': token},
        headers: {'Authorization': 'Bearer $authToken'},
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ FCM token sent to server');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error sending FCM token to server: $e');
      return false;
    }
  }

  /// Register FCM token after login
  Future<bool> registerToken() async {
    if (_fcmToken == null) {
      await _getToken();
    }
    
    if (_fcmToken != null) {
      return await _sendTokenToServer(_fcmToken!);
    }
    return false;
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📩 Foreground message received');
    print('📩 Data: ${message.data}');
    
    if (message.notification != null) {
      print('📩 Title: ${message.notification?.title}');
      print('📩 Body: ${message.notification?.body}');
    }
    
    // Check if this is a login alert
    if (message.data['type'] == 'login_alert') {
      _loginAlertController.add(message);
    }
  }

  /// Handle when user taps on notification
  void _handleNotificationTap(RemoteMessage message) {
    print('📱 Notification tapped');
    print('📱 Data: ${message.data}');
    
    // Handle navigation based on notification type
    final type = message.data['type'];
    
    switch (type) {
      case 'login_alert':
        // Navigation will be handled by the app
        print('📱 Should navigate to sessions screen');
        break;
      default:
        print('📱 Unknown notification type: $type');
    }
  }

  /// Toggle login alerts
  Future<bool> toggleLoginAlerts(bool enabled) async {
    try {
      final authToken = await _authService.getToken();
      if (authToken == null) {
        print('⚠️ No auth token available');
        return false;
      }
      
      final response = await _apiService.post(
        '/sessions/login-alerts',
        body: {'enabled': enabled},
        headers: {'Authorization': 'Bearer $authToken'},
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Login alerts ${enabled ? 'enabled' : 'disabled'}');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error toggling login alerts: $e');
      return false;
    }
  }

  /// Get login alerts status
  Future<bool> getLoginAlertsStatus() async {
    try {
      final authToken = await _authService.getToken();
      if (authToken == null) {
        print('⚠️ No auth token available');
        return true; // Default to enabled
      }
      
      final response = await _apiService.get(
        '/sessions/login-alerts',
        headers: {'Authorization': 'Bearer $authToken'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['enabled'] ?? true;
        }
      }
      return true; // Default to enabled
    } catch (e) {
      print('❌ Error getting login alerts status: $e');
      return true;
    }
  }

  /// Dispose resources
  void dispose() {
    _foregroundSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    _loginAlertController.close();
  }
}
