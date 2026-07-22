import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('HCVDisplayRiskFusion', () {
    test('keeps a real scene with no evidence at low risk', () {
      final result = HCVDisplayRiskFusion.combine([
        _liveProbe(score: 20),
        _staticOptical(score: 20),
      ]);

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.risk, 'LOW');
      expect(result.score, 20);
    });

    test('does not promote an uncorroborated spatial pattern', () {
      final result = HCVDisplayRiskFusion.combine([
        _liveProbe(
          score: 20,
          fineGrid: 0.9887,
          fineStripe: 0.1713,
          persistent: 0.9535,
          dynamic: 0.0761,
          signals: const {
            'uncorroboratedDisplayPattern': true,
          },
        ),
        _staticOptical(score: 20),
      ]);

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.risk, 'LOW');
      expect(result.score, 20);
      expect(result.evidenceSources, isNot(contains('LIVE_PREVIEW')));
    });

    test('does not turn one passive high score into a strong verdict', () {
      final result = HCVDisplayRiskFusion.combine([
        _unknownLiveProbe('NOT_ENOUGH_PREVIEW_FRAMES'),
        _staticOptical(score: 70, structural: true),
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 69);
      expect(result.analysisStatus, 'PARTIAL');
      expect(
        result.reasons,
        contains('LIVE_PROBE_MISSING_NOT_ENOUGH_PREVIEW_FRAMES'),
      );
    });

    test('requires independent corroboration for strong display risk', () {
      final result = HCVDisplayRiskFusion.combine([
        _liveProbe(
          score: 85,
          decision: 'STRONG_DISPLAY_RISK',
          signals: const {
            'confirmedDisplayTrace': true,
            'periodicLightTrace': true,
          },
        ),
        _staticOptical(score: 76, structural: true),
      ]);

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.risk, 'HIGH');
      expect(result.score, greaterThanOrEqualTo(70));
      expect(result.strongSources, contains('LIVE_TEMPORAL'));
      expect(result.strongSources, contains('STATIC_OPTICAL'));
    });

    test('a low live score does not veto two independent strong sources', () {
      final result = HCVDisplayRiskFusion.combine([
        _liveProbe(score: 20),
        _staticOptical(score: 78, structural: true),
        _mlScreen(score: 96, confidence: 0.91),
      ]);

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.risk, 'HIGH');
      expect(
          result.evidenceSources,
          containsAll([
            'STATIC_OPTICAL',
            'ML_SCREEN_CLASS',
          ]));
    });

    test('archive 13 real selfie photo stays at no display evidence', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            score: 69,
            frames: 45,
            localFlicker: 0.1871,
            refresh: 0.1459,
            fineStripe: 0.51,
            fineGrid: 0.8783,
            moire: 0.4704,
            dynamic: 0.2015,
            persistent: 0.7538,
            signals: const {
              'pairedFlickerTrace': true,
              'uncorroboratedDisplayPattern': true,
            },
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 30);
    });

    test('archive 13 real selfie video remains no display evidence', () {
      final result = HCVDisplayRiskFusion.combine([
        _liveProbe(
          score: 30,
          frames: 45,
          localFlicker: 0.1936,
          refresh: 0.146,
          fineStripe: 0.5079,
          fineGrid: 0.8716,
          moire: 0.4676,
          dynamic: 0.2043,
          persistent: 0.7451,
        ),
        _staticOptical(score: 20),
      ]);

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 30);
    });

    test('archive 13 monitor photo keeps a cautious display warning', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            score: 30,
            frames: 45,
            localFlicker: 0.6672,
            refresh: 0.1600,
            fineStripe: 0.4396,
            fineGrid: 0.8782,
            moire: 0.5103,
            dynamic: 0.4375,
            persistent: 0.6956,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.reasons, contains('LIVE_EMISSIVE_TEMPORAL_PATTERN'));
    });

    test('archive 13 monitor video remains non-conclusive', () {
      final result = HCVDisplayRiskFusion.combine([
        _liveProbe(
          score: 30,
          frames: 45,
          localFlicker: 0.4922,
          refresh: 0.1962,
          fineStripe: 0.3769,
          fineGrid: 0.8002,
          moire: 0.4169,
          dynamic: 0.4869,
          persistent: 0.5611,
        ),
        _staticOptical(score: 20),
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.evidenceSources, contains('LIVE_PREVIEW'));
      expect(
        result.reasons,
        contains('LIVE_CORROBORATED_TEMPORAL_PATTERN'),
      );
    });

    test('archive 11 selfie photo does not become a display warning', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            score: 70,
            frames: 45,
            localFlicker: 0.4364,
            refresh: 0.064,
            fineStripe: 0.2334,
            fineGrid: 0.5254,
            moire: 0.3464,
            dynamic: 0.3953,
            persistent: 0.3653,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 30);
    });

    test('archive 12 desk photo does not become a display warning', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            score: 70,
            frames: 32,
            localFlicker: 0.2688,
            refresh: 0.0512,
            fineStripe: 0.1805,
            fineGrid: 0.7872,
            moire: 0.3345,
            dynamic: 0.3373,
            persistent: 0.5479,
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 30);
    });

    test('close paper pattern stays at no display evidence', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            score: 70,
            frames: 38,
            localFlicker: 0.1246,
            refresh: 0.1009,
            fineStripe: 0.2546,
            fineGrid: 0.9863,
            moire: 0.294,
            dynamic: 0.062,
            persistent: 0.9602,
            signals: const {
              'uncorroboratedDisplayPattern': true,
            },
          ),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 30);
    });
  });
}

Map<String, dynamic> _liveProbe({
  required int score,
  String? decision,
  int frames = 45,
  double localFlicker = 0,
  double refresh = 0,
  double fineGrid = 0,
  double fineStripe = 1,
  double moire = 0,
  double persistent = 0,
  double dynamic = 1,
  Map<String, dynamic> signals = const {},
}) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'framesAnalyzed': frames,
    'displayRiskDecision': decision ??
        (score >= 70
            ? 'STRONG_DISPLAY_RISK'
            : score >= 45
                ? 'NON_CONCLUSIVE'
                : 'NO_DISPLAY_EVIDENCE'),
    'fineGridScore': fineGrid,
    'fineStripeScore': fineStripe,
    'localTemporalFlickerScore': localFlicker,
    'refreshBandScore': refresh,
    'moireFrequencyScore': moire,
    'persistentPatternScore': persistent,
    'dynamicChallengeScore': dynamic,
    'signals': signals,
  };
}

Map<String, dynamic> _unknownLiveProbe(String reason) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'analysisStatus': 'NOT_ANALYZED',
    'screenReplayRiskScore': null,
    'displayRiskDecision': 'NOT_ANALYZED',
    'reason': reason,
  };
}

Map<String, dynamic> _staticOptical({
  required int score,
  bool structural = false,
}) {
  return {
    'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
    'screenReplayRiskScore': score,
    'signals': {
      'structuralDisplayTrace': structural,
    },
  };
}

Map<String, dynamic> _mlScreen({
  required int score,
  required double confidence,
}) {
  return {
    'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'predictedClass': 'SCREEN_MONITOR',
    'predictedClassConfidence': confidence,
  };
}
