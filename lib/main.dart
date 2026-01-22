import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:scalable_short_video_app/firebase_options.dart';
import 'package:scalable_short_video_app/src/presentation/screens/main_screen.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 App starting - initializing services...');
  
  // Initialize Firebase first
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('🔥 Firebase initialized');
  
  // Initialize ThemeService first to register login/logout listeners
  // This ensures the singleton is created and listeners are registered
  final themeService = ThemeService();
  await themeService.init();
  print('✅ ThemeService initialized');
  
  // Initialize LocaleService
  final localeService = LocaleService();
  await localeService.init();
  print('✅ LocaleService initialized');
  
  // Then try auto-login which will trigger the listeners if successful
  await AuthService().tryAutoLogin();
  print('✅ Auth check completed');
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

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
      title: 'Short Video App',
      theme: _themeService.themeData,
      home: MainScreen(key: mainScreenKey),
      debugShowCheckedModeBanner: false,
      // Add builder to ensure we always have a navigator
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
