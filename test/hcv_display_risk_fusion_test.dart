import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

void main() {
  group('HCVDisplayRiskFusion production policy', () {
    test('real scene with analyzed sources and no evidence stays low', () {
      final result = HCVDisplayRiskFusion.combine([
        _liveProbe(score: 10),
        _staticOptical(score: 20),
        _mlReality(),
      ]);

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.risk, 'LOW');
      expect(result.score, lessThanOrEqualTo(30));
    });

    test('one static source cannot create a photo warning alone', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(score: 10),
          _staticOptical(score: 78, structural: true),
          _mlReality(),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.strongSources, contains('STATIC_OPTICAL'));
    });

    test('static and ML screen evidence corroborate a photo warning', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(score: 10),
          _staticOptical(score: 78, structural: true),
          _mlScreen(score: 95, confidence: 0.90),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, inInclusiveRange(45, 69));
      expect(
        result.evidenceSources,
        containsAll(<String>['STATIC_OPTICAL', 'ML_SCREEN_CLASS']),
      );
      expect(
        result.reasons,
        contains('POST_CAPTURE_SOURCES_CORROBORATE_SCREEN'),
      );
    });

    test('weak live support plus one static source is non-conclusive', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            score: 24,
            signals: const {'temporalEvidence': true},
          ),
          _staticOptical(score: 72, structural: true),
          _mlReality(),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.reasons, contains('LIVE_DISPLAY_TRACE_WEAK_SUPPORT'));
    });

    test('strong photo warning requires live and independent corroboration', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _liveProbe(
            score: 82,
            decision: 'STRONG_DISPLAY_RISK',
            signals: const {'confirmedDisplayTrace': true},
          ),
          _staticOptical(score: 75, structural: true),
          _mlReality(),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.risk, 'HIGH');
    });

    test('failed live acquisition is not reported as no display evidence', () {
      final result = HCVDisplayRiskFusion.combine(
        [
          _unknownLiveProbe('INSUFFICIENT_ANALYSIS_QUALITY'),
          _staticOptical(score: 72, structural: true),
          _mlReality(),
        ],
        liveCaptureOnly: true,
      );

      expect(result.decision, 'NOT_ANALYZED');
      expect(result.risk, 'UNKNOWN');
    });

    test('video strong risk requires two independent evidence sources', () {
      final result = HCVDisplayRiskFusion.combine([
        _liveProbe(score: 10),
        _staticOptical(score: 78, structural: true),
        _mlScreen(score: 96, confidence: 0.91),
      ]);

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.risk, 'HIGH');
      expect(
        result.evidenceSources,
        containsAll(<String>['STATIC_OPTICAL', 'ML_SCREEN_CLASS']),
      );
    });

    test('a single ML screen classification remains non-conclusive', () {
      final result = HCVDisplayRiskFusion.combine([
        _liveProbe(score: 10),
        _staticOptical(score: 20),
        _mlScreen(score: 95, confidence: 0.90),
      ]);

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.risk, 'MEDIUM');
    });
  });
}

Map<String, dynamic> _liveProbe({
  required int score,
  String? decision,
  double quality = 0.80,
  Map<String, dynamic> signals = const <String, dynamic>{},
}) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V2',
    'analysisStatus': 'ANALYZED',
    'analysisQuality': quality,
    'screenReplayRiskScore': score,
    'displayRiskDecision': decision ??
        (score >= 70
            ? 'STRONG_DISPLAY_RISK'
            : score >= 45
                ? 'NON_CONCLUSIVE'
                : 'NO_DISPLAY_EVIDENCE'),
    'signals': signals,
  };
}

Map<String, dynamic> _unknownLiveProbe(String reason) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V2',
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
    'type': 'SIGILLUM_SCREEN_REPLAY_IMAGE_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'signals': {
      'structuralDisplayTrace': structural,
      'pixelGridOrMoireHint': structural,
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

Map<String, dynamic> _mlReality() {
  return {
    'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': 12,
    'predictedClass': 'REALITY_OBJECT',
    'predictedClassConfidence': 0.91,
  };
}
