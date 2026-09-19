import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_context_free_display_policy.dart';

void main() {
  group('BUILD123: 62 real physical capture evidence vectors', () {
    test('all 62 compatible HCVs are classified without Scene Context', () {
      final lines = File('test/fixtures/build123_archive70_71_72_corpus.psv')
          .readAsLinesSync()
          .skip(1)
          .where((line) => line.trim().isNotEmpty)
          .toList();
      expect(lines.length, 62);

      final counts = <String, int>{};
      final correct = <String, int>{};
      var trueDisplays = 0;
      var trueReality = 0;
      var photoCount = 0;
      var videoCount = 0;

      for (final line in lines) {
        final row = line.split('|');
        expect(row.length, 16, reason: line);
        final archive = row[0];
        final id = row[1];
        final isPhoto = row[2] == 'P';
        final isDisplay = row[3] == 'D';
        final frontCamera = const <String>{
          '9C9D2C89',
          '50687DF3',
          '0A4AFB99',
          '64CDE0FF',
          '2CA67E1E',
          '7970AEE9',
        }.contains(id);
        final hfrFrames = frontCamera ? 42 : 84;
        final hfrFps = frontCamera ? 120.0 : 240.0;
        final videoScores = row[15].isEmpty
            ? <int>[]
            : row[15].split(',').map(int.parse).toList();

        final hfr = <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'shortExposureVerified': true,
          'exposureLockedForEntireNativeCapture': true,
          'framesAnalyzed': hfrFrames,
          'targetFrameCount': hfrFrames,
          'configuredFrameRate': hfrFps,
          'actualFrameRateFromTimestamps': hfrFps,
          'displayRealityEvidenceV3': <String, dynamic>{
            'displayLikeCellCount': int.parse(row[4]),
            'realityLikeCellCount': int.parse(row[5]),
            'spatialFamilyCellCount': int.parse(row[8]),
            'harmonicAwareSpatialFamilyCellCount': int.parse(row[9]),
            'rowTimeFamilyCellCount': int.parse(row[10]),
          },
          'coherentDisplayPeriodicityEvidence': <String, dynamic>{
            'periodicCellCount': int.parse(row[6]),
            'stableCellCount': int.parse(row[7]),
          },
        };
        final ml = <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'predictedClass': row[11],
          'screenProbability': double.parse(row[12]),
          'framesAnalyzed': isPhoto ? 1 : videoScores.length,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': int.parse(row[13]),
            'contentAreaRiskScore': int.parse(row[14]),
          },
          if (!isPhoto)
            'videoFrameAnalyses': <Map<String, dynamic>>[
              for (final score in videoScores)
                <String, dynamic>{
                  'signals': <String, dynamic>{
                    'fullFrameRiskScore': score,
                  },
                },
            ],
        };

        final result = HCVContextFreeDisplayPolicy.resolve(
          isPhoto: isPhoto,
          temporalFrequencyProbe: hfr,
          mlScreenReplayAnalysis: ml,
        );
        counts[archive] = (counts[archive] ?? 0) + 1;
        if (isDisplay) {
          trueDisplays++;
        } else {
          trueReality++;
        }
        if (isPhoto) {
          photoCount++;
        } else {
          videoCount++;
        }
        final expected =
            isDisplay ? 'STRONG_DISPLAY_RISK' : 'NO_DISPLAY_EVIDENCE';
        expect(
          result.decision,
          expected,
          reason: 'archive $archive HCV-$id: $line',
        );
        correct[archive] = (correct[archive] ?? 0) + 1;
      }

      expect(counts, <String, int>{'70': 23, '71': 23, '72': 16});
      expect(correct, counts);
      expect(trueDisplays, 20);
      expect(trueReality, 42);
      expect(photoCount, 31);
      expect(videoCount, 31);
    });
  });

  group('BUILD123 decision safety', () {
    test('an uncorroborated one-frame VIDEO screen peak is not DISPLAY', () {
      final result = HCVContextFreeDisplayPolicy.resolve(
        isPhoto: false,
        temporalFrequencyProbe: null,
        mlScreenReplayAnalysis: <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'predictedClass': 'SCREEN_PHONE',
          'screenProbability': 0.9503,
          'framesAnalyzed': 3,
          'videoFrameAnalyses': <Map<String, dynamic>>[
            <String, dynamic>{
              'signals': <String, dynamic>{'fullFrameRiskScore': 95},
            },
            <String, dynamic>{
              'signals': <String, dynamic>{'fullFrameRiskScore': 49},
            },
            <String, dynamic>{
              'signals': <String, dynamic>{'fullFrameRiskScore': 33},
            },
          ],
        },
      );
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('reality still with strong isolated ML full-frame score is not DISPLAY',
        () {
      final result = HCVContextFreeDisplayPolicy.resolve(
        isPhoto: true,
        temporalFrequencyProbe: null,
        mlScreenReplayAnalysis: <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'predictedClass': 'REALITY_ROOM',
          'screenProbability': 0.1829,
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 94,
            'contentAreaRiskScore': 18,
          },
        },
      );
      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
    });

    test('incomplete ML is not silently mapped to REALITY', () {
      final result = HCVContextFreeDisplayPolicy.resolve(
        isPhoto: true,
        temporalFrequencyProbe: null,
        mlScreenReplayAnalysis: null,
      );
      expect(result.decision, 'NON_CONCLUSIVE');
    });

    test('both actual PHOTO and VIDEO final decisions bypass Scene Context', () {
      final source = File('lib/camera_page.dart').readAsStringSync();
      expect(
        'HCVContextFreeDisplayPolicy.resolve('.allMatches(source).length,
        2,
      );
      expect(source, isNot(contains('HCVDisplayFinalPolicy.resolve(')));
      expect(source, contains('"sceneContextEvidence": sceneContext.toJson()'));
      expect(source, contains('"passiveSceneContextProbe": sceneContextProbe'));
    });
  });
}
