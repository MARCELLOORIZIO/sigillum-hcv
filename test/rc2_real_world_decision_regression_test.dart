import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_decision_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  test('classifier REALITY is not rejected by a second fusion threshold', () {
    final geometry = HCVSceneGeometryClassifier.classify(
      motionMagnitude: 0.1667,
      flowReliability: 0.5792,
      directionCoherence: 0.60,
      depthDispersion: 0.8196,
      planarCoherence: 0.0781,
      matchedRegions: 20,
    );
    expect(geometry.realityEvidence, isTrue);

    final result = HCVSceneDecisionFusion.fuse(
      illumination: const HCVActiveDisplayClassification(
        decision: 'NON_CONCLUSIVE',
        risk: 'MEDIUM',
        score: 45,
        displayProbability: 0.55,
        illuminationResponseScore: 0.4,
        emissiveIndependenceScore: 0.6,
        electronicCueScore: 0.5,
        reasons: <String>['EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH'],
      ),
      geometry: geometry,
    );

    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.sceneClass, 'REALITY');
  });

  test('real-world temporal false positive cannot become HIGH by itself', () {
    final result = HCVDisplayRiskFusion.combine([
      _liveProbe(
        score: 75,
        geometrySceneClass: 'PLANAR',
        signals: const {
          'activeChallengeIndeterminate': true,
        },
      ),
      _passive(
        score: 75,
        strongDisplayTrace: true,
        structuralDisplayTrace: false,
        confirmedDisplayTrace: false,
      ),
      _mlReality(score: 1, confidence: 0.9584),
    ]);

    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
    expect(result.risk, isNot('HIGH'));
    expect(result.decision, 'NON_CONCLUSIVE');
    expect(result.reasons, contains('ML_REALITY_REQUIRES_INDEPENDENT_CORROBORATION'));
  });

  test('strong SCREEN ML conflicting with REALITY geometry is non-conclusive', () {
    final result = HCVDisplayRiskFusion.combine([
      _liveProbe(
        score: 20,
        geometrySceneClass: 'REALITY',
        signals: const {
          'reflectedRealityEvidence': true,
        },
      ),
      _mlScreen(score: 99, confidence: 0.985),
    ]);

    expect(result.decision, 'NON_CONCLUSIVE');
    expect(result.risk, 'MEDIUM');
    expect(result.reasons, contains('ML_GEOMETRY_CONFLICT'));
  });

  test('two genuinely independent strong display families still produce HIGH', () {
    final result = HCVDisplayRiskFusion.combine([
      _liveProbe(
        score: 85,
        decision: 'STRONG_DISPLAY_RISK',
        signals: const {
          'confirmedDisplayTrace': true,
          'periodicLightTrace': true,
        },
      ),
      _mlScreen(score: 96, confidence: 0.92),
    ]);

    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(result.risk, 'HIGH');
  });
}

Map<String, dynamic> _liveProbe({
  required int score,
  String? decision,
  String geometrySceneClass = 'UNKNOWN',
  Map<String, dynamic> signals = const {},
}) {
  return {
    'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'framesAnalyzed': 45,
    'displayRiskDecision': decision ??
        (score >= 70
            ? 'STRONG_DISPLAY_RISK'
            : score >= 45
                ? 'NON_CONCLUSIVE'
                : 'NO_DISPLAY_EVIDENCE'),
    'fineGridScore': 0.0,
    'fineStripeScore': 1.0,
    'localTemporalFlickerScore': 0.0,
    'refreshBandScore': 0.0,
    'moireFrequencyScore': 0.0,
    'persistentPatternScore': 0.0,
    'dynamicChallengeScore': 1.0,
    'geometryChallenge': {
      'sceneClass': geometrySceneClass,
    },
    'signals': signals,
  };
}

Map<String, dynamic> _passive({
  required int score,
  bool strongDisplayTrace = false,
  bool structuralDisplayTrace = false,
  bool confirmedDisplayTrace = false,
}) {
  return {
    'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
    'screenReplayRiskScore': score,
    'signals': {
      'strongDisplayTrace': strongDisplayTrace,
      'structuralDisplayTrace': structuralDisplayTrace,
      'confirmedDisplayTrace': confirmedDisplayTrace,
    },
  };
}

Map<String, dynamic> _mlReality({
  required int score,
  required double confidence,
}) {
  return {
    'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
    'analysisStatus': 'ANALYZED',
    'screenReplayRiskScore': score,
    'predictedClass': 'REALITY_OUTDOOR',
    'predictedClassConfidence': confidence,
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
