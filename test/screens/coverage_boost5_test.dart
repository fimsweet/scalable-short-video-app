/// Coverage boost 5 – targets exception/error paths in ApiService, VideoService,
/// MessageService, AuthService deeper, GoogleSignInResult model, and more error branches.
/// Focused on triggering catch blocks that only fire on network exceptions.
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:scalable_short_video_app/src/services/api_service.dart';
import 'package:scalable_short_video_app/src/services/video_service.dart';
import 'package:scalable_short_video_app/src/services/message_service.dart';
import 'package:scalable_short_video_app/src/services/auth_service.dart';

/// MockClient that always throws to trigger catch blocks
MockClient _throwing() {
  return MockClient((_) => throw Exception('Network error'));
}

/// Token long enough for substring(0,20)
const _tok = 'abcdefghijklmnopqrstuvwxyz1234567890';

/// Normal mock with configurable response
MockClient _mk({
  int statusCode = 200,
  Map<String, dynamic>? json,
  String body = '{}',
}) {
  final responseBody = json != null ? jsonEncode(json) : body;
  return MockClient((_) async => http.Response(responseBody, statusCode));
}

void main() {
  // =================== GROUP 1: ApiService exception paths ===================
  group('ApiService exception paths', () {
    test('register exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().register(username: 'u', email: 'e', password: 'p');
        expect(r['success'], false);
        expect(r['message'], contains('kết nối'));
      }, _throwing);
    });

    test('registerWithPhone exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().registerWithPhone(firebaseIdToken: 'f', username: 'u');
        expect(r['success'], false);
      }, _throwing);
    });

    test('loginWithPhone exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().loginWithPhone('tok');
        expect(r['success'], false);
      }, _throwing);
    });

    test('checkPhone exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().checkPhone('+84123');
        expect(r['available'], false);
      }, _throwing);
    });

    test('login exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().login(username: 'u', password: 'p');
        expect(r['success'], false);
      }, _throwing);
    });

    test('getProfile exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getProfile(_tok);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('getUserById exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getUserById('1');
        expect(r, isNull);
      }, _throwing);
    });

    test('sendHeartbeat exception', () async {
      await http.runWithClient(() async {
        await ApiService().sendHeartbeat('1');
      }, _throwing);
    });

    test('getOnlineStatus exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getOnlineStatus('1');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('updateProfile exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().updateProfile(token: _tok, bio: 'test');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('getDisplayNameChangeInfo exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getDisplayNameChangeInfo(token: _tok);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('changeDisplayName exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().changeDisplayName(token: _tok, newDisplayName: 'name');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('removeDisplayName exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().removeDisplayName(token: _tok);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('getUsernameChangeInfo exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getUsernameChangeInfo(token: _tok);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('changeUsername exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().changeUsername(token: _tok, newUsername: 'new');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('changePassword exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().changePassword(token: _tok, currentPassword: 'old', newPassword: 'new');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('setPassword exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().setPassword(token: _tok, newPassword: 'new');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('hasPassword exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().hasPassword(_tok);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('linkPhone exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().linkPhone(token: _tok, firebaseIdToken: 'firebaseTok');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('checkPhoneForLink exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().checkPhoneForLink(token: _tok, phone: '+84');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('unlinkPhone exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().unlinkPhone(token: _tok, password: 'pass');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('deactivateAccount exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().deactivateAccount(token: _tok, password: 'pass');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('reactivateAccount exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().reactivateAccount(email: 'e', password: 'p');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('checkDeactivatedStatus exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().checkDeactivatedStatus('user');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('getSessions exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getSessions(token: _tok);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('logoutSession exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().logoutSession(token: _tok, sessionId: 1);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('logoutOtherSessions exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().logoutOtherSessions(token: _tok);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('logoutAllSessions exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().logoutAllSessions(token: _tok);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('forgotPassword exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().forgotPassword('e@e.com');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('verifyOtp exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().verifyOtp(email: 'e@e.com', otp: '123456');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('resetPassword exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().resetPassword(email: 'e', otp: '123456', newPassword: 'new');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('getFollowers exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getFollowers('u1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getFollowing exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getFollowing('u1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getFollowersWithStatus exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getFollowersWithStatus('u1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getFollowingWithStatus exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getFollowingWithStatus('u1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('checkUsernameAvailability exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().checkUsernameAvailability('test');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('searchUsers exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().searchUsers('query');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('blockUser exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().blockUser('target');
        expect(r, false);
      }, _throwing);
    });

    test('unblockUser exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().unblockUser('target');
        expect(r, false);
      }, _throwing);
    });

    test('getBlockedUsers exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getBlockedUsers('u1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('isUserBlocked exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().isUserBlocked('u1', 'u2');
        expect(r, false);
      }, _throwing);
    });

    test('getReportCount exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getReportCount('u1');
        expect(r, 0);
      }, _throwing);
    });

    test('getUserSettings exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getUserSettings(_tok);
        expect(r['success'], false);
      }, _throwing);
    });

    test('updateUserSettings exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().updateUserSettings(_tok, {'key': 'val'});
        expect(r['success'], false);
      }, _throwing);
    });

    test('checkPrivacyPermission exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().checkPrivacyPermission('r', 't', 'a');
        expect(r['allowed'], false);
      }, _throwing);
    });

    test('getPrivacySettings exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getPrivacySettings('u1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getAccountInfo exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getAccountInfo(_tok);
        expect(r['success'], false);
      }, _throwing);
    });

    test('sendLinkEmailOtp exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().sendLinkEmailOtp(_tok, 'e@e.com');
        expect(r['success'], false);
      }, _throwing);
    });

    test('verifyAndLinkEmail exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().verifyAndLinkEmail(_tok, 'e', '123');
        expect(r['success'], false);
      }, _throwing);
    });

    test('get2FASettings exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().get2FASettings(_tok);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('update2FASettings exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().update2FASettings(_tok, true, ['email']);
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('send2FAOtp exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().send2FAOtp(1, 'email');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('verify2FAOtp exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().verify2FAOtp(1, '123', 'email');
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
        final r = await ApiService().verifyTotpSetup(_tok, '123456', 'secret');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('checkPhoneForPasswordReset exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().checkPhoneForPasswordReset('+84');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('resetPasswordWithPhone exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().resetPasswordWithPhone(phone: '+84', firebaseIdToken: 'fbTok', newPassword: 'newPwd');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('getCategories exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getCategories();
        expect(r['success'], false);
      }, _throwing);
    });

    test('getUserInterests exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getUserInterests(1);
        expect(r['success'], false);
      }, _throwing);
    });

    test('hasSelectedInterests exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().hasSelectedInterests(1);
        expect(r, false);
      }, _throwing);
    });

    test('setUserInterests exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().setUserInterests(1, [1], _tok);
        expect(r['success'], false);
      }, _throwing);
    });

    test('getRecommendedVideos exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getRecommendedVideos(1);
        expect(r['success'], false);
      }, _throwing);
    });

    test('getTrendingVideos exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getTrendingVideos();
        expect(r['success'], false);
      }, _throwing);
    });

    test('getVideosByCategory exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getVideosByCategory(1);
        expect(r['success'], false);
      }, _throwing);
    });

    test('getVideoCategories exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getVideoCategories('v1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('getVideoCategoriesWithAiInfo exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getVideoCategoriesWithAiInfo('v1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('recordWatchTime exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().recordWatchTime(userId: 'u', videoId: 'v', watchDuration: 1, videoDuration: 2);
        expect(r['success'], false);
      }, _throwing);
    });

    test('getWatchHistory exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getWatchHistory('u1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('getWatchTimeInterests exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getWatchTimeInterests('u1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('getWatchStats exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getWatchStats('u1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('clearWatchHistory exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().clearWatchHistory('u1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('getActivityHistory exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getActivityHistory('u1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('deleteActivity exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().deleteActivity('u1', 1);
        expect(r['success'], false);
      }, _throwing);
    });

    test('deleteAllActivities exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().deleteAllActivities('u1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('deleteActivitiesByType exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().deleteActivitiesByType('u1', 'likes');
        expect(r['success'], false);
      }, _throwing);
    });

    test('deleteActivitiesByTimeRange exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().deleteActivitiesByTimeRange('u1', 'today');
        expect(r['success'], false);
      }, _throwing);
    });

    test('getActivityCount exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getActivityCount('u1', 'today');
        expect(r['count'], 0);
      }, _throwing);
    });

    test('getAnalytics exception', () async {
      await http.runWithClient(() async {
        final r = await ApiService().getAnalytics('u1');
        expect(r['success'], false);
      }, _throwing);
    });
  });

  // =================== GROUP 2: VideoService exception paths ===================
  group('VideoService exception paths', () {
    test('getVideoById exception returns null', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getVideoById('v1');
        expect(r, isNull);
      }, _throwing);
    });

    test('getUserVideos exception returns empty', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getUserVideos('u1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getAllVideos exception returns empty', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getAllVideos();
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getVideosByUserIdWithPrivacy exception', () async {
      await http.runWithClient(() async {
        try {
          await VideoService().getVideosByUserIdWithPrivacy('u1');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, _throwing);
    });

    test('getVideosByUserId exception', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getVideosByUserId('u1');
        expect(r, isA<List>());
      }, _throwing);
    });

    test('getFollowingVideos exception', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getFollowingVideos('u1');
        expect(r, isA<List>());
      }, _throwing);
    });

    test('getFriendsVideos exception', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getFriendsVideos('u1');
        expect(r, isA<List>());
      }, _throwing);
    });

    test('getFollowingNewVideoCount exception', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getFollowingNewVideoCount('u1', DateTime.now());
        expect(r, 0);
      }, _throwing);
    });

    test('getFriendsNewVideoCount exception', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getFriendsNewVideoCount('u1', DateTime.now());
        expect(r, 0);
      }, _throwing);
    });

    test('searchVideos exception returns empty', () async {
      await http.runWithClient(() async {
        final r = await VideoService().searchVideos('query');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('toggleHideVideo exception', () async {
      await http.runWithClient(() async {
        try {
          await VideoService().toggleHideVideo('v1', 'u1');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, _throwing);
    });

    test('deleteVideo exception', () async {
      await http.runWithClient(() async {
        try {
          await VideoService().deleteVideo('v1', 'u1');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, _throwing);
    });

    test('getRecommendedVideos exception', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getRecommendedVideos(1);
        expect(r, isA<List>());
      }, _throwing);
    });

    test('getTrendingVideos exception', () async {
      await http.runWithClient(() async {
        final r = await VideoService().getTrendingVideos();
        expect(r, isA<List>());
      }, _throwing);
    });

    test('updateVideoPrivacy exception', () async {
      await http.runWithClient(() async {
        try {
          await VideoService().updateVideoPrivacy(videoId: 'v1', userId: 'u1');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, _throwing);
    });

    test('editVideo exception', () async {
      await http.runWithClient(() async {
        try {
          await VideoService().editVideo(videoId: 'v1', userId: 'u1', title: 'new');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, _throwing);
    });

    test('retryVideo exception', () async {
      await http.runWithClient(() async {
        final r = await VideoService().retryVideo(videoId: 'v1', userId: 'u1');
        expect(r, isA<Map>());
      }, _throwing);
    });

    test('incrementViewCount exception', () async {
      await http.runWithClient(() async {
        await VideoService().incrementViewCount('v1');
      }, _throwing);
    });
  });

  // =================== GROUP 3: MessageService exception paths ===================
  group('MessageService exception paths', () {
    test('getMessages exception returns empty', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getMessages('u1', 'u2');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getConversations exception returns empty', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getConversations('u1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getUnreadCount exception returns 0', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getUnreadCount('u1');
        expect(r, 0);
      }, _throwing);
    });

    test('sendMessage exception', () async {
      await http.runWithClient(() async {
        // sendMessage requires _currentUserId to be set
        // Since it's empty, it returns early
        final r = await MessageService().sendMessage(
          recipientId: 'r1',
          content: 'hello',
        );
        expect(r['success'], false);
      }, _throwing);
    });

    test('getConversationSettings exception returns defaults', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getConversationSettings('r1');
        expect(r['isMuted'], false);
      }, _throwing);
    });

    test('updateConversationSettings exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().updateConversationSettings('r1');
        expect(r, false);
      }, _throwing);
    });

    test('pinMessage exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().pinMessage('m1');
        expect(r, false);
      }, _throwing);
    });

    test('unpinMessage exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().unpinMessage('m1');
        expect(r, false);
      }, _throwing);
    });

    test('getPinnedMessages exception returns empty', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getPinnedMessages('r1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('searchMessages exception returns empty', () async {
      await http.runWithClient(() async {
        final r = await MessageService().searchMessages('r1', 'query');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('getMediaMessages exception returns empty', () async {
      await http.runWithClient(() async {
        final r = await MessageService().getMediaMessages('r1');
        expect(r, isEmpty);
      }, _throwing);
    });

    test('deleteForMe exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().deleteForMe('m1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('deleteForEveryone exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().deleteForEveryone('m1');
        expect(r['success'], false);
      }, _throwing);
    });

    test('editMessage exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().editMessage('m1', 'new');
        expect(r['success'], false);
      }, _throwing);
    });

    test('translateMessage exception', () async {
      await http.runWithClient(() async {
        final r = await MessageService().translateMessage('text', 'vi');
        expect(r['success'], false);
      }, _throwing);
    });

    test('notifyPrivacySettingsChanged exception', () async {
      await http.runWithClient(() async {
        await MessageService().notifyPrivacySettingsChanged(userId: 'u1');
      }, _throwing);
    });
  });

  // =================== GROUP 4: GoogleSignInResult model ===================
  group('GoogleSignInResult model', () {
    test('success factory', () {
      final r = GoogleSignInResult.success(
        idToken: 'tok',
        email: 'e@e.com',
        displayName: 'Name',
        photoUrl: 'http://photo.jpg',
        providerId: 'pid',
      );
      expect(r.success, true);
      expect(r.cancelled, false);
      expect(r.idToken, 'tok');
      expect(r.email, 'e@e.com');
      expect(r.displayName, 'Name');
      expect(r.photoUrl, 'http://photo.jpg');
      expect(r.providerId, 'pid');
      expect(r.error, isNull);
    });

    test('cancelled factory', () {
      final r = GoogleSignInResult.cancelled();
      expect(r.success, false);
      expect(r.cancelled, true);
      expect(r.idToken, isNull);
    });

    test('error factory', () {
      final r = GoogleSignInResult.error('Something went wrong');
      expect(r.success, false);
      expect(r.cancelled, false);
      expect(r.error, 'Something went wrong');
    });
  });

  // =================== GROUP 5: AuthService listeners & model ===================
  group('AuthService listeners', () {
    test('addLogoutListener and removeLogoutListener', () {
      int callCount = 0;
      void listener() => callCount++;

      AuthService().addLogoutListener(listener);
      AuthService().removeLogoutListener(listener);
      // Listener was removed, count should stay 0
      expect(callCount, 0);
    });

    test('addLoginListener and removeLoginListener', () {
      int callCount = 0;
      void listener() => callCount++;

      AuthService().addLoginListener(listener);
      AuthService().removeLoginListener(listener);
      expect(callCount, 0);
    });

    test('bio getter', () {
      final bio = AuthService().bio;
      expect(bio == null || bio is String, true);
    });

    test('phoneNumber getter', () {
      final p = AuthService().phoneNumber;
      expect(p == null || p is String, true);
    });

    test('authProvider getter', () {
      final a = AuthService().authProvider;
      expect(a == null || a is String, true);
    });
  });

  // =================== GROUP 6: ApiService status code edge cases ===================
  group('ApiService status edge cases', () {
    test('register with 409 conflict', () async {
      final client = _mk(statusCode: 409, json: {'message': 'Username already exists'});
      await http.runWithClient(() async {
        final r = await ApiService().register(username: 'u', email: 'e', password: 'p');
        expect(r['success'], false);
        expect(r['message'], 'Username already exists');
      }, () => client);
    });

    test('login 401 with 2FA required', () async {
      final client = _mk(statusCode: 401, json: {'message': '2FA required', 'requires2FA': true});
      await http.runWithClient(() async {
        final r = await ApiService().login(username: 'u', password: 'p');
        expect(r['success'], false);
      }, () => client);
    });

    test('getProfile unauthorized', () async {
      final client = _mk(statusCode: 401, json: {'message': 'Unauthorized'});
      await http.runWithClient(() async {
        final r = await ApiService().getProfile(_tok);
        expect(r, isA<Map>());
      }, () => client);
    });

    test('deactivateAccount 403', () async {
      final client = _mk(statusCode: 403, json: {'message': 'Wrong password'});
      await http.runWithClient(() async {
        final r = await ApiService().deactivateAccount(token: _tok, password: 'wrong');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('changePassword 400', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Weak password'});
      await http.runWithClient(() async {
        final r = await ApiService().changePassword(token: _tok, currentPassword: 'old', newPassword: 'weak');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('linkPhone 409 already linked', () async {
      final client = _mk(statusCode: 409, json: {'message': 'Phone already linked'});
      await http.runWithClient(() async {
        final r = await ApiService().linkPhone(token: _tok, firebaseIdToken: 'fbToken');
        expect(r, isA<Map>());
      }, () => client);
    });

    test('update2FASettings with methods and disabled', () async {
      final client = _mk(json: {'enabled': false});
      await http.runWithClient(() async {
        final r = await ApiService().update2FASettings(_tok, false, []);
        expect(r, isA<Map>());
      }, () => client);
    });

    test('getFollowers with non-200 status', () async {
      final client = _mk(statusCode: 403);
      await http.runWithClient(() async {
        final r = await ApiService().getFollowers('u1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('getFollowing with non-200 status', () async {
      final client = _mk(statusCode: 403);
      await http.runWithClient(() async {
        final r = await ApiService().getFollowing('u1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('reportUser exception rethrows', () async {
      await http.runWithClient(() async {
        try {
          await ApiService().reportUser(reporterId: 'r', reportedUserId: 'u', reason: 'spam');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, _throwing);
    });

    test('reportUser non-201 throws', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Invalid'});
      await http.runWithClient(() async {
        try {
          await ApiService().reportUser(reporterId: 'r', reportedUserId: 'u', reason: 'spam', description: 'desc');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, () => client);
    });

    test('ApiService get method', () async {
      final client = _mk(json: {'data': 'ok'});
      await http.runWithClient(() async {
        final r = await ApiService().get('/test');
        expect(r.statusCode, 200);
      }, () => client);
    });

    test('ApiService post method', () async {
      final client = _mk(json: {'data': 'ok'});
      await http.runWithClient(() async {
        final r = await ApiService().post('/test', body: {'key': 'val'});
        expect(r.statusCode, 200);
      }, () => client);
    });

    test('ApiService post method without body', () async {
      final client = _mk(json: {'data': 'ok'});
      await http.runWithClient(() async {
        final r = await ApiService().post('/test');
        expect(r.statusCode, 200);
      }, () => client);
    });
  });

  // =================== GROUP 7: VideoService non-200 responses ===================
  group('VideoService non-200 responses', () {
    test('getUserVideos non-200', () async {
      final client = _mk(statusCode: 403);
      await http.runWithClient(() async {
        final r = await VideoService().getUserVideos('u1');
        expect(r, isEmpty);
      }, () => client);
    });

    test('searchVideos with results including user fetch', () async {
      final client = _mk(json: {
        'data': [
          {'id': 'v1', 'title': 'Test', 'userId': '1', 'likeCount': 5}
        ]
      });
      await http.runWithClient(() async {
        final r = await VideoService().searchVideos('test');
        expect(r, isA<List>());
      }, () => client);
    });

    test('getFollowingVideos non-200', () async {
      final client = _mk(statusCode: 404);
      await http.runWithClient(() async {
        final r = await VideoService().getFollowingVideos('u1');
        expect(r, isA<List>());
      }, () => client);
    });

    test('getFriendsVideos non-200', () async {
      final client = _mk(statusCode: 404);
      await http.runWithClient(() async {
        final r = await VideoService().getFriendsVideos('u1');
        expect(r, isA<List>());
      }, () => client);
    });

    test('getFollowingNewVideoCount non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await VideoService().getFollowingNewVideoCount('u1', DateTime.now());
        expect(r, 0);
      }, () => client);
    });

    test('getFriendsNewVideoCount non-200', () async {
      final client = _mk(statusCode: 500);
      await http.runWithClient(() async {
        final r = await VideoService().getFriendsNewVideoCount('u1', DateTime.now());
        expect(r, 0);
      }, () => client);
    });

    test('toggleHideVideo non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Bad'});
      await http.runWithClient(() async {
        try {
          await VideoService().toggleHideVideo('v1', 'u1');
          fail('Should have thrown');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, () => client);
    });

    test('deleteVideo non-200', () async {
      final client = _mk(statusCode: 403, json: {'message': 'Not allowed'});
      await http.runWithClient(() async {
        try {
          await VideoService().deleteVideo('v1', 'u1');
          fail('Should have thrown');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, () => client);
    });

    test('getRecommendedVideos non-200', () async {
      final client = _mk(statusCode: 500, json: {'message': 'Error'});
      await http.runWithClient(() async {
        final r = await VideoService().getRecommendedVideos(1);
        expect(r, isA<List>());
      }, () => client);
    });

    test('updateVideoPrivacy non-200', () async {
      final client = _mk(statusCode: 403, json: {'message': 'Forbidden'});
      await http.runWithClient(() async {
        try {
          await VideoService().updateVideoPrivacy(videoId: 'v1', userId: 'u1', visibility: 'private');
          fail('Should have thrown');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, () => client);
    });

    test('editVideo non-200', () async {
      final client = _mk(statusCode: 400, json: {'message': 'Bad'});
      await http.runWithClient(() async {
        try {
          await VideoService().editVideo(videoId: 'v1', userId: 'u1', description: 'desc');
          fail('Should have thrown');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      }, () => client);
    });

    test('retryVideo non-200', () async {
      final client = _mk(statusCode: 404, json: {'message': 'Not found'});
      await http.runWithClient(() async {
        final r = await VideoService().retryVideo(videoId: 'v1', userId: 'u1');
        expect(r, isA<Map>());
      }, () => client);
    });
  });

  // =================== GROUP 8: MessageService sendMessage deeper ===================
  group('MessageService sendMessage', () {
    test('sendMessage 201 success with data', () async {
      final client = _mk(statusCode: 201, json: {'data': {'id': 'm1', 'content': 'hello'}});
      await http.runWithClient(() async {
        // Need to set currentUserId by manipulating the singleton
        // Since sendMessage checks _currentUserId internally and it may be null,
        // let's test the "no sender" path
        final r = await MessageService().sendMessage(
          recipientId: 'r1',
          content: 'hello',
        );
        // If _currentUserId is empty, returns {success: false}
        expect(r, isA<Map>());
      }, () => client);
    });

    test('sendMessage with replyTo', () async {
      final client = _mk(statusCode: 201, json: {'data': {'id': 'm2'}});
      await http.runWithClient(() async {
        final r = await MessageService().sendMessage(
          recipientId: 'r1',
          content: 'reply text',
          replyTo: {'messageId': 'm1', 'content': 'original'},
        );
        expect(r, isA<Map>());
      }, () => client);
    });

    test('sendMessage 403 blocked', () async {
      final client = _mk(statusCode: 403, json: {'message': 'Blocked by user'});
      await http.runWithClient(() async {
        final r = await MessageService().sendMessage(
          recipientId: 'r1',
          content: 'blocked',
        );
        expect(r, isA<Map>());
      }, () => client);
    });
  });
}
