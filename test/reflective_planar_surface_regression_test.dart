import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/camera_page.dart';

Map<String, dynamic> mlPhoto({
  required double probability,
  required double confidence,
  required int score,
  required int full,
  required int content,
}) =>
    {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'COMPLETE',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': probability,
      'predictedClassConfidence': confidence,
      'screenReplayRiskScore': score,
      'framesAnalyzed': 1,
      'signals': {
        'fullFrameRiskScore': full,
        'contentAreaRiskScore': content,
        'flatSceneUniformity': true,
        'lowMicroVariation': true,
      },
    };

Map<String, dynamic> optical({bool physical = false}) => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ANALYSIS_V1',
      'analysisStatus': 'COMPLETE',
      'screenReplayRiskScore': physical ? 70 : 0,
      'signals': {
        'flatSceneUniformity': true,
        'lowMicroVariation': true,
        'confirmedDisplayTrace': false,
        'periodicLightTrace': false,
        'opticalCorroboratedTrace': false,
        'structuralDisplayTrace': physical,
        'strongDisplayTrace': false,
        'localRefreshFlicker': physical,
        'horizontalRefreshBands': false,
      },
    };

Map<String, dynamic> mlVideo({
  required double probability,
  required double confidence,
  required int score,
  required int medium,
  required int strong,
  required double average,
  required int maxFrame,
  required int full,
  required int content,
  required int frames,
}) =>
    {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'COMPLETE',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': probability,
      'predictedClassConfidence': confidence,
      'screenReplayRiskScore': score,
      'framesAnalyzed': frames,
      'mediumScreenFrameCount': medium,
      'strongScreenFrameCount': strong,
      'averageScreenReplayRiskScore': average,
      'maxFrameScreenReplayRiskScore': maxFrame,
      'signals': {
        'fullFrameRiskScore': full,
        'contentAreaRiskScore': content,
        'flatSceneUniformity': true,
        'lowMicroVariation': true,
      },
      'videoFrameAnalyses': List.generate(
        frames,
        (_) => {'predictedClass': 'SCREEN_MONITOR'},
      ),
    };

void main() {
  test('framed reflective artwork is no longer strong from ML alone', () {
    final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
      mlPhoto(
        probability: 0.8519,
        confidence: 0.7745,
        score: 85,
        full: 85,
        content: 85,
      ),
      optical(),
    ]);
    expect(result.decision, 'NON_CONCLUSIVE');
    expect(result.risk, 'MEDIUM');
    expect(result.reasons,
        contains('FLAT_REFLECTIVE_SCREEN_LIKE_CONTENT_WITHOUT_STRONG_DISPLAY_CORROBORATION'));
  });

  test('reflective artwork video is no longer strong from weak persistence', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      mlVideo(
        probability: 0.9551,
        confidence: 0.9421,
        score: 96,
        medium: 1,
        strong: 1,
        average: 84.67,
        maxFrame: 96,
        full: 96,
        content: 95,
        frames: 3,
      ),
      optical(),
    ]);
    expect(result.decision, 'NON_CONCLUSIVE');
  });

  test('true monitor photo remains strong with physical corroboration', () {
    final result = combinePhotoDisplayRiskFromPreCaptureEvidence([
      mlPhoto(
        probability: 0.9845,
        confidence: 0.9742,
        score: 97,
        full: 98,
        content: 98,
      ),
      optical(physical: true),
    ]);
    expect(result.decision, 'STRONG_DISPLAY_RISK');
  });

  test('true monitor video remains strong with stringent multi-frame ML', () {
    final result = combineVideoDisplayRiskFromCaptureEvidence([
      mlVideo(
        probability: 0.9937,
        confidence: 0.9906,
        score: 99,
        medium: 3,
        strong: 3,
        average: 98.67,
        maxFrame: 99,
        full: 99,
        content: 99,
        frames: 3,
      ),
      optical(),
    ]);
    expect(result.decision, 'STRONG_DISPLAY_RISK');
  });
}
