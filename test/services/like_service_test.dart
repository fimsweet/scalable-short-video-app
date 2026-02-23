import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/like_service.dart';

void main() {
  group('LikeService', () {
    late LikeService service;

    setUp(() {
      service = LikeService();
      LikeService.clearCache();
    });

    test('singleton returns same instance', () {
      final a = LikeService();
      final b = LikeService();
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
        // The cache is static, so we can't easily pre-fill without HTTP calls
        LikeService.clearCache();
        expect(service.getCached('any'), isNull);
        expect(service.getCachedCount('any'), isNull);
      });
    });

    group('likeChangeNotifier', () {
      test('is accessible', () {
        expect(LikeService.likeChangeNotifier, isNotNull);
        expect(LikeService.likeChangeNotifier.value, isA<int>());
      });
    });

    group('toggleLike', () {
      test('handles network error gracefully', () async {
        final result = await service.toggleLike('video1', 'user1');
        expect(result, isA<Map<String, dynamic>>());
        expect(result['liked'], false);
        expect(result['likeCount'], 0);
      });
    });

    group('getLikeCount', () {
      test('handles network error gracefully', () async {
        final count = await service.getLikeCount('video1');
        expect(count, 0);
      });
    });

    group('isLikedByUser', () {
      test('handles network error with fallback to cache', () async {
        final liked = await service.isLikedByUser('video1', 'user1');
        expect(liked, false); // No cache, defaults to false
      });
    });

    group('getUserLikedVideos', () {
      test('handles network error gracefully', () async {
        final videos = await service.getUserLikedVideos('user1');
        expect(videos, isEmpty);
      });
    });

    group('getTotalReceivedLikes', () {
      test('handles network error gracefully', () async {
        final count = await service.getTotalReceivedLikes('user1');
        expect(count, 0);
      });
    });
  });
}
