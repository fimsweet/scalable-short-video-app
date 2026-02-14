import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:scalable_short_video_app/firebase_options.dart';
import 'package:scalable_short_video_app/src/presentation/screens/main_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/select_interests_screen.dart';
import 'package:scalable_short_video_app/src/presentation/screens/phone_register_screen.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/fcm_service.dart';
import 'package:scalable_short_video_app/src/services/in_app_notification_service.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/in_app_notification_overlay.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:timeago/timeago.dart' as timeago;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('App starting - initializing services...');
  
  // Add Vietnamese locale for timeago
  timeago.setLocaleMessages('vi', timeago.ViMessages());
  
  // Initialize Firebase first
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('Firebase initialized');
  
  // Initialize ThemeService first to register login/logout listeners
  // This ensures the singleton is created and listeners are registered
  final themeService = ThemeService();
  await themeService.init();
  print('ThemeService initialized');
  
  // Initialize LocaleService
  final localeService = LocaleService();
  await localeService.init();
  print('LocaleService initialized');
  
  // Initialize FCM service for push notifications
  await FcmService().initialize();
  print('FCM Service initialized');
  
  // Then try auto-login which will trigger the listeners if successful
  await AuthService().tryAutoLogin();
  print('Auth check completed');
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

// Global navigator key for navigation from anywhere (e.g. notification taps)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global route observer so screens can detect when they become visible again
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      title: 'Short Video App',
      theme: _themeService.themeData,
      home: MainScreen(key: mainScreenKey),
      debugShowCheckedModeBanner: false,
      // Named routes for navigation
      routes: {
        '/select-interests': (context) => const SelectInterestsScreen(isOnboarding: true),
        '/phone-register': (context) => const PhoneRegisterScreen(isRegistration: true),
      },
      // Add builder to wrap with in-app notification overlay
      builder: (context, child) {
        return InAppNotificationOverlay(
          onTap: (notification) => _handleInAppNotificationTap(notification),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// Handle tap on in-app notification banner — delegate to MainScreen
  /// via the InAppNotificationService tap stream for proper tab switching
  /// and navigation stack.
  void _handleInAppNotificationTap(InAppNotification notification) {
    InAppNotificationService().emitTap(notification);
  }
}
