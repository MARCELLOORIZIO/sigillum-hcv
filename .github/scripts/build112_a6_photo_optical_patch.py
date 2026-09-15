from pathlib import Path

fusion_path = Path('lib/hcv_display_risk_fusion.dart')
source = fusion_path.read_text(encoding='utf-8')

marker = "PHOTO_MODERATE_SCREEN_OPTICAL_CORROBORATION"
if marker not in source:
    anchor = """    final photoStillTemporalScreenCorroboration =
        photoTemporalMl != null &&
        v3Analyzed &&
        !mixedScene &&
        !physicalDisplay &&
        temporalFrames >= 3 &&
        highAnyScreenFrames == temporalFrames &&
        mlStrongScreenFrames >= 3 &&
        mlAverageScreenRisk >= 90.0 &&
        stillPredictedClass.startsWith('SCREEN_') &&
        stillScreenProbability >= 0.92 &&
        stillScreenRisk >= 92 &&
        stillFullFrameRisk >= 92 &&
        stillContentAreaRisk >= 85 &&
        base.decision == 'STRONG_DISPLAY_RISK';

    final screenPresentButNotFullFrame =
"""
    replacement = """    final photoStillTemporalScreenCorroboration =
        photoTemporalMl != null &&
        v3Analyzed &&
        !mixedScene &&
        !physicalDisplay &&
        temporalFrames >= 3 &&
        highAnyScreenFrames == temporalFrames &&
        mlStrongScreenFrames >= 3 &&
        mlAverageScreenRisk >= 90.0 &&
        stillPredictedClass.startsWith('SCREEN_') &&
        stillScreenProbability >= 0.92 &&
        stillScreenRisk >= 92 &&
        stillFullFrameRisk >= 92 &&
        stillContentAreaRisk >= 85 &&
        base.decision == 'STRONG_DISPLAY_RISK';

    // BUILD112: recover the physically observed A6 photo false negative without
    // weakening any global ML/HFR threshold. This path is PHOTO-only and needs
    // three independent families to agree: near-full-frame still ML, a stable
    // three-frame SCREEN_* temporal sequence, and a strong passive optical
    // refresh trace from the technical mini-video. Mixed/physical-reality HFR
    // evidence remains an explicit veto.
    final opticalSignals = _signals(passiveOptical);
    final opticalRisk = passiveOptical?['screenReplayRisk']?.toString() ?? '';
    final opticalScore =
        (passiveOptical?['screenReplayRiskScore'] as num?)?.toInt() ?? 0;
    final temporalFrameAnalyses = temporalMl?['videoFrameAnalyses'];
    var temporalScreenClassFrames = 0;
    var temporalRisk80Frames = 0;
    var temporalFullFrame80Frames = 0;
    if (temporalFrameAnalyses is List) {
      for (final rawFrame in temporalFrameAnalyses) {
        if (rawFrame is! Map) continue;
        final frame = Map<String, dynamic>.from(rawFrame);
        final frameSignals = _signals(frame);
        if ((frame['predictedClass']?.toString() ?? '').startsWith('SCREEN_')) {
          temporalScreenClassFrames++;
        }
        if (((frame['screenReplayRiskScore'] as num?)?.toInt() ?? 0) >= 80) {
          temporalRisk80Frames++;
        }
        if (((frameSignals['fullFrameRiskScore'] as num?)?.toInt() ?? 0) >= 80) {
          temporalFullFrame80Frames++;
        }
      }
    }
    final positivePhysicalReality =
        _v3Evidence(temporalFrequencyProbe)?['positivePhysicalRealityEvidence'] ==
        true;
    final photoModerateScreenOpticalCorroboration =
        photoTemporalMl != null &&
        v3Analyzed &&
        !mixedScene &&
        !physicalDisplay &&
        !positivePhysicalReality &&
        base.decision == 'NON_CONCLUSIVE' &&
        passiveOptical?['captureSource'] == 'PHOTO_TECHNICAL_MINI_VIDEO_V2' &&
        opticalRisk == 'HIGH' &&
        opticalScore >= 80 &&
        opticalSignals['strongDisplayTrace'] == true &&
        opticalSignals['temporalScreenPulse'] == true &&
        opticalSignals['localRefreshFlicker'] == true &&
        stillPredictedClass.startsWith('SCREEN_') &&
        stillScreenProbability >= 0.88 &&
        stillScreenRisk >= 88 &&
        stillFullFrameRisk >= 88 &&
        stillContentAreaRisk >= 90 &&
        temporalFrames >= 3 &&
        mlAverageScreenRisk >= 80.0 &&
        temporalScreenClassFrames == temporalFrames &&
        temporalRisk80Frames == temporalFrames &&
        temporalFullFrame80Frames == temporalFrames;

    if (photoModerateScreenOpticalCorroboration) {
      final evidenceSources = <String>{
        ...base.evidenceSources,
        'PHOTO_MODERATE_SCREEN_OPTICAL_CORROBORATION',
      };
      final strongSources = <String>{
        ...base.strongSources,
        'PHOTO_MODERATE_SCREEN_OPTICAL_CORROBORATION',
      };
      final reasons = base.reasons
          .where(
            (reason) =>
                reason != 'DISPLAY_CLASSIFICATION_NOT_RESOLVED' &&
                reason != 'LIVE_PROBE_MISSING',
          )
          .toList()
        ..add('PHOTO_NEAR_FULL_FRAME_SCREEN_ML_SEQUENCE')
        ..add('PHOTO_OPTICAL_REFRESH_TRACE_CORROBORATES_SCREEN')
        ..add('DUAL_EVIDENCE_V3_ACTIVE');
      final corroboratedScore = max(
        base.score,
        max(opticalScore, max(stillScreenRisk, mlAverageScreenRisk.round())),
      );
      return HCVDisplayRiskResult(
        risk: 'HIGH',
        score: corroboratedScore,
        decision: 'STRONG_DISPLAY_RISK',
        analysisStatus: 'COMPLETE',
        evidenceSources: evidenceSources.toList(),
        strongSources: strongSources.toList(),
        reasons: reasons,
      );
    }

    final screenPresentButNotFullFrame =
"""
    if anchor not in source:
        raise RuntimeError('BUILD112 fusion anchor not found')
    source = source.replace(anchor, replacement, 1)
    fusion_path.write_text(source, encoding='utf-8')


