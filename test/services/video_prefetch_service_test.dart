import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/video_prefetch_service.dart';

void main() {
  group('VideoPrefetchService', () {
    late VideoPrefetchService service;

    setUp(() {
      service = VideoPrefetchService();
      service.clearCache();
    });

    test('singleton returns same instance', () {
      final a = VideoPrefetchService();
      final b = VideoPrefetchService();
      expect(identical(a, b), true);
    });

    group('isPrefetched', () {
      test('returns false for unseen URL', () {
        expect(service.isPrefetched('https://example.com/video.m3u8'), false);
      });
    });

    group('clearCache', () {
      test('clears all cached entries', () {
        service.clearCache();
        expect(service.isPrefetched('any_url'), false);
      });
    });

    group('getStats', () {
      test('returns stats map', () {
        final stats = service.getStats();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('cachedUrls'), true);
        expect(stats.containsKey('pendingPrefetch'), true);
        expect(stats.containsKey('successRate'), true);
      });

      test('cached count starts at 0 after clear', () {
        service.clearCache();
        final stats = service.getStats();
        expect(stats['cachedUrls'], 0);
      });
    });

    group('prefetchVideosAround', () {
      test('handles empty video list', () async {
        await service.prefetchVideosAround([], 0);
        // Should not throw
      });

      test('handles index out of bounds gracefully', () async {
        final videos = [
          {'hlsUrl': '/path/to/video.m3u8'},
        ];
        await service.prefetchVideosAround(videos, 5);
        // Should not throw even with out-of-bounds index
      });

      test('handles videos without hlsUrl', () async {
        final videos = [
          {'title': 'No URL'},
          {'url': '/some/other/path'},
        ];
        await service.prefetchVideosAround(videos, 0);
        // Should not throw
      });

      test('handles videos with hlsUrl', () async {
        final videos = [
          {'hlsUrl': '/path/to/video1.m3u8'},
          {'hlsUrl': '/path/to/video2.m3u8'},
          {'hlsUrl': '/path/to/video3.m3u8'},
        ];
        // Since there's no server, HTTP HEAD will fail silently
        await service.prefetchVideosAround(videos, 1);
        // Should handle the error gracefully
      });
    });
  });
}
