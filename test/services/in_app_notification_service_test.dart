import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/in_app_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InAppNotificationType', () {
    test('has all expected values', () {
      expect(InAppNotificationType.values.length, 5);
      expect(InAppNotificationType.values, contains(InAppNotificationType.like));
      expect(InAppNotificationType.values, contains(InAppNotificationType.comment));
      expect(InAppNotificationType.values, contains(InAppNotificationType.follow));
      expect(InAppNotificationType.values, contains(InAppNotificationType.mention));
      expect(InAppNotificationType.values, contains(InAppNotificationType.message));
    });
  });

  group('InAppNotification', () {
    test('creates with required parameters', () {
      final notification = InAppNotification(
        type: InAppNotificationType.like,
        title: 'New Like',
        body: 'Someone liked your video',
        senderId: 'sender1',
        senderName: 'TestUser',
        rawData: {'key': 'value'},
      );
      expect(notification.type, InAppNotificationType.like);
      expect(notification.title, 'New Like');
      expect(notification.body, 'Someone liked your video');
      expect(notification.senderId, 'sender1');
      expect(notification.senderName, 'TestUser');
      expect(notification.rawData, {'key': 'value'});
      expect(notification.timestamp, isA<DateTime>());
    });

    test('creates with optional parameters', () {
      final notification = InAppNotification(
        type: InAppNotificationType.comment,
        title: 'New Comment',
        body: 'Someone commented',
        avatarUrl: 'https://example.com/avatar.jpg',
        senderId: 'sender2',
        senderName: 'Commenter',
        videoId: 'video123',
        commentId: 'comment456',
        conversationId: 'conv789',
        rawData: {},
      );
      expect(notification.avatarUrl, 'https://example.com/avatar.jpg');
      expect(notification.videoId, 'video123');
      expect(notification.commentId, 'comment456');
      expect(notification.conversationId, 'conv789');
    });

    test('creates with null optional parameters', () {
      final notification = InAppNotification(
        type: InAppNotificationType.follow,
        title: 'New Follower',
        body: 'Someone followed you',
        senderId: 'sender3',
        senderName: 'Follower',
        rawData: {},
      );
      expect(notification.avatarUrl, isNull);
      expect(notification.videoId, isNull);
      expect(notification.commentId, isNull);
      expect(notification.conversationId, isNull);
    });

    test('timestamp is set to current time', () {
      final before = DateTime.now();
      final notification = InAppNotification(
        type: InAppNotificationType.mention,
        title: 'Mention',
        body: 'You were mentioned',
        senderId: 's',
        senderName: 'n',
        rawData: {},
      );
      final after = DateTime.now();
      expect(notification.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(notification.timestamp.isBefore(after.add(const Duration(seconds: 1))), true);
    });
  });

  group('InAppNotificationService', () {
    late InAppNotificationService service;

    setUp(() {
      service = InAppNotificationService();
      service.setActiveVideo(null);
      service.setInInboxScreen(false);
      service.setActiveChatUser(null);
    });

    test('singleton returns same instance', () {
      final a = InAppNotificationService();
      final b = InAppNotificationService();
      expect(identical(a, b), true);
    });

    group('streams', () {
      test('notificationStream is accessible', () {
        expect(service.notificationStream, isA<Stream<InAppNotification>>());
      });

      test('notificationTapStream is accessible', () {
        expect(service.notificationTapStream, isA<Stream<InAppNotification>>());
      });
    });

    group('setActiveVideo', () {
      test('sets active video ID', () {
        service.setActiveVideo('video1');
        // Can't verify directly but shouldn't throw
      });

      test('sets null active video', () {
        service.setActiveVideo(null);
        // Should not throw
      });
    });

    group('setInInboxScreen', () {
      test('sets inbox screen state', () {
        service.setInInboxScreen(true);
        // Should not throw
        service.setInInboxScreen(false);
      });
    });

    group('setActiveChatUser', () {
      test('sets active chat user', () {
        service.setActiveChatUser('user1');
        // Should not throw
        service.setActiveChatUser(null);
      });
    });

    group('emitTap', () {
      test('emits tap event to stream', () async {
        final notification = InAppNotification(
          type: InAppNotificationType.like,
          title: 'Test',
          body: 'Test body',
          senderId: 'sender1',
          senderName: 'Test',
          rawData: {},
        );

        final future = service.notificationTapStream.first;
        service.emitTap(notification);
        final result = await future;
        expect(result.title, 'Test');
      });
    });

    group('invalidatePreferences', () {
      test('clears cached preferences', () {
        service.invalidatePreferences();
        // Should not throw
      });
    });

    group('showNotification', () {
      test('returns false when no user is logged in', () async {
        final notification = InAppNotification(
          type: InAppNotificationType.like,
          title: 'Test',
          body: 'Test body',
          senderId: 'sender1',
          senderName: 'Test',
          rawData: {},
        );
        // No user logged in, should return false
        final result = await service.showNotification(notification);
        expect(result, false);
      });
    });
  });
}
