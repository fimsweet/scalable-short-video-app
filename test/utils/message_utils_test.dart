import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/utils/message_utils.dart';

void main() {
  group('MessageUtils', () {
    group('formatMessagePreview', () {
      test('returns empty string for null content', () {
        expect(MessageUtils.formatMessagePreview(null), '');
      });

      test('returns empty string for empty content', () {
        expect(MessageUtils.formatMessagePreview(''), '');
      });

      test('formats video share message', () {
        expect(
          MessageUtils.formatMessagePreview('[VIDEO_SHARE:abc123]'),
          '📹 Đã chia sẻ một video',
        );
      });

      test('formats image message', () {
        expect(
          MessageUtils.formatMessagePreview('[IMAGE:photo.jpg]'),
          '🖼️ Đã gửi một hình ảnh',
        );
      });

      test('formats sticker message', () {
        expect(
          MessageUtils.formatMessagePreview('[STICKER:smile]'),
          '😀 Đã gửi một sticker',
        );
      });

      test('formats voice message', () {
        expect(
          MessageUtils.formatMessagePreview('[VOICE:audio.mp3]'),
          '🎤 Tin nhắn thoại',
        );
      });

      test('formats location message', () {
        expect(
          MessageUtils.formatMessagePreview('[LOCATION:10.0,106.0]'),
          '📍 Đã chia sẻ vị trí',
        );
      });

      test('truncates long messages to 50 chars', () {
        final longMessage = 'A' * 60;
        final result = MessageUtils.formatMessagePreview(longMessage);
        expect(result, '${'A' * 50}...');
        expect(result.length, 53); // 50 chars + "..."
      });

      test('returns short messages as-is', () {
        expect(MessageUtils.formatMessagePreview('Hello!'), 'Hello!');
      });

      test('returns exactly 50 char message as-is', () {
        final message = 'A' * 50;
        expect(MessageUtils.formatMessagePreview(message), message);
      });

      test('does not format partial video share tag', () {
        expect(MessageUtils.formatMessagePreview('[VIDEO_SHARE:abc'), '[VIDEO_SHARE:abc');
      });

      test('does not format video share without closing bracket', () {
        expect(MessageUtils.formatMessagePreview('[VIDEO_SHARE:abc123'), '[VIDEO_SHARE:abc123');
      });
    });

    group('isVideoShare', () {
      test('returns true for valid video share format', () {
        expect(MessageUtils.isVideoShare('[VIDEO_SHARE:abc123]'), true);
      });

      test('returns false for non-video-share content', () {
        expect(MessageUtils.isVideoShare('Hello world'), false);
      });

      test('returns false for image format', () {
        expect(MessageUtils.isVideoShare('[IMAGE:photo.jpg]'), false);
      });

      test('returns false for partial match', () {
        expect(MessageUtils.isVideoShare('[VIDEO_SHARE:abc'), false);
      });

      test('returns false for empty string', () {
        expect(MessageUtils.isVideoShare(''), false);
      });
    });

    group('extractVideoId', () {
      test('extracts video ID from valid format', () {
        expect(MessageUtils.extractVideoId('[VIDEO_SHARE:abc123]'), 'abc123');
      });

      test('extracts complex video ID', () {
        expect(
          MessageUtils.extractVideoId('[VIDEO_SHARE:video-id-123-456]'),
          'video-id-123-456',
        );
      });

      test('returns null for non-video-share content', () {
        expect(MessageUtils.extractVideoId('Hello world'), null);
      });

      test('returns null for image format', () {
        expect(MessageUtils.extractVideoId('[IMAGE:photo.jpg]'), null);
      });

      test('returns null for empty string', () {
        expect(MessageUtils.extractVideoId(''), null);
      });

      test('extracts empty video ID returns null', () {
        // When ':' and ']' are adjacent, start == end so null is returned
        expect(MessageUtils.extractVideoId('[VIDEO_SHARE:]'), isNull);
      });
    });
  });
}
