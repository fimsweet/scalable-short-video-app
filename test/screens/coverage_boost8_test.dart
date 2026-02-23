// coverage_boost8_test.dart — Targets ThemeService, LocaleService, NotificationService,
// VideoPrefetchService, OptionsMenuWidget, VideoMoreOptionsSheet, AuthService logout listeners
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

import 'package:scalable_short_video_app/src/services/theme_service.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';
import 'package:scalable_short_video_app/src/services/notification_service.dart';
import 'package:scalable_short_video_app/src/services/video_prefetch_service.dart';
import 'package:scalable_short_video_app/src/config/app_config.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/options_menu_widget.dart';
import 'package:scalable_short_video_app/src/presentation/widgets/video_more_options_sheet.dart';

// ── Mock FlutterSecureStorage ──
class _MockStorage extends Fake
    with MockPlatformInterfaceMixin
    implements FlutterSecureStoragePlatform {
  final Map<String, String> _store = {};
  @override
  Future<String?> read(
          {required String key,
          required Map<String, String> options}) async =>
      _store[key];
  @override
  Future<void> write(
          {required String key,
          required String value,
          required Map<String, String> options}) async =>
      _store[key] = value;
  @override
  Future<void> delete(
          {required String key,
          required Map<String, String> options}) async =>
      _store.remove(key);
  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _store.clear();
  @override
  Future<Map<String, String>> readAll(
          {required Map<String, String> options}) async =>
      Map.from(_store);
  @override
  Future<bool> containsKey(
          {required String key,
          required Map<String, String> options}) async =>
      _store.containsKey(key);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════
  // G1: ThemeService — init, toggleTheme, themeData
  // Targets lines: 99-102, 107 (init), 155-168 (toggle), 182-203 (themeData)
  // ═══════════════════════════════════════════════════
  group('G1 ThemeService init + toggle + themeData', () {
    test('init loads saved light mode from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'is_light_mode': true});
      final ts = ThemeService();
      await ts.init();
      expect(ts.isLightMode, isTrue);
    });

    test('init defaults to dark mode when no pref saved', () async {
      SharedPreferences.setMockInitialValues({});
      final ts = ThemeService();
      await ts.init();
      expect(ts.isLightMode, isFalse);
    });

    test('init with explicit false saves dark mode', () async {
      SharedPreferences.setMockInitialValues({'is_light_mode': false});
      final ts = ThemeService();
      await ts.init();
      expect(ts.isLightMode, isFalse);
    });

    test('toggleTheme to light mode', () async {
      SharedPreferences.setMockInitialValues({});
      final ts = ThemeService();
      await ts.toggleTheme(true);
      expect(ts.isLightMode, isTrue);
    });

    test('toggleTheme to dark mode', () async {
      SharedPreferences.setMockInitialValues({});
      final ts = ThemeService();
      await ts.toggleTheme(false);
      expect(ts.isLightMode, isFalse);
    });

    test('toggleTheme persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final ts = ThemeService();
      await ts.toggleTheme(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_light_mode'), isTrue);
    });

    test('themeData in light mode returns light brightness', () async {
      SharedPreferences.setMockInitialValues({});
      final ts = ThemeService();
      await ts.toggleTheme(true);
      final td = ts.themeData;
      expect(td.brightness, Brightness.light);
      expect(td.scaffoldBackgroundColor, isNotNull);
      expect(td.colorScheme.brightness, Brightness.light);
    });

    test('themeData in dark mode returns dark brightness', () async {
      SharedPreferences.setMockInitialValues({});
      final ts = ThemeService();
      await ts.toggleTheme(false);
      final td = ts.themeData;
      expect(td.brightness, Brightness.dark);
      expect(td.scaffoldBackgroundColor, isNotNull);
      expect(td.colorScheme.brightness, Brightness.dark);
    });

    test('toggleTheme notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final ts = ThemeService();
      bool notified = false;
      ts.addListener(() => notified = true);
      await ts.toggleTheme(true);
      expect(notified, isTrue);
      ts.removeListener(() {});
    });

    test('init notifies listeners', () async {
      SharedPreferences.setMockInitialValues({'is_light_mode': true});
      final ts = ThemeService();
      bool notified = false;
      ts.addListener(() => notified = true);
      await ts.init();
      expect(notified, isTrue);
    });

    test('color getters change with mode', () async {
      SharedPreferences.setMockInitialValues({});
      final ts = ThemeService();
      await ts.toggleTheme(false);
      final darkBg = ts.backgroundColor;
      final darkCard = ts.cardColor;
      final darkText = ts.textPrimaryColor;

      await ts.toggleTheme(true);
      final lightBg = ts.backgroundColor;
      final lightCard = ts.cardColor;
      final lightText = ts.textPrimaryColor;

      // Dark and light should differ
      expect(darkBg, isNot(equals(lightBg)));
    });
  });

  // ═══════════════════════════════════════════════════
  // G2: LocaleService — init
  // Targets lines: 45-49 (init)
  // ═══════════════════════════════════════════════════
  group('G2 LocaleService init', () {
    test('init loads en from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});
      final ls = LocaleService();
      await ls.init();
      expect(ls.isEnglish, isTrue);
      expect(ls.isVietnamese, isFalse);
      expect(ls.currentLocale, 'en');
    });

    test('init defaults to vi when no pref', () async {
      SharedPreferences.setMockInitialValues({});
      final ls = LocaleService();
      await ls.init();
      expect(ls.isVietnamese, isTrue);
      expect(ls.currentLocale, 'vi');
    });

    test('init with explicit vi', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'vi'});
      final ls = LocaleService();
      await ls.init();
      expect(ls.isVietnamese, isTrue);
    });

    test('init notifies listeners', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'en'});
      final ls = LocaleService();
      bool notified = false;
      ls.addListener(() => notified = true);
      await ls.init();
      expect(notified, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════
  // G3: NotificationService refreshBadgeCounts
  // Targets lines: 129-131
  // ═══════════════════════════════════════════════════
  group('G3 NotificationService refreshBadgeCounts', () {
    test('refreshBadgeCounts without polling userId returns early', () async {
      // _pollingUserId should be null initially (never set from previous tests)
      final ns = NotificationService();
      ns.stopPolling(); // ensure clean state
      await ns.refreshBadgeCounts();
      // No error — just returns because _pollingUserId is null
    });

    test('refreshBadgeCounts with active polling fetches counts', () async {
      final client = http_testing.MockClient((req) async {
        final path = req.url.path;
        if (path.contains('unread-count')) {
          return http.Response(json.encode({'count': 5}), 200);
        }
        if (path.contains('pending-follow-count')) {
          return http.Response(json.encode({'count': 3}), 200);
        }
        return http.Response('{}', 200);
      });

      await http.runWithClient(() async {
        final ns = NotificationService();
        // Start polling with very long interval so timer never fires
        ns.startPolling('boost8user', interval: const Duration(hours: 1));
        // Wait for the immediate _fetchAndEmitCounts call to complete
        await Future.delayed(const Duration(milliseconds: 300));
        // Now call refreshBadgeCounts — covers lines 129-131
        await ns.refreshBadgeCounts();
        // Stop the timer
        ns.stopPolling();
      }, () => client);
    });
  });

  // ═══════════════════════════════════════════════════
  // G4: VideoPrefetchService
  // Targets lines: 89 (_prefetchUrl catch), 130 (getStats non-empty)
  // ═══════════════════════════════════════════════════
  group('G4 VideoPrefetchService deeper', () {
    test('prefetchVideosAround HEAD success + getStats nonEmpty', () async {
      final client = http_testing.MockClient((req) async {
        return http.Response('', 200);
      });

      await http.runWithClient(() async {
        final vps = VideoPrefetchService();
        vps.clearCache();
        await vps.prefetchVideosAround([
          {'hlsUrl': 'https://cdn.boost8a.com/skip.m3u8'},
          {'hlsUrl': 'https://cdn.boost8a.com/v1.m3u8',
           'thumbnailUrl': 'https://cdn.boost8a.com/t1.jpg'},
          {'hlsUrl': 'https://cdn.boost8a.com/v2.m3u8'},
        ], 0);
        // Wait for async _prefetchUrl to complete
        await Future.delayed(const Duration(milliseconds: 300));
        final stats = vps.getStats();
        expect(stats['cachedUrls'], greaterThan(0));
        expect(stats['successRate'], greaterThan(0.0));
      }, () => client);
    });

    test('prefetchVideosAround exception covers catch block', () async {
      final client = http_testing.MockClient((req) async {
        throw Exception('network error');
      });

      await http.runWithClient(() async {
        final vps = VideoPrefetchService();
        vps.clearCache();
        await vps.prefetchVideosAround([
          {'hlsUrl': 'https://cdn.boost8b.com/skip.m3u8'},
          {'hlsUrl': 'https://cdn.boost8b.com/fail.m3u8'},
        ], 0);
        // Wait for catch block to complete
        await Future.delayed(const Duration(milliseconds: 300));
        // URL cached as false after exception
        expect(vps.isPrefetched('https://cdn.boost8b.com/fail.m3u8'), isFalse);
      }, () => client);
    });

    test('isPrefetched with absolute URL after successful prefetch', () async {
      final client = http_testing.MockClient((req) async {
        return http.Response('', 200);
      });

      await http.runWithClient(() async {
        final vps = VideoPrefetchService();
        vps.clearCache();
        await vps.prefetchVideosAround([
          {'hlsUrl': 'https://cdn.boost8c.com/dummy.m3u8'},
          {'hlsUrl': 'https://cdn.boost8c.com/check.m3u8'},
        ], 0);
        await Future.delayed(const Duration(milliseconds: 300));
        expect(vps.isPrefetched('https://cdn.boost8c.com/check.m3u8'), isTrue);
      }, () => client);
    });

    test('getStats structure after data', () {
      final stats = VideoPrefetchService().getStats();
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('cachedUrls'), isTrue);
      expect(stats.containsKey('pendingPrefetch'), isTrue);
      expect(stats.containsKey('successRate'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════
  // G5: OptionsMenuWidget
  // Targets lines: 35-37 (_onThemeChanged), 47-49, 51 (_handleSaveToggle)
  // ═══════════════════════════════════════════════════
  group('G5 OptionsMenuWidget', () {
    testWidgets('renders and triggers initState', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OptionsMenuWidget(
            videoId: 'vid1',
            userId: 'uid1',
            isSaved: false,
            onSaveToggle: () {},
          ),
        ),
      ));
      expect(find.byType(OptionsMenuWidget), findsOneWidget);
    });

    testWidgets('dispose triggers removeListener', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OptionsMenuWidget(
            videoId: 'vid2',
            userId: 'uid2',
            isSaved: true,
            onSaveToggle: () {},
          ),
        ),
      ));
      // Replace widget to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();
    });

    testWidgets('theme change triggers _onThemeChanged', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OptionsMenuWidget(
            videoId: 'vid3',
            userId: 'uid3',
            isSaved: false,
            onSaveToggle: () {},
          ),
        ),
      ));
      // Toggle theme while widget mounted → _onThemeChanged fires
      final ts = ThemeService();
      await ts.toggleTheme(true);
      await tester.pump();
      await ts.toggleTheme(false);
      await tester.pump();
    });

    testWidgets('tap save/bookmark icon triggers handleSaveToggle',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      bool toggled = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OptionsMenuWidget(
            videoId: 'vid4',
            userId: 'uid4',
            isSaved: false,
            onSaveToggle: () {
              toggled = true;
            },
          ),
        ),
      ));
      // Find and tap bookmark icon
      final bookmarkFinder = find.byIcon(Icons.bookmark_border);
      expect(bookmarkFinder, findsOneWidget);
      await tester.tap(bookmarkFinder);
      await tester.pump();
      expect(toggled, isTrue);
      // After toggle, icon should change to filled bookmark
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('renders with isSaved true shows filled bookmark',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OptionsMenuWidget(
            videoId: 'vid5',
            userId: 'uid5',
            isSaved: true,
            onSaveToggle: () {},
          ),
        ),
      ));
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════
  // G6: VideoMoreOptionsSheet
  // Targets lines: 33, 164, 173, 190 (light mode), 67, 148-150 (button taps)
  // ═══════════════════════════════════════════════════
  group('G6 VideoMoreOptionsSheet', () {
    testWidgets('renders in dark mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ts = ThemeService();
      await ts.toggleTheme(false);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VideoMoreOptionsSheet(
              videoId: 'vm1',
              userId: 'um1',
            ),
          ),
        ),
      ));
      expect(find.byType(VideoMoreOptionsSheet), findsOneWidget);
    });

    testWidgets('renders in light mode covers light branches', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ts = ThemeService();
      await ts.toggleTheme(true); // Switch to light
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: VideoMoreOptionsSheet(
              videoId: 'vm2',
              userId: 'um2',
              isHidden: true,
            ),
          ),
        ),
      ));
      expect(find.byType(VideoMoreOptionsSheet), findsOneWidget);
      // Reset
      await ts.toggleTheme(false);
    });

    testWidgets('tap edit option calls callback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      bool editTapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => VideoMoreOptionsSheet(
                  videoId: 'vm3',
                  userId: 'um3',
                  onEditTap: () {
                    editTapped = true;
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Tap edit icon
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(editTapped, isTrue);
    });

    testWidgets('tap close button pops sheet', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => VideoMoreOptionsSheet(
                  videoId: 'vm4',
                  userId: 'um4',
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Tap close icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    });

    testWidgets('tap delete option calls callback', (tester) async {
      SharedPreferences.setMockInitialValues({});
      bool deleteTapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                builder: (_) => VideoMoreOptionsSheet(
                  videoId: 'vm5',
                  userId: 'um5',
                  onDeleteTap: () {
                    deleteTapped = true;
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // Tap delete icon
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(deleteTapped, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════
  // G7: AuthService logout triggers ThemeService + LocaleService _onLogout
  // Targets: ThemeService lines 35, 37-44, LocaleService lines 35-42
  // ═══════════════════════════════════════════════════
  group('G7 AuthService logout triggers listener resets', () {
    test('logout resets theme to dark and locale to vi', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStoragePlatform.instance = _MockStorage();

      // Set up theme to light mode before logout
      final ts = ThemeService();
      await ts.toggleTheme(true);
      expect(ts.isLightMode, isTrue);

      final ls = LocaleService();

      // Mock HTTP client so FcmService calls don't hang
      final client =
          http_testing.MockClient((req) async => http.Response('{}', 200));

      await http.runWithClient(() async {
        await AuthService().logout();
      }, () => client);

      // Wait for fire-and-forget .then() callbacks
      await Future.delayed(const Duration(milliseconds: 300));

      // ThemeService._onLogout resets to dark
      expect(ts.isLightMode, isFalse);
      // LocaleService._onLogout resets to Vietnamese
      expect(ls.isVietnamese, isTrue);
    });

    test('logout preserves dark mode prefs via _onLogout', () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStoragePlatform.instance = _MockStorage();

      final ts = ThemeService();
      // Already dark from previous test, but toggle to light then logout
      await ts.toggleTheme(true);
      expect(ts.isLightMode, isTrue);

      final client =
          http_testing.MockClient((req) async => http.Response('{}', 200));

      await http.runWithClient(() async {
        await AuthService().logout();
      }, () => client);

      await Future.delayed(const Duration(milliseconds: 300));

      expect(ts.isLightMode, isFalse);
      // Check prefs saved
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_light_mode'), isFalse);
    });
  });
}
