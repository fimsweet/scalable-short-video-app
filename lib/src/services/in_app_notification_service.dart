import 'dart:async';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'api_service.dart';

/// Types of in-app notifications
enum InAppNotificationType {
  like,
  comment,
  follow,
  mention,
  message,
}

/// Data model for an in-app notification
class InAppNotification {
  final InAppNotificationType type;
  final String title;
  final String body;
  final String? avatarUrl;
  final String senderId;
  final String senderName;
  final String? videoId;
  final String? commentId;
  final String? conversationId;
  final Map<String, dynamic> rawData;
  final DateTime timestamp;

  InAppNotification({
    required this.type,
    required this.title,
    required this.body,
    this.avatarUrl,
    required this.senderId,
    required this.senderName,
    this.videoId,
    this.commentId,
    this.conversationId,
    required this.rawData,
  }) : timestamp = DateTime.now();
}

/// Service managing in-app notification banners with smart suppression,
/// rate limiting, and context-aware behavior — inspired by TikTok/Instagram.
class InAppNotificationService {
  static final InAppNotificationService _instance =
      InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  /// Stream controller that emits notifications to the overlay widget
  final StreamController<InAppNotification> _notificationController =
      StreamController<InAppNotification>.broadcast();

  Stream<InAppNotification> get notificationStream =>
      _notificationController.stream;

  /// Stream for notification banner taps — MainScreen listens to this
  /// so it can navigate with proper tab switching / back stack.
  final StreamController<InAppNotification> _tapController =
      StreamController<InAppNotification>.broadcast();

  Stream<InAppNotification> get notificationTapStream => _tapController.stream;

  /// Emit a tap event so MainScreen can handle navigation
  void emitTap(InAppNotification notification) {
    _tapController.add(notification);
  }

  // ── Context Suppression State ──────────────────────────────

  /// Currently viewing this video's detail/comments (suppress like/comment for it)
  String? _activeVideoId;

  /// Currently in inbox/conversation list screen (suppress message notifications)
  bool _isInInboxScreen = false;

  /// Currently chatting with this user (suppress messages from them)
  String? _activeChatUserId;

  // ── Rate Limiting ──────────────────────────────────────────

  /// Rolling window: tracks recent notification timestamps per type+source
  /// Key format: "type:senderId" or "type:videoId"
  final Map<String, Queue<DateTime>> _recentNotifications = {};

  /// Max notifications per type+source in the time window
  static const int _maxPerWindow = 3;

  /// Time window for rate limiting
  static const Duration _rateLimitWindow = Duration(minutes: 2);

  /// Global cooldown between showing any banner (prevent spam)
  DateTime? _lastBannerShown;
  static const Duration _globalCooldown = Duration(seconds: 2);

  // ── User Preferences (cached) ──────────────────────────────

  Map<String, bool> _preferences = {};
  DateTime? _preferencesLoadedAt;
  static const Duration _preferencesCacheDuration = Duration(minutes: 5);

  // ── Public API: Context Tracking ───────────────────────────

  /// Call when user opens/views a specific video (detail or comments)
  void setActiveVideo(String? videoId) {
    _activeVideoId = videoId;
  }

  /// Call when user enters/leaves the inbox screen
  void setInInboxScreen(bool isInInbox) {
    _isInInboxScreen = isInInbox;
  }

  /// Call when user enters/leaves a chat with a specific user
  void setActiveChatUser(String? userId) {
    _activeChatUserId = userId;
  }

  // ── Public API: Show Notification ──────────────────────────

  /// Main entry point: evaluate and potentially show an in-app notification.
  /// Returns true if the notification was shown, false if suppressed.
  Future<bool> showNotification(InAppNotification notification) async {
    final currentUserId = _authService.user?['id']?.toString();
    if (currentUserId == null) return false;

    // Don't notify yourself
    if (notification.senderId == currentUserId) return false;

    // 1. Check user preferences
    if (!await _isTypeEnabled(notification.type)) {
      debugPrint('[InAppNotif] Suppressed: user disabled ${notification.type}');
      return false;
    }

    // 2. Context suppression
    if (_shouldSuppressByContext(notification)) {
      debugPrint('[InAppNotif] Suppressed by context: ${notification.type}');
      return false;
    }

    // 3. Rate limiting
    if (_isRateLimited(notification)) {
      debugPrint('[InAppNotif] Rate limited: ${notification.type} from ${notification.senderId}');
      return false;
    }

    // 4. Global cooldown
    if (_lastBannerShown != null &&
        DateTime.now().difference(_lastBannerShown!) < _globalCooldown) {
      // Queue it with a slight delay instead of dropping
      Future.delayed(_globalCooldown, () {
        if (!_notificationController.isClosed) {
          _notificationController.add(notification);
          _lastBannerShown = DateTime.now();
        }
      });
      return true;
    }

    // 5. Emit to overlay
    _notificationController.add(notification);
    _lastBannerShown = DateTime.now();
    _recordNotification(notification);

    return true;
  }

