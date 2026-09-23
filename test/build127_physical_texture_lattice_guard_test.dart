import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sigillum_iphone/hcv_display_lattice_discriminator.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

void main() {
  group('BUILD127 physical repetitive texture guard', () {
    test('irregular fabric lattice is detected as physical repeating texture', () {
      final image = _fabricLikeImage();
      final evidence = HCVDisplayLatticeDiscriminator.analyze(image);

      expect(evidence.repetitiveTextureScore, greaterThan(0.55));
      expect(evidence.latticeDefectScore, greaterThan(0.30));
      expect(evidence.rgbPhaseConsistencyScore, lessThan(0.30));
      expect(evidence.physicalRepeatingTextureLikely, isTrue);
    });

    test('regular RGB display lattice is not classified as physical texture', () {
      final image = _rgbDisplayLikeImage();
      final evidence = HCVDisplayLatticeDiscriminator.analyze(image);

      expect(evidence.repetitiveTextureScore, greaterThan(0.45));
      expect(evidence.latticeRegularityScore, greaterThan(0.70));
      expect(evidence.physicalRepeatingTextureLikely, isFalse);
    });

    test('VIDEO V2 persistence alone cannot override physical texture guard', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(fullFrame: false),
        ml: _videoMl(),
        passiveOptical: _physicalTextureOptical(),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('BUILD127_VIDEO_PHYSICAL_REPEATING_TEXTURE_GUARD'),
      );
    });

    test('positive HFR remains stronger than physical texture guard', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(fullFrame: true),
        ml: _videoMl(),
        passiveOptical: _physicalTextureOptical(),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.reasons, contains('BUILD124_HFR_FULL_FRAME_DISPLAY'));
    });

    test('PHOTO high V2 becomes non-conclusive when physical texture is measured', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(fullFrame: false),
        stillMl: _stillMl(),
        temporalMl: _videoMl(),
        stillOptical: _physicalTextureOptical(),
        temporalOptical: _physicalTextureOptical(),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('BUILD127_PHOTO_PHYSICAL_REPEATING_TEXTURE_GUARD'),
      );
    });

    test('optical structural display trace blocks physical texture downgrade', () {
      final optical = _physicalTextureOptical();
      final signals = Map<String, dynamic>.from(optical['signals'] as Map);
      signals['structuralDisplayTrace'] = true;
      optical['signals'] = signals;

      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(fullFrame: false),
        ml: _videoMl(),
        passiveOptical: optical,
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_PERSISTENT_STRONG_DISPLAY'),
      );
    });

    test('screen analyzer exposes auditable lattice metrics', () {
      final source = File('lib/hcv_screen_replay_analyzer.dart').readAsStringSync();

      for (final token in <String>[
        'repetitiveTextureScore',
        'latticeRegularityScore',
        'latticeDefectScore',
        'macroPatternScore',
        'rgbPhaseConsistencyScore',
        'dominantPatternPeriodPx',
        'physicalRepeatingTextureLikely',
      ]) {
        expect(source, contains(token));
      }
    });
  });
}

img.Image _fabricLikeImage() {
  final image = img.Image(width: 240, height: 240);
  for (var y = 0; y < image.height; y++) {
    final period = y < 80
        ? 5
        : y < 160
            ? 8
            : 7;
    for (var x = 0; x < image.width; x++) {
      final seam = (x % period) < 2;
      final warp = ((x + y ~/ 9) % (period * 3)) == 0;
      final value = seam ? 90 : (warp ? 135 : 185);
      image.setPixelRgba(x, y, value, value + 3, value + 5, 255);
    }
  }
  return image;
}

img.Image _rgbDisplayLikeImage() {
  final image = img.Image(width: 240, height: 240);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final phase = x % 6;
      if (phase < 2) {
        image.setPixelRgba(x, y, 235, 55, 45, 255);
      } else if (phase < 4) {
        image.setPixelRgba(x, y, 45, 235, 55, 255);
      } else {
        image.setPixelRgba(x, y, 45, 55, 235, 255);
      }
    }
  }
  return image;
}

Map<String, dynamic> _physicalTextureOptical() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'screenReplayRisk': 'LOW',
      'screenReplayRiskScore': 20,
      'signals': <String, dynamic>{
        'strongDisplayTrace': false,
        'structuralDisplayTrace': false,
        'confirmedDisplayTrace': false,
        'physicalRepeatingTextureLikely': true,
        'repetitiveTextureScore': 0.82,
        'latticeRegularityScore': 0.34,
        'latticeDefectScore': 0.66,
        'macroPatternScore': 0.54,
        'rgbPhaseConsistencyScore': 0.08,
        'dominantPatternPeriodPx': 15.0,
      },
    };

Map<String, dynamic> _stillMl() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.95,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 96,
        'contentAreaRiskScore': 92,
      },
    };

Map<String, dynamic> _videoMl() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.96,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (var i = 0; i < 3; i++)
          <String, dynamic>{
            'predictedClass': 'SCREEN_MONITOR',
            'signals': <String, dynamic>{
              'fullFrameRiskScore': i == 0 ? 96 : 91,
              'contentAreaRiskScore': 90,
            },
          },
      ],
    };

Map<String, dynamic> _hfr({required bool fullFrame}) => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'hfrSpatialComparability': 'COMPARABLE',
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': fullFrame,
        'displayLikeCellCount': fullFrame ? 9 : 0,
        'realityLikeCellCount': 0,
        'spatialFamilyCellCount': fullFrame ? 9 : 0,
        'harmonicAwareSpatialFamilyCellCount': fullFrame ? 9 : 0,
        'rowTimeFamilyCellCount': fullFrame ? 9 : 0,
      },
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'periodicCellCount': fullFrame ? 9 : 0,
        'stableCellCount': fullFrame ? 9 : 0,
        'medianCellPeriodicityStrength': fullFrame ? 0.24 : 0.02,
      },
    };
