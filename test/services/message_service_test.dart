import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MessageService', () {
    late MessageService service;

    setUp(() {
      service = MessageService();
    });

    test('singleton returns same instance', () {
      final a = MessageService();
      final b = MessageService();
      expect(identical(a, b), true);
    });

    group('streams', () {
      test('newMessageStream is accessible', () {
        expect(service.newMessageStream, isA<Stream>());
      });

      test('messageSentStream is accessible', () {
        expect(service.messageSentStream, isA<Stream>());
      });

      test('messagesReadStream is accessible', () {
        expect(service.messagesReadStream, isA<Stream>());
      });

      test('userTypingStream is accessible', () {
        expect(service.userTypingStream, isA<Stream>());
      });

      test('onlineStatusStream is accessible', () {
        expect(service.onlineStatusStream, isA<Stream>());
      });

      test('messageUnsentStream is accessible', () {
        expect(service.messageUnsentStream, isA<Stream>());
      });

      test('messageEditedStream is accessible', () {
        expect(service.messageEditedStream, isA<Stream>());
      });

      test('messageDeletedForMeStream is accessible', () {
        expect(service.messageDeletedForMeStream, isA<Stream>());
      });

      test('privacySettingsChangedStream is accessible', () {
        expect(service.privacySettingsChangedStream, isA<Stream>());
      });

      test('newNotificationStream is accessible', () {
        expect(service.newNotificationStream, isA<Stream>());
      });

      test('themeColorChangedStream is accessible', () {
        expect(service.themeColorChangedStream, isA<Stream>());
      });
    });

    group('isConnected', () {
      test('returns false when not connected', () {
        expect(service.isConnected, false);
      });
    });

    group('currentUserId', () {
      test('is null when not connected', () {
        expect(service.currentUserId, isNull);
      });
    });

    group('getConversations', () {
      test('handles network error gracefully', () async {
        final result = await service.getConversations('user1');
        expect(result, isEmpty);
      });
    });

    group('getMessages', () {
      test('handles network error gracefully', () async {
        final result = await service.getMessages('user1', 'user2');
        expect(result, isEmpty);
      });
    });

    group('getUnreadCount', () {
      test('handles network error gracefully', () async {
        final result = await service.getUnreadCount('user1');
        expect(result, 0);
      });
    });

    group('sendMessage', () {
      test('handles network error gracefully', () async {
        final result = await service.sendMessage(
          recipientId: 'user2',
          content: 'Hello',
        );
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('getConversationSettings', () {
      test('handles network error gracefully', () async {
        final result = await service.getConversationSettings('user2');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('updateConversationSettings', () {
      test('handles network error gracefully', () async {
        final result = await service.updateConversationSettings(
          'user2',
          isMuted: true,
        );
        expect(result, false);
      });
    });

    group('markAsRead', () {
      test('handles disconnected state', () {
        // Should not throw even when disconnected
        service.markAsRead('conv1');
      });
    });

    group('sendTypingIndicator', () {
      test('handles disconnected state', () {
        // Should not throw even when disconnected
        service.sendTypingIndicator('user2', true);
      });
    });

    group('deleteForMe', () {
      test('handles network error gracefully', () async {
        final result = await service.deleteForMe('msg1');
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('deleteForEveryone', () {
      test('handles network error gracefully', () async {
        final result = await service.deleteForEveryone('msg1');
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('editMessage', () {
      test('handles network error gracefully', () async {
        final result = await service.editMessage('msg1', 'new content');
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('searchMessages', () {
      test('handles network error gracefully', () async {
        final result = await service.searchMessages('user2', 'search query');
        expect(result, isEmpty);
      });
    });

    group('getPinnedMessages', () {
      test('handles network error gracefully', () async {
        final result = await service.getPinnedMessages('user2');
        expect(result, isEmpty);
      });
    });

    group('pinMessage', () {
      test('handles network error gracefully', () async {
        final result = await service.pinMessage('msg1');
        expect(result, false);
      });
    });

    group('unpinMessage', () {
      test('handles network error gracefully', () async {
        final result = await service.unpinMessage('msg1');
        expect(result, false);
      });
    });

    group('getMediaMessages', () {
      test('handles network error gracefully', () async {
        final result = await service.getMediaMessages('user2');
        expect(result, isEmpty);
      });
    });

    group('translateMessage', () {
      test('handles network error gracefully', () async {
        final result = await service.translateMessage('Hello', 'vi');
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
      });
    });

    group('getOnlineStatus', () {
      test('handles network error gracefully', () async {
        final result = await service.getOnlineStatus('user1');
        expect(result['isOnline'], false);
      });
    });

    group('canUnsendMessage', () {
      test('returns false for non-sender', () {
        final msg = {
          'senderId': 'other_user',
          'createdAt': DateTime.now().toIso8601String(),
        };
        expect(service.canUnsendMessage(msg, 'user1'), false);
      });

      test('returns true for recent own message', () {
        final msg = {
          'senderId': 'user1',
          'createdAt': DateTime.now().toIso8601String(),
        };
        expect(service.canUnsendMessage(msg, 'user1'), true);
      });

      test('returns false for old message', () {
        final msg = {
          'senderId': 'user1',
          'createdAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
        };
        expect(service.canUnsendMessage(msg, 'user1'), false);
      });

      test('returns false for deleted message', () {
        final msg = {
          'senderId': 'user1',
          'createdAt': DateTime.now().toIso8601String(),
          'isDeletedForEveryone': true,
        };
        expect(service.canUnsendMessage(msg, 'user1'), false);
      });
    });

    group('getUnsendTimeRemaining', () {
      test('returns positive value for recent message', () {
        final msg = {
          'senderId': 'user1',
          'createdAt': DateTime.now().toIso8601String(),
        };
        expect(service.getUnsendTimeRemaining(msg), greaterThan(0));
      });

      test('returns 0 for old message', () {
        final msg = {
          'senderId': 'user1',
          'createdAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
        };
        expect(service.getUnsendTimeRemaining(msg), 0);
      });
    });

    group('canEditMessage', () {
      test('returns false for non-sender', () {
        final msg = {
          'senderId': 'other_user',
          'createdAt': DateTime.now().toIso8601String(),
          'type': 'text',
        };
        expect(service.canEditMessage(msg, 'user1'), false);
      });

      test('returns true for recent own text message', () {
        final msg = {
          'senderId': 'user1',
          'createdAt': DateTime.now().toIso8601String(),
          'type': 'text',
        };
        expect(service.canEditMessage(msg, 'user1'), true);
      });

      test('returns false for media message', () {
        final msg = {
          'senderId': 'user1',
          'createdAt': DateTime.now().toIso8601String(),
          'content': '[IMAGE:photo.jpg]',
        };
        expect(service.canEditMessage(msg, 'user1'), false);
      });
    });
  });
}
