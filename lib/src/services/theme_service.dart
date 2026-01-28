import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal() {
    print('🎨 ThemeService._internal() constructor called - registering listeners');
    _authService.addLogoutListener(_onLogout);
    _authService.addLoginListener(_onLogin);
    print('✅ ThemeService listeners registered');
  }

  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  static const String _themeKey = 'is_light_mode';
  bool _isLightMode = false;

  bool get isLightMode => _isLightMode;

  void _onLogin() {
    // Load settings from backend when user logs in
    print('👤 Login detected in ThemeService - loading settings from backend');
    print('   Current isLoggedIn: ${_authService.isLoggedIn}');
    // Use Future to avoid blocking but handle errors
    _loadSettingsFromBackend().catchError((error) {
      print('❌ Error in _onLogin while loading settings: $error');
      print('   Stack trace: ${StackTrace.current}');
    });
  }

  void _onLogout() {
    // Reset to dark mode when user logs out
    print('🌙 Logout detected - resetting to dark mode');
    _isLightMode = false;
    SharedPreferences.getInstance().then((prefs) async {
      await prefs.setBool(_themeKey, false);
      print('💾 Dark mode saved to storage');
    });
    notifyListeners();
    print('📢 Theme listeners notified - isLightMode: $_isLightMode');
  }

  // Colors for Dark Mode
  static const Color darkBackground = Colors.black;
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E1E1E);
  static const Color darkDivider = Color(0xFF2D2D2D);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFF9E9E9E);
  static const Color darkIcon = Colors.white;

  // Colors for Light Mode
  static const Color lightBackground = Colors.white;
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightDivider = Color(0xFFE0E0E0);
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightIcon = Color(0xFF212121);

  // App accent colors (TikTok-style)
  static const Color accentColor = Color(0xFFFF2D55); // TikTok red/pink
  static const Color accentColorLight = Color(0xFFFF6B81);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFF9800);

  // Getters for current theme colors
  Color get backgroundColor => _isLightMode ? lightBackground : darkBackground;
  Color get surfaceColor => _isLightMode ? lightSurface : darkSurface;
  Color get cardColor => _isLightMode ? lightCard : darkCard;
  Color get dividerColor => _isLightMode ? lightDivider : darkDivider;
  Color get textPrimaryColor => _isLightMode ? lightTextPrimary : darkTextPrimary;
  Color get textSecondaryColor => _isLightMode ? lightTextSecondary : darkTextSecondary;
  Color get iconColor => _isLightMode ? lightIcon : darkIcon;
  
  // Accent color getter
  Color get primaryAccentColor => accentColor;
  Color get radioActiveColor => accentColor;
  
  // Additional helper colors
  Color get sectionTitleBackground => _isLightMode ? const Color(0xFFF5F5F5) : Colors.black;
  Color get inputBackground => _isLightMode ? Colors.white : const Color(0xFF1A1A1A);
  Color get switchTrackColor => _isLightMode ? Colors.grey[300]! : Colors.grey[700]!;
  Color get appBarBackground => _isLightMode ? Colors.white : Colors.black;
  Color get snackBarBackground => _isLightMode ? const Color(0xFF333333) : const Color(0xFF333333);
  Color get snackBarTextColor => Colors.white;
  
  // Switch colors for dark/light mode - consistent across app
  Color get switchActiveColor => Colors.white;
  Color get switchActiveTrackColor => const Color(0xFF2196F3);
  Color get switchInactiveThumbColor => _isLightMode ? Colors.white : Colors.grey[400]!;
  Color get switchInactiveTrackColor => _isLightMode ? Colors.grey[400]! : Colors.grey[700]!;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLightMode = prefs.getBool(_themeKey) ?? false;
    print('🎨 ThemeService initialized - local theme: ${_isLightMode ? "light" : "dark"}');
    
    // Don't load from backend here - let the login listener handle it
    // This ensures settings are loaded AFTER authentication is complete
    
    notifyListeners();
  }

  Future<void> _loadSettingsFromBackend() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        print('⚠️ No token found, skipping backend settings load');
        return;
      }

      print('🔄 Loading settings from backend...');
      final response = await _apiService.getUserSettings(token);
      print('📦 Backend response: $response');
      
      if (response['success'] == true && response['settings'] != null) {
        final theme = response['settings']['theme'] ?? 'dark';
        final wasLightMode = _isLightMode;
        _isLightMode = theme == 'light';
        
        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_themeKey, _isLightMode);
        
        print('✅ Settings loaded from backend: theme=$theme (changed from ${wasLightMode ? "light" : "dark"} to ${_isLightMode ? "light" : "dark"})');
        print('   Current _isLightMode value: $_isLightMode');
        
        // Notify listeners if theme changed
        if (wasLightMode != _isLightMode) {
          print('📢 Theme changed - notifying listeners');
          notifyListeners();
        } else {
          print('ℹ️ Theme unchanged - no notification needed');
        }
      } else {
        print('⚠️ Backend response missing success or settings: $response');
      }
    } catch (e, stackTrace) {
      print('⚠️ Failed to load settings from backend: $e');
      print('Stack trace: $stackTrace');
      // Fall back to local storage
    }
  }

  Future<void> toggleTheme(bool isLight) async {
    _isLightMode = isLight;
    
    // Save to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isLight);
    
    // Sync to backend if user is logged in
    if (_authService.isLoggedIn) {
      _syncThemeToBackend(isLight ? 'light' : 'dark');
    }
    
    notifyListeners();
  }

  Future<void> _syncThemeToBackend(String theme) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      await _apiService.updateUserSettings(token, {
        'theme': theme,
      });
      print('✅ Theme synced to backend: $theme');
    } catch (e) {
      print('⚠️ Failed to sync theme to backend: $e');
    }
  }

  ThemeData get themeData {
    if (_isLightMode) {
      return ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: lightTextPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          shadowColor: Colors.grey[300],
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: Colors.black26,
          selectionHandleColor: Colors.black,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          textStyle: const TextStyle(color: lightTextPrimary),
        ),
      );
    } else {
      return ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: darkTextPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          shadowColor: Colors.grey[900],
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Colors.white24,
          selectionHandleColor: Colors.white,
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.grey[900],
          textStyle: const TextStyle(color: darkTextPrimary),
        ),
      );
    }
  }
}
