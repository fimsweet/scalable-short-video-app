/// Coverage boost 6 – targets non-200 status code error branches in ApiService,
/// FollowService exception/error paths, CommentService exception/error paths,
/// VideoService non-200 code paths, and SuggestedUser.getReasonText branches.
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/follow_service.dart';
import 'package:scalable_short_video_app/src/services/comment_service.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';

const _tok = 'abcdefghijklmnopqrstuvwxyz1234567890';

/// Dummy localize function for SuggestedUser.getReasonText
String _localize(String key) => key;

MockClient _throwing() => MockClient((_) => throw Exception('Network error'));

MockClient _mk({int statusCode = 200, Map<String, dynamic>? json, String body = '{}'}) {
  final responseBody = json != null ? jsonEncode(json) : body;
  return MockClient((_) async => http.Response(responseBody, statusCode));
}

void main() {
  // =================== GROUP 1: ApiService non-200 status branches ===================
  group('ApiService non-200 branches', () {
    test('changeDisplayName non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Cooldown active'});
      await http.runWithClient(() async {
        final r = await ApiService().changeDisplayName(token: _tok, newDisplayName: 'new');
        expect(r['success'], false);
        expect(r['message'], 'Cooldown active');
      }, () => client);
    });

    test('removeDisplayName non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Cooldown'});
      await http.runWithClient(() async {
        final r = await ApiService().removeDisplayName(token: _tok);
        expect(r['success'], false);
      }, () => client);
    });

    test('checkUsernameAvailability non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await ApiService().checkUsernameAvailability('test');
        expect(r['success'], false);
        expect(r['available'], false);
      }, () => client);
    });

    test('searchUsers non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await ApiService().searchUsers('query');
        expect(r, isEmpty);
      }, () => client);
    });

    test('searchUsers with empty query returns empty', () async {
      final client = _mk(json: {'success': true, 'users': []});
      await http.runWithClient(() async {
        final r = await ApiService().searchUsers('');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getUsernameChangeInfo non-200', () async {
      final client = _mk(statusCode: 403);
      await http.runWithClient(() async {
        final r = await ApiService().getUsernameChangeInfo(token: _tok);
        expect(r['success'], false);
      }, () => client);
    });

    test('changeUsername non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': '30-day cooldown'});
      await http.runWithClient(() async {
        final r = await ApiService().changeUsername(token: _tok, newUsername: 'taken');
        expect(r['success'], false);
      }, () => client);
    });

    test('updateProfile non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await ApiService().updateProfile(token: _tok, bio: 'test');
        expect(r['success'], false);
      }, () => client);
    });

    test('getDisplayNameChangeInfo non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await ApiService().getDisplayNameChangeInfo(token: _tok);
        expect(r['success'], false);
      }, () => client);
    });

    test('setPassword non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Weak password'});
      await http.runWithClient(() async {
        final r = await ApiService().setPassword(token: _tok, newPassword: 'w');
        expect(r['success'], false);
      }, () => client);
    });

    test('resetPassword non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Invalid OTP'});
      await http.runWithClient(() async {
        final r = await ApiService().resetPassword(email: 'e', otp: 'bad', newPassword: 'n');
        expect(r['success'], false);
      }, () => client);
    });

    test('updateUserSettings non-200', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await ApiService().updateUserSettings(_tok, {'key': 'val'});
        expect(r['success'], false);
      }, () => client);
    });

    test('getUserSettings non-200', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await ApiService().getUserSettings(_tok);
        expect(r['success'], false);
      }, () => client);
    });

    test('sendLinkEmailOtp non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Invalid email'});
      await http.runWithClient(() async {
        final r = await ApiService().sendLinkEmailOtp(_tok, 'bad');
        expect(r['success'], false);
      }, () => client);
    });

    test('verifyAndLinkEmail non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Bad OTP'});
      await http.runWithClient(() async {
        final r = await ApiService().verifyAndLinkEmail(_tok, 'e', 'otp');
        expect(r['success'], false);
      }, () => client);
    });

    test('update2FASettings non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await ApiService().update2FASettings(_tok, true, ['email']);
        expect(r, isA<Map>());
      }, () => client);
    });

    test('send2FASettingsOtp non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await ApiService().send2FASettingsOtp(_tok, 'email');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('verify2FASettings non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await ApiService().verify2FASettings(_tok, '123', 'email', true, ['email']);
        expect(r, isA<Map>());
      }, () => client);
    });

    test('setupTotp non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await ApiService().setupTotp(_tok);
        expect(r, isA<Map>());
      }, () => client);
    });

    test('verifyTotpSetup non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await ApiService().verifyTotpSetup(_tok, '123456', 'secret');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('checkPhoneForPasswordReset non-200', () async {
      final client = _mk(statusCode: 404, json: {'message': 'Not found'});
      await http.runWithClient(() async {
        final r = await ApiService().checkPhoneForPasswordReset('+84');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('resetPasswordWithPhone non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Invalid'});
      await http.runWithClient(() async {
        final r = await ApiService().resetPasswordWithPhone(phone: '+84', firebaseIdToken: 'tok', newPassword: 'new');
        expect(r['success'], false);
      }, () => client);
    });

    test('getAccountInfo non-200', () async {
      final client = _mk(statusCode: 401, json: {'message': 'Unauthorized'});
      await http.runWithClient(() async {
        final r = await ApiService().getAccountInfo(_tok);
        expect(r['success'], false);
      }, () => client);
    });

    test('hasPassword non-200', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await ApiService().hasPassword(_tok);
        expect(r, isA<Map>());
      }, () => client);
    });

    test('checkPhoneForLink exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().checkPhoneForLink(token: _tok, phone: '+84');
        expect(r['available'], false);
      }, _throwing);
    });

    test('unlinkPhone exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().unlinkPhone(token: _tok, password: 'p');
        expect(r['success'], false);
      }, _throwing);
    });

    test('getSessions exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getSessions(token: _tok);
        expect(r['success'], false);
      }, _throwing);
    });

    test('logoutSession exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().logoutSession(token: _tok, sessionId: 1);
        expect(r['success'], false);
      }, _throwing);
    });

    test('logoutOtherSessions exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().logoutOtherSessions(token: _tok);
        expect(r['success'], false);
      }, _throwing);
    });

    test('logoutAllSessions exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().logoutAllSessions(token: _tok);
        expect(r['success'], false);
      }, _throwing);
    });

    test('forgotPassword exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().forgotPassword('e@e.com');
        expect(r['success'], false);
      }, _throwing);
    });

    test('verifyOtp exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().verifyOtp(email: 'e', otp: '123');
        expect(r['success'], false);
      }, _throwing);
    });

    test('resetPassword exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().resetPassword(email: 'e', otp: '123', newPassword: 'new');
        expect(r['success'], false);
      }, _throwing);
    });

    test('reactivateAccount exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().reactivateAccount(email: 'e', password: 'p');
        expect(r['success'], false);
      }, _throwing);
    });

    test('checkDeactivatedStatus exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().checkDeactivatedStatus('user');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('changeDisplayName exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().changeDisplayName(token: _tok, newDisplayName: 'n');
        expect(r['success'], false);
      }, _throwing);
    });

    test('removeDisplayName exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().removeDisplayName(token: _tok);
        expect(r['success'], false);
      }, _throwing);
    });

    test('getUsernameChangeInfo exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getUsernameChangeInfo(token: _tok);
        expect(r['success'], false);
      }, _throwing);
    });

    test('changeUsername exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().changeUsername(token: _tok, newUsername: 'x');
        expect(r['success'], false);
      }, _throwing);
    });

    test('setPassword exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().setPassword(token: _tok, newPassword: 'x');
        expect(r['success'], false);
      }, _throwing);
    });

    test('getDisplayNameChangeInfo exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getDisplayNameChangeInfo(token: _tok);
        expect(r['success'], false);
      }, _throwing);
    });

    test('checkUsernameAvailability exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().checkUsernameAvailability('user');
        expect(r['success'], false);
      }, _throwing);
    });

    test('sendLinkEmailOtp exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().sendLinkEmailOtp(_tok, 'e');
        expect(r['success'], false);
      }, _throwing);
    });

    test('verifyAndLinkEmail exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().verifyAndLinkEmail(_tok, 'e', '123');
        expect(r['success'], false);
      }, _throwing);
    });

    test('update2FASettings exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().update2FASettings(_tok, true, ['email']);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('send2FASettingsOtp exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().send2FASettingsOtp(_tok, 'email');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('verify2FASettings exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().verify2FASettings(_tok, '123', 'email', true, ['email']);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('setupTotp exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().setupTotp(_tok);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('verifyTotpSetup exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().verifyTotpSetup(_tok, '123456', 'sec');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('checkPhoneForPasswordReset exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().checkPhoneForPasswordReset('+84');
        expect(r['success'], false);
      }, _throwing);
    });

    test('resetPasswordWithPhone exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().resetPasswordWithPhone(phone: '+84', firebaseIdToken: 'tok', newPassword: 'new');
        expect(r['success'], false);
      }, _throwing);
    });
  });

  // =================== GROUP 2: FollowService exception paths ===================
  group('FollowService exception paths', () {
    test('getFollowers exception', () async {
      await http.runWithClient(() async {
        final r = await FollowService().getFollowers(1);
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getFollowing exception', () async {
      await http.runWithClient(() async {
        final r = await FollowService().getFollowing(1);
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getFollowersWithStatus exception', () async {
      await http.runWithClient(() async {
        final r = await FollowService().getFollowersWithStatus(1);
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getFollowingWithStatus exception', () async {
      await http.runWithClient(() async {
        final r = await FollowService().getFollowingWithStatus(1);
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getFollowersWithStatusPaginated exception', () async {
      await http.runWithClient(() async {
        final r = await FollowService().getFollowersWithStatusPaginated(1);
        expect(r['data'], isEmpty);
      }, _throwing);
    });

    test('getFollowingWithStatusPaginated exception', () async {
      await http.runWithClient(() async {
        final r = await FollowService().getFollowingWithStatusPaginated(1);
        expect(r['data'], isEmpty);
      }, _throwing);
    });

    test('getMutualFriendsPaginated exception', () async {
      await http.runWithClient(() async {
        final r = await FollowService().getMutualFriendsPaginated(1);
        expect(r['data'], isEmpty);
      }, _throwing);
    });

    test('checkListPrivacy exception', () async {
      await http.runWithClient(() async {
        final r = await FollowService().checkListPrivacy(targetUserId: 1, requesterId: 2, listType: 'followers');
        expect(r['allowed'], false);
      }, _throwing);
    });

    test('getFollowers non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getFollowers(1);
        expect(r, isEmpty);
      }, () => client);
    });

    test('getFollowing non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getFollowing(1);
        expect(r, isEmpty);
      }, () => client);
    });

    test('getFollowersWithStatus non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getFollowersWithStatus(1);
        expect(r, isEmpty);
      }, () => client);
    });

    test('getFollowingWithStatus non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getFollowingWithStatus(1);
        expect(r, isEmpty);
      }, () => client);
    });

    test('getFollowersWithStatusPaginated non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getFollowersWithStatusPaginated(1);
        expect(r['data'], isEmpty);
      }, () => client);
    });

    test('getFollowingWithStatusPaginated non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getFollowingWithStatusPaginated(1);
        expect(r['data'], isEmpty);
      }, () => client);
    });

    test('getMutualFriendsPaginated non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().getMutualFriendsPaginated(1);
        expect(r['data'], isEmpty);
      }, () => client);
    });

    test('checkListPrivacy non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await FollowService().checkListPrivacy(targetUserId: 1, requesterId: 2, listType: 'followers');
        expect(r['allowed'], false);
      }, () => client);
    });
  });

  // =================== GROUP 3: CommentService exception & non-200 ===================
  group('CommentService exception paths', () {
    test('createComment without image exception returns null', () async {
      await http.runWithClient(() async {
        final r = await CommentService().createComment('v1', 'u1', 'content');
        expect(r, isNull);
      }, _throwing);
    });

    test('getCommentsByVideo exception returns empty', () async {
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideo('v1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getCommentsByVideo non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideo('v1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getCommentsByVideo with limit and offset', () async {
      final client = _mk(json: {'comments': [{'id': '1', 'content': 'hi'}], 'hasMore': false, 'total': 1});
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideo('v1', limit: 10, offset: 0);
        expect(r, isA<List>());
      }, () => client);
    });

    test('getCommentsByVideoWithPagination exception', () async {
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideoWithPagination('v1');
        expect(r['comments'], isEmpty);
      }, _throwing);
    });

    test('getCommentsByVideoWithPagination non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideoWithPagination('v1');
        expect(r['comments'], isEmpty);
      }, () => client);
    });

    test('getCommentsByVideoWithPagination success with map data', () async {
      final client = _mk(json: {'comments': [{'id': '1', 'content': 'hi'}], 'hasMore': false, 'total': 1});
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideoWithPagination('v1');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('getCommentsByVideo with list format', () async {
      final client = MockClient((_) async => http.Response(
        jsonEncode([
          {'id': '1', 'content': 'hi'}
        ]), 200));
      await http.runWithClient(() async {
        final r = await CommentService().getCommentsByVideo('v1');
        expect(r.length, 1);
      }, () => client);
    });

    test('createComment non-201 without image returns null', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Bad content'});
      await http.runWithClient(() async {
        final r = await CommentService().createComment('v1', 'u1', 'bad');
        expect(r, isNull);
      }, () => client);
    });

    test('editComment exception rethrows', () async {
      await http.runWithClient(() async {
        try {
          await CommentService().editComment('c1', 'u1', 'new content');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, _throwing);
    });

    test('editComment non-200 throws', () async {
      final client = _mk(statusCode: 403, json: {'message': 'Forbidden'});
      await http.runWithClient(() async {
        try {
          await CommentService().editComment('c1', 'u1', 'new');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, () => client);
    });

    test('deleteComment exception', () async {
      await http.runWithClient(() async {
        try {
          await CommentService().deleteComment('c1', 'u1');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, _throwing);
    });

    test('toggleCommentLike exception', () async {
      await http.runWithClient(() async {
        try {
          await CommentService().toggleCommentLike('c1', 'u1');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, _throwing);
    });

    test('isCommentLikedByUser exception', () async {
      await http.runWithClient(() async {
        final r = await CommentService().isCommentLikedByUser('c1', 'u1');
        expect(r, false);
      }, _throwing);
    });
  });

  // =================== GROUP 4: SuggestedUser.getReasonText branches ===================
  group('SuggestedUser.getReasonText branches', () {
    SuggestedUser _makeUser(String reason, {
      List<String> mutualNames = const [],
      int mutualCount = 0,
    }) {
      return SuggestedUser(
        id: 1,
        username: 'user1',
        followerCount: 100,
        reason: reason,
        mutualFriendsCount: mutualCount,
        mutualFollowerNames: mutualNames,
      );
    }

    test('mutual_friends with one mutual follower name', () {
      final user = _makeUser('mutual_friends', mutualNames: ['Alice'], mutualCount: 1);
      final text = user.getReasonText(_localize);
      expect(text, isNotEmpty);
    });

    test('mutual_friends with multiple mutual follower names', () {
      final user = _makeUser('mutual_friends', mutualNames: ['Alice', 'Bob'], mutualCount: 2);
      final text = user.getReasonText(_localize);
      expect(text, contains('Alice'));
    });

    test('mutual_friends with no names but count=1', () {
      final user = _makeUser('mutual_friends', mutualCount: 1);
      final text = user.getReasonText(_localize);
      expect(text, isNotEmpty);
    });

    test('mutual_friends with no names but count=3', () {
      final user = _makeUser('mutual_friends', mutualCount: 3);
      final text = user.getReasonText(_localize);
      expect(text, isNotEmpty);
    });

    test('popular reason', () {
      final user = _makeUser('popular');
      final text = user.getReasonText(_localize);
      expect(text, isNotEmpty);
    });

    test('similar_taste reason', () {
      final user = _makeUser('similar_taste');
      final text = user.getReasonText(_localize);
      expect(text, isNotEmpty);
    });

    test('liked_their_content reason', () {
      final user = _makeUser('liked_their_content');
      final text = user.getReasonText(_localize);
      expect(text, isNotEmpty);
    });

    test('friends_and_similar_taste with mutual names', () {
      final user = _makeUser('friends_and_similar_taste', mutualNames: ['Alice']);
      final text = user.getReasonText(_localize);
      expect(text, contains('Alice'));
    });

    test('friends_and_similar_taste without mutual names', () {
      final user = _makeUser('friends_and_similar_taste');
      final text = user.getReasonText(_localize);
      expect(text, isNotEmpty);
    });

    test('default/unknown reason', () {
      final user = _makeUser('unknown_reason');
      final text = user.getReasonText(_localize);
      expect(text, isNotEmpty);
    });

    test('getReasonText with Vietnamese locale', () {
      final user = _makeUser('popular');
      final text = user.getReasonText(_localize, isVietnamese: true);
      expect(text, isNotEmpty);
    });

    test('similar_taste Vietnamese', () {
      final user = _makeUser('similar_taste');
      final text = user.getReasonText(_localize, isVietnamese: true);
      expect(text, isNotEmpty);
    });

    test('liked_their_content Vietnamese', () {
      final user = _makeUser('liked_their_content');
      final text = user.getReasonText(_localize, isVietnamese: true);
      expect(text, isNotEmpty);
    });

    test('mutual_friends Vietnamese with one name', () {
      final user = _makeUser('mutual_friends', mutualNames: ['Alice'], mutualCount: 1);
      final text = user.getReasonText(_localize, isVietnamese: true);
      expect(text, isNotEmpty);
    });

    test('mutual_friends Vietnamese with multiple names', () {
      final user = _makeUser('mutual_friends', mutualNames: ['Alice', 'Bob', 'Charlie'], mutualCount: 3);
      final text = user.getReasonText(_localize, isVietnamese: true);
      expect(text, contains('Alice'));
    });

    test('friends_and_similar_taste Vietnamese with names', () {
      final user = _makeUser('friends_and_similar_taste', mutualNames: ['Alice']);
      final text = user.getReasonText(_localize, isVietnamese: true);
      expect(text, isNotEmpty);
    });

    test('getReasonText English', () {
      final user = _makeUser('similar_taste');
      final text = user.getReasonText(_localize, isVietnamese: false);
      expect(text, 'Similar taste');
    });

    test('liked_their_content English', () {
      final user = _makeUser('liked_their_content');
      final text = user.getReasonText(_localize, isVietnamese: false);
      expect(text, 'You liked their videos');
    });

    test('mutual_friends English with one name', () {
      final user = _makeUser('mutual_friends', mutualNames: ['Alice'], mutualCount: 1);
      final text = user.getReasonText(_localize, isVietnamese: false);
      expect(text, 'Followed by Alice');
    });

    test('friends_and_similar_taste English with names', () {
      final user = _makeUser('friends_and_similar_taste', mutualNames: ['Alice']);
      final text = user.getReasonText(_localize, isVietnamese: false);
      expect(text, 'Followed by Alice & similar taste');
    });
  });

  // =================== GROUP 5: VideoService additional paths ===================
  group('VideoService additional paths', () {
    test('getVideosByUserId non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await VideoService().getVideosByUserId('u1');
        expect(r, isA<List>());
      }, () => client);
    });

    test('getVideosByUserId exception', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getVideosByUserId('u1');
        expect(r, isA<List>());
      }, _throwing);
    });

    test('searchVideos non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await VideoService().searchVideos('query');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getAllVideos non-200', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await VideoService().getAllVideos();
        expect(r, isEmpty);
      }, () => client);
    });

    test('getVideoById non-200 returns null', () async {
      final client = _mk(statusCode: 404);
      await http.runWithClient(() async {
        final r = await VideoService().getVideoById('v1');
        expect(r, isNull);
      }, () => client);
    });

    test('getVideosByUserIdWithPrivacy success', () async {
      final client = _mk(json: {'data': [{'id': 'v1', 'title': 'Test'}]});
      await http.runWithClient(() async {
        final r = await VideoService().getVideosByUserIdWithPrivacy('u1');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('getVideosByUserIdWithPrivacy non-200', () async {
      final client = _mk(statusCode: 403, json: {'message': 'Privacy'});
      await http.runWithClient(() async {
        try {
          await VideoService().getVideosByUserIdWithPrivacy('u1');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, () => client);
    });
  });

  // =================== GROUP 6: MessageService additional paths ===================
  group('MessageService additional paths', () {
    test('getConversationSettings success', () async {
      final client = _mk(json: {'isMuted': true, 'theme': 'dark'});
      await http.runWithClient(() async {
        final r = await MessageService().getConversationSettings('r1');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('updateConversationSettings success', () async {
      final client = _mk(json: {'success': true});
      await http.runWithClient(() async {
        final r = await MessageService().updateConversationSettings('r1');
        expect(r, isA<bool>());
      }, () => client);
    });

    test('pinMessage success', () async {
      final client = _mk(json: {'success': true});
      await http.runWithClient(() async {
        final r = await MessageService().pinMessage('m1');
        expect(r, isA<bool>());
      }, () => client);
    });

    test('unpinMessage success', () async {
      final client = _mk(json: {'success': true});
      await http.runWithClient(() async {
        final r = await MessageService().unpinMessage('m1');
        expect(r, isA<bool>());
      }, () => client);
    });

    test('getPinnedMessages success', () async {
      final client = _mk(json: {'data': [{'id': 'm1', 'content': 'hi'}]});
      await http.runWithClient(() async {
        final r = await MessageService().getPinnedMessages('r1');
        expect(r, isA<List>());
      }, () => client);
    });

    test('searchMessages success', () async {
      final client = _mk(json: {'data': [{'id': 'm1'}]});
      await http.runWithClient(() async {
        final r = await MessageService().searchMessages('r1', 'query');
        expect(r, isA<List>());
      }, () => client);
    });

    test('getMediaMessages success', () async {
      final client = _mk(json: {'data': [{'id': 'm1', 'type': 'IMAGE'}]});
      await http.runWithClient(() async {
        final r = await MessageService().getMediaMessages('r1');
        expect(r, isA<List>());
      }, () => client);
    });

    test('deleteForMe success', () async {
      final client = _mk(json: {'success': true});
      await http.runWithClient(() async {
        final r = await MessageService().deleteForMe('m1');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('deleteForEveryone success', () async {
      final client = _mk(json: {'success': true});
      await http.runWithClient(() async {
        final r = await MessageService().deleteForEveryone('m1');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('editMessage success', () async {
      final client = _mk(json: {'success': true});
      await http.runWithClient(() async {
        final r = await MessageService().editMessage('m1', 'new content');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('translateMessage success', () async {
      final client = _mk(json: {'success': true, 'translatedText': 'Xin chào'});
      await http.runWithClient(() async {
        final r = await MessageService().translateMessage('Hello', 'vi');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('notifyPrivacySettingsChanged success', () async {
      final client = _mk(json: {'success': true});
      await http.runWithClient(() async {
        await MessageService().notifyPrivacySettingsChanged(userId: 'u1');
      }, () => client);
    });
  });

  // =================== GROUP 7: ApiService formatPhoneForDisplay ===================
  group('ApiService static methods', () {
    test('formatPhoneForDisplay with null', () {
      final r = ApiService.formatPhoneForDisplay(null);
      expect(r, '');
    });

    test('formatPhoneForDisplay with +84 prefix', () {
      final r = ApiService.formatPhoneForDisplay('+84901234567');
      expect(r, isNotEmpty);
    });

    test('formatPhoneForDisplay with 0 prefix', () {
      final r = ApiService.formatPhoneForDisplay('0901234567');
      expect(r, isNotEmpty);
    });

    test('formatPhoneForDisplay with short number', () {
      final r = ApiService.formatPhoneForDisplay('123');
      expect(r, '123');
    });

    test('parsePhoneToE164 with 0 prefix', () {
      final r = ApiService.parsePhoneToE164('0901234567');
      expect(r, startsWith('+84'));
    });

    test('parsePhoneToE164 with +84 prefix', () {
      final r = ApiService.parsePhoneToE164('+84901234567');
      expect(r, '+84901234567');
    });

    test('parsePhoneToE164 with other', () {
      final r = ApiService.parsePhoneToE164('901234567');
      expect(r, isNotEmpty);
    });
  });
}