test_path = Path('test/build112_photo_optical_corroboration_test.dart')
test_path.write_text(r'''import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

Map<String, dynamic> _frame({
  required double probability,
  required int risk,
  required int fullFrame,
  required int contentArea,
  String predictedClass = 'SCREEN_MONITOR',
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': predictedClass,
      'screenProbability': probability,
      'screenReplayRiskScore': risk,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': fullFrame,
        'contentAreaRiskScore': contentArea,
      },
    };

Map<String, dynamic> _temporal(List<Map<String, dynamic>> frames) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'framesAnalyzed': frames.length,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 1,
      'averageScreenReplayRiskScore': frames
              .map((e) => (e['screenReplayRiskScore'] as num).toDouble())
              .reduce((a, b) => a + b) /
          frames.length,
      'videoFrameAnalyses': frames,
    };

Map<String, dynamic> _still({
  double probability = 0.895,
  int risk = 89,
  int fullFrame = 89,
  int contentArea = 94,
}) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': probability,
      'screenReplayRiskScore': risk,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': fullFrame,
        'contentAreaRiskScore': contentArea,
      },
    };

Map<String, dynamic> _optical({
  String risk = 'HIGH',
  int score = 80,
  bool strongDisplayTrace = true,
  bool temporalScreenPulse = true,
  bool localRefreshFlicker = true,
}) =>
    <String, dynamic>{
      'captureSource': 'PHOTO_TECHNICAL_MINI_VIDEO_V2',
      'screenReplayRisk': risk,
      'screenReplayRiskScore': score,
      'signals': <String, dynamic>{
        'strongDisplayTrace': strongDisplayTrace,
        'temporalScreenPulse': temporalScreenPulse,
        'localRefreshFlicker': localRefreshFlicker,
      },
    };

Map<String, dynamic> _quietHfr({
  bool mixedScene = false,
  bool positivePhysicalReality = false,
}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'coherentDisplayPeriodicity': false,
      'shortExposureVerified': true,
      'exposureLockedForEntireNativeCapture': true,
      'framesAnalyzed': 84,
      'actualFrameRateFromTimestamps': 240.0,
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': false,
        'fullFrameReality': false,
        'positivePhysicalRealityEvidence': positivePhysicalReality,
        'mixedSceneDetected': mixedScene,
        'allNineCellsSameDisplayFamily': false,
        'displayLikeCellCount': 0,
        'spatialFamilyCellCount': 0,
        'harmonicAwareSpatialFamilyCellCount': 0,
        'rowTimeFamilyCellCount': 0,
      },
    };

const _baseA6 = HCVDisplayRiskResult(
  risk: 'MEDIUM',
  score: 45,
  decision: 'NON_CONCLUSIVE',
  analysisStatus: 'COMPLETE',
  evidenceSources: <String>[],
  strongSources: <String>[],
  reasons: <String>['DISPLAY_CLASSIFICATION_NOT_RESOLVED'],
);

HCVDisplayRiskResult _resolve({
  Map<String, dynamic>? still,
  Map<String, dynamic>? temporal,
  Map<String, dynamic>? optical,
  Map<String, dynamic>? hfr,
}) =>
    HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: _baseA6,
      passiveOptical: optical ?? _optical(),
      ml: still ?? _still(),
      temporalFrequencyProbe: hfr ?? _quietHfr(),
      photoTemporalMl: temporal ??
          _temporal(<Map<String, dynamic>>[
            _frame(probability: 0.8801, risk: 88, fullFrame: 88, contentArea: 77),
            _frame(probability: 0.8293, risk: 83, fullFrame: 83, contentArea: 72),
            _frame(probability: 0.8109, risk: 81, fullFrame: 81, contentArea: 84),
          ]),
    );

void main() {
  test('A6 BUILD111 physical monitor sample is recovered as HIGH', () {
    final result = _resolve();

    expect(result.risk, 'HIGH');
    expect(result.score, 89);
    expect(result.decision, 'STRONG_DISPLAY_RISK');
    expect(
      result.evidenceSources,
      contains('PHOTO_MODERATE_SCREEN_OPTICAL_CORROBORATION'),
    );
    expect(
      result.reasons,
      contains('PHOTO_OPTICAL_REFRESH_TRACE_CORROBORATES_SCREEN'),
    );
  });

  test('same ML semantics without optical refresh trace stay non-HIGH', () {
    final result = _resolve(
      optical: _optical(
        risk: 'LOW',
        score: 20,
        strongDisplayTrace: false,
        temporalScreenPulse: false,
        localRefreshFlicker: false,
      ),
    );

    expect(result.risk, isNot('HIGH'));
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });

  test('optical trace cannot override mixed real scene', () {
    final result = _resolve(hfr: _quietHfr(mixedScene: true));

    expect(result.risk, 'LOW');
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.reasons, contains('HFR_V3_MIXED_REAL_SCENE'));
  });

  test('positive physical reality veto blocks A6 recovery', () {
    final result = _resolve(
      hfr: _quietHfr(positivePhysicalReality: true),
    );

    expect(result.risk, isNot('HIGH'));
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });

  test('one temporal frame below full-frame 80 blocks recovery', () {
    final result = _resolve(
      temporal: _temporal(<Map<String, dynamic>>[
        _frame(probability: 0.8801, risk: 88, fullFrame: 88, contentArea: 77),
        _frame(probability: 0.8293, risk: 83, fullFrame: 79, contentArea: 72),
        _frame(probability: 0.8109, risk: 81, fullFrame: 81, contentArea: 84),
      ]),
    );

    expect(result.risk, isNot('HIGH'));
    expect(result.decision, isNot('STRONG_DISPLAY_RISK'));
  });
}
''', encoding='utf-8')

print('BUILD112 A6 fusion patch and focused regression test materialized')
