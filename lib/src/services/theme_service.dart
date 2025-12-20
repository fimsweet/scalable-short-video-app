import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themeKey = 'is_light_mode';
  bool _isLightMode = false;

  bool get isLightMode => _isLightMode;

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

  // Getters for current theme colors
  Color get backgroundColor => _isLightMode ? lightBackground : darkBackground;
  Color get surfaceColor => _isLightMode ? lightSurface : darkSurface;
  Color get cardColor => _isLightMode ? lightCard : darkCard;
  Color get dividerColor => _isLightMode ? lightDivider : darkDivider;
  Color get textPrimaryColor => _isLightMode ? lightTextPrimary : darkTextPrimary;
  Color get textSecondaryColor => _isLightMode ? lightTextSecondary : darkTextSecondary;
  Color get iconColor => _isLightMode ? lightIcon : darkIcon;
  
  // Additional helper colors
  Color get sectionTitleBackground => _isLightMode ? Colors.white : Colors.grey[900]!;
  Color get inputBackground => _isLightMode ? Colors.white : Colors.black;
  Color get switchTrackColor => _isLightMode ? Colors.grey[300]! : Colors.grey[700]!;
  Color get appBarBackground => _isLightMode ? Colors.white : Colors.black;
  Color get snackBarBackground => _isLightMode ? Colors.grey[300]! : Colors.grey[700]!;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isLightMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isLight) async {
    _isLightMode = isLight;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isLight);
    notifyListeners();
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
