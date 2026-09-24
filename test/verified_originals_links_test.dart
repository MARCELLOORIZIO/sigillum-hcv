import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/verified_originals_links.dart';

void main() {
  test('accepts one canonical YouTube video link', () {
    expect(
      verifiedOriginalsYoutubeUri('https://www.youtube.com/watch?v=ABCDEFGHIJK').toString(),
      'https://www.youtube.com/watch?v=ABCDEFGHIJK',
    );
  });
  test('rejects redirects, spoofed hosts and noncanonical YouTube routes', () {
    for (final value in <Object?>[
      null,
      'http://www.youtube.com/watch?v=ABCDEFGHIJK',
      'https://youtube.com/watch?v=ABCDEFGHIJK',
      'https://www.youtube.com.evil.test/watch?v=ABCDEFGHIJK',
      'https://www.youtube.com/watch?v=ABCDEFGHIJK&next=bad',
      'https://www.youtube.com/watch?v=ABCDEFGHIJK&v=ABCDEFGHIJK',
      'https://www.youtube.com/watch?v=ABCDEFGHIJK#fragment',
      'https://www.youtube.com/shorts/ABCDEFGHIJK',
      'https://www.youtube.com/watch?v=ABC',
    ]) {
      expect(verifiedOriginalsYoutubeUri(value), isNull, reason: '$value');
    }
  });
}
