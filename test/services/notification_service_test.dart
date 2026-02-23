import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService();
      service.stopPolling();
    });

    tearDown(() {
      service.stopPolling();
    });

    test('singleton returns same instance', () {
      final a = NotificationService();
      final b = NotificationService();
      expect(identical(a, b), true);
    });

    group('streams', () {
      test('unreadCountStream is accessible', () {
        expect(service.unreadCountStream, isA<Stream<int>>());
      });

      test('pendingFollowCountStream is accessible', () {
        expect(service.pendingFollowCountStream, isA<Stream<int>>());
      });
    });

    group('getNotifications', () {
      test('handles network error gracefully', () async {
        final notifications = await service.getNotifications('user1');
        expect(notifications, isEmpty);
      });
    });

    group('getUnreadCount', () {
      test('handles network error gracefully', () async {
        final count = await service.getUnreadCount('user1');
        expect(count, 0);
      });
    });

    group('getPendingFollowCount', () {
      test('handles network error gracefully', () async {
        final count = await service.getPendingFollowCount('user1');
        expect(count, 0);
      });
    });

    group('markAsRead', () {
      test('handles network error gracefully', () async {
        final result = await service.markAsRead('notif1', 'user1');
        expect(result, false);
      });
    });

    group('markAllAsRead', () {
      test('handles network error gracefully', () async {
        final result = await service.markAllAsRead('user1');
        expect(result, false);
      });
    });

    group('deleteNotification', () {
      test('handles network error gracefully', () async {
        final result = await service.deleteNotification('notif1', 'user1');
        expect(result, false);
      });
    });

    group('polling', () {
      test('startPolling does not throw', () {
        service.startPolling('user1');
        // Give it a moment then stop
        service.stopPolling();
      });

      test('stopPolling does not throw when not polling', () {
        service.stopPolling(); // Should be safe to call
      });

      test('can restart polling', () {
        service.startPolling('user1');
        service.stopPolling();
        service.startPolling('user2');
        service.stopPolling();
      });
    });
  });
}
