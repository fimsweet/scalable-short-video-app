import 'package:flutter_test/flutter_test.dart';
import 'package:scalable_short_video_app/src/services/share_service.dart';

void main() {
  group('ShareService', () {
    late ShareService service;

    setUp(() {
      service = ShareService();
    });

    test('singleton returns same instance', () {
      final a = ShareService();
      final b = ShareService();
      expect(identical(a, b), true);
    });

    group('shareVideo', () {
      test('handles network error gracefully', () async {
        final result = await service.shareVideo('video1', 'sharer1', 'recipient1');
        expect(result, isA<Map<String, dynamic>>());
        expect(result['success'], false);
        expect(result['shareCount'], 0);
      });
    });

    group('getShareCount', () {
      test('handles network error gracefully', () async {
        final count = await service.getShareCount('video1');
        expect(count, 0);
      });
    });
  });
}
