import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// OpenCV 4.x reference: cv2.resize(RGB_320, (160,160),
/// interpolation=cv2.INTER_AREA). Source is a synthetic RGB pattern.
/// A failure here means the mobile preprocessing is not numerically
/// equivalent to training preprocessing; do not silently accept it.
void main() {
  test('PHOTO average resize agrees with OpenCV INTER_AREA fixture', () {
    final source = img.Image(width: 320, height: 320, numChannels: 3);
    for (var y = 0; y < 320; y++) {
      for (var x = 0; x < 320; x++) {
        source.setPixelRgb(
          x, y,
          (x * 13 + y * 7) % 256,
          (x * 5 + y * 11) % 256,
          (x * 3 + y * 17) % 256,
        );
      }
    }
    final actual = img.copyResize(
      source, width: 160, height: 160,
      interpolation: img.Interpolation.average,
    );
    final expected = <(int, int, List<int>)>[
      (0, 0, [10, 8, 10]),
      (1, 1, [50, 40, 50]),
      (20, 42, [94, 108, 22]),
      (79, 80, [112, 126, 132]),
      (159, 159, [226, 232, 226]),
      (32, 90, [54, 68, 190]),
    ];
    for (final (x, y, reference) in expected) {
      final p = actual.getPixel(x, y);
      final observed = [p.r.toInt(), p.g.toInt(), p.b.toInt()];
      for (var c = 0; c < 3; c++) {
        expect((observed[c] - reference[c]).abs(), lessThanOrEqualTo(1),
          reason: 'RGB channel $c at ($x,$y): observed $observed, OpenCV $reference');
      }
    }
  });
}
