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

    test('does not discard a close monitor spatial pattern', () {
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

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.risk, 'MEDIUM');
      expect(result.score, 45);
      expect(result.evidenceSources, contains('LIVE_PREVIEW'));
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
  });
}

Map<String, dynamic> _liveProbe({
  required int score,
  String? decision,
  double fineGrid = 0,
  double fineStripe = 1,
  double persistent = 0,
  double dynamic = 1,
  Map<String, dynamic> signals = const {},
}) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'displayRiskDecision': decision ??
        (score >= 70
            ? 'STRONG_DISPLAY_RISK'
            : score >= 45
                ? 'NON_CONCLUSIVE'
                : 'NO_DISPLAY_EVIDENCE'),
    'fineGridScore': fineGrid,
    'fineStripeScore': fineStripe,
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
