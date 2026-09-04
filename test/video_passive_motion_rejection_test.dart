import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sigillum_iphone/hcv_display_microtexture_probe.dart';

img.Image _pattern({int shiftX = 0}) {
  final image = img.Image(width: 96, height: 96);
  for (var y = 0; y < 96; y++) {
    for (var x = 0; x < 96; x++) {
      final sourceX = (x - shiftX) % 96;
      final value = (sourceX * 17 + y * 31 + ((sourceX ~/ 7) * 19)) % 256;
      image.setPixelRgba(x, y, value, value, value, 255);
    }
  }
  return image;
}

void main() {
  const probe = HCVDisplayMicrotextureShadowProbe();

  test('stable frames stay below passive motion rejection threshold', () {
    final frame = _pattern();
    final score = probe.sceneMotionScoreForFrames([frame, frame, frame]);
    expect(
        score,
        lessThan(
            HCVDisplayMicrotextureShadowProbe.passiveMotionRejectionThreshold));
  });

  test('translated scene exceeds passive motion rejection threshold', () {
    final score = probe.sceneMotionScoreForFrames([
      _pattern(),
      _pattern(shiftX: 9),
      _pattern(shiftX: 18),
    ]);
    expect(
        score,
        greaterThan(
            HCVDisplayMicrotextureShadowProbe.passiveMotionRejectionThreshold));
  });
}
