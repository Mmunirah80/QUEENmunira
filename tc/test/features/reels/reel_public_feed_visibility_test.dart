import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/reels/domain/reel_public_feed_visibility.dart';

void main() {
  group('isReelRowPublicFeedVisible', () {
    test('default active reel with no deleted_at / is_hidden → visible', () {
      expect(isReelRowPublicFeedVisible(<String, dynamic>{}), isTrue);
      expect(isReelRowPublicFeedVisible(<String, dynamic>{'is_active': true}), isTrue);
    });

    test('is_active false → hidden', () {
      expect(isReelRowPublicFeedVisible(<String, dynamic>{'is_active': false}), isFalse);
    });

    test('deleted_at set → hidden', () {
      expect(
        isReelRowPublicFeedVisible(<String, dynamic>{
          'deleted_at': DateTime.utc(2025, 1, 1).toIso8601String(),
        }),
        isFalse,
      );
    });

    test('is_hidden true → hidden', () {
      expect(isReelRowPublicFeedVisible(<String, dynamic>{'is_hidden': true}), isFalse);
    });
  });
}
