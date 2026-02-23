import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/comment_service.dart';

void main() {
  group('CommentService', () {
    late CommentService service;

    setUp(() {
      service = CommentService();
    });

    test('singleton returns same instance', () {
      final a = CommentService();
      final b = CommentService();
      expect(identical(a, b), true);
    });

    group('createComment', () {
      test('handles network error gracefully', () async {
        final result = await service.createComment('video1', 'user1', 'Hello');
        expect(result, isNull);
      });

      test('handles network error with parentId', () async {
        final result = await service.createComment(
          'video1',
          'user1',
          'Reply text',
          parentId: 'comment1',
        );
        expect(result, isNull);
      });
    });

    group('getCommentsByVideo', () {
      test('handles network error gracefully', () async {
        final comments = await service.getCommentsByVideo('video1');
        expect(comments, isEmpty);
      });

      test('handles network error with pagination params', () async {
        final comments = await service.getCommentsByVideo(
          'video1',
          limit: 10,
          offset: 0,
        );
        expect(comments, isEmpty);
      });
    });

    group('getCommentsByVideoWithPagination', () {
      test('handles network error gracefully', () async {
        final result = await service.getCommentsByVideoWithPagination('video1');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('getReplies', () {
      test('handles network error gracefully', () async {
        final replies = await service.getReplies('comment1');
        expect(replies, isEmpty);
      });
    });

    group('getCommentCount', () {
      test('handles network error gracefully', () async {
        final count = await service.getCommentCount('video1');
        expect(count, 0);
      });
    });

    group('deleteComment', () {
      test('handles network error gracefully', () async {
        final result = await service.deleteComment('comment1', 'user1');
        expect(result, false);
      });
    });

    group('toggleCommentLike', () {
      test('handles network error gracefully', () async {
        final result = await service.toggleCommentLike('comment1', 'user1');
        expect(result, isA<Map<String, dynamic>>());
      });
    });

    group('isCommentLikedByUser', () {
      test('handles network error gracefully', () async {
        final result = await service.isCommentLikedByUser('comment1', 'user1');
        expect(result, false);
      });
    });

    group('editComment', () {
      test('rethrows network error', () async {
        expect(
          () => service.editComment('comment1', 'user1', 'Updated content'),
          throwsA(anything),
        );
      });
    });
  });
}
