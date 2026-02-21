import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'theme_service.dart';
import 'locale_service.dart';
import 'in_app_notification_service.dart';
import 'message_service.dart';
import 'notification_service.dart';

/// Flutter local notifications plugin instance (shared with background handler)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Android notification channel for high importance messages
const AndroidNotificationChannel highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Thông báo quan trọng',
  description: 'Kênh thông báo cho tin nhắn và thông báo quan trọng',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  print('Message data: ${message.data}');
  if (message.notification != null) {
    print('Message notification: ${message.notification?.title}');
  }
  // Background messages with notification payload are automatically displayed by the system.
  // Data-only messages need manual handling — but for our case, we send notification+data.
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final InAppNotificationService _inAppNotifService = InAppNotificationService();
  
  String? _fcmToken;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  
  // Stream controller for login alerts
  final StreamController<RemoteMessage> _loginAlertController = 
      StreamController<RemoteMessage>.broadcast();
  
  // Stream controller for notification taps (to navigate to chat)
  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Buffer for notification tap data when no listener is attached yet
  // (e.g. app opened from terminated state before MainScreen subscribes)
  Map<String, dynamic>? _pendingNotificationData;
  
  Stream<RemoteMessage> get loginAlertStream => _loginAlertController.stream;
  Stream<Map<String, dynamic>> get notificationTapStream => _notificationTapController.stream;
  
  /// Consume any pending notification data that was buffered before a listener attached.
  /// Returns the data and clears it, or null if nothing pending.
  Map<String, dynamic>? consumePendingNotification() {
    final data = _pendingNotificationData;
    _pendingNotificationData = null;
    return data;
  }
  
  String? get fcmToken => _fcmToken;

  /// Check if system notification permission is currently granted
  Future<bool> isSystemPermissionGranted() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Open the Android system notification settings for this app
  /// Uses platform channel to invoke Android Intent
  Future<void> openNotificationSettings() async {
    try {
      const platform = MethodChannel('com.app.notification_settings');
      await platform.invokeMethod('openNotificationSettings');
    } catch (e) {
      debugPrint('Error opening notification settings: $e');
      // Fallback: try requesting permission again (works on first-time)
      await requestPermission();
    }
  }

  /// Initialize push notifications (without requesting permission)
  Future<void> initialize() async {
    try {
      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Initialize flutter_local_notifications for foreground display
      await _initializeLocalNotifications();
      
      // Create the Android notification channel
      await _createNotificationChannel();
      
      // Set foreground notification presentation options (iOS)
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Check if permission was already granted
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Permission already granted, get token (simple retrieval, no deletion)
        // We intentionally do NOT call deleteToken() here because:
        //  1. User might not be logged in yet → can't send token to server
        //  2. deleteToken() invalidates the token the server knows about
        //  3. This creates a gap where push notifications don't work
        // The force-refresh happens in registerToken() after login.
        _fcmToken = await _messaging.getToken();
        if (_fcmToken != null) {
          print('[FCM] Init token (${_fcmToken!.length} chars): ${_fcmToken!.substring(0, 20)}...');
        }
      }
      
      // Listen for token refresh
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
        print('[FCM] Token refreshed (${newToken.length} chars): ${newToken.substring(0, 30)}...');
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
      
      print('Push notifications initialized');
    } catch (e) {
      print('Error initializing push notifications: $e');
    }
  }

  /// Initialize flutter_local_notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
    
    await flutterLocalNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Create the high importance notification channel on Android
  Future<void> _createNotificationChannel() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(highImportanceChannel);
    }
  }

  /// Handle local notification tap (foreground notifications)
  void _onNotificationTapped(NotificationResponse response) {
    print('[FCM] === LOCAL NOTIFICATION TAPPED (foreground) ===');
    print('[FCM] Action ID: ${response.id}');
    print('[FCM] Payload: ${response.payload}');
    print('[FCM] ActionId: ${response.actionId}');
    print('[FCM] NotificationResponseType: ${response.notificationResponseType}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        print('[FCM] Parsed data: $data');
        _handleNotificationNavigation(data);
      } catch (e) {
        print('[FCM] Error parsing notification payload: $e');
      }
    } else {
      print('[FCM] No payload in local notification tap');
    }
  }

  /// Show a local notification (for foreground messages)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    
    // Use notification title/body if available, otherwise construct from data
    final title = notification?.title ?? data['title'] ?? 'Thông báo mới';
    final body = notification?.body ?? data['body'] ?? '';
    
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Thông báo quan trọng',
      channelDescription: 'Kênh thông báo cho tin nhắn và thông báo quan trọng',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
    
    // Use message hashCode as notification ID to avoid duplicates
    final notificationId = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;
    
    await flutterLocalNotificationsPlugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(data),
    );
  }

  /// Show custom dialog before requesting permission
  /// Call this after user has been using the app for a while or after login
  Future<bool> requestPermissionWithDialog(BuildContext context) async {
    final themeService = ThemeService();
    final localeService = LocaleService();
    
    // Check if permission was already requested
    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Already have permission
      await _getToken();
      return true;
    }
    
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      // User already denied, don't show dialog again
      return false;
    }
    
    // Show custom dialog explaining why we need notification permission
    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: themeService.backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.notifications_active_rounded,
              color: ThemeService.accentColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                localeService.get('notification_permission_title'),
                style: TextStyle(
                  color: themeService.textPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          localeService.get('notification_permission_message'),
          style: TextStyle(
            color: themeService.textSecondaryColor,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              localeService.get('not_now'),
              style: TextStyle(
                color: themeService.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeService.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              localeService.get('enable_notifications'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    
    if (shouldRequest == true) {
      return await requestPermission();
    }
    
    return false;
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
      
      print('Notification permission: ${settings.authorizationStatus}');
      return authorized;
    } catch (e) {
      print('Error requesting permission: $e');
      return false;
    }
  }

  /// Get FCM token — simple retrieval without deletion
  Future<String?> _getToken() async {
    try {
      if (kIsWeb) {
        print('Web FCM not configured');
        return null;
      }
      
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        print('[FCM] Got token (${_fcmToken!.length} chars): ${_fcmToken!.substring(0, 20)}...');
      } else {
        print('[FCM] WARNING: getToken() returned null');
      }
      return _fcmToken;
    } catch (e) {
      print('[FCM] Error getting FCM token: $e');
      return null;
    }
  }

  /// Force refresh FCM token — deletes old token and gets a fresh one.
  /// This fixes "registration-token-not-registered" errors that happen
  /// on emulators and after APK reinstalls where old tokens become stale.
  /// Should ONLY be called during registerToken() (after login), not during initialize().
  Future<String?> _forceRefreshToken() async {
    try {
      if (kIsWeb) return null;
      
      // Delete old (potentially stale) token
      try {
        await _messaging.deleteToken();
        print('[FCM] Old token deleted, requesting fresh token...');
      } catch (e) {
        print('[FCM] deleteToken failed (ok if first time): $e');
      }
      
      // Give Firebase enough time to process deletion and register new token
      await Future.delayed(const Duration(seconds: 2));
      
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        print('[FCM] Fresh token (${_fcmToken!.length} chars): ${_fcmToken!.substring(0, 30)}...${_fcmToken!.substring(_fcmToken!.length - 15)}');
      } else {
        print('[FCM] WARNING: getToken() returned null after refresh');
      }
      return _fcmToken;
    } catch (e) {
      print('[FCM] Error during force refresh: $e');
      // Fallback to simple retrieval
      return _getToken();
    }
  }

  /// Send FCM token to server
  Future<bool> _sendTokenToServer(String token) async {
    try {
      final authToken = await _authService.getToken();
      if (authToken == null) {
        print('[FCM] No auth token available, cannot register FCM token');
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
          print('[FCM] FCM token registered successfully on server');
          return true;
        } else {
          print('[FCM] Server rejected FCM token update: ${data['message']}');
          return false;
        }
      }
      print('[FCM] FCM token registration failed with status: ${response.statusCode}');
      return false;
    } catch (e) {
      print('[FCM] Error sending FCM token to server: $e');
      return false;
    }
  }

  /// Register FCM token after login.
  /// 
  /// Strategy:
  /// 1. First try the current cached token (fast path — works if token is still valid)
  /// 2. If no token or send fails, force-refresh (deleteToken + getToken) and retry
  /// 
  /// This avoids unnecessary token churn while still fixing stale tokens.
  Future<bool> registerToken() async {
    // Step 1: Try current token first (fast path)
    if (_fcmToken == null) {
      await _getToken();
    }
    
    if (_fcmToken != null) {
      final success = await _sendTokenToServer(_fcmToken!);
      if (success) {
        print('[FCM] Token registered (fast path)');
        return true;
      }
      print('[FCM] Fast path failed, force-refreshing token...');
    }
    
    // Step 2: Force refresh — delete old token, get fresh one
    await _forceRefreshToken();
    
    if (_fcmToken != null) {
      final success = await _sendTokenToServer(_fcmToken!);
      if (success) {
        print('[FCM] Token registered (after force-refresh)');
        return true;
      }
      print('[FCM] WARNING: FCM token registration failed even after force-refresh!');
      return false;
    }
    
    print('[FCM] No FCM token available from Firebase');
    return false;
  }

  /// Unregister FCM token on logout (prevents stale push to wrong user)
  Future<void> unregisterToken() async {
    try {
      final authToken = await _authService.getToken();
      if (authToken == null) {
        print('[FCM] No auth token, cannot unregister FCM token');
        return;
      }
      
      final response = await _apiService.post(
        '/sessions/clear-fcm-token',
        body: {},
        headers: {'Authorization': 'Bearer $authToken'},
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[FCM] FCM token unregistered from server');
      } else {
        print('[FCM] Failed to unregister FCM token: ${response.statusCode}');
      }
    } catch (e) {
      print('[FCM] Error unregistering FCM token: $e');
    }
    _fcmToken = null;
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('[FCM] Foreground message received');
    print('[FCM] Data: ${message.data}');
    
    if (message.notification != null) {
      print('[FCM] Title: ${message.notification?.title}');
      print('[FCM] Body: ${message.notification?.body}');
    }
    
    final type = message.data['type'];
    
    // Check if this is a login alert
    if (type == 'login_alert') {
      _loginAlertController.add(message);
      return;
    }
    
    // Immediately refresh badge counts for all notification types
    // This ensures the profile badge updates in real-time
    NotificationService().refreshBadgeCounts();
    
    // Route to in-app notification banner (TikTok-style)
    _showInAppNotificationBanner(message);
  }

  /// Sanitize message body for notification display.
  /// Converts [IMAGE:...], [STACKED_IMAGE:...], [VIDEO_SHARE:...] tags to friendly text.
  String _sanitizeMessageBody(String body, String senderName) {
    if (body.isEmpty) return body;
    
    if (body.contains('[STACKED_IMAGE:')) {
      final textPart = body.replaceAll(RegExp(r'\n?\[STACKED_IMAGE:[^\]]+\]'), '').trim();
      return textPart.isNotEmpty ? textPart : '$senderName đã gửi nhiều ảnh 📷';
    }
    
    if (body.contains('[IMAGE:')) {
      final textPart = body.replaceAll(RegExp(r'\n?\[IMAGE:[^\]]+\]'), '').trim();
      return textPart.isNotEmpty ? textPart : '$senderName đã gửi một ảnh 📷';
    }
    
    if (body.contains('[VIDEO_SHARE:')) {
      return '$senderName đã chia sẻ một video 🎬';
    }
    
    return body;
  }

  /// Route a foreground FCM message to the in-app notification banner system.
  /// Fetches sender avatar and creates an InAppNotification with proper type mapping.
  Future<void> _showInAppNotificationBanner(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;
    final type = data['type'] as String?;
    
    if (type == null) {
      // Fallback: show system notification for unknown types
      _showLocalNotification(message);
      return;
    }

    // Map FCM type to InAppNotificationType
    InAppNotificationType? notifType;
    switch (type) {
      case 'like':
        notifType = InAppNotificationType.like;
        break;
      case 'comment':
        notifType = InAppNotificationType.comment;
        break;
      case 'follow':
        notifType = InAppNotificationType.follow;
        break;
      case 'mention':
      case 'reply':
        notifType = InAppNotificationType.mention;
        break;
      case 'message':
        notifType = InAppNotificationType.message;
        break;
      default:
        // Unknown type — use system notification
        _showLocalNotification(message);
        return;
    }

    // Extract sender info
    final senderId = data['senderId'] ?? data['userId'] ?? '';
    final senderName = data['senderName'] ?? 
        data['likerName'] ?? 
        data['commenterName'] ?? 
        data['followerName'] ?? '';
    
    // Fetch sender avatar and resolve display name
    String? avatarUrl;
    String resolvedName = senderName;
    if (senderId.isNotEmpty) {
      try {
        final userInfo = await _apiService.getUserById(senderId);
        if (userInfo != null) {
          if (userInfo['avatar'] != null) {
            final url = _apiService.getAvatarUrl(userInfo['avatar']);
            if (url.isNotEmpty) avatarUrl = url;
          }
          // For messages: use nickname > fullName > senderName
          if (type == 'message') {
            try {
              final settings = await MessageService().getConversationSettings(senderId);
              final nickname = settings['nickname'] as String?;
              if (nickname != null && nickname.isNotEmpty) {
                resolvedName = nickname;
              } else if (userInfo['fullName'] != null && (userInfo['fullName'] as String).isNotEmpty) {
                resolvedName = userInfo['fullName'];
              }
            } catch (_) {
              if (userInfo['fullName'] != null && (userInfo['fullName'] as String).isNotEmpty) {
                resolvedName = userInfo['fullName'];
              }
            }
          } else {
            // For other notification types: use fullName > senderName
            if (userInfo['fullName'] != null && (userInfo['fullName'] as String).isNotEmpty) {
              resolvedName = userInfo['fullName'];
            }
          }
        }
      } catch (_) {}
    }

    final title = type == 'message' ? '💬 $resolvedName' : (notification?.title ?? resolvedName);
    String body = notification?.body ?? data['body'] ?? '';
    
    // Sanitize message body for display (convert image/video tags to friendly text)
    if (type == 'message') {
      body = _sanitizeMessageBody(body, resolvedName);
    }

    final inAppNotif = InAppNotification(
      type: notifType,
      title: title,
      body: body,
      avatarUrl: avatarUrl,
      senderId: senderId,
      senderName: resolvedName,
      videoId: data['videoId'],
      commentId: data['commentId'],
      conversationId: data['conversationId'],
      rawData: Map<String, dynamic>.from(data),
    );

    final shown = await _inAppNotifService.showNotification(inAppNotif);
    if (!shown) {
      print('[FCM] In-app notification suppressed, not showing system notification');
    }
  }

  /// Handle when user taps on notification (from background/terminated state)
  void _handleNotificationTap(RemoteMessage message) {
    print('[FCM] === NOTIFICATION TAPPED (background/terminated) ===');
    print('[FCM] Message ID: ${message.messageId}');
    print('[FCM] Data: ${message.data}');
    print('[FCM] Notification: ${message.notification?.title} / ${message.notification?.body}');
    _handleNotificationNavigation(message.data);
  }

  /// Common navigation handler for both FCM tap and local notification tap
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type'];
    print('[FCM] _handleNotificationNavigation — type: $type, data: $data');
    
    Map<String, dynamic>? navData;
    
    switch (type) {
      case 'login_alert':
        print('[FCM] Should navigate to sessions screen');
        break;
      case 'message':
        navData = {
          'type': 'message',
          'conversationId': data['conversationId'],
          'senderId': data['senderId'],
          'senderName': data['senderName'],
        };
        break;
      case 'like':
      case 'comment':
      case 'follow':
        navData = {
          'type': type,
          'videoId': data['videoId'],
          'userId': data['userId'],
        };
        break;
      default:
        print('[FCM] Unknown notification type: $type');
    }
    
    if (navData != null) {
      print('[FCM] navData created: $navData');
      print('[FCM] hasListener: ${_notificationTapController.hasListener}');
      if (_notificationTapController.hasListener) {
        _notificationTapController.add(navData);
        print('[FCM] Event emitted to notificationTapStream');
      } else {
        // No listener yet (app just starting from terminated state)
        // Buffer the data so MainScreen can pick it up
        print('[FCM] No listener — buffering data for later');
        _pendingNotificationData = navData;
      }
    } else {
      print('[FCM] No navData generated for type: $type');
    }
  }

  /// Toggle login alerts
  Future<bool> toggleLoginAlerts(bool enabled) async {
    try {
      final authToken = await _authService.getToken();
      if (authToken == null) {
        print('No auth token available');
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
          print('Login alerts ${enabled ? 'enabled' : 'disabled'}');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error toggling login alerts: $e');
      return false;
    }
  }

  /// Get login alerts status
  Future<bool> getLoginAlertsStatus() async {
    try {
      final authToken = await _authService.getToken();
      if (authToken == null) {
        print('No auth token available');
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
      print('Error getting login alerts status: $e');
      return true;
    }
  }

  /// Clear all notifications and badge when app is opened
  Future<void> clearNotifications() async {
    // Clear all displayed notifications
    await flutterLocalNotificationsPlugin.cancelAll();
    // Clear badge count on iOS
    await _messaging.setAutoInitEnabled(true);
  }

  /// Dispose resources
  void dispose() {
    _foregroundSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    _loginAlertController.close();
    _notificationTapController.close();
  }
}
