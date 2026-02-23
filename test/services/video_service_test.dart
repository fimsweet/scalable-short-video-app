import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoService', () {
    late VideoService service;

    setUp(() {
      service = VideoService();
    });

    test('singleton returns same instance', () {
      final a = VideoService();
      final b = VideoService();
      expect(identical(a, b), true);
    });

    group('getVideoById', () {
      test('handles network error gracefully', () async {
        final result = await service.getVideoById('video1');
        expect(result, isNull);
      });
    });

    group('incrementViewCount', () {
      test('handles network error gracefully', () async {
        // Should not throw
        await service.incrementViewCount('video1');
      });
    });

    group('getUserVideos', () {
      test('handles network error gracefully', () async {
        final result = await service.getUserVideos('user1');
        expect(result, isEmpty);
      });
    });

    group('getAllVideos', () {
      test('handles network error gracefully', () async {
        final result = await service.getAllVideos();
        expect(result, isEmpty);
      });
    });

    group('getVideoUrl', () {
      test('returns a URL string', () {
        final url = service.getVideoUrl('test-video-path');
        expect(url, isA<String>());
        expect(url, isNotEmpty);
      });
    });

    group('getVideosByUserIdWithPrivacy', () {
      test('handles network error gracefully', () async {
        final result = await service.getVideosByUserIdWithPrivacy('user1', requesterId: 'requester1');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('getFollowingVideos', () {
      test('handles network error gracefully', () async {
        final result = await service.getFollowingVideos('user1');
        expect(result, isEmpty);
      });
    });

    group('getFriendsVideos', () {
      test('handles network error gracefully', () async {
        final result = await service.getFriendsVideos('user1');
        expect(result, isEmpty);
      });
    });

    group('searchVideos', () {
      test('handles network error gracefully', () async {
        final result = await service.searchVideos('test query');
        expect(result, isEmpty);
      });
    });

    group('toggleHideVideo', () {
      test('rethrows network error', () async {
        expect(
          () => service.toggleHideVideo('video1', 'user1'),
          throwsA(anything),
        );
      });
    });

    group('deleteVideo', () {
      test('rethrows network error', () async {
        expect(
          () => service.deleteVideo('video1', 'user1'),
          throwsA(anything),
        );
      });
    });

    group('getRecommendedVideos', () {
      test('handles network error gracefully', () async {
        final result = await service.getRecommendedVideos(1);
        expect(result, isA<List>());
      });
    });

    group('getTrendingVideos', () {
      test('handles network error gracefully', () async {
        final result = await service.getTrendingVideos();
        expect(result, isEmpty);
      });
    });

    group('updateVideoPrivacy', () {
      test('handles network error by rethrowing', () async {
        expect(
          () => service.updateVideoPrivacy(
            videoId: 'video1',
            userId: 'user1',
            visibility: 'public',
          ),
          throwsException,
        );
      });
    });

    group('editVideo', () {
      test('rethrows network error', () async {
        expect(
          () => service.editVideo(
            videoId: 'video1',
            userId: 'user1',
            title: 'Updated title',
          ),
          throwsA(anything),
        );
      });
    });

    group('retryVideo', () {
      test('handles network error gracefully', () async {
        final result = await service.retryVideo(videoId: 'video1', userId: 'user1');
        expect(result, isA<Map<String, dynamic>>());
      });
    });
  });
}
