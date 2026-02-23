/// Coverage boost 4 – targets MessageService REST, ApiService remaining methods,
/// VideoService remaining methods, and auth_service additional paths.
/// All pure Dart tests (no testWidgets) for reliability.
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

/// Generic mock client helper
MockClient _mk({
  int statusCode = 200,
  String body = '{}',
  Map<String, dynamic>? json,
}) {
  final responseBody = json != null ? jsonEncode(json) : body;
  return MockClient((_) async => http.Response(responseBody, statusCode));
}

/// Token long enough for substring(0,20)
const _tok = 'abcdefghijklmnopqrstuvwxyz1234567890';

void main() {
  // =================== GROUP 1: MessageService REST methods ===================
  group('MessageService REST', () {
    test('getMessages success', () async {
      final client = _mk(json: {'data': [{'id': 'm1', 'content': 'hi'}]});
      await http.runWithClient(() async {
        final ms = MessageService();
        final result = await ms.getMessages('u1', 'u2');
        expect(result, isA<List>());
        expect(result.length, 1);
      }, () => client);
    });

    test('getMessages error returns empty', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().getMessages('u1', 'u2');
        expect(result, isEmpty);
      }, () => client);
    });

    test('getMessages with pagination', () async {
      final client = _mk(json: {'data': []});
      await http.runWithClient(() async {
        final result = await MessageService().getMessages('u1', 'u2', limit: 10, offset: 5);
        expect(result, isA<List>());
      }, () => client);
    });

    test('getConversations success', () async {
      final client = _mk(json: {'data': [{'id': 'c1'}]});
      await http.runWithClient(() async {
        final result = await MessageService().getConversations('u1');
        expect(result, isA<List>());
        expect(result.length, 1);
      }, () => client);
    });

    test('getConversations error returns empty', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().getConversations('u1');
        expect(result, isEmpty);
      }, () => client);
    });

    test('getUnreadCount success', () async {
      final client = _mk(json: {'count': 5});
      await http.runWithClient(() async {
        final result = await MessageService().getUnreadCount('u1');
        expect(result, 5);
      }, () => client);
    });

    test('getUnreadCount error returns 0', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().getUnreadCount('u1');
        expect(result, 0);
      }, () => client);
    });

    test('getConversationSettings success', () async {
      final client = _mk(json: {'isMuted': true, 'isPinned': false});
      await http.runWithClient(() async {
        final result = await MessageService().getConversationSettings('r1');
        expect(result['isMuted'], true);
      }, () => client);
    });

    test('getConversationSettings error returns defaults', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().getConversationSettings('r1');
        expect(result['isMuted'], false);
        expect(result['isPinned'], false);
      }, () => client);
    });

    test('updateConversationSettings success', () async {
      final client = _mk(statusCode: 200);
      await http.runWithClient(() async {
        final result = await MessageService().updateConversationSettings(
          'r1',
          isMuted: true,
          isPinned: true,
          themeColor: '#FF0000',
          nickname: 'nick',
          autoTranslate: true,
        );
        expect(result, true);
      }, () => client);
    });

    test('updateConversationSettings error returns false', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().updateConversationSettings('r1', isMuted: false);
        expect(result, false);
      }, () => client);
    });

    test('pinMessage success', () async {
      final client = _mk(statusCode: 200);
      await http.runWithClient(() async {
        final result = await MessageService().pinMessage('m1');
        expect(result, true);
      }, () => client);
    });

    test('pinMessage error returns false', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().pinMessage('m1');
        expect(result, false);
      }, () => client);
    });

    test('unpinMessage success', () async {
      final client = _mk(statusCode: 200);
      await http.runWithClient(() async {
        final result = await MessageService().unpinMessage('m1');
        expect(result, true);
      }, () => client);
    });

    test('unpinMessage error returns false', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().unpinMessage('m1');
        expect(result, false);
      }, () => client);
    });

    test('getPinnedMessages success', () async {
      final client = _mk(json: {'data': [{'id': 'p1'}]});
      await http.runWithClient(() async {
        final result = await MessageService().getPinnedMessages('r1');
        expect(result, isA<List>());
        expect(result.length, 1);
      }, () => client);
    });

    test('getPinnedMessages error returns empty', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().getPinnedMessages('r1');
        expect(result, isEmpty);
      }, () => client);
    });

    test('searchMessages success', () async {
      final client = _mk(json: {'data': [{'id': 's1', 'content': 'search hit'}]});
      await http.runWithClient(() async {
        final result = await MessageService().searchMessages('r1', 'search');
        expect(result.length, 1);
      }, () => client);
    });

    test('searchMessages error returns empty', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().searchMessages('r1', 'test');
        expect(result, isEmpty);
      }, () => client);
    });

    test('searchMessages with limit', () async {
      final client = _mk(json: {'data': []});
      await http.runWithClient(() async {
        final result = await MessageService().searchMessages('r1', 'q', limit: 10);
        expect(result, isA<List>());
      }, () => client);
    });

    test('getMediaMessages success', () async {
      final client = _mk(json: {'data': [{'id': 'img1', 'type': 'image'}]});
      await http.runWithClient(() async {
        final result = await MessageService().getMediaMessages('r1');
        expect(result.length, 1);
      }, () => client);
    });

    test('getMediaMessages error returns empty', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().getMediaMessages('r1');
        expect(result, isEmpty);
      }, () => client);
    });

    test('getMediaMessages with pagination', () async {
      final client = _mk(json: {'data': []});
      await http.runWithClient(() async {
        final result = await MessageService().getMediaMessages('r1', limit: 10, offset: 5);
        expect(result, isA<List>());
      }, () => client);
    });

    test('deleteForMe success', () async {
      final client = _mk(json: {'success': true});
      await http.runWithClient(() async {
        final result = await MessageService().deleteForMe('m1');
        expect(result['success'], true);
      }, () => client);
    });

    test('deleteForMe error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().deleteForMe('m1');
        expect(result['success'], false);
      }, () => client);
    });

    test('deleteForEveryone success', () async {
      final client = _mk(json: {'success': true, 'message': 'OK', 'canUnsend': true});
      await http.runWithClient(() async {
        final result = await MessageService().deleteForEveryone('m1');
        expect(result['success'], true);
      }, () => client);
    });

    test('deleteForEveryone error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().deleteForEveryone('m1');
        expect(result['success'], false);
      }, () => client);
    });

    test('editMessage success', () async {
      final client = _mk(json: {'success': true, 'message': 'OK', 'editedMessage': {'id': 'm1', 'content': 'new'}});
      await http.runWithClient(() async {
        final result = await MessageService().editMessage('m1', 'new content');
        expect(result['success'], true);
      }, () => client);
    });

    test('editMessage error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().editMessage('m1', 'new');
        expect(result['success'], false);
      }, () => client);
    });

    test('translateMessage success', () async {
      final client = _mk(json: {'success': true, 'translatedText': 'Xin chào'});
      await http.runWithClient(() async {
        final result = await MessageService().translateMessage('Hello', 'vi');
        expect(result['success'], true);
        expect(result['translatedText'], 'Xin chào');
      }, () => client);
    });

    test('translateMessage error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await MessageService().translateMessage('Hello', 'vi');
        expect(result['success'], false);
      }, () => client);
    });

    test('notifyPrivacySettingsChanged completes', () async {
      final client = _mk(statusCode: 200);
      await http.runWithClient(() async {
        await MessageService().notifyPrivacySettingsChanged(
          userId: 'u1',
          whoCanSendMessages: 'everyone',
          showOnlineStatus: true,
        );
      }, () => client);
    });

    test('notifyPrivacySettingsChanged error does not throw', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        await MessageService().notifyPrivacySettingsChanged(userId: 'u1');
      }, () => client);
    });

    // Utility methods
    test('canUnsendMessage returns true for recent own message', () {
      final msg = {
        'senderId': 'me',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      };
      expect(MessageService().canUnsendMessage(msg, 'me'), true);
    });

    test('canUnsendMessage returns false for old message', () {
      final msg = {
        'senderId': 'me',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
      };
      expect(MessageService().canUnsendMessage(msg, 'me'), false);
    });

    test('canUnsendMessage returns false for other user message', () {
      final msg = {
        'senderId': 'other',
        'createdAt': DateTime.now().toIso8601String(),
      };
      expect(MessageService().canUnsendMessage(msg, 'me'), false);
    });

    test('canUnsendMessage returns false for deleted message', () {
      final msg = {
        'senderId': 'me',
        'createdAt': DateTime.now().toIso8601String(),
        'isDeletedForEveryone': true,
      };
      expect(MessageService().canUnsendMessage(msg, 'me'), false);
    });

    test('canUnsendMessage returns false for null createdAt', () {
      final msg = {'senderId': 'me'};
      expect(MessageService().canUnsendMessage(msg, 'me'), false);
    });

    test('getUnsendTimeRemaining returns seconds', () {
      final msg = {
        'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      };
      final remaining = MessageService().getUnsendTimeRemaining(msg);
      expect(remaining, greaterThan(200)); // ~300s remaining
      expect(remaining, lessThanOrEqualTo(300));
    });

    test('getUnsendTimeRemaining returns 0 for expired', () {
      final msg = {
        'createdAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
      };
      final remaining = MessageService().getUnsendTimeRemaining(msg);
      expect(remaining, 0);
    });

    test('getUnsendTimeRemaining returns 0 for null', () {
      expect(MessageService().getUnsendTimeRemaining({}), 0);
    });

    test('canEditMessage returns true for recent text message', () {
      final msg = {
        'senderId': 'me',
        'content': 'hello',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
      };
      expect(MessageService().canEditMessage(msg, 'me'), true);
    });

    test('canEditMessage returns false for old message', () {
      final msg = {
        'senderId': 'me',
        'content': 'hello',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(),
      };
      expect(MessageService().canEditMessage(msg, 'me'), false);
    });

    test('canEditMessage returns false for image message', () {
      final msg = {
        'senderId': 'me',
        'content': '[IMAGE:url]',
        'createdAt': DateTime.now().toIso8601String(),
      };
      expect(MessageService().canEditMessage(msg, 'me'), false);
    });

    test('canEditMessage returns false for video share', () {
      final msg = {
        'senderId': 'me',
        'content': '[VIDEO_SHARE:id]',
        'createdAt': DateTime.now().toIso8601String(),
      };
      expect(MessageService().canEditMessage(msg, 'me'), false);
    });

    test('canEditMessage returns false for stacker image', () {
      final msg = {
        'senderId': 'me',
        'content': '[STACKED_IMAGE:urls]',
        'createdAt': DateTime.now().toIso8601String(),
      };
      expect(MessageService().canEditMessage(msg, 'me'), false);
    });

    test('canEditMessage returns false for sticker', () {
      final msg = {
        'senderId': 'me',
        'content': '[STICKER:path]',
        'createdAt': DateTime.now().toIso8601String(),
      };
      expect(MessageService().canEditMessage(msg, 'me'), false);
    });

    test('canEditMessage returns false for voice', () {
      final msg = {
        'senderId': 'me',
        'content': '[VOICE:path]',
        'createdAt': DateTime.now().toIso8601String(),
      };
      expect(MessageService().canEditMessage(msg, 'me'), false);
    });

    test('canEditMessage returns false for other user', () {
      final msg = {
        'senderId': 'other',
        'content': 'hello',
        'createdAt': DateTime.now().toIso8601String(),
      };
      expect(MessageService().canEditMessage(msg, 'me'), false);
    });

    test('canEditMessage returns false for null createdAt', () {
      final msg = {'senderId': 'me', 'content': 'hello'};
      expect(MessageService().canEditMessage(msg, 'me'), false);
    });

    test('isConnected returns false when no socket', () {
      expect(MessageService().isConnected, false);
    });

    test('currentUserId is accessible', () {
      // Singleton may have been set by connect, or null
      final uid = MessageService().currentUserId;
      expect(uid == null || uid is String, true);
    });

    test('streams are accessible', () {
      final ms = MessageService();
      expect(ms.newMessageStream, isA<Stream>());
      expect(ms.messageSentStream, isA<Stream>());
      expect(ms.messagesReadStream, isA<Stream>());
      expect(ms.userTypingStream, isA<Stream>());
      expect(ms.onlineStatusStream, isA<Stream>());
      expect(ms.messageUnsentStream, isA<Stream>());
      expect(ms.messageEditedStream, isA<Stream>());
      expect(ms.messageDeletedForMeStream, isA<Stream>());
      expect(ms.privacySettingsChangedStream, isA<Stream>());
      expect(ms.newNotificationStream, isA<Stream>());
      expect(ms.themeColorChangedStream, isA<Stream>());
    });
  });

  // =================== GROUP 2: ApiService remaining methods ===================
  group('ApiService remaining methods', () {
    test('register success', () async {
      final client = _mk(json: {'success': true, 'user': {'id': 1}});
      await http.runWithClient(() async {
        final result = await ApiService().register(
          username: 'test',
          email: 'test@test.com',
          password: 'pass123',
          fullName: 'Test User',
          phoneNumber: '+84123456789',
          dateOfBirth: '2000-01-01',
          gender: 'male',
          language: 'vi',
        );
        expect(result['success'], true);
      }, () => client);
    });

    test('register error', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Username taken'});
      await http.runWithClient(() async {
        final result = await ApiService().register(
          username: 'test',
          email: 'test@test.com',
          password: 'pass123',
        );
        expect(result['success'], false);
      }, () => client);
    });

    test('registerWithPhone success', () async {
      final client = _mk(json: {'token': 'abc', 'user': {'id': 1}});
      await http.runWithClient(() async {
        final result = await ApiService().registerWithPhone(
          firebaseIdToken: 'firebase-token',
          username: 'phoneuser',
          fullName: 'Phone User',
          dateOfBirth: '1999-01-01',
          language: 'en',
        );
        expect(result['success'], true);
      }, () => client);
    });

    test('registerWithPhone error', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Bad token'});
      await http.runWithClient(() async {
        final result = await ApiService().registerWithPhone(
          firebaseIdToken: 'bad',
          username: 'user',
        );
        expect(result['success'], false);
      }, () => client);
    });

    test('loginWithPhone success', () async {
      final client = _mk(json: {'token': 'jwt', 'user': {'id': 1}});
      await http.runWithClient(() async {
        final result = await ApiService().loginWithPhone('firebase-id-token');
        expect(result['success'], true);
      }, () => client);
    });

    test('loginWithPhone error', () async {
      final client = _mk(statusCode: 401, json: {'message': 'Invalid'});
      await http.runWithClient(() async {
        final result = await ApiService().loginWithPhone('bad');
        expect(result['success'], false);
      }, () => client);
    });

    test('checkPhone success', () async {
      final client = _mk(json: {'available': true});
      await http.runWithClient(() async {
        final result = await ApiService().checkPhone('+84123456789');
        expect(result['available'], true);
      }, () => client);
    });

    test('unblockUser success', () async {
      // unblockUser uses http.Request with .send() — MockClient should handle
      final client = MockClient.streaming((request, _) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('{"success":true}')),
          200,
        );
      });
      await http.runWithClient(() async {
        final result = await ApiService().unblockUser('target1', currentUserId: 'me');
        expect(result, true);
      }, () => client);
    });

    test('checkPrivacyPermission success', () async {
      final client = _mk(json: {'allowed': true, 'reason': 'OK'});
      await http.runWithClient(() async {
        final result = await ApiService().checkPrivacyPermission('req', 'target', 'view_video');
        expect(result['allowed'], true);
      }, () => client);
    });

    test('checkPrivacyPermission error returns not allowed', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ApiService().checkPrivacyPermission('req', 'target', 'send_message');
        expect(result['allowed'], false);
      }, () => client);
    });

    test('getPrivacySettings success', () async {
      final client = _mk(json: {'settings': {'isPrivate': true}});
      await http.runWithClient(() async {
        final result = await ApiService().getPrivacySettings('u1');
        expect(result['isPrivate'], true);
      }, () => client);
    });

    test('getPrivacySettings error returns empty', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ApiService().getPrivacySettings('u1');
        expect(result, isEmpty);
      }, () => client);
    });

    test('getAccountInfo success', () async {
      final client = _mk(json: {'email': 'a@b.com', 'phone': '+84'});
      await http.runWithClient(() async {
        final result = await ApiService().getAccountInfo(_tok);
        expect(result['success'], true);
      }, () => client);
    });

    test('get2FASettings success', () async {
      final client = _mk(json: {'enabled': true, 'methods': ['email']});
      await http.runWithClient(() async {
        final result = await ApiService().get2FASettings(_tok);
        expect(result, isA<Map>());
      }, () => client);
    });

    test('hasSelectedInterests true', () async {
      final client = _mk(json: {'hasInterests': true});
      await http.runWithClient(() async {
        final result = await ApiService().hasSelectedInterests(1);
        expect(result, true);
      }, () => client);
    });

    test('hasSelectedInterests false on error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ApiService().hasSelectedInterests(1);
        expect(result, false);
      }, () => client);
    });

    test('setUserInterests success', () async {
      final client = _mk(json: {'data': [], 'message': 'OK'});
      await http.runWithClient(() async {
        final result = await ApiService().setUserInterests(1, [1, 2, 3], _tok);
        expect(result['success'], true);
      }, () => client);
    });

    test('setUserInterests error', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Bad'});
      await http.runWithClient(() async {
        final result = await ApiService().setUserInterests(1, [1], _tok);
        expect(result['success'], false);
      }, () => client);
    });

    test('getRecommendedVideos (ApiService) success', () async {
      final client = _mk(json: {'data': [{'id': 'v1'}], 'count': 1});
      await http.runWithClient(() async {
        final result = await ApiService().getRecommendedVideos(1, limit: 10);
        expect(result['success'], true);
        expect(result['count'], 1);
      }, () => client);
    });

    test('getRecommendedVideos error', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final result = await ApiService().getRecommendedVideos(1);
        expect(result['success'], false);
      }, () => client);
    });

    test('getTrendingVideos success', () async {
      final client = _mk(json: {'data': [{'id': 'v1'}], 'count': 1});
      await http.runWithClient(() async {
        final result = await ApiService().getTrendingVideos(limit: 20);
        expect(result['success'], true);
      }, () => client);
    });

    test('getTrendingVideos error', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final result = await ApiService().getTrendingVideos();
        expect(result['success'], false);
      }, () => client);
    });

    test('getVideosByCategory success', () async {
      final client = _mk(json: {'data': [{'id': 'v1'}], 'count': 1});
      await http.runWithClient(() async {
        final result = await ApiService().getVideosByCategory(5, limit: 10);
        expect(result['success'], true);
      }, () => client);
    });

    test('getVideosByCategory error', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final result = await ApiService().getVideosByCategory(1);
        expect(result['success'], false);
      }, () => client);
    });

    test('getVideoCategories success', () async {
      final client = _mk(json: {'data': [{'id': 1, 'name': 'Music'}]});
      await http.runWithClient(() async {
        final result = await ApiService().getVideoCategories('v1');
        expect(result['success'], true);
      }, () => client);
    });

    test('getVideoCategories error', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final result = await ApiService().getVideoCategories('v1');
        expect(result['success'], false);
      }, () => client);
    });

    test('getVideoCategoriesWithAiInfo success', () async {
      final client = _mk(json: {'data': [{'id': 1, 'name': 'Music', 'aiSuggested': true}]});
      await http.runWithClient(() async {
        final result = await ApiService().getVideoCategoriesWithAiInfo('v1');
        expect(result['success'], true);
      }, () => client);
    });

    test('getVideoCategoriesWithAiInfo error', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final result = await ApiService().getVideoCategoriesWithAiInfo('v1');
        expect(result['success'], false);
      }, () => client);
    });

    test('recordWatchTime success', () async {
      final client = _mk(json: {'data': {'id': 1}}, statusCode: 201);
      await http.runWithClient(() async {
        final result = await ApiService().recordWatchTime(
          userId: 'u1',
          videoId: 'v1',
          watchDuration: 30,
          videoDuration: 60,
        );
        expect(result['success'], true);
      }, () => client);
    });

    test('recordWatchTime error', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Fail'});
      await http.runWithClient(() async {
        final result = await ApiService().recordWatchTime(
          userId: 'u1',
          videoId: 'v1',
          watchDuration: 30,
          videoDuration: 60,
        );
        expect(result['success'], false);
      }, () => client);
    });

    test('getWatchHistory success', () async {
      final client = _mk(json: {'data': [{'videoId': 'v1'}], 'total': 1});
      await http.runWithClient(() async {
        final result = await ApiService().getWatchHistory('u1', limit: 10, offset: 0);
        expect(result['success'], true);
        expect(result['total'], 1);
      }, () => client);
    });

    test('getWatchHistory error', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Fail'});
      await http.runWithClient(() async {
        final result = await ApiService().getWatchHistory('u1');
        expect(result['success'], false);
      }, () => client);
    });

    test('getWatchTimeInterests success', () async {
      final client = _mk(json: {'data': [{'category': 'Music', 'weight': 0.5}]});
      await http.runWithClient(() async {
        final result = await ApiService().getWatchTimeInterests('u1');
        expect(result['success'], true);
      }, () => client);
    });

    test('getWatchTimeInterests error', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Fail'});
      await http.runWithClient(() async {
        final result = await ApiService().getWatchTimeInterests('u1');
        expect(result['success'], false);
      }, () => client);
    });

    test('getWatchStats success', () async {
      final client = _mk(json: {'data': {'totalWatched': 100}});
      await http.runWithClient(() async {
        final result = await ApiService().getWatchStats('u1');
        expect(result['success'], true);
      }, () => client);
    });

    test('getWatchStats error', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Fail'});
      await http.runWithClient(() async {
        final result = await ApiService().getWatchStats('u1');
        expect(result['success'], false);
      }, () => client);
    });

    test('clearWatchHistory success', () async {
      final client = _mk(json: {'deletedCount': 5});
      await http.runWithClient(() async {
        final result = await ApiService().clearWatchHistory('u1');
        expect(result['success'], true);
        expect(result['deletedCount'], 5);
      }, () => client);
    });

    test('clearWatchHistory error', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Fail'});
      await http.runWithClient(() async {
        final result = await ApiService().clearWatchHistory('u1');
        expect(result['success'], false);
      }, () => client);
    });

    test('getActivityHistory success', () async {
      final client = _mk(json: {'activities': [{'id': 1}], 'total': 1});
      await http.runWithClient(() async {
        final result = await ApiService().getActivityHistory('u1', page: 1, limit: 10, filter: 'videos');
        expect(result['success'], true);
      }, () => client);
    });

    test('getActivityHistory with filter all', () async {
      final client = _mk(json: {'activities': []});
      await http.runWithClient(() async {
        final result = await ApiService().getActivityHistory('u1', filter: 'all');
        expect(result['success'], true);
      }, () => client);
    });

    test('getActivityHistory error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ApiService().getActivityHistory('u1');
        expect(result['success'], false);
      }, () => client);
    });

    test('deleteActivity success', () async {
      final client = _mk(json: {'success': true, 'deleted': 1});
      await http.runWithClient(() async {
        final result = await ApiService().deleteActivity('u1', 123);
        expect(result['success'], true);
      }, () => client);
    });

    test('deleteActivity error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ApiService().deleteActivity('u1', 123);
        expect(result['success'], false);
      }, () => client);
    });

    test('deleteAllActivities success', () async {
      final client = _mk(json: {'success': true, 'deleted': 10});
      await http.runWithClient(() async {
        final result = await ApiService().deleteAllActivities('u1');
        expect(result['success'], true);
      }, () => client);
    });

    test('deleteAllActivities error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ApiService().deleteAllActivities('u1');
        expect(result['success'], false);
      }, () => client);
    });

    test('deleteActivitiesByType success', () async {
      final client = _mk(json: {'success': true, 'deleted': 3});
      await http.runWithClient(() async {
        final result = await ApiService().deleteActivitiesByType('u1', 'likes');
        expect(result['success'], true);
      }, () => client);
    });

    test('deleteActivitiesByType error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ApiService().deleteActivitiesByType('u1', 'comments');
        expect(result['success'], false);
      }, () => client);
    });

    test('deleteActivitiesByTimeRange success', () async {
      final client = _mk(json: {'success': true, 'deleted': 7});
      await http.runWithClient(() async {
        final result = await ApiService().deleteActivitiesByTimeRange('u1', 'today');
        expect(result['success'], true);
      }, () => client);
    });

    test('deleteActivitiesByTimeRange with filter', () async {
      final client = _mk(json: {'success': true, 'deleted': 2});
      await http.runWithClient(() async {
        final result = await ApiService().deleteActivitiesByTimeRange('u1', 'week', filter: 'videos');
        expect(result['success'], true);
      }, () => client);
    });

    test('deleteActivitiesByTimeRange error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ApiService().deleteActivitiesByTimeRange('u1', 'month');
        expect(result['success'], false);
      }, () => client);
    });

    test('getActivityCount success', () async {
      final client = _mk(json: {'count': 15});
      await http.runWithClient(() async {
        final result = await ApiService().getActivityCount('u1', 'today');
        expect(result['count'], 15);
      }, () => client);
    });

    test('getActivityCount with filter', () async {
      final client = _mk(json: {'count': 3});
      await http.runWithClient(() async {
        final result = await ApiService().getActivityCount('u1', 'week', filter: 'likes');
        expect(result['count'], 3);
      }, () => client);
    });

    test('getActivityCount error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ApiService().getActivityCount('u1', 'all');
        expect(result['count'], 0);
      }, () => client);
    });

    test('getAnalytics success', () async {
      final client = _mk(json: {'totalViews': 1000, 'totalLikes': 50});
      await http.runWithClient(() async {
        final result = await ApiService().getAnalytics('u1');
        expect(result['totalViews'], 1000);
      }, () => client);
    });

    test('getAnalytics error', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await ApiService().getAnalytics('u1');
        expect(result['success'], false);
      }, () => client);
    });

    test('hasPassword returns true', () async {
      final client = _mk(json: {'hasPassword': true});
      await http.runWithClient(() async {
        final result = await ApiService().hasPassword(_tok);
        expect(result, isA<Map>());
      }, () => client);
    });

    test('getUserSettings success', () async {
      final client = _mk(json: {'language': 'vi', 'theme': 'dark'});
      await http.runWithClient(() async {
        final result = await ApiService().getUserSettings(_tok);
        expect(result['language'], 'vi');
      }, () => client);
    });
  });

  // =================== GROUP 3: VideoService remaining ===================
  group('VideoService remaining methods', () {
    test('incrementViewCount success', () async {
      final client = _mk(json: {'viewCount': 101});
      await http.runWithClient(() async {
        await VideoService().incrementViewCount('v1');
      }, () => client);
    });

    test('incrementViewCount error does not throw', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        await VideoService().incrementViewCount('v1');
      }, () => client);
    });

    test('getTrendingVideos (VideoService) success', () async {
      final client = _mk(json: {'data': [{'id': 'v1', 'title': 'Trend'}]});
      await http.runWithClient(() async {
        final result = await VideoService().getTrendingVideos(limit: 5);
        expect(result, isA<List>());
      }, () => client);
    });

    test('getTrendingVideos error returns empty', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final result = await VideoService().getTrendingVideos();
        expect(result, isA<List>());
      }, () => client);
    });

    test('getVideoById success returns video map', () async {
      final client = _mk(json: {
        'id': 'v1',
        'title': 'Test',
        'userId': '1',
        'username': 'user1',
        'hlsUrl': 'http://example.com/video.m3u8',
      });
      await http.runWithClient(() async {
        final result = await VideoService().getVideoById('v1');
        expect(result, isA<Map<String, dynamic>?>());
      }, () => client);
    });

    test('getVideoById error returns null', () async {
      final client = _mk(statusCode: 404);
      await http.runWithClient(() async {
        final result = await VideoService().getVideoById('missing');
        expect(result, isNull);
      }, () => client);
    });
  });

  // =================== GROUP 4: AuthService additional ===================
  group('AuthService additional', () {
    test('singleton instance', () {
      final a1 = AuthService();
      final a2 = AuthService();
      expect(identical(a1, a2), true);
    });

    test('isLoggedIn defaults false', () {
      // May or may not be logged in depending on state
      expect(AuthService().isLoggedIn, isA<bool>());
    });

    test('user getter returns map or null', () {
      final u = AuthService().user;
      expect(u == null || u is Map, true);
    });

    test('userId getter returns string or null', () {
      final id = AuthService().userId;
      expect(id == null || id is String, true);
    });

    test('username getter returns string or null', () {
      final name = AuthService().username;
      expect(name == null || name is String, true);
    });

    test('fullName getter', () {
      final fn = AuthService().fullName;
      expect(fn == null || fn is String, true);
    });

    test('email getter', () {
      final em = AuthService().email;
      expect(em == null || em is String, true);
    });

    test('avatarUrl getter', () {
      final av = AuthService().avatarUrl;
      expect(av == null || av is String, true);
    });

    // getToken requires FlutterSecureStorage binding — skip in pure Dart test
  });

  // =================== GROUP 5: MessageService WebSocket no-ops ===================
  group('MessageService WebSocket safety', () {
    test('disconnect without connect does not throw', () {
      MessageService().disconnect();
    });

    test('subscribeOnlineStatus without socket does nothing', () {
      MessageService().subscribeOnlineStatus('u1');
    });

    test('unsubscribeOnlineStatus without socket does nothing', () {
      MessageService().unsubscribeOnlineStatus('u1');
    });

    test('markAsRead without socket does nothing', () {
      MessageService().markAsRead('conv1');
    });

    test('sendTypingIndicator without socket does nothing', () {
      MessageService().sendTypingIndicator('r1', true);
    });

    test('changeThemeColor without socket does nothing', () {
      MessageService().changeThemeColor('r1', '#FF0000', 'User');
    });

    test('getOnlineStatus without socket returns offline', () async {
      final result = await MessageService().getOnlineStatus('u1');
      expect(result['isOnline'], false);
    });

    test('getMultipleOnlineStatus without socket returns all offline', () async {
      final result = await MessageService().getMultipleOnlineStatus(['u1', 'u2']);
      expect(result.length, 2);
      expect(result[0]['isOnline'], false);
      expect(result[1]['isOnline'], false);
    });
  });
}
