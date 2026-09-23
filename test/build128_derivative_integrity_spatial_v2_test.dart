import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sigillum_iphone/hcv_spatial_fingerprint_v2.dart';
import 'package:sigillum_iphone/registry_verify_copy.dart';

img.Image _scene({bool xOverlay = false, bool gray = false, int offset = 0}) {
  final image = img.Image(width: 256, height: 256);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final sky = y < 110;
      final r = sky ? 75 + x ~/ 18 : 165 + (x ~/ 21) % 35;
      final g = sky ? 115 + y ~/ 9 : 130 + (y ~/ 15) % 40;
      final b = sky ? 180 + x ~/ 25 : 92 + (x ~/ 11) % 50;
      final nearDiagonal = ((y - x).abs() < 19 || (y - (255 - x)).abs() < 19) &&
          y > 48 &&
          y < 237;
      var rr = xOverlay && nearDiagonal ? 5 : r + offset;
      var gg = xOverlay && nearDiagonal ? 5 : g + offset;
      var bb = xOverlay && nearDiagonal ? 5 : b + offset;
      if (gray) {
        final luma = (0.2126 * rr + 0.7152 * gg + 0.0722 * bb).round();
        rr = gg = bb = luma;
      }
      image.setPixelRgba(
        x,
        y,
        rr.clamp(0, 255).toInt(),
        gg.clamp(0, 255).toInt(),
        bb.clamp(0, 255).toInt(),
        255,
      );
    }
  }
  return image;
}

void main() {
  group('BUILD128 derivative integrity spatial fingerprint', () {
    test('spatial RGB signature is signed as 4x4x3, structurally validated',
        () {
      final signature = HCVSpatialFingerprintV2.build(_scene());
      expect(signature['algorithm'], HCVSpatialFingerprintV2.algorithm);
      expect(signature['grid'], 4);
      expect((signature['tiles'] as List).length, 48);
      expect(HCVSpatialFingerprintV2.isValid(signature), isTrue);
      expect(
        HCVSpatialFingerprintV2.isValid(<String, dynamic>{
          ...signature,
          'tiles': <int>[1, 2],
        }),
        isFalse,
      );
    });

    test('JPEG recompression retains compatibility', () {
      final source = _scene();
      final derived = img.decodeJpg(img.encodeJpg(source, quality: 55))!;
      expect(
        HCVSpatialFingerprintV2.matches(
          HCVSpatialFingerprintV2.build(source),
          HCVSpatialFingerprintV2.build(derived),
        ),
        isTrue,
      );
    });

    test('large black X is not benign recompression', () {
      expect(
        HCVSpatialFingerprintV2.matches(
          HCVSpatialFingerprintV2.build(_scene()),
          HCVSpatialFingerprintV2.build(_scene(xOverlay: true)),
        ),
        isFalse,
      );
    });

    test('grayscale/color edit is not benign recompression', () {
      expect(
        HCVSpatialFingerprintV2.matches(
          HCVSpatialFingerprintV2.build(_scene()),
          HCVSpatialFingerprintV2.build(_scene(gray: true)),
        ),
        isFalse,
      );
    });

    test('brightness edit is not benign recompression', () {
      expect(
        HCVSpatialFingerprintV2.matches(
          HCVSpatialFingerprintV2.build(_scene()),
          HCVSpatialFingerprintV2.build(_scene(offset: 40)),
        ),
        isFalse,
      );
    });

    test('spatial VIDEO extraction preserves RGB and full-size frames on all platforms', () {
      final source = File('lib/hcv_social_fingerprint.dart').readAsStringSync();
      expect(source, contains('format=rgb24'));
      expect(source, contains("min(iw,640)"));
      expect(source, isNot(contains('pad=16:16:(ow-iw)/2:(oh-ih)/2,format=gray')));
      expect(source, contains('HCVSpatialFingerprintV2.build(decoded)'));
    });

    test('no audio match can override visual fingerprint mismatch', () {
      final source = File('lib/registry_verify_page.dart').readAsStringSync();
      expect(source, contains('videoFingerprintMatches == false'));
      expect(source, contains("'ID VALID / MEDIA NOT VERIFIED'"));
      expect(source, contains('videoFingerprintMatches == true &&'));
    });

    test('new PHOTO and VIDEO certificates sign independent spatial evidence',
        () {
      final source = File('lib/hcv_social_fingerprint.dart').readAsStringSync();
      expect(source, contains("'spatialFingerprint': spatial"));
      expect(source, contains("'spatialFrameFingerprints': spatialFrames"));
      expect(source, contains('HCVSpatialFingerprintV2.build(decoded)'));
      expect(source, contains("SIGILLUM_SOCIAL_IMAGE_AHASH_V1"));
      expect(source, contains("SIGILLUM_SOCIAL_AHASH_V1"));
    });

    test('legacy V1 cannot reach strong derivative verdict', () {
      final source = File('lib/registry_verify_page.dart').readAsStringSync();
      expect(source, contains('if (signedSpatial == null) return null'));
      expect(source, contains("'SOCIAL LIMITED'"));
      expect(source, contains('HCVSpatialFingerprintV2.matches('));
      expect(source, contains('_videoFrameSpatialHashesMatch('));
      expect(source, contains('markLimited();'));
      expect(source, contains('if (_isSocialLimited) return _r('));
      for (final language in <String>['it', 'en', 'es', 'ru']) {
        expect(
            RegistryVerifyCopy.t(language, 'socialLimitedTitle'), isNotEmpty);
        expect(
            RegistryVerifyCopy.t(language, 'socialLimitedDetail'), isNotEmpty);
      }
    });
  });
}
