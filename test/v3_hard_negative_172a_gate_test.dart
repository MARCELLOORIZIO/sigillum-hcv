import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_ml_v3_photo_residual.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

void main() {
  group('V3 172A hard-negative residual gate', () {
    const screens = <_ScreenCase>[
      _ScreenCase('HCV-88CC6F97F38A4D65', 0.9920, 0.953613281, 0.920078039, 0.012978703),
      _ScreenCase('HCV-49FA17D6D28E4688', 0.9892, 0.962475896, 0.933414161, 0.000118596),
      _ScreenCase('HCV-22ADB79B73BD4FBB', 0.9929, 0.910183966, 0.867636323, 0.000056743),
      _ScreenCase('HCV-66B58B42B999416A', 0.9993, 0.960200727, 0.930551946, 0.000263101),
      _ScreenCase('HCV-27463957577E4ED5', 0.9716, 0.985965192, 0.966782570, 0.000002070),
      _ScreenCase('HCV-D0DFF784C2D446DF', 0.9377, 0.967316747, 0.935002327, 0.000016483),
      _ScreenCase('HCV-AE0F458640004FE7', 0.9972, 0.973800361, 0.953398049, 0.000048375),
      _ScreenCase('HCV-6A5B55785D2C4D9E', 0.9633, 0.236175060, 0.296962857, 0.167185172),
      _ScreenCase('HCV-C6FA3CBBD5714382', 0.9979, 0.972454786, 0.947705090, 0.000000186),
      _ScreenCase('HCV-D516E077C10140D9', 0.9633, 0.978363037, 0.957448483, 0.000000000),
      _ScreenCase('HCV-C6C696A6E63344DF', 0.9937, 0.811744273, 0.749025226, 0.000000343),
      _ScreenCase('HCV-E9F75F00F6134AF7', 0.9754, 0.304911762, 0.311984092, 0.914134085),
      _ScreenCase('HCV-C8C399E3E9BE4B86', 0.9845, 0.897673249, 0.822535157, 0.000001475),
      _ScreenCase('HCV-BF1B0754CA594555', 0.8943, 0.972742379, 0.962737739, 0.000000801),
      _ScreenCase('HCV-AEAFD4855C0B416E', 0.4038, 0.525791526, 0.603410184, 0.032956772),
      _ScreenCase('HCV-E7F4F3D3456A4AE1', 0.3723, 0.990484715, 0.986592412, 0.000000004),
      _ScreenCase('HCV-BD06C9FD69284BB6', 0.9265, 0.241004199, 0.266232550, 0.974783421),
    ];

    test('all 17 frozen SCREEN cases remain protected', () {
      expect(screens, hasLength(17));
      for (final item in screens) {
        final veto = HCVMLV3PhotoResidual.shouldVetoStrongV2(
          v2ScreenProbability: item.v2,
          v3CleanScreenProbability: item.clean,
          v3HardScreenProbability: item.hard,
          hardNegativeRealityProbability: item.hardNegativeReality,
        );
        expect(
          veto,
          isFalse,
          reason: 'hard-negative head must not veto SCREEN ${item.id}',
        );
        expect(
          item.hardNegativeReality,
          lessThan(HCVMLV3PhotoResidual.hardNegativeRealityThreshold),
          reason: 'SCREEN ${item.id} must stay below the hard-negative threshold',
        );
      }
    });

    test('172A real lamella original now vetoes strong V2 false positive', () {
      expect(
        HCVMLV3PhotoResidual.shouldVetoStrongV2(
          v2ScreenProbability: 0.9996,
          v3CleanScreenProbability: 0.851991653,
          v3HardScreenProbability: 0.817748904,
          hardNegativeRealityProbability: 0.997451246,
        ),
        isTrue,
      );
    });

    test('BMW legacy false-positive veto remains active', () {
      expect(
        HCVMLV3PhotoResidual.shouldVetoStrongV2(
          v2ScreenProbability: 0.9396,
          v3CleanScreenProbability: 0.083124205,
          v3HardScreenProbability: 0.126133233,
          hardNegativeRealityProbability: 0.999969602,
        ),
        isTrue,
      );
    });

    test('hard-negative head cannot bypass the V2 high gate', () {
      expect(
        HCVMLV3PhotoResidual.shouldVetoStrongV2(
          v2ScreenProbability: 0.7993,
          v3CleanScreenProbability: 0.056732561,
          v3HardScreenProbability: 0.096965507,
          hardNegativeRealityProbability: 0.999882340,
        ),
        isFalse,
      );
    });

    test('172A fusion no longer resolves as STRONG display', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: const <String, dynamic>{
          'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
          'analysisStatus': 'ANALYZED',
          'hfrSpatialComparability': 'COMPARABLE',
          'displayRealityEvidenceV3': <String, dynamic>{
            'fullFrameDisplay': false,
            'displayLikeCellCount': 0,
            'realityLikeCellCount': 0,
            'spatialFamilyCellCount': 6,
            'harmonicAwareSpatialFamilyCellCount': 6,
            'rowTimeFamilyCellCount': 9,
          },
          'coherentDisplayPeriodicityEvidence': <String, dynamic>{
            'periodicCellCount': 0,
            'stableCellCount': 0,
            'medianCellPeriodicityStrength': 0.03277382231703225,
          },
        },
        stillMl: const <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'predictedClass': 'SCREEN_MONITOR',
          'screenProbability': 0.9996,
          'v3RealityVeto': true,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 100,
            'contentAreaRiskScore': 100,
            'v3RealityVeto': true,
          },
        },
        temporalMl: const <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'predictedClass': 'SCREEN_MONITOR',
          'screenProbability': 0.9996,
          'videoFrameAnalyses': <Map<String, dynamic>>[
            <String, dynamic>{
              'predictedClass': 'SCREEN_MONITOR',
              'signals': <String, dynamic>{
                'fullFrameRiskScore': 100,
                'contentAreaRiskScore': 100,
              },
            },
            <String, dynamic>{
              'predictedClass': 'SCREEN_MONITOR',
              'signals': <String, dynamic>{
                'fullFrameRiskScore': 100,
                'contentAreaRiskScore': 100,
              },
            },
            <String, dynamic>{
              'predictedClass': 'SCREEN_MONITOR',
              'signals': <String, dynamic>{
                'fullFrameRiskScore': 100,
                'contentAreaRiskScore': 100,
              },
            },
          ],
        },
        stillOptical: const <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'signals': <String, dynamic>{
            'strongDisplayTrace': false,
            'structuralDisplayTrace': false,
            'confirmedDisplayTrace': false,
          },
        },
        temporalOptical: const <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'signals': <String, dynamic>{
            'strongDisplayTrace': false,
            'structuralDisplayTrace': false,
            'confirmedDisplayTrace': false,
          },
        },
        videoEquivalentDisplayRisk: const <String, dynamic>{
          'decision': 'STRONG_DISPLAY_RISK',
        },
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(
        result.reasons,
        contains('BUILD127_V3_RESIDUAL_VETO_NO_CORROBORATED_DISPLAY_EVIDENCE'),
      );
      expect(
        result.reasons,
        isNot(contains('BUILD124_PHOTO_STILL_STRONG_DISPLAY')),
      );
      expect(
        result.reasons,
        isNot(contains('BUILD124_PHOTO_MULTI_EVIDENCE_DISPLAY')),
      );
    });

    test('threshold and runtime wiring are frozen and PHOTO-only', () {
      expect(
        HCVMLV3PhotoResidual.hardNegativeRealityThreshold,
        closeTo(0.9837759923934937, 1e-12),
      );

      final source = File('lib/hcv_ml_v3_photo_residual.dart').readAsStringSync();
      final video =
          File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();

      expect(source, contains('<int, Object>{0: output0, 1: output1, 2: output2}'));
      expect(source, contains("'hardNegativeRealityProbability'"));
      expect(source, contains("'PHOTO_STRONG_V2_FALSE_POSITIVE_VETO_ONLY'"));
      expect(video, isNot(contains('hardNegativeRealityProbability')));
      expect(video, isNot(contains('hardNegativeRealityThreshold')));
    });
  });
}

class _ScreenCase {
  const _ScreenCase(
    this.id,
    this.v2,
    this.clean,
    this.hard,
    this.hardNegativeReality,
  );

  final String id;
  final double v2;
  final double clean;
  final double hard;
  final double hardNegativeReality;
}
