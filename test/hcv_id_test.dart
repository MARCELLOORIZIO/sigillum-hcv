import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_id.dart';

void main() {
  group('HCVID', () {
    test('generates a 64-bit hexadecimal content identifier', () {
      final id = HCVID.generate();
      expect(id, matches(RegExp(r'^HCV-[A-F0-9]{16}$')));
    });

    test('generated identifiers are not repeated in a practical sample', () {
      final ids = List.generate(5000, (_) => HCVID.generate()).toSet();
      expect(ids.length, 5000);
    });

    test('normalizes legacy eight-character identifiers', () {
      expect(HCVID.normalize('hcv-ab12cd34'), 'HCV-AB12CD34');
      expect(HCVID.normalize('HCV-ID: AB12CD34'), 'HCV-AB12CD34');
    });

    test('normalizes new sixteen-character identifiers', () {
      expect(
        HCVID.normalize('hcv_0123456789abcdef'),
        'HCV-0123456789ABCDEF',
      );
    });

    test('rejects values outside the supported hexadecimal range', () {
      expect(HCVID.normalize('HCV-1234'), isNull);
      expect(HCVID.normalize('HCV-1234567Z'), isNull);
      expect(HCVID.normalize('not-an-id'), isNull);
    });
  });
}
