import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/config/app_config.dart';

void main() {
  group('AppConfig', () {
    group('static constants', () {
      test('appName is defined', () {
        expect(AppConfig.appName, 'Short Video App');
      });

      test('appVersion is defined', () {
        expect(AppConfig.appVersion, '1.0.0');
      });

      test('connectionTimeout is 30 seconds', () {
        expect(AppConfig.connectionTimeout, const Duration(seconds: 30));
      });

      test('receiveTimeout is 30 seconds', () {
        expect(AppConfig.receiveTimeout, const Duration(seconds: 30));
      });
    });

    group('URL configuration', () {
      test('userServiceUrl returns a valid URL string', () {
        final url = AppConfig.userServiceUrl;
        expect(url, isNotEmpty);
        expect(url, startsWith('http'));
      });

      test('videoServiceUrl returns a valid URL string', () {
        final url = AppConfig.videoServiceUrl;
        expect(url, isNotEmpty);
        expect(url, startsWith('http'));
      });

      test('webSocketUrl returns a valid URL string', () {
        final url = AppConfig.webSocketUrl;
        expect(url, isNotEmpty);
        expect(url, startsWith('ws'));
      });

      test('cloudFrontUrl returns string or null', () {
        final url = AppConfig.cloudFrontUrl;
        if (url != null) {
          expect(url, startsWith('https'));
        }
      });
    });

    group('isProduction', () {
      test('returns a boolean', () {
        expect(AppConfig.isProduction, isA<bool>());
      });
    });

    group('printConfig', () {
      test('does not throw', () {
        // Just verify it can be called without error
        AppConfig.printConfig();
      });
    });

    group('environment-based URLs', () {
      test('development user service URL contains port 3000', () {
        if (!AppConfig.isProduction) {
          expect(AppConfig.userServiceUrl, contains('3000'));
        }
      });

      test('development video service URL contains port 3002', () {
        if (!AppConfig.isProduction) {
          expect(AppConfig.videoServiceUrl, contains('3002'));
        }
      });

      test('production URLs point to AWS', () {
        if (AppConfig.isProduction) {
          expect(AppConfig.userServiceUrl, contains('18.138.223.226'));
          expect(AppConfig.videoServiceUrl, contains('18.138.223.226'));
        }
      });
    });
  });
}
