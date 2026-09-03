import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_display_risk_fusion.dart';

class _Case {
  const _Case(
    this.id,
    this.kind,
    this.groundTruth,
    this.mlClass,
    this.screenProbability,
    this.score,
    this.frames,
    this.screenFrames,
  );

  final String id;
  final String kind;
  final String groundTruth;
  final String mlClass;
  final double screenProbability;
  final int score;
  final int frames;
  final int screenFrames;

  Map<String, dynamic> get ml {
    final frameAnalyses = <Map<String, dynamic>>[];
    if (kind == 'VIDEO') {
      for (var i = 0; i < frames; i++) {
        frameAnalyses.add({
          'predictedClass':
              i < screenFrames ? 'SCREEN_MONITOR' : 'REALITY_ROOM',
        });
      }
    }
    return {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'predictedClass': mlClass,
      'screenProbability': screenProbability,
      'screenReplayRiskScore': score,
      'framesAnalyzed': frames,
      if (kind == 'VIDEO') 'videoFrameAnalyses': frameAnalyses,
    };
  }
}

const _calibrationCorpusV1 = <_Case>[
    _Case('22ADB79B73BD4FBB', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9929, 99, 1, 0),
    _Case('27463957577E4ED5', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9716, 97, 1, 0),
    _Case('3C474C416BF04EB4', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9747, 97, 1, 0),
    _Case('3DC36F32EAEA4979', 'PHOTO', 'REALITY', 'REALITY_OUTDOOR', 0.0512, 5, 1, 0),
    _Case('413BB913231F4CFF', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9978, 100, 1, 0),
    _Case('44600755CCC44B82', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9900, 99, 1, 0),
    _Case('49FA17D6D28E4688', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9892, 99, 1, 0),
    _Case('4B92D5AC4CAD4C31', 'PHOTO', 'REALITY', 'REALITY_ROOM', 0.0102, 1, 1, 0),
    _Case('4ED7CFABC97A45CB', 'PHOTO', 'REALITY', 'REALITY_ROOM', 0.0045, 0, 1, 0),
    _Case('4FDF7EF227AE416E', 'PHOTO', 'REALITY', 'REALITY_PAPER', 0.0648, 6, 1, 0),
    _Case('573AE60246D649B3', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9577, 96, 1, 0),
    _Case('66B58B42B999416A', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9993, 100, 1, 0),
    _Case('6A5B55785D2C4D9E', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9633, 96, 1, 0),
    _Case('729930E97F7B41BC', 'PHOTO', 'REALITY', 'REALITY_ROOM', 0.0028, 0, 1, 0),
    _Case('7BF4AD2ABD13476C', 'PHOTO', 'REALITY', 'REALITY_OUTDOOR', 0.0011, 0, 1, 0),
    _Case('83B118A622F34B40', 'PHOTO', 'REALITY', 'REALITY_OUTDOOR', 0.0307, 3, 1, 0),
    _Case('88CC6F97F38A4D65', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9920, 99, 1, 0),
    _Case('8EE0354E1D4D4576', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9897, 99, 1, 0),
    _Case('93DB7F6428514700', 'PHOTO', 'REALITY', 'REALITY_ROOM', 0.0130, 1, 1, 0),
    _Case('93FC9CC6AE7B4A1E', 'PHOTO', 'REALITY', 'REALITY_OUTDOOR', 0.1286, 13, 1, 0),
    _Case('96EFA199423A48FB', 'PHOTO', 'REALITY', 'REALITY_ROOM', 0.0086, 1, 1, 0),
    _Case('9C3A746DB0754A8F', 'PHOTO', 'SCREEN', 'SCREEN_TABLET', 0.9790, 98, 1, 0),
    _Case('AE0F458640004FE7', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9972, 100, 1, 0),
    _Case('AFE15BE3C9AC4902', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9812, 98, 1, 0),
    _Case('C2ACF74657CD43F1', 'PHOTO', 'REALITY', 'REALITY_OUTDOOR', 0.1475, 15, 1, 0),
    _Case('C65137D329B54D7F', 'PHOTO', 'REALITY', 'REALITY_OUTDOOR', 0.0010, 0, 1, 0),
    _Case('CD36AD6BC6DE4771', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9949, 99, 1, 0),
    _Case('D0DFF784C2D446DF', 'PHOTO', 'SCREEN', 'SCREEN_MONITOR', 0.9377, 94, 1, 0),
    _Case('F1D8EB5B623A486D', 'PHOTO', 'REALITY', 'REALITY_ROOM', 0.0078, 1, 1, 0),
    _Case('F3B5EB05CB944C3A', 'PHOTO', 'REALITY', 'REALITY_ROOM', 0.0020, 0, 1, 0),
    _Case('F73ED4196B17443D', 'PHOTO', 'REALITY', 'REALITY_OUTDOOR', 0.0022, 0, 1, 0),
    _Case('FBBA3DA68D4A4A35', 'PHOTO', 'REALITY', 'REALITY_OUTDOOR', 0.0008, 0, 1, 0),
    _Case('06C8D611B6CF46A6', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9902, 99, 2, 2),
    _Case('19C1C3146080470F', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9924, 99, 8, 8),
    _Case('1EC18BC9FF984C66', 'VIDEO', 'REALITY', 'REALITY_ROOM', 0.0264, 3, 2, 0),
    _Case('1EF8C2C224FF45F0', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9928, 99, 5, 5),
    _Case('36F2D23DAE6C4475', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9801, 98, 6, 5),
    _Case('3E694CD106314E67', 'VIDEO', 'REALITY', 'REALITY_OUTDOOR', 0.0986, 10, 6, 0),
    _Case('3F31A5EA164F4AE7', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.7593, 76, 2, 2),
    _Case('43E117D98CF74627', 'VIDEO', 'REALITY', 'REALITY_ROOM', 0.2889, 29, 4, 0),
    _Case('4C1DFC2A05CE4537', 'VIDEO', 'REALITY', 'SCREEN_MONITOR', 0.7059, 71, 4, 2),
    _Case('5EA3CC20287A44C1', 'VIDEO', 'REALITY', 'REALITY_OUTDOOR', 0.0025, 0, 5, 0),
    _Case('6052EF81478945A4', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9980, 100, 3, 3),
    _Case('6128F250D19149E2', 'VIDEO', 'REALITY', 'REALITY_ROOM', 0.0665, 7, 2, 0),
    _Case('63C7419C42F44C6D', 'VIDEO', 'REALITY', 'REALITY_OUTDOOR', 0.0405, 4, 4, 0),
    _Case('69D28D56A4D74FF7', 'VIDEO', 'REALITY', 'SCREEN_MONITOR', 0.6701, 67, 4, 2),
    _Case('764755A5002C4BE2', 'VIDEO', 'REALITY', 'REALITY_ROOM', 0.0180, 2, 5, 0),
    _Case('82A1F84E5FF14140', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9913, 99, 2, 2),
    _Case('8AF51D104A344D11', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9889, 99, 5, 5),
    _Case('90C4DF18990F4A12', 'VIDEO', 'REALITY', 'SCREEN_MONITOR', 0.4504, 45, 4, 1),
    _Case('9497C066EF314B21', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9882, 99, 4, 4),
    _Case('9EA7757CBC104AFA', 'VIDEO', 'REALITY', 'REALITY_OUTDOOR', 0.0963, 10, 4, 0),
    _Case('A192D34C3FD94301', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9969, 100, 3, 3),
    _Case('ACF72FC8E1CD4389', 'VIDEO', 'REALITY', 'REALITY_OUTDOOR', 0.0973, 10, 4, 0),
    _Case('AF671040A8BF4B1F', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9941, 99, 5, 5),
    _Case('C2C05C9075684131', 'VIDEO', 'REALITY', 'SCREEN_MONITOR', 0.5839, 58, 5, 1),
    _Case('C39CF29B96AA4729', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9424, 94, 6, 6),
    _Case('CBAAC08557EE4F90', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9895, 99, 2, 2),
    _Case('D2962901988A4ED9', 'VIDEO', 'REALITY', 'REALITY_OUTDOOR', 0.0045, 0, 2, 0),
    _Case('D3C7A5C7D25D4734', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9688, 97, 5, 5),
    _Case('D68094E39B07404D', 'VIDEO', 'REALITY', 'REALITY_ROOM', 0.0681, 7, 3, 0),
    _Case('DDF720714EE64A92', 'VIDEO', 'REALITY', 'REALITY_OUTDOOR', 0.0158, 2, 4, 0),
    _Case('E63D1C1AD3DC4AF6', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9774, 98, 3, 3),
    _Case('E86E25DB25444946', 'VIDEO', 'REALITY', 'REALITY_PAPER', 0.2218, 22, 2, 0),
    _Case('E9A6DBE1DC9F4D5C', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9830, 98, 5, 5),
    _Case('ECDF5D74505F4AC3', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9739, 97, 4, 3),
    _Case('F6A769EE24A449DC', 'VIDEO', 'REALITY', 'SCREEN_MONITOR', 0.5171, 52, 6, 1),
    _Case('F6CA0E9A1C7B4F56', 'VIDEO', 'SCREEN', 'SCREEN_MONITOR', 0.9962, 100, 3, 2),
];