  // ── Context Suppression Logic ──────────────────────────────

  bool _shouldSuppressByContext(InAppNotification notification) {
    switch (notification.type) {
      case InAppNotificationType.like:
      case InAppNotificationType.comment:
      case InAppNotificationType.mention:
        // Suppress if user is viewing this specific video or its comments
        if (_activeVideoId != null &&
            notification.videoId == _activeVideoId) {
          return true;
        }
        return false;

      case InAppNotificationType.message:
        // Suppress if in inbox screen (already seeing messages)
        if (_isInInboxScreen) return true;
        // Suppress if chatting with this specific sender
        if (_activeChatUserId != null &&
            notification.senderId == _activeChatUserId) {
          return true;
        }
        return false;

      case InAppNotificationType.follow:
        // Never suppress follow notifications (they're always exciting)
        return false;
    }
  }

  // ── Rate Limiting Logic ────────────────────────────────────

  String _rateLimitKey(InAppNotification notification) {
    // Rate limit per type + source
    switch (notification.type) {
      case InAppNotificationType.like:
      case InAppNotificationType.comment:
      case InAppNotificationType.mention:
        // Rate limit per video (many people liking same video = throttle)
        return '${notification.type}:${notification.videoId ?? notification.senderId}';
      case InAppNotificationType.follow:
        // Rate limit follows globally (celebrity scenario)
        return 'follow:global';
      case InAppNotificationType.message:
        // Rate limit per sender
        return 'message:${notification.senderId}';
    }
  }

  bool _isRateLimited(InAppNotification notification) {
    // Never rate-limit direct messages — users expect every message to appear
    if (notification.type == InAppNotificationType.message) return false;

    final key = _rateLimitKey(notification);
    final now = DateTime.now();

    if (!_recentNotifications.containsKey(key)) {
      _recentNotifications[key] = Queue<DateTime>();
    }

    final queue = _recentNotifications[key]!;

    // Remove entries outside the window
    while (queue.isNotEmpty && now.difference(queue.first) > _rateLimitWindow) {
      queue.removeFirst();
    }

    return queue.length >= _maxPerWindow;
  }

  void _recordNotification(InAppNotification notification) {
    final key = _rateLimitKey(notification);
    if (!_recentNotifications.containsKey(key)) {
      _recentNotifications[key] = Queue<DateTime>();
    }
    _recentNotifications[key]!.add(DateTime.now());
  }

  // ── User Preferences ──────────────────────────────────────

  Future<bool> _isTypeEnabled(InAppNotificationType type) async {
    await _ensurePreferencesLoaded();

    switch (type) {
      case InAppNotificationType.like:
        return _preferences['inAppLikes'] ?? true;
      case InAppNotificationType.comment:
        return _preferences['inAppComments'] ?? true;
      case InAppNotificationType.follow:
        return _preferences['inAppNewFollowers'] ?? true;
      case InAppNotificationType.mention:
        return _preferences['inAppMentions'] ?? true;
      case InAppNotificationType.message:
        return _preferences['inAppMessages'] ?? true;
    }
  }

  Future<void> _ensurePreferencesLoaded() async {
    final now = DateTime.now();
    if (_preferencesLoadedAt != null &&
        now.difference(_preferencesLoadedAt!) < _preferencesCacheDuration &&
        _preferences.isNotEmpty) {
      return;
    }

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final result = await _apiService.getUserSettings(token);
      if (result['success'] == true && result['settings'] != null) {
        final s = result['settings'];
        _preferences = {
          'inAppLikes': s['inAppLikes'] ?? true,
          'inAppComments': s['inAppComments'] ?? true,
          'inAppNewFollowers': s['inAppNewFollowers'] ?? true,
          'inAppMentions': s['inAppMentions'] ?? true,
          'inAppMessages': s['inAppMessages'] ?? true,
        };
        _preferencesLoadedAt = now;
      }
    } catch (e) {
      debugPrint('[InAppNotif] Error loading preferences: $e');
    }
  }

  /// Force reload preferences (call after settings change)
  void invalidatePreferences() {
    _preferencesLoadedAt = null;
    _preferences.clear();
  }

  /// Clean up
  void dispose() {
    _notificationController.close();
    _tapController.close();
  }
}
