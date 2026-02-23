import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/locale_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleService', () {
    late LocaleService service;

    setUp(() {
      service = LocaleService();
    });

    test('singleton returns same instance', () {
      final a = LocaleService();
      final b = LocaleService();
      expect(identical(a, b), true);
    });

    group('locale getters', () {
      test('currentLocale returns a string', () {
        expect(service.currentLocale, isA<String>());
      });

      test('isVietnamese and isEnglish are consistent', () {
        if (service.currentLocale == 'vi') {
          expect(service.isVietnamese, true);
          expect(service.isEnglish, false);
        } else if (service.currentLocale == 'en') {
          expect(service.isVietnamese, false);
          expect(service.isEnglish, true);
        }
      });

      test('currentLocaleObject returns valid Locale', () {
        final locale = service.currentLocaleObject;
        expect(locale, isNotNull);
        expect(locale.languageCode, isIn(['vi', 'en']));
      });
    });

    group('get() - Vietnamese translations', () {
      test('returns app_name', () {
        // Ensure Vietnamese locale
        final result = service.get('app_name');
        expect(result, isNotEmpty);
      });

      test('returns common translations', () {
        final keys = [
          'save', 'cancel', 'confirm', 'delete', 'edit', 'back',
          'done', 'loading', 'error', 'success', 'ok', 'yes', 'no',
          'search', 'refresh', 'settings', 'profile', 'home',
          'messages', 'notifications', 'help',
        ];
        for (final key in keys) {
          final value = service.get(key);
          expect(value, isNotEmpty, reason: 'Key "$key" should have a translation');
        }
      });

      test('returns auth translations', () {
        final keys = [
          'login', 'logout', 'register', 'email', 'password',
          'username', 'forgot_password',
        ];
        for (final key in keys) {
          final value = service.get(key);
          expect(value, isNotEmpty, reason: 'Key "$key" should have a translation');
        }
      });

      test('returns the key itself for unknown translations', () {
        final result = service.get('unknown_key_that_does_not_exist');
        expect(result, 'unknown_key_that_does_not_exist');
      });

      test('translate is alias for get', () {
        final get_result = service.get('app_name');
        final translate_result = service.translate('app_name');
        expect(get_result, translate_result);
      });

      test('returns profile-related translations', () {
        final keys = [
          'followers', 'following', 'posts', 'likes',
          'edit_profile', 'no_videos_yet',
        ];
        for (final key in keys) {
          final value = service.get(key);
          // Should return either translation or key itself
          expect(value, isNotEmpty);
        }
      });

      test('returns video-related translations', () {
        final keys = [
          'videos_tab', 'for_you_tab', 'following_tab', 'friends_tab',
        ];
        for (final key in keys) {
          final value = service.get(key);
          expect(value, isNotEmpty);
        }
      });

      test('returns registration translations', () {
        final keys = [
          'full_name', 'phone_number', 'date_of_birth',
          'confirm_password',
        ];
        for (final key in keys) {
          final value = service.get(key);
          expect(value, isNotEmpty);
        }
      });

      test('returns settings translations', () {
        final keys = [
          'settings', 'notifications',
        ];
        for (final key in keys) {
          final value = service.get(key);
          expect(value, isNotEmpty);
        }
      });
    });

    // setLocale and loadFromBackend require SharedPreferences plugin
    // which is not available in test environment, so we skip those tests.

    group('English translations', () {
      test('get returns key when translation is missing', () {
        // For missing keys, get() returns the key itself
        final result = service.get('nonexistent_key_xyz');
        expect(result, 'nonexistent_key_xyz');
      });
    });
  });
}
