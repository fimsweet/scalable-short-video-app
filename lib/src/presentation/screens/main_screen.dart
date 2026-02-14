import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scalable_short_video_app/src/presentation/screens/profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/upload_video_screen_v2.dart';
import 'package:scalable_short_video_app/src/presentation/screens/chat_screen.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/video_playback_service.dart';
import 'package:scalable_short_video_app/src/services/fcm_service.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/in_app_notification_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/presentation/screens/inbox_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/user_profile_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/video_detail_screen.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/login_required_dialog.dart';
import 'package:scalable_short_video_app/src/utils/navigation_utils.dart';

// Global key to access MainScreen state
final GlobalKey<_MainScreenState> mainScreenKey = GlobalKey<_MainScreenState>();

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final LocaleService _localeService = LocaleService();
  final VideoPlaybackService _videoPlaybackService = VideoPlaybackService();
  final FcmService _fcmService = FcmService();
  final ApiService _apiService = ApiService();
  final MessageService _messageService = MessageService();
  
  // Key to force rebuild screens when auth state changes
  int _rebuildKey = 0;
  bool _hasRequestedNotificationPermission = false;

  // Global heartbeat timer for online status
  Timer? _heartbeatTimer;

  // GlobalKey to access VideoScreenState for refresh
  GlobalKey<VideoScreenState> _videoScreenKey = GlobalKey<VideoScreenState>();

  // Whether home feed is currently refreshing (shows loading icon)
  bool _isRefreshingFeed = false;

  // Subscription for notification tap stream
  StreamSubscription<Map<String, dynamic>>? _notificationTapSubscription;

  // Subscription for in-app notification banner taps
  StreamSubscription<InAppNotification>? _inAppNotifTapSubscription;

  // Public method to switch to profile tab
  void switchToProfileTab() {
    _videoPlaybackService.setVideoTabInvisible();
    setState(() {
      _selectedIndex = 1; // Profile tab index
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeService.addListener(_onThemeChanged);
    _localeService.addListener(_onLocaleChanged);
    
    // Listen to auth events using the same method
    _authService.addLogoutListener(_onAuthStateChanged);
    _authService.addLoginListener(_onLoginStateChanged);
    
    // Listen to notification taps to navigate to the correct screen
    _notificationTapSubscription = _fcmService.notificationTapStream.listen(_onNotificationTap);
    
    // Listen to in-app notification banner taps
    _inAppNotifTapSubscription = InAppNotificationService().notificationTapStream.listen(_onInAppNotificationTap);
    
    // Check for any pending notification tap from terminated state
    // (buffered because no listener was attached when getInitialMessage fired)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = _fcmService.consumePendingNotification();
      if (pending != null) {
        print('Processing pending notification from terminated state: $pending');
        _onNotificationTap(pending);
      }
    });
    
    // Check if should request notification permission on startup
    _checkNotificationPermission();

    // Connect WebSocket + start heartbeat immediately if logged in
    _connectOnlineStatus();
  }

  /// Connect WebSocket and start heartbeat for online status
  void _connectOnlineStatus() {
    final userId = _authService.userId;
    if (_authService.isLoggedIn && userId != null) {
      final userIdStr = userId.toString();
      _messageService.connect(userIdStr);
      _startGlobalHeartbeat(userIdStr);
    }
  }

  /// Start global heartbeat timer (sends every 60s)
  void _startGlobalHeartbeat(String userId) {
    _heartbeatTimer?.cancel();
    _apiService.sendHeartbeat(userId);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_authService.isLoggedIn) {
        _apiService.sendHeartbeat(userId);
      }
    });
  }

  /// Stop heartbeat and disconnect WebSocket
  void _disconnectOnlineStatus() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _messageService.disconnect();
  }
  
  /// Check and request notification permission after delay if user is logged in
  Future<void> _checkNotificationPermission() async {
    // Wait for context to be ready and some time for user to settle
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    if (!_authService.isLoggedIn) return;
    if (_hasRequestedNotificationPermission) return;
    
    _hasRequestedNotificationPermission = true;
    await _fcmService.requestPermissionWithDialog(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeService.removeListener(_onThemeChanged);
    _localeService.removeListener(_onLocaleChanged);
    // Remove listeners using the same method reference
    _authService.removeLogoutListener(_onAuthStateChanged);
    _authService.removeLoginListener(_onLoginStateChanged);
    _notificationTapSubscription?.cancel();
    _inAppNotifTapSubscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onLocaleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Handle notification tap events — navigate to the appropriate screen
  void _onNotificationTap(Map<String, dynamic> data) {
    final type = data['type'];
    print('[MainScreen] === NOTIFICATION TAP RECEIVED ===');
    print('[MainScreen] type: $type, data: $data');

    if (type == 'message') {
      _navigateToChatFromNotification(data);
    }
  }

  /// Navigate to ChatScreen from notification data
  /// Builds proper navigation stack: MainScreen(Profile) → InboxScreen → ChatScreen
  /// So pressing back goes: ChatScreen → Inbox → Profile (like Instagram/Messenger)
  void _navigateToChatFromNotification(Map<String, dynamic> data) async {
    final senderId = data['senderId'] as String?;
    final senderName = data['senderName'] as String? ?? 'User';

    print('[MainScreen] _navigateToChatFromNotification — senderId: $senderId, senderName: $senderName');

    if (senderId == null || senderId.isEmpty) {
      print('[MainScreen] ERROR: Missing senderId in notification data');
      return;
    }

    if (!mounted) {
      print('[MainScreen] ERROR: MainScreen not mounted, cannot navigate');
      return;
    }

    // 1. Pop any screens stacked above MainScreen (e.g. Settings, UserProfile, etc.)
    //    so that Inbox → back always returns to MainScreen(Profile)
    Navigator.popUntil(context, (route) => route.isFirst);

    // 2. Switch to Profile tab (so back from Inbox returns to Profile)
    _videoPlaybackService.setVideoTabInvisible();
    setState(() => _selectedIndex = 1);

    // 3. Fetch sender's avatar from API (like InboxScreen does)
    String? avatarUrl;
    try {
      final userInfo = await _apiService.getUserById(senderId);
      if (userInfo != null && userInfo['avatar'] != null) {
        avatarUrl = _apiService.getAvatarUrl(userInfo['avatar']);
        if (avatarUrl.isEmpty) avatarUrl = null;
      }
      print('[MainScreen] Fetched avatar for $senderName: $avatarUrl');
    } catch (e) {
      print('[MainScreen] Error fetching avatar: $e');
    }

    if (!mounted) return;

    // 4. Push InboxScreen, then immediately push ChatScreen on top
    //    This creates proper back stack: ChatScreen → Inbox → Profile
    print('[MainScreen] Building navigation stack: Profile → Inbox → ChatScreen');
    
    // Push InboxScreen (without animation, as an intermediate screen)
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const InboxScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // No animation when pushing, but slide animation when popping back
          return child;
        },
      ),
    );

    // Small delay to let InboxScreen mount, then push ChatScreen on top with animation
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    NavigationUtils.slideToScreen(
      context,
      ChatScreen(
        recipientId: senderId,
        recipientUsername: senderName,
        recipientAvatar: avatarUrl,
      ),
    ).then((_) {
      print('[MainScreen] ChatScreen navigation completed (popped back to Inbox)');
    }).catchError((e) {
      print('[MainScreen] ERROR navigating to ChatScreen: $e');
    });
  }

  /// Handle taps on in-app notification banners — all types
  void _onInAppNotificationTap(InAppNotification notification) {
    print('[MainScreen] In-app notification tap: ${notification.type}');
    if (!mounted) return;

    switch (notification.type) {
      case InAppNotificationType.message:
        // Reuse the existing chat navigation with proper tab+stack
        _navigateToChatFromNotification({
          'senderId': notification.senderId,
          'senderName': notification.senderName,
        });
        break;

      case InAppNotificationType.like:
      case InAppNotificationType.comment:
      case InAppNotificationType.mention:
        // Navigate to video detail — pop to MainScreen first, then switch tab
        if (notification.videoId != null) {
          Navigator.popUntil(context, (route) => route.isFirst);
          _videoPlaybackService.setVideoTabInvisible();
          setState(() => _selectedIndex = 1);
          _navigateToVideoFromBanner(notification);
        }
        break;

      case InAppNotificationType.follow:
        // Navigate to follower's profile — pop to MainScreen first
        final senderId = int.tryParse(notification.senderId);
        if (senderId != null) {
          Navigator.popUntil(context, (route) => route.isFirst);
          _videoPlaybackService.setVideoTabInvisible();
          setState(() => _selectedIndex = 1);
          NavigationUtils.slideToScreen(
            context,
            UserProfileScreen(userId: senderId),
          );
        }
        break;
    }
  }

  /// Fetch video and navigate to VideoDetailScreen from in-app banner tap
  Future<void> _navigateToVideoFromBanner(InAppNotification notification) async {
    try {
      final video = await VideoService().getVideoById(notification.videoId!);
      if (video != null && mounted) {
        NavigationUtils.slideToScreen(
          context,
          VideoDetailScreen(
            videos: [video],
            initialIndex: 0,
            openCommentsOnLoad: notification.type == InAppNotificationType.comment,
          ),
        );
      }
    } catch (e) {
      debugPrint('[MainScreen] Error navigating to video from banner: $e');
    }
  }
  
  void _onLoginStateChanged() {
    print('MainScreen: Login state changed - forcing rebuild');
    print('   isLoggedIn: ${_authService.isLoggedIn}');
    
    // Force rebuild all screens by changing the key
    if (mounted) {
      setState(() {
        _rebuildKey++;
        _videoScreenKey = GlobalKey<VideoScreenState>();
      });
    }
    
    // Request notification permission after login with delay
    _checkNotificationPermission();

    // Connect WebSocket + start heartbeat on login
    _connectOnlineStatus();
  }

  void _onAuthStateChanged() {
    print('MainScreen: Auth state changed - forcing rebuild (logout)');
    print('   isLoggedIn: ${_authService.isLoggedIn}');
    
    // Disconnect WebSocket + stop heartbeat on logout
    _disconnectOnlineStatus();

    // Force rebuild all screens by changing the key
    if (mounted) {
      setState(() {
        _rebuildKey++;
        _videoScreenKey = GlobalKey<VideoScreenState>();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Clear notification badge when app returns to foreground
      _fcmService.clearNotifications();
      // Reconnect WebSocket + resume heartbeat when app comes to foreground
      _connectOnlineStatus();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Stop heartbeat when app goes to background (socket auto-disconnects on kill)
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // VideoScreen uses GlobalKey to access state for refresh
          VideoScreen(key: _videoScreenKey),
          // ProfileScreen can be rebuilt when auth changes
          ProfileScreen(key: ValueKey('profile_screen_$_rebuildKey')),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: _selectedIndex == 1 && _themeService.isLightMode
            ? BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[400]!, width: 1),
                ),
              )
            : (_selectedIndex == 1 && !_themeService.isLightMode
                ? BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.grey[800]!, width: 0.5),
                    ),
                  )
                : null),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _isRefreshingFeed
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _selectedIndex == 0 ? Colors.white : (_themeService.isLightMode ? Colors.black : Colors.white),
                          ),
                        )
                      : Icon(Icons.home, key: const ValueKey('home')),
                ),
                label: _localeService.get('home'),
              ),
              BottomNavigationBarItem(
                icon: Container(
                  width: 48,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _selectedIndex == 0 ? Colors.white : (_themeService.isLightMode ? Colors.black : Colors.white),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _selectedIndex == 0 ? Colors.black : (_themeService.isLightMode ? Colors.black : Colors.black), width: 1),
                  ),
                  child: Icon(
                    Icons.add,
                    color: _selectedIndex == 0 ? Colors.black : (_themeService.isLightMode ? Colors.white : Colors.black),
                    size: 24,
                  ),
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: _localeService.get('profile'),
              ),
            ],
            currentIndex: _selectedIndex == 0 ? 0 : 2,
            selectedItemColor: _selectedIndex == 0 ? Colors.white : (_themeService.isLightMode ? Colors.black : Colors.white),
            unselectedItemColor: _selectedIndex == 0 ? Colors.grey : _themeService.textSecondaryColor,
            onTap: (index) {
              if (index == 1) {
                _navigateToUpload();
              } else if (index == 2) {
                // Switching to Profile tab - pause video via service
                _videoPlaybackService.setVideoTabInvisible();
                setState(() => _selectedIndex = 1);
              } else {
                if (_selectedIndex == 0) {
                  // Already on feed — spin home icon & refresh feed
                  _spinAndRefreshFeed();
                } else {
                  // Switching to Feed tab - resume video via service
                  _videoPlaybackService.setVideoTabVisible();
                  setState(() => _selectedIndex = 0);
                }
              }
            },
            backgroundColor: _selectedIndex == 0 ? Colors.black : (_themeService.isLightMode ? Colors.white : Colors.black),
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: false,
            showUnselectedLabels: false,
            enableFeedback: false,
          ),
        ),
      ),
    );
  }

  /// Spin the home icon and refresh the For You feed
  /// Show loading spinner on home icon, refresh feed, then restore home icon
  void _spinAndRefreshFeed() async {
    if (_isRefreshingFeed) return;

    setState(() => _isRefreshingFeed = true);

    await _videoScreenKey.currentState?.refreshForYouFeed();

    if (mounted) {
      setState(() => _isRefreshingFeed = false);
    }
  }

  void _navigateToUpload() async {
    if (!_authService.isLoggedIn) {
      LoginRequiredDialog.show(context, 'post');
      return;
    }

    // Pause video when navigating to upload
    _videoPlaybackService.setVideoTabInvisible();

    final result = await NavigationUtils.slideToScreen(
      context,
      const UploadVideoScreenV2(),
    );

    if (result == true) {
      setState(() {
        _rebuildKey++;
        _selectedIndex = 1;
      });
    } else if (_selectedIndex == 0) {
      // Resume video if we're back on video tab
      _videoPlaybackService.setVideoTabVisible();
    }
  }
}
