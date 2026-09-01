import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

Map<String, dynamic> _ml({
  required String predictedClass,
  required int frames,
  required int score,
  required double probability,
  required double confidence,
  required int full,
  required int content,
  int strong = 0,
  int medium = 0,
  double? average,
  int? maxFrame,
}) =>
    {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'predictedClass': predictedClass,
      'framesAnalyzed': frames,
      'screenReplayRiskScore': score,
      'screenProbability': probability,
      'predictedClassConfidence': confidence,
      'strongScreenFrameCount': strong,
      'mediumScreenFrameCount': medium,
      if (average != null) 'averageScreenReplayRiskScore': average,
      if (maxFrame != null) 'maxFrameScreenReplayRiskScore': maxFrame,
      'signals': {
        'fullFrameRiskScore': full,
        'contentAreaRiskScore': content,
      },
    };

void main() {
  test(
      '48-case corpus: spatial PHOTO gate has 13/13 display recall and 0/14 reality promotions',
      () {
    final cases = <(String, bool, Map<String, dynamic>)>[
      (
        'HCV-0886E66EC19F47DA',
        false,
        _ml(
            predictedClass: 'REALITY_OUTDOOR',
            frames: 1,
            score: 0,
            probability: 0.0047,
            confidence: 0.871,
            full: 0,
            content: 1)
      ),
      (
        'HCV-22ADB79B73BD4FBB',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 99,
            probability: 0.9929,
            confidence: 0.8985,
            full: 99,
            content: 96)
      ),
      (
        'HCV-27463957577E4ED5',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 97,
            probability: 0.9716,
            confidence: 0.9658,
            full: 97,
            content: 96)
      ),
      (
        'HCV-35FC86BB9E2A4A7B',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 98,
            probability: 0.9827,
            confidence: 0.949,
            full: 98,
            content: 94)
      ),
      (
        'HCV-38ABE0F66F864534',
        false,
        _ml(
            predictedClass: 'REALITY_ROOM',
            frames: 1,
            score: 1,
            probability: 0.0062,
            confidence: 0.9924,
            full: 1,
            content: 1)
      ),
      (
        'HCV-3DC36F32EAEA4979',
        false,
        _ml(
            predictedClass: 'REALITY_OUTDOOR',
            frames: 1,
            score: 5,
            probability: 0.0512,
            confidence: 0.6032,
            full: 5,
            content: 0)
      ),
      (
        'HCV-49FA17D6D28E4688',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 99,
            probability: 0.9892,
            confidence: 0.9714,
            full: 99,
            content: 99)
      ),
      (
        'HCV-4B92D5AC4CAD4C31',
        false,
        _ml(
            predictedClass: 'REALITY_ROOM',
            frames: 1,
            score: 1,
            probability: 0.0102,
            confidence: 0.9643,
            full: 1,
            content: 0)
      ),
      (
        'HCV-66B58B42B999416A',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 100,
            probability: 0.9993,
            confidence: 0.9992,
            full: 100,
            content: 99)
      ),
      (
        'HCV-6A5B55785D2C4D9E',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 96,
            probability: 0.9633,
            confidence: 0.9548,
            full: 96,
            content: 91)
      ),
      (
        'HCV-6CB3077233A04206',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 99,
            probability: 0.9892,
            confidence: 0.972,
            full: 99,
            content: 99)
      ),
      (
        'HCV-70694B65313F4B5D',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 99,
            probability: 0.9945,
            confidence: 0.9922,
            full: 99,
            content: 99)
      ),
      (
        'HCV-7BF4AD2ABD13476C',
        false,
        _ml(
            predictedClass: 'REALITY_OUTDOOR',
            frames: 1,
            score: 0,
            probability: 0.0011,
            confidence: 0.8314,
            full: 0,
            content: 0)
      ),
      (
        'HCV-88CC6F97F38A4D65',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 99,
            probability: 0.992,
            confidence: 0.9821,
            full: 99,
            content: 99)
      ),
      (
        'HCV-9305ECEF2E0943D6',
        false,
        _ml(
            predictedClass: 'NOT_ANALYZED',
            frames: 1,
            score: 0,
            probability: 0.0,
            confidence: 0.0,
            full: 0,
            content: 0)
      ),
      (
        'HCV-93FC9CC6AE7B4A1E',
        false,
        _ml(
            predictedClass: 'REALITY_OUTDOOR',
            frames: 1,
            score: 13,
            probability: 0.1286,
            confidence: 0.7202,
            full: 13,
            content: 5)
      ),
      (
        'HCV-96EFA199423A48FB',
        false,
        _ml(
            predictedClass: 'REALITY_ROOM',
            frames: 1,
            score: 1,
            probability: 0.0086,
            confidence: 0.4821,
            full: 1,
            content: 7)
      ),
      (
        'HCV-AE0F458640004FE7',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 100,
            probability: 0.9972,
            confidence: 0.9764,
            full: 100,
            content: 100)
      ),
      (
        'HCV-BC4C8B0359E7422F',
        false,
        _ml(
            predictedClass: 'REALITY_ROOM',
            frames: 1,
            score: 45,
            probability: 0.4458,
            confidence: 0.4621,
            full: 45,
            content: 8)
      ),
      (
        'HCV-C055D9B1FF2049D9',
        false,
        _ml(
            predictedClass: 'REALITY_OBJECT',
            frames: 1,
            score: 18,
            probability: 0.183,
            confidence: 0.511,
            full: 18,
            content: 2)
      ),
      (
        'HCV-C2ACF74657CD43F1',
        false,
        _ml(
            predictedClass: 'REALITY_OUTDOOR',
            frames: 1,
            score: 15,
            probability: 0.1475,
            confidence: 0.8025,
            full: 15,
            content: 40)
      ),
      (
        'HCV-C65137D329B54D7F',
        false,
        _ml(
            predictedClass: 'REALITY_OUTDOOR',
            frames: 1,
            score: 0,
            probability: 0.001,
            confidence: 0.7472,
            full: 0,
            content: 0)
      ),
      (
        'HCV-C9F892D8D1FC4D2C',
        false,
        _ml(
            predictedClass: 'REALITY_ROOM',
            frames: 1,
            score: 0,
            probability: 0.0033,
            confidence: 0.9963,
            full: 0,
            content: 2)
      ),
      (
        'HCV-D0DFF784C2D446DF',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 94,
            probability: 0.9377,
            confidence: 0.895,
            full: 94,
            content: 89)
      ),
      (
        'HCV-D2BEECE9BB114783',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 99,
            probability: 0.993,
            confidence: 0.99,
            full: 99,
            content: 99)
      ),
      (
        'HCV-DBDEC4C79CD146DC',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 1,
            score: 100,
            probability: 0.999,
            confidence: 0.9977,
            full: 100,
            content: 100)
      ),
      (
        'HCV-F82074D886C64768',
        false,
        _ml(
            predictedClass: 'REALITY_PAPER',
            frames: 1,
            score: 4,
            probability: 0.0354,
            confidence: 0.9381,
            full: 4,
            content: 2)
      ),
    ];
    var displayHits = 0;
    var realityPromotions = 0;
    for (final item in cases) {
      final matched =
          HCVDisplayRiskFusion.hasSpatialScreenCorroboration(item.$3);
      if (item.$2 && matched) displayHits++;
      if (!item.$2 && matched) realityPromotions++;
    }
    expect(displayHits, 13);
    expect(realityPromotions, 0);
  });

  test(
      '48-case corpus: VIDEO consistency gate adds 7 safe recalls and 0/12 reality promotions',
      () {
    final cases = <(String, bool, Map<String, dynamic>)>[
      (
        'HCV-0012A8DA05744F71',
        false,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 5,
            score: 49,
            probability: 0.4934,
            confidence: 0.3909,
            full: 49,
            content: 10,
            strong: 0,
            medium: 0,
            average: 14.4,
            maxFrame: 49)
      ),
      (
        'HCV-06C8D611B6CF46A6',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 2,
            score: 99,
            probability: 0.9902,
            confidence: 0.9333,
            full: 99,
            content: 93,
            strong: 2,
            medium: 2,
            average: 98.0,
            maxFrame: 99)
      ),
      (
        'HCV-10488B39ACFA4DF3',
        false,
        _ml(
            predictedClass: 'REALITY_OUTDOOR',
            frames: 5,
            score: 1,
            probability: 0.0061,
            confidence: 0.6482,
            full: 1,
            content: 22,
            strong: 0,
            medium: 0,
            average: 0.2,
            maxFrame: 1)
      ),
      (
        'HCV-1EC18BC9FF984C66',
        false,
        _ml(
            predictedClass: 'REALITY_ROOM',
            frames: 2,
            score: 3,
            probability: 0.0264,
            confidence: 0.8949,
            full: 3,
            content: 14,
            strong: 0,
            medium: 0,
            average: 1.5,
            maxFrame: 3)
      ),
      (
        'HCV-2FC1C715911542BC',
        false,
        _ml(
            predictedClass: 'NOT_ANALYZED',
            frames: 5,
            score: 0,
            probability: 0.0,
            confidence: 0.0,
            full: 0,
            content: 0,
            strong: 0,
            medium: 0,
            average: 0.0,
            maxFrame: 0)
      ),
      (
        'HCV-3F31A5EA164F4AE7',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 2,
            score: 76,
            probability: 0.7593,
            confidence: 0.7445,
            full: 76,
            content: 59,
            strong: 0,
            medium: 0,
            average: 64.5,
            maxFrame: 76)
      ),
      (
        'HCV-46A91EF372E44F3B',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 3,
            score: 100,
            probability: 0.9983,
            confidence: 0.9981,
            full: 100,
            content: 99,
            strong: 3,
            medium: 3,
            average: 100.0,
            maxFrame: 100)
      ),
      (
        'HCV-5EA3CC20287A44C1',
        false,
        _ml(
            predictedClass: 'REALITY_OUTDOOR',
            frames: 5,
            score: 0,
            probability: 0.0025,
            confidence: 0.7503,
            full: 0,
            content: 2,
            strong: 0,
            medium: 0,
            average: 0.0,
            maxFrame: 0)
      ),
      (
        'HCV-6052EF81478945A4',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 3,
            score: 100,
            probability: 0.998,
            confidence: 0.9973,
            full: 100,
            content: 99,
            strong: 3,
            medium: 3,
            average: 100.0,
            maxFrame: 100)
      ),
      (
        'HCV-6128F250D19149E2',
        false,
        _ml(
            predictedClass: 'REALITY_ROOM',
            frames: 2,
            score: 7,
            probability: 0.0665,
            confidence: 0.871,
            full: 7,
            content: 44,
            strong: 0,
            medium: 0,
            average: 4.0,
            maxFrame: 7)
      ),
      (
        'HCV-6790D75E285B40B9',
        false,
        _ml(
            predictedClass: 'NOT_ANALYZED',
            frames: 8,
            score: 0,
            probability: 0.0,
            confidence: 0.0,
            full: 0,
            content: 0,
            strong: 0,
            medium: 0,
            average: 0.0,
            maxFrame: 0)
      ),
      (
        'HCV-6EF1EE9912DF4FAA',
        false,
        _ml(
            predictedClass: 'REALITY_ROOM',
            frames: 2,
            score: 0,
            probability: 0.0008,
            confidence: 0.7822,
            full: 0,
            content: 2,
            strong: 0,
            medium: 0,
            average: 0.0,
            maxFrame: 0)
      ),
      (
        'HCV-7BDBF43A60304115',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 4,
            score: 97,
            probability: 0.9746,
            confidence: 0.9064,
            full: 97,
            content: 99,
            strong: 4,
            medium: 4,
            average: 94.0,
            maxFrame: 97)
      ),
      (
        'HCV-82A1F84E5FF14140',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 2,
            score: 99,
            probability: 0.9913,
            confidence: 0.9894,
            full: 99,
            content: 96,
            strong: 2,
            medium: 2,
            average: 96.5,
            maxFrame: 99)
      ),
      (
        'HCV-C1214B3C319247D8',
        false,
        _ml(
            predictedClass: 'NOT_ANALYZED',
            frames: 4,
            score: 0,
            probability: 0.0,
            confidence: 0.0,
            full: 0,
            content: 0,
            strong: 0,
            medium: 0,
            average: 0.0,
            maxFrame: 0)
      ),
      (
        'HCV-CB12CF907302451D',
        false,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 3,
            score: 38,
            probability: 0.3792,
            confidence: 0.3749,
            full: 38,
            content: 62,
            strong: 0,
            medium: 0,
            average: 21.6667,
            maxFrame: 38)
      ),
      (
        'HCV-CBAAC08557EE4F90',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 2,
            score: 99,
            probability: 0.9895,
            confidence: 0.9851,
            full: 99,
            content: 98,
            strong: 2,
            medium: 2,
            average: 98.0,
            maxFrame: 99)
      ),
      (
        'HCV-D2962901988A4ED9',
        false,
        _ml(
            predictedClass: 'REALITY_OUTDOOR',
            frames: 2,
            score: 0,
            probability: 0.0045,
            confidence: 0.9584,
            full: 0,
            content: 2,
            strong: 0,
            medium: 0,
            average: 0.0,
            maxFrame: 0)
      ),
      (
        'HCV-E5BF4693387F452A',
        true,
        _ml(
            predictedClass: 'SCREEN_PHONE',
            frames: 4,
            score: 91,
            probability: 0.9843,
            confidence: 0.8432,
            full: 98,
            content: 96,
            strong: 1,
            medium: 4,
            average: 91.25,
            maxFrame: 98)
      ),
      (
        'HCV-F50A8EFBDB1041AC',
        false,
        _ml(
            predictedClass: 'NOT_ANALYZED',
            frames: 5,
            score: 0,
            probability: 0.0,
            confidence: 0.0,
            full: 0,
            content: 0,
            strong: 0,
            medium: 0,
            average: 0.0,
            maxFrame: 0)
      ),
      (
        'HCV-F6CA0E9A1C7B4F56',
        true,
        _ml(
            predictedClass: 'SCREEN_MONITOR',
            frames: 3,
            score: 100,
            probability: 0.9962,
            confidence: 0.9953,
            full: 100,
            content: 100,
            strong: 2,
            medium: 2,
            average: 68.0,
            maxFrame: 100)
      ),
    ];
    var displayHits = 0;
    var realityPromotions = 0;
    final missedDisplays = <String>[];
    for (final item in cases) {
      final matched =
          HCVDisplayRiskFusion.hasMultiFrameScreenConsistency(item.$3);
      if (item.$2 && matched) displayHits++;
      if (item.$2 && !matched) missedDisplays.add(item.$1);
      if (!item.$2 && matched) realityPromotions++;
    }
    expect(displayHits, 7);
    expect(realityPromotions, 0);
    expect(missedDisplays.toSet(),
        {'HCV-3F31A5EA164F4AE7', 'HCV-F6CA0E9A1C7B4F56'});
  });
}
