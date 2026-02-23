import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/analytics_tracking_service.dart';

void main() {
  group('AnalyticsTrackingService', () {
    late AnalyticsTrackingService service;

    setUp(() {
      service = AnalyticsTrackingService();
      service.resetTrackedViews();
    });

    test('singleton returns same instance', () {
      final a = AnalyticsTrackingService();
      final b = AnalyticsTrackingService();
      expect(identical(a, b), true);
    });

    group('startWatching', () {
      test('starts tracking video', () {
        service.startWatching('video1');
        expect(service.isWatching('video1'), true);
      });

      test('can track multiple videos', () {
        service.startWatching('video1');
        service.startWatching('video2');
        expect(service.isWatching('video1'), true);
        expect(service.isWatching('video2'), true);
      });
    });

    group('stopWatching', () {
      test('returns 0 if video was not being watched', () {
        expect(service.stopWatching('unknown'), 0);
      });

      test('returns duration and stops tracking', () {
        service.startWatching('video1');
        // Small delay to ensure duration > 0
        final duration = service.stopWatching('video1');
        expect(duration, isA<int>());
        expect(duration, greaterThanOrEqualTo(0));
        expect(service.isWatching('video1'), false);
      });

      test('accumulates watch duration', () {
        service.startWatching('video1');
        service.stopWatching('video1');
        final firstDuration = service.getWatchDuration('video1');

        service.startWatching('video1');
        service.stopWatching('video1');
        final totalDuration = service.getWatchDuration('video1');

        expect(totalDuration, greaterThanOrEqualTo(firstDuration));
      });
    });

    group('shouldCountView', () {
      test('returns true for first view', () {
        expect(service.shouldCountView('video1'), true);
      });

      test('returns false for duplicate view', () {
        service.shouldCountView('video1');
        expect(service.shouldCountView('video1'), false);
      });

      test('returns true for different videos', () {
        service.shouldCountView('video1');
        expect(service.shouldCountView('video2'), true);
      });
    });

    group('resetTrackedViews', () {
      test('clears all tracking data', () {
        service.startWatching('video1');
        service.shouldCountView('video1');
        service.stopWatching('video1');

        service.resetTrackedViews();

        expect(service.isWatching('video1'), false);
        expect(service.shouldCountView('video1'), true); // Can count again
        expect(service.getWatchDuration('video1'), 0);
      });
    });

    group('getWatchDuration', () {
      test('returns 0 for unwatched video', () {
        expect(service.getWatchDuration('unknown'), 0);
      });
    });

    group('isWatching', () {
      test('returns false for untracked video', () {
        expect(service.isWatching('unknown'), false);
      });

      test('returns true when actively watching', () {
        service.startWatching('video1');
        expect(service.isWatching('video1'), true);
      });

      test('returns false after stopping', () {
        service.startWatching('video1');
        service.stopWatching('video1');
        expect(service.isWatching('video1'), false);
      });
    });

    group('trackInteraction', () {
      test('handles network error gracefully', () async {
        // This will fail due to no server, but should not throw
        await service.trackInteraction(
          videoId: 'video1',
          userId: 'user1',
          type: InteractionType.like,
        );
        // If we reach here, error was handled gracefully
      });

      test('handles all interaction types', () async {
        for (final type in InteractionType.values) {
          await service.trackInteraction(
            videoId: 'video1',
            userId: 'user1',
            type: type,
          );
        }
        // All should complete without throwing
      });
    });

    group('trackVideoCompletion', () {
      test('handles network error gracefully', () async {
        await service.trackVideoCompletion(
          videoId: 'video1',
          userId: 'user1',
          watchDurationSeconds: 30,
          videoDurationSeconds: 60,
        );
        // Should not throw
      });

      test('handles zero video duration', () async {
        await service.trackVideoCompletion(
          videoId: 'video1',
          userId: 'user1',
          watchDurationSeconds: 10,
          videoDurationSeconds: 0,
        );
        // Should not throw - completion rate would be 0
      });
    });
  });

  group('InteractionType', () {
    test('has all expected values', () {
      expect(InteractionType.values, contains(InteractionType.like));
      expect(InteractionType.values, contains(InteractionType.unlike));
      expect(InteractionType.values, contains(InteractionType.comment));
      expect(InteractionType.values, contains(InteractionType.share));
      expect(InteractionType.values, contains(InteractionType.save));
      expect(InteractionType.values, contains(InteractionType.unsave));
      expect(InteractionType.values, contains(InteractionType.follow));
      expect(InteractionType.values, contains(InteractionType.unfollow));
    });

    test('has correct count', () {
      expect(InteractionType.values.length, 8);
    });
  });
}
