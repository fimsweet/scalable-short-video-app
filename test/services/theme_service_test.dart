import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeService', () {
    late ThemeService service;

    setUp(() {
      service = ThemeService();
    });

    test('singleton returns same instance', () {
      final a = ThemeService();
      final b = ThemeService();
      expect(identical(a, b), true);
    });

    group('static color constants', () {
      test('dark mode colors are defined', () {
        expect(ThemeService.darkBackground, Colors.black);
        expect(ThemeService.darkSurface, const Color(0xFF121212));
        expect(ThemeService.darkCard, const Color(0xFF1E1E1E));
        expect(ThemeService.darkDivider, const Color(0xFF2D2D2D));
        expect(ThemeService.darkTextPrimary, Colors.white);
        expect(ThemeService.darkTextSecondary, const Color(0xFF9E9E9E));
        expect(ThemeService.darkIcon, Colors.white);
      });

      test('light mode colors are defined', () {
        expect(ThemeService.lightBackground, Colors.white);
        expect(ThemeService.lightSurface, Colors.white);
        expect(ThemeService.lightCard, Colors.white);
        expect(ThemeService.lightDivider, const Color(0xFFE0E0E0));
        expect(ThemeService.lightTextPrimary, const Color(0xFF212121));
        expect(ThemeService.lightTextSecondary, const Color(0xFF757575));
        expect(ThemeService.lightIcon, const Color(0xFF212121));
      });

      test('accent colors are defined', () {
        expect(ThemeService.accentColor, const Color(0xFFFF2D55));
        expect(ThemeService.accentColorLight, const Color(0xFFFF6B81));
        expect(ThemeService.successColor, const Color(0xFF4CAF50));
        expect(ThemeService.errorColor, const Color(0xFFE53935));
        expect(ThemeService.warningColor, const Color(0xFFFF9800));
      });
    });

    group('dynamic color getters', () {
      test('backgroundColor returns appropriate color', () {
        expect(service.backgroundColor, isA<Color>());
      });

      test('surfaceColor returns appropriate color', () {
        expect(service.surfaceColor, isA<Color>());
      });

      test('cardColor returns appropriate color', () {
        expect(service.cardColor, isA<Color>());
      });

      test('dividerColor returns appropriate color', () {
        expect(service.dividerColor, isA<Color>());
      });

      test('textPrimaryColor returns appropriate color', () {
        expect(service.textPrimaryColor, isA<Color>());
      });

      test('textSecondaryColor returns appropriate color', () {
        expect(service.textSecondaryColor, isA<Color>());
      });

      test('iconColor returns appropriate color', () {
        expect(service.iconColor, isA<Color>());
      });

      test('primaryAccentColor returns accent', () {
        expect(service.primaryAccentColor, ThemeService.accentColor);
      });

      test('radioActiveColor returns accent', () {
        expect(service.radioActiveColor, ThemeService.accentColor);
      });

      test('sectionTitleBackground returns a color', () {
        expect(service.sectionTitleBackground, isA<Color>());
      });

      test('inputBackground returns a color', () {
        expect(service.inputBackground, isA<Color>());
      });

      test('switchTrackColor returns a color', () {
        expect(service.switchTrackColor, isA<Color>());
      });

      test('appBarBackground returns a color', () {
        expect(service.appBarBackground, isA<Color>());
      });

      test('snackBarBackground returns a color', () {
        expect(service.snackBarBackground, isA<Color>());
      });

      test('snackBarTextColor is white', () {
        expect(service.snackBarTextColor, Colors.white);
      });

      test('switch colors are defined', () {
        expect(service.switchActiveColor, Colors.white);
        expect(service.switchActiveTrackColor, isA<Color>());
        expect(service.switchInactiveThumbColor, Colors.white);
        expect(service.switchInactiveTrackColor, isA<Color>());
      });
    });

    group('themeData', () {
      test('returns ThemeData', () {
        final themeData = service.themeData;
        expect(themeData, isA<ThemeData>());
      });

      test('themeData has correct brightness based on mode', () {
        final themeData = service.themeData;
        if (service.isLightMode) {
          expect(themeData.brightness, Brightness.light);
        } else {
          expect(themeData.brightness, Brightness.dark);
        }
      });

      test('themeData has app bar theme', () {
        final themeData = service.themeData;
        expect(themeData.appBarTheme, isNotNull);
        expect(themeData.appBarTheme.elevation, 0);
      });

      test('themeData has text selection theme', () {
        final themeData = service.themeData;
        expect(themeData.textSelectionTheme, isNotNull);
      });

      test('themeData has popup menu theme', () {
        final themeData = service.themeData;
        expect(themeData.popupMenuTheme, isNotNull);
      });
    });

    group('isLightMode', () {
      test('returns boolean', () {
        expect(service.isLightMode, isA<bool>());
      });
    });

    // toggleTheme requires SharedPreferences plugin which is not available
    // in test environment, so we skip those tests and rely on static color
    // verification instead.
  });
}
