import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sigillum_iphone/hcv_photo_visual_framing.dart';

void main() {
  group('PHOTO visual framing diagnostic', () {
    test('small image cannot establish framing', () {
      final result = HCVPhotoVisualFraming.analyzeImage(img.Image(width: 40, height: 40));
      expect(result['analysisStatus'], 'NOT_ANALYZED');
      expect(result['sceneFraming'], 'UNKNOWN');
    });

    test('plain physical surface remains UNKNOWN', () {
      final image = img.Image(width: 224, height: 224);
      img.fill(image, color: img.ColorRgb8(165, 160, 155));
      final result = HCVPhotoVisualFraming.analyzeImage(image);
      expect(result['analysisStatus'], 'ANALYZED');
      expect(result['sceneFraming'], 'UNKNOWN');
      expect(result['possibleInsetRectangle'], false);
      expect(result['decisionRole'], 'DIAGNOSTIC_ONLY');
    });

    test('inset rectangular edges are not declared a screen', () {
      final image = img.Image(width: 224, height: 224);
      img.fill(image, color: img.ColorRgb8(30, 30, 30));
      img.fillRect(image, x1: 33, y1: 33, x2: 191, y2: 191,
          color: img.ColorRgb8(220, 220, 220));
      final result = HCVPhotoVisualFraming.analyzeImage(image);
      expect(result['sceneFraming'], 'UNKNOWN');
      expect(result['decisionRole'], 'DIAGNOSTIC_ONLY');
    });
  });
}
