import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_ml_v3_photo_residual.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

void main() {
  group('BUILD127 V3 PHOTO residual veto', () {
    test('BMW-like high V2 + low V3 triggers veto', () {
      expect(
        HCVMLV3PhotoResidual.shouldVetoStrongV2(
          v2ScreenProbability: 0.9396,
          v3CleanScreenProbability: 0.083,
          v3HardScreenProbability: 0.126,
        ),
        isTrue,
      );
    });

    test('BD06-like true monitor is protected by V3 margin', () {
      expect(
        HCVMLV3PhotoResidual.shouldVetoStrongV2(
          v2ScreenProbability: 0.9265,
          v3CleanScreenProbability: 0.242,
          v3HardScreenProbability: 0.267,
        ),
        isFalse,
      );
    });

    test('E9F-like true monitor is protected by V3 margin', () {
      expect(
        HCVMLV3PhotoResidual.shouldVetoStrongV2(
          v2ScreenProbability: 0.9754,
          v3CleanScreenProbability: 0.306,
          v3HardScreenProbability: 0.313,
        ),
        isFalse,
      );
    });

    test('V3 veto suppresses only standalone PHOTO ML shortcut', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          display: 0,
          reality: 0,
          periodic: 0,
          stable: 0,
          medianPeriodicity: 0.03,
        ),
        stillMl: _stillMl(veto: true),
        temporalMl: _videoMl(screenFrames: 3),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(
        result.reasons,
        isNot(contains('BUILD124_PHOTO_STILL_STRONG_DISPLAY')),
      );
    });

    test('HFR full-frame display always overrides V3 veto', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          display: 9,
          reality: 0,
          periodic: 9,
          stable: 9,
          medianPeriodicity: 0.25,
          fullFrame: true,
        ),
        stillMl: _stillMl(veto: true),
        temporalMl: _videoMl(screenFrames: 3),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.reasons, contains('BUILD124_HFR_FULL_FRAME_DISPLAY'));
    });

    test('HFR plus multi-evidence can still recover DISPLAY after V3 veto', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _hfr(
          display: 2,
          reality: 0,
          periodic: 2,
          stable: 2,
          medianPeriodicity: 0.06,
        ),
        stillMl: _stillMl(veto: true, probability: 0.94),
        temporalMl: _videoMl(screenFrames: 3),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_PHOTO_MULTI_EVIDENCE_DISPLAY'),
      );
    });

    test('VIDEO path remains V2-only', () {
      final camera = File('lib/camera_page.dart').readAsStringSync();
      final classifier =
          File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();

      expect(camera, contains('HCVMLV3PhotoResidual.instance.analyzePhoto'));
      expect(classifier, isNot(contains('HCVMLV3PhotoResidual')));
      expect(
        camera,
        matches(
          RegExp(
            r'HCVMLScreenReplayClassifier\\.instance\\s*'
            r'\\.analyzeVideo\\(savedVideoPath\\)',
          ),
        ),
      );
    });

    test('V3 is fail-open and cannot create positive REALITY proof', () {
      final source =
          File('lib/hcv_ml_v3_photo_residual.dart').readAsStringSync();
      final policy =
          File('lib/hcv_multi_evidence_display_policy.dart').readAsStringSync();

      expect(source, contains('PHOTO_V2_FALSE_POSITIVE_VETO_ONLY'));
      expect(source, contains('cannotOverrideHfrDisplay'));
      expect(source, contains('cannotAffectVideo'));
      expect(
        policy,
        contains('ABSENCE_OF_DISPLAY_PROOF_IS_NOT_POSITIVE_REALITY_PROOF'),
      );
    });
  });
}

Map<String, dynamic> _stillMl({
  bool veto = false,
  double probability = 0.94,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': probability,
      'v3RealityVeto': veto,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 94,
        'contentAreaRiskScore': 93,
        'v3RealityVeto': veto,
      },
    };

Map<String, dynamic> _videoMl({required int screenFrames}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.93,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (var i = 0; i < 3; i++)
          <String, dynamic>{
            'predictedClass':
                i < screenFrames ? 'SCREEN_MONITOR' : 'REALITY_ROOM',
            'signals': <String, dynamic>{
              'fullFrameRiskScore': 93,
              'contentAreaRiskScore': 93,
            },
          },
      ],
    };

Map<String, dynamic> _hfr({
  required int display,
  required int reality,
  required int periodic,
  required int stable,
  required double medianPeriodicity,
  bool fullFrame = false,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'hfrSpatialComparability': 'COMPARABLE',
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': fullFrame,
        'displayLikeCellCount': display,
        'realityLikeCellCount': reality,
        'spatialFamilyCellCount': display >= 2 ? 9 : 0,
        'harmonicAwareSpatialFamilyCellCount': display >= 2 ? 9 : 0,
        'rowTimeFamilyCellCount': display >= 2 ? 9 : 0,
      },
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'periodicCellCount': periodic,
        'stableCellCount': stable,
        'medianCellPeriodicityStrength': medianPeriodicity,
      },
    };