void main() {
  test('calibration corpus v1 is frozen at 68 ML-complete HCVPACKs', () {
    expect(_calibrationCorpusV1, hasLength(68));
    expect(
      _calibrationCorpusV1.where((c) => c.kind == 'PHOTO'),
      hasLength(32),
    );
    expect(
      _calibrationCorpusV1.where((c) => c.kind == 'VIDEO'),
      hasLength(36),
    );
    expect(
      _calibrationCorpusV1.where((c) => c.groundTruth == 'SCREEN'),
      hasLength(34),
    );
    expect(
      _calibrationCorpusV1.where((c) => c.groundTruth == 'REALITY'),
      hasLength(34),
    );
  });

  test('conservative ML-first rule resolves 67/68 with zero errors', () {
    var resolved = 0;
    var correct = 0;
    final gray = <String>[];

    for (final c in _calibrationCorpusV1) {
      final result = c.kind == 'PHOTO'
          ? HCVDisplayRiskFusion.mlFirstPhotoDecision(c.ml)
          : HCVDisplayRiskFusion.mlFirstVideoDecision(c.ml);
      if (result == null) {
        gray.add(c.id);
        continue;
      }
      resolved++;
      final predicted = result.decision == 'STRONG_DISPLAY_RISK'
          ? 'SCREEN'
          : result.decision == 'NO_DISPLAY_EVIDENCE'
              ? 'REALITY'
              : 'GRAY';
      if (predicted == c.groundTruth) correct++;
    }

    expect(resolved, 67);
    expect(correct, 67);
    expect(gray, ['4C1DFC2A05CE4537']);
  });

  test('photo thresholds preserve the 0.80/0.20 gray zone', () {
    final almostScreen = {
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': 0.799,
      'screenReplayRiskScore': 79,
      'framesAnalyzed': 1,
    };
    final almostReality = {
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'REALITY_ROOM',
      'screenProbability': 0.201,
      'screenReplayRiskScore': 20,
      'framesAnalyzed': 1,
    };
    expect(HCVDisplayRiskFusion.mlFirstPhotoDecision(almostScreen), isNull);
    expect(HCVDisplayRiskFusion.mlFirstPhotoDecision(almostReality), isNull);
  });

  test('video requires probability and semantic majority together', () {
    Map<String, dynamic> videoMl(double p, List<String> classes) => {
          'analysisStatus': 'ANALYZED',
          'predictedClass': 'SCREEN_MONITOR',
          'screenProbability': p,
          'screenReplayRiskScore': (p * 100).round(),
          'framesAnalyzed': classes.length,
          'videoFrameAnalyses': [
            for (final c in classes) {'predictedClass': c},
          ],
        };

    expect(
      HCVDisplayRiskFusion.mlFirstVideoDecision(
        videoMl(0.90, const [
          'SCREEN_MONITOR',
          'REALITY_ROOM',
          'REALITY_PAPER',
          'SCREEN_MONITOR',
        ]),
      ),
      isNull,
    );
    expect(
      HCVDisplayRiskFusion.mlFirstVideoDecision(
        videoMl(0.76, const [
          'SCREEN_MONITOR',
          'SCREEN_TABLET',
          'REALITY_ROOM',
        ]),
      )?.decision,
      'STRONG_DISPLAY_RISK',
    );
    expect(
      HCVDisplayRiskFusion.mlFirstVideoDecision(
        videoMl(0.69, const [
          'SCREEN_MONITOR',
          'REALITY_ROOM',
          'REALITY_PAPER',
          'SCREEN_MONITOR',
        ]),
      )?.decision,
      'NO_DISPLAY_EVIDENCE',
    );
  });
}
