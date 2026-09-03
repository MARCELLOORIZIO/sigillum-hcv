import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

Map<String, dynamic> _photoMl({
  required String predictedClass,
  required double screenProbability,
  required int score,
}) => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'predictedClass': predictedClass,
      'screenProbability': screenProbability,
      'screenReplayRiskScore': score,
      'framesAnalyzed': 1,
    };

Map<String, dynamic> _videoMl() => {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.74,
      'screenReplayRiskScore': 74,
      'framesAnalyzed': 4,
      'videoFrameAnalyses': const [
        {'predictedClass': 'SCREEN_MONITOR'},
        {'predictedClass': 'SCREEN_MONITOR'},
        {'predictedClass': 'SCREEN_MONITOR'},
        {'predictedClass': 'REALITY_ROOM'},
      ],
    };

void main() {
  test('photo SCREEN at p=0.80 is classified STRONG', () {
    final result = HCVDisplayRiskFusion.mlFirstPhotoDecision(
      _photoMl(
        predictedClass: 'SCREEN_TABLET',
        screenProbability: 0.80,
        score: 80,
      ),
    );

    expect(result, isNotNull);
    expect(result!.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, 80);
    expect(
      result.reasons,
      contains('ML_FIRST_PHOTO_SCREEN_FAMILY_HIGH_PROBABILITY'),
    );
  });

  test('build76 TV-like photo at p=0.8474 is classified STRONG', () {
    final result = HCVDisplayRiskFusion.mlFirstPhotoDecision(
      _photoMl(
        predictedClass: 'SCREEN_TABLET',
        screenProbability: 0.8474,
        score: 85,
      ),
    );

    expect(result, isNotNull);
    expect(result!.decision, 'STRONG_DISPLAY_RISK');
    expect(result.score, 85);
  });

  test('photo SCREEN at p=0.79 remains in gray zone', () {
    final result = HCVDisplayRiskFusion.mlFirstPhotoDecision(
      _photoMl(
        predictedClass: 'SCREEN_MONITOR',
        screenProbability: 0.79,
        score: 79,
      ),
    );

    expect(result, isNull);
  });

  test('photo REALITY threshold remains unchanged at p<=0.20', () {
    final result = HCVDisplayRiskFusion.mlFirstPhotoDecision(
      _photoMl(
        predictedClass: 'REALITY_ROOM',
        screenProbability: 0.20,
        score: 20,
      ),
    );

    expect(result, isNotNull);
    expect(result!.decision, 'NO_DISPLAY_EVIDENCE');
    expect(result.score, 20);
  });

  test('video ML-first threshold remains unchanged', () {
    final result = HCVDisplayRiskFusion.mlFirstVideoDecision(_videoMl());
    expect(result, isNull);
  });
}
