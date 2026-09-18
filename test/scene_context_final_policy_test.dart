import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_context_evidence.dart';
import 'package:sigillum_iphone/hcv_temporal_frequency_probe.dart';

HCVDisplayRiskResult _strongBase() => const HCVDisplayRiskResult(
      risk: 'HIGH',
      score: 98,
      decision: 'STRONG_DISPLAY_RISK',
      analysisStatus: 'COMPLETE',
      evidenceSources: <String>['ML_SCREEN_CLASS'],
      strongSources: <String>['ML_SCREEN_CLASS'],
      reasons: <String>['ML_SCREEN_STRONG'],
    );

Map<String, dynamic> _quietOptical() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 15,
      'screenReplayRisk': 'LOW',
      'screenReplayRiskScore': 20,
      'signals': <String, dynamic>{
        'structuralDisplayTrace': false,
        'strongDisplayTrace': false,
        'temporalScreenPulse': false,
        'localRefreshFlicker': false,
      },
    };

Map<String, dynamic> _persistentMl() => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': 3,
      'strongScreenFrameCount': 3,
      'mediumScreenFrameCount': 3,
      'averageScreenReplayRiskScore': 97.0,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (final p in <double>[0.98, 0.97, 0.96])
          <String, dynamic>{
            'predictedClass': 'SCREEN_MONITOR',
            'screenProbability': p,
            'screenReplayRiskScore': (p * 100).round(),
            'signals': <String, dynamic>{
              'fullFrameRiskScore': 97,
              'contentAreaRiskScore': 96,
            },
          },
      ],
    };

Map<String, dynamic> _mixedHfr() => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.62,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'fullFrameReality': false,
        'positivePhysicalRealityEvidence': false,
        'mixedSceneDetected': true,
        'allNineCellsSameDisplayFamily': false,
        'displayLikeCellCount': 4,
        'realityLikeCellCount': 1,
        'indeterminateCellCount': 4,
        'spatialFamilyCellCount': 7,
        'harmonicAwareSpatialFamilyCellCount': 8,
        'rowTimeFamilyCellCount': 6,
      },
    };

Map<String, dynamic> _liveGeometry({
  required String sceneClass,
  bool reality = false,
  bool planar = false,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'analysisStatus': 'ANALYZED',
      'geometryChallenge': <String, dynamic>{
        'sceneClass': sceneClass,
        'realityEvidence': reality,
        'planarEvidence': planar,
      },
      'signals': <String, dynamic>{
        'geometricRealityEvidence': reality,
        'planarSceneEvidence': planar,
      },
    };

void main() {
  group('scene context separation', () {
    test('DISPLAY plus UNKNOWN cells is never mixed HFR coverage', () {
      expect(
        HCVTemporalFrequencyProbe.qualifiesHfrHeterogeneousCoverage(
          displayLikeCellCount: 4,
          realityLikeCellCount: 0,
          fullFrameDisplay: false,
          displayOnlyFullGridCoverage: false,
        ),
        isFalse,
      );
      expect(
        HCVTemporalFrequencyProbe.qualifiesHfrHeterogeneousCoverage(
          displayLikeCellCount: 4,
          realityLikeCellCount: 1,
          fullFrameDisplay: false,
          displayOnlyFullGridCoverage: false,
        ),
        isTrue,
      );
    });

    test('mixed HFR remains diagnostic when scene context is unknown', () {
      final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: _strongBase(),
        passiveOptical: _quietOptical(),
        ml: _persistentMl(),
        temporalFrequencyProbe: _mixedHfr(),
        sceneContextEvidence: HCVSceneContextEvidence.unknown(),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('HFR_HETEROGENEOUS_COVERAGE_DIAGNOSTIC_ONLY'),
      );
    });

    test('positive 3D geometry makes a detected display embedded in reality', () {
      final context = HCVSceneContextEvidence.fromLiveProbe(
        _liveGeometry(sceneClass: 'REALITY', reality: true),
      );
      expect(context.positiveRealityContext, isTrue);

      final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: _strongBase(),
        passiveOptical: _quietOptical(),
        ml: _persistentMl(),
        temporalFrequencyProbe: _mixedHfr(),
        sceneContextEvidence: context,
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.risk, 'LOW');
      expect(
        result.reasons,
        contains('DISPLAY_PHYSICS_EMBEDDED_IN_POSITIVE_REALITY_CONTEXT'),
      );
      expect(result.evidenceSources, contains('ML_SCREEN_CLASS'));
      expect(result.strongSources, contains('ML_SCREEN_CLASS'));
    });

    test('planarity alone is neither display proof nor positive reality proof', () {
      final context = HCVSceneContextEvidence.fromLiveProbe(
        _liveGeometry(sceneClass: 'PLANAR', planar: true),
      );

      expect(context.positiveRealityContext, isFalse);
      expect(context.planarOnly, isTrue);

      final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
        base: _strongBase(),
        passiveOptical: _quietOptical(),
        ml: _persistentMl(),
        temporalFrequencyProbe: _mixedHfr(),
        sceneContextEvidence: context,
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });
  });
}
