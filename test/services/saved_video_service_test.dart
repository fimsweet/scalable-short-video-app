import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/saved_video_service.dart';

void main() {
  group('SavedVideoService', () {
    late SavedVideoService service;

    setUp(() {
      service = SavedVideoService();
      SavedVideoService.clearCache();
    });

    test('singleton returns same instance', () {
      final a = SavedVideoService();
      final b = SavedVideoService();
      expect(identical(a, b), true);
    });

    group('cache operations', () {
      test('getCached returns null for unknown video', () {
        expect(service.getCached('unknown'), isNull);
      });

      test('getCachedCount returns null for unknown video', () {
        expect(service.getCachedCount('unknown'), isNull);
      });

      test('clearCache empties all caches', () {
        SavedVideoService.clearCache();
        expect(service.getCached('any'), isNull);
        expect(service.getCachedCount('any'), isNull);
      });
    });

    group('toggleSave', () {
      test('handles network error gracefully', () async {
        final result = await service.toggleSave('video1', 'user1');
        expect(result, isA<Map<String, dynamic>>());
        expect(result['saved'], false);
      });
    });

    group('isSavedByUser', () {
      test('handles network error with fallback to cache', () async {
        final saved = await service.isSavedByUser('video1', 'user1');
        expect(saved, false);
      });
    });

    group('getSavedVideos', () {
      test('handles network error gracefully', () async {
        final videos = await service.getSavedVideos('user1');
        expect(videos, isEmpty);
      });
    });
  });
}
