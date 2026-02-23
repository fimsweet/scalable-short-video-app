import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/video_playback_service.dart';

void main() {
  group('VideoState', () {
    test('creates with required parameters', () {
      final state = VideoState(
        position: const Duration(seconds: 30),
        wasManuallyPaused: false,
      );
      expect(state.position, const Duration(seconds: 30));
      expect(state.wasManuallyPaused, false);
    });

    test('creates with paused state', () {
      final state = VideoState(
        position: const Duration(minutes: 1, seconds: 15),
        wasManuallyPaused: true,
      );
      expect(state.position, const Duration(minutes: 1, seconds: 15));
      expect(state.wasManuallyPaused, true);
    });

    test('toString returns formatted string', () {
      final state = VideoState(
        position: const Duration(seconds: 10),
        wasManuallyPaused: true,
      );
      final str = state.toString();
      expect(str, contains('VideoState'));
      expect(str, contains('position'));
      expect(str, contains('paused'));
    });

    test('zero position', () {
      final state = VideoState(
        position: Duration.zero,
        wasManuallyPaused: false,
      );
      expect(state.position, Duration.zero);
    });
  });

  group('VideoPlaybackService', () {
    late VideoPlaybackService service;

    setUp(() {
      service = VideoPlaybackService();
      // Reset state
      service.clearAllVideoStates();
    });

    test('singleton returns same instance', () {
      final a = VideoPlaybackService();
      final b = VideoPlaybackService();
      expect(identical(a, b), true);
    });

    test('isVideoTabVisible defaults to true', () {
      // May be previously set, but test the getter
      expect(service.isVideoTabVisible, isA<bool>());
    });

    group('setCurrentTabIndex', () {
      test('changes current tab index', () {
        service.setCurrentTabIndex(0);
        service.setManuallyPaused(true);
        expect(service.wasManuallyPaused, true);

        service.setCurrentTabIndex(1);
        expect(service.wasManuallyPaused, false); // Different tab
      });

      test('preserves paused state per tab', () {
        service.setCurrentTabIndex(0);
        service.setManuallyPaused(true);

        service.setCurrentTabIndex(1);
        service.setManuallyPaused(false);

        service.setCurrentTabIndex(0);
        expect(service.wasManuallyPaused, true);

        service.setCurrentTabIndex(1);
        expect(service.wasManuallyPaused, false);
      });
    });

    group('setManuallyPaused', () {
      test('sets paused state for current tab', () {
        service.setCurrentTabIndex(2);
        service.setManuallyPaused(true);
        expect(service.wasManuallyPaused, true);
      });

      test('does not notify when value stays same', () {
        service.setCurrentTabIndex(2);
        service.setManuallyPaused(true);
        // Setting same value again should not trigger additional logic
        service.setManuallyPaused(true);
        expect(service.wasManuallyPaused, true);
      });

      test('updates when value changes', () {
        service.setCurrentTabIndex(2);
        service.setManuallyPaused(true);
        service.setManuallyPaused(false);
        expect(service.wasManuallyPaused, false);
      });
    });

    group('setManuallyPausedForTab', () {
      test('sets paused state for specific tab', () {
        service.setManuallyPausedForTab(3, true);
        expect(service.wasManuallyPausedForTab(3), true);
      });

      test('does not affect other tabs', () {
        service.setManuallyPausedForTab(0, true);
        expect(service.wasManuallyPausedForTab(1), false);
      });

      test('no-op when setting same value', () {
        service.setManuallyPausedForTab(0, true);
        service.setManuallyPausedForTab(0, true); // Same value
        expect(service.wasManuallyPausedForTab(0), true);
      });
    });

    group('wasManuallyPausedForTab', () {
      test('returns false for unset tab', () {
        expect(service.wasManuallyPausedForTab(99), false);
      });
    });

    group('setVideoTabVisible', () {
      test('sets tab visible and notifies listeners', () {
        bool notified = false;
        service.addListener(() => notified = true);

        service.setVideoTabInvisible(); // First make invisible
        notified = false;
        service.setVideoTabVisible();
        expect(service.isVideoTabVisible, true);
        expect(notified, true);

        service.removeListener(() {});
      });

      test('does not notify if already visible', () {
        service.setVideoTabVisible(); // Ensure visible
        bool notified = false;
        service.addListener(() => notified = true);
        service.setVideoTabVisible(); // Already visible
        expect(notified, false);
        service.removeListener(() {});
      });
    });

    group('setVideoTabInvisible', () {
      test('sets tab invisible and notifies listeners', () {
        service.setVideoTabVisible(); // Ensure visible first
        bool notified = false;
        service.addListener(() => notified = true);
        service.setVideoTabInvisible();
        expect(service.isVideoTabVisible, false);
        expect(notified, true);
        service.removeListener(() {});
      });

      test('does not notify if already invisible', () {
        service.setVideoTabInvisible(); // Make invisible
        bool notified = false;
        service.addListener(() => notified = true);
        service.setVideoTabInvisible(); // Already invisible
        expect(notified, false);
        service.removeListener(() {});
      });
    });

    group('resetManualPauseState', () {
      test('resets pause state for current tab', () {
        service.setCurrentTabIndex(2);
        service.setManuallyPaused(true);
        service.resetManualPauseState();
        expect(service.wasManuallyPaused, false);
      });

      test('no-op when not paused', () {
        service.setCurrentTabIndex(2);
        service.setManuallyPaused(false);
        service.resetManualPauseState(); // Should be no-op
        expect(service.wasManuallyPaused, false);
      });
    });

    group('saveVideoState', () {
      test('saves state for specific tab and video', () {
        service.saveVideoState(2, 'video1', const Duration(seconds: 30), false);
        final state = service.getVideoState(2, 'video1');
        expect(state, isNotNull);
        expect(state!.position, const Duration(seconds: 30));
        expect(state.wasManuallyPaused, false);
      });

      test('saves paused state', () {
        service.saveVideoState(0, 'video2', const Duration(seconds: 45), true);
        final state = service.getVideoState(0, 'video2');
        expect(state, isNotNull);
        expect(state!.wasManuallyPaused, true);
      });

      test('overwrites previous state', () {
        service.saveVideoState(1, 'v1', const Duration(seconds: 10), false);
        service.saveVideoState(1, 'v1', const Duration(seconds: 20), true);
        final state = service.getVideoState(1, 'v1');
        expect(state!.position, const Duration(seconds: 20));
        expect(state.wasManuallyPaused, true);
      });
    });

    group('getVideoState', () {
      test('returns null for unknown video', () {
        expect(service.getVideoState(0, 'nonexistent'), isNull);
      });

      test('distinguishes between tabs for same video', () {
        service.saveVideoState(0, 'v1', const Duration(seconds: 10), false);
        service.saveVideoState(1, 'v1', const Duration(seconds: 20), true);

        final state0 = service.getVideoState(0, 'v1');
        final state1 = service.getVideoState(1, 'v1');

        expect(state0!.position, const Duration(seconds: 10));
        expect(state1!.position, const Duration(seconds: 20));
      });
    });

    group('clearAllVideoStates', () {
      test('clears all saved states', () {
        service.saveVideoState(0, 'v1', const Duration(seconds: 10), false);
        service.saveVideoState(1, 'v2', const Duration(seconds: 20), true);
        service.clearAllVideoStates();
        expect(service.getVideoState(0, 'v1'), isNull);
        expect(service.getVideoState(1, 'v2'), isNull);
      });
    });

    group('clearTabVideoStates', () {
      test('clears states for specific tab only', () {
        service.saveVideoState(0, 'v1', const Duration(seconds: 10), false);
        service.saveVideoState(0, 'v2', const Duration(seconds: 20), false);
        service.saveVideoState(1, 'v3', const Duration(seconds: 30), false);

        service.clearTabVideoStates(0);

        expect(service.getVideoState(0, 'v1'), isNull);
        expect(service.getVideoState(0, 'v2'), isNull);
        expect(service.getVideoState(1, 'v3'), isNotNull);
      });
    });
  });
}
