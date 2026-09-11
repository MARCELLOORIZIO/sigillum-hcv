import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

HCVDisplayRiskResult unresolved() => const HCVDisplayRiskResult(
  risk: 'MEDIUM',
  score: 45,
  decision: 'NON_CONCLUSIVE',
  analysisStatus: 'PARTIAL',
  evidenceSources: <String>[],
  strongSources: <String>[],
  reasons: <String>[
    'DISPLAY_CLASSIFICATION_NOT_RESOLVED',
    'LIVE_PROBE_MISSING',
  ],
);

Map<String, dynamic> negativeHfr() => <String, dynamic>{
  'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V2',
  'analysisStatus': 'ANALYZED',
  'coherentDisplayPeriodicity': false,
  'shortExposureVerified': true,
  'exposureLockedForEntireNativeCapture': true,
  'framesAnalyzed': 84,
  'actualFrameRateFromTimestamps': 240.62,
};

Map<String, dynamic> cleanOptical() => <String, dynamic>{
  'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
  'analysisStatus': 'ANALYZED',
  'framesAnalyzed': 15,
  'screenReplayRiskScore': 20,
  'signals': <String, dynamic>{
    'displayFlicker': false,
    'pixelGridOrMoireHint': false,
    'uniformPixelGrid': false,
    'localRefreshFlicker': false,
    'horizontalRefreshBands': false,
    'pairedLocalRefresh': false,
    'temporalScreenPulse': false,
    'structuralDisplayTrace': false,
    'strongDisplayTrace': false,
  },
};

Map<String, dynamic> ml({
  required int frames,
  required String predictedClass,
  required double p,
  required double confidence,
  required int score,
  int medium = 0,
  int strong = 0,
  double? average,
  int? maxFrame,
  int fullFrame = 0,
  int contentArea = 0,
}) => <String, dynamic>{
  'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
  'analysisStatus': 'ANALYZED',
  'framesAnalyzed': frames,
  'predictedClass': predictedClass,
  'screenProbability': p,
  'predictedClassConfidence': confidence,
  'screenReplayRiskScore': score,
  'mediumScreenFrameCount': medium,
  'strongScreenFrameCount': strong,
  if (average != null) 'averageScreenReplayRiskScore': average,
  if (maxFrame != null) 'maxFrameScreenReplayRiskScore': maxFrame,
  'signals': <String, dynamic>{
    'fullFrameRiskScore': fullFrame,
    'contentAreaRiskScore': contentArea,
  },
};

void main() {
  test(
    'build100 reflective artwork photo resolves without weakening gates',
    () {
      final result =
          HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
            base: unresolved(),
            passiveOptical: cleanOptical(),
            ml: ml(
              frames: 1,
              predictedClass: 'SCREEN_MONITOR',
              p: 0.5516,
              confidence: 0.4407,
              score: 55,
              fullFrame: 55,
              contentArea: 59,
            ),
            temporalFrequencyProbe: negativeHfr(),
            photoTemporalMl: ml(
              frames: 4,
              predictedClass: 'SCREEN_MONITOR',
              p: 0.5915,
              confidence: 0.3368,
              score: 59,
              average: 53.75,
              maxFrame: 59,
              fullFrame: 59,
              contentArea: 66,
            ),
          );
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.score, 20);
    },
  );

  test('build100 textile photo resolves weak texture semantics', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 1,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.6155,
        confidence: 0.3864,
        score: 62,
        fullFrame: 62,
        contentArea: 26,
      ),
      temporalFrequencyProbe: negativeHfr(),
      photoTemporalMl: ml(
        frames: 4,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.7795,
        confidence: 0.5167,
        score: 78,
        average: 51.5,
        maxFrame: 78,
        fullFrame: 78,
        contentArea: 67,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test('build100 reflective artwork video resolves weak screen semantics', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 2,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.7476,
        confidence: 0.4658,
        score: 75,
        average: 64.5,
        maxFrame: 75,
        fullFrame: 75,
        contentArea: 81,
      ),
      temporalFrequencyProbe: negativeHfr(),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test('build100 short real video resolves extreme single-frame reality', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 1,
        predictedClass: 'REALITY_ROOM',
        p: 0.0008,
        confidence: 0.4795,
        score: 0,
        average: 0.0,
        maxFrame: 0,
        fullFrame: 0,
        contentArea: 1,
      ),
      temporalFrequencyProbe: negativeHfr(),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test('missing HFR keeps historical incompatible samples unchanged', () {
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 2,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.60,
        confidence: 0.40,
        score: 60,
        average: 55.0,
        maxFrame: 65,
      ),
      temporalFrequencyProbe: null,
    );
    expect(identical(result, base), isTrue);
  });

  test('any hard physical display signal blocks downgrade', () {
    final base = unresolved();
    final optical = cleanOptical();
    (optical['signals'] as Map<String, dynamic>)['horizontalRefreshBands'] =
        true;
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: optical,
      ml: ml(
        frames: 2,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.60,
        confidence: 0.40,
        score: 60,
        average: 55.0,
        maxFrame: 65,
      ),
      temporalFrequencyProbe: negativeHfr(),
    );
    expect(identical(result, base), isTrue);
  });

  test('persistent medium or strong ML screen evidence blocks downgrade', () {
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 4,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.94,
        confidence: 0.92,
        score: 94,
        medium: 4,
        strong: 3,
        average: 92.75,
        maxFrame: 94,
        fullFrame: 94,
        contentArea: 90,
      ),
      temporalFrequencyProbe: negativeHfr(),
    );
    expect(identical(result, base), isTrue);
  });

  test('positive coherent HFR can never be downgraded', () {
    final base = unresolved();
    final hfr = negativeHfr()..['coherentDisplayPeriodicity'] = true;
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 2,
        predictedClass: 'REALITY_OUTDOOR',
        p: 0.01,
        confidence: 0.90,
        score: 1,
        average: 1.0,
        maxFrame: 1,
      ),
      temporalFrequencyProbe: hfr,
    );
    expect(identical(result, base), isTrue);
  });
}
