import 'package:flutter_test/flutter_test.dart';
import 'package:hcv_app/hcv_display_risk_fusion.dart';

Map<String, dynamic> _frame(String predictedClass) => {
      'predictedClass': predictedClass,
    };

void main() {
  test('reflective framed artwork photo is not strong from ML alone', () {
    final ml = <String, dynamic>{
      'analysisStatus': 'COMPLETE',
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.7745,
      'screenProbability': 0.8519,
      'screenReplayRiskScore': 85,
      'framesAnalyzed': 1,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 85,
        'contentAreaRiskScore': 78,
      },
    };

    expect(HCVDisplayRiskFusion.mlFirstPhotoDecision(ml), isNull);
  });

  test('true monitor photo remains a strong ML-first display result', () {
    final ml = <String, dynamic>{
      'analysisStatus': 'COMPLETE',
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.995,
      'screenProbability': 0.9991,
      'screenReplayRiskScore': 100,
      'framesAnalyzed': 1,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 100,
        'contentAreaRiskScore': 99,
      },
    };

    final result = HCVDisplayRiskFusion.mlFirstPhotoDecision(ml);
    expect(result, isNotNull);
    expect(result!.decision, 'STRONG_DISPLAY_RISK');
  });

  test('reflective framed artwork video is not strong from semantic majority alone', () {
    final ml = <String, dynamic>{
      'analysisStatus': 'COMPLETE',
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.9421,
      'screenProbability': 0.9551,
      'screenReplayRiskScore': 54,
      'framesAnalyzed': 3,
      'strongScreenFrameCount': 1,
      'mediumScreenFrameCount': 1,
      'averageScreenReplayRiskScore': 84.6667,
      'maxFrameScreenReplayRiskScore': 96,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 96,
        'contentAreaRiskScore': 93,
      },
      'videoFrameAnalyses': [
        _frame('SCREEN_MONITOR'),
        _frame('SCREEN_MONITOR'),
        _frame('SCREEN_MONITOR'),
      ],
    };

    expect(HCVDisplayRiskFusion.mlFirstVideoDecision(ml), isNull);
  });

  test('true monitor video retains strong multi-frame ML evidence', () {
    final ml = <String, dynamic>{
      'analysisStatus': 'COMPLETE',
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.9906,
      'screenProbability': 0.9937,
      'screenReplayRiskScore': 99,
      'framesAnalyzed': 3,
      'strongScreenFrameCount': 3,
      'mediumScreenFrameCount': 3,
      'averageScreenReplayRiskScore': 98.6667,
      'maxFrameScreenReplayRiskScore': 99,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 99,
        'contentAreaRiskScore': 94,
      },
      'videoFrameAnalyses': [
        _frame('SCREEN_MONITOR'),
        _frame('SCREEN_MONITOR'),
        _frame('SCREEN_MONITOR'),
      ],
    };

    final result = HCVDisplayRiskFusion.mlFirstVideoDecision(ml);
    expect(result, isNotNull);
    expect(result!.decision, 'STRONG_DISPLAY_RISK');
  });

  test('manuscript video is not promoted to display by weak screen semantics', () {
    final ml = <String, dynamic>{
      'analysisStatus': 'COMPLETE',
      'predictedClass': 'SCREEN_MONITOR',
      'predictedClassConfidence': 0.6503,
      'screenProbability': 0.7976,
      'screenReplayRiskScore': 80,
      'framesAnalyzed': 2,
      'strongScreenFrameCount': 0,
      'mediumScreenFrameCount': 0,
      'averageScreenReplayRiskScore': 77.5,
      'maxFrameScreenReplayRiskScore': 80,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': 80,
        'contentAreaRiskScore': 75,
      },
      'videoFrameAnalyses': [
        _frame('SCREEN_MONITOR'),
        _frame('SCREEN_MONITOR'),
      ],
    };

    expect(HCVDisplayRiskFusion.mlFirstVideoDecision(ml), isNull);
  });
}
