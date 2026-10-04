import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_photo_detail_compare.dart';

void main() {
  group('photo detail comparator', () {
    test('social-like low-amplitude recompression remains conforming', () {
      final expected = _baseFrame();
      final current = Uint8List.fromList(expected);
      for (var i = 0; i < current.length; i++) {
        final noise = ((i * 31 + 11) % 5) - 2;
        current[i] = (current[i] + noise).clamp(0, 255).toInt();
      }

      final comparison =
          HCVPhotoDetailComparator.compareNormalizedRgb(expected, current);

      expect(comparison.verdict, HCVPhotoDetailVerdict.conforming);
      expect(comparison.localizedTamperTiles, 0);
    });

    test('thin local overlay remains visible and is detected', () {
      final expected = _baseFrame();
      final current = Uint8List.fromList(expected);

      for (var x = 70; x < 190; x++) {
        final centerY = 80 + ((x - 70) ~/ 2);
        for (var dy = -2; dy <= 2; dy++) {
          final y = centerY + dy;
          if (y < 0 || y >= HCVPhotoDetailComparator.height) continue;
          final offset =
              (y * HCVPhotoDetailComparator.width + x) * 3;
          current[offset] = 0;
          current[offset + 1] = 0;
          current[offset + 2] = 0;
        }
      }

      final comparison =
          HCVPhotoDetailComparator.compareNormalizedRgb(expected, current);

      expect(comparison.verdict, HCVPhotoDetailVerdict.modified);
      expect(comparison.localizedTamperTiles, greaterThan(0));
    });

    test('large global tonal edit is detected', () {
      final expected = _baseFrame();
      final current = Uint8List.fromList(expected);
      for (var i = 0; i < current.length; i++) {
        current[i] = (current[i] + 30).clamp(0, 255).toInt();
      }

      final comparison =
          HCVPhotoDetailComparator.compareNormalizedRgb(expected, current);

      expect(comparison.verdict, HCVPhotoDetailVerdict.modified);
    });

    test('invalid normalized input is inconclusive', () {
      final comparison = HCVPhotoDetailComparator.compareNormalizedRgb(
        Uint8List(8),
        Uint8List(8),
      );
      expect(comparison.verdict, HCVPhotoDetailVerdict.inconclusive);
    });
  });
}

Uint8List _baseFrame() {
  final bytes = Uint8List(
    HCVPhotoDetailComparator.width *
        HCVPhotoDetailComparator.height *
        3,
  );
  for (var y = 0; y < HCVPhotoDetailComparator.height; y++) {
    for (var x = 0; x < HCVPhotoDetailComparator.width; x++) {
      final offset =
          (y * HCVPhotoDetailComparator.width + x) * 3;
      bytes[offset] = (40 + x ~/ 2).clamp(0, 255).toInt();
      bytes[offset + 1] = (70 + y ~/ 3).clamp(0, 255).toInt();
      bytes[offset + 2] = (90 + (x + y) ~/ 5).clamp(0, 255).toInt();
    }
  }
  return bytes;
}
