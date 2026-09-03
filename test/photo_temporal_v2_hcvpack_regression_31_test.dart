import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_photo_temporal_v2_policy.dart';

class _Case {
  const _Case({
    required this.id,
    required this.mediaType,
    required this.expectedSemantic,
    required this.signedDecision,
    this.build = '',
    this.method,
    this.stillClass,
    this.stillP,
    this.stillFull,
    this.temporalFrames,
    this.temporalClass,
    this.temporalP,
    this.temporalScreenFrames = 0,
    this.temporalMaxScreenP,
    this.historicalKnownFalseNegative = false,
  });

  final String id;
  final String mediaType;
  final String expectedSemantic;
  final String signedDecision;
  final String build;
  final String? method;
  final String? stillClass;
  final double? stillP;
  final int? stillFull;
  final int? temporalFrames;
  final String? temporalClass;
  final double? temporalP;
  final int temporalScreenFrames;
  final double? temporalMaxScreenP;
  final bool historicalKnownFalseNegative;

  Map<String, dynamic>? get stillMl {
    if (mediaType != 'PHOTO') return null;
    return <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': stillClass,
      'screenProbability': stillP,
      'signals': <String, dynamic>{
        'fullFrameRiskScore': stillFull,
      },
    };
  }

  Map<String, dynamic>? get liveProbe {
    if (mediaType != 'PHOTO') return null;
    final frameCount = temporalFrames ?? 0;
    final screenCount = temporalScreenFrames.clamp(0, frameCount);
    final frames = <Map<String, dynamic>>[];
    for (var i = 0; i < frameCount; i++) {
      final screen = i < screenCount;
      frames.add(<String, dynamic>{
        'predictedClass': screen ? 'SCREEN_MONITOR' : 'REALITY_OBJECT',
        'screenProbability': screen
            ? (temporalMaxScreenP ?? temporalP ?? 0.0)
            : 0.01,
      });
    }
    return <String, dynamic>{
      'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
      'analysisStatus': 'ANALYZED',
      'photoDecisionMethod': method,
      'photoTemporalVideoProbe': <String, dynamic>{
        'mlScreenReplayAnalysis': <String, dynamic>{
          'analysisStatus': 'ANALYZED',
          'predictedClass': temporalClass,
          'screenProbability': temporalP,
          'framesAnalyzed': frameCount,
          'videoFrameAnalyses': frames,
        },
      },
    };
  }
}

const _cases = <_Case>[
  _Case(id: '27FCD7449BD840D7', mediaType: 'PHOTO', build: '80', expectedSemantic: 'DISPLAY', signedDecision: 'NO_DISPLAY_EVIDENCE', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'SCREEN_MONITOR', stillP: 0.4534, stillFull: 45, temporalFrames: 4, temporalClass: 'SCREEN_MONITOR', temporalP: 0.4184, temporalScreenFrames: 1, temporalMaxScreenP: 0.4184),
  _Case(id: '2842C59A816240F4', mediaType: 'PHOTO', build: '80', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'REALITY_OUTDOOR', stillP: 0.0010, stillFull: 0, temporalFrames: 4, temporalClass: 'REALITY_OUTDOOR', temporalP: 0.0009),
  _Case(id: '3F78EC8709D84DA1', mediaType: 'PHOTO', build: '79', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'REALITY_OUTDOOR', stillP: 0.0051, stillFull: 1, temporalFrames: 2, temporalClass: 'REALITY_OUTDOOR', temporalP: 0.0086),
  _Case(id: '4288D501B7394D79', mediaType: 'PHOTO', build: '79', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'SCREEN_TABLET', stillP: 0.9915, stillFull: 99, temporalFrames: 2, temporalClass: 'SCREEN_MONITOR', temporalP: 0.9897, temporalScreenFrames: 2, temporalMaxScreenP: 0.9897),
  _Case(id: '434A480BFF9A4D5B', mediaType: 'PHOTO', build: '79', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'SCREEN_PHONE', stillP: 0.9167, stillFull: 92, temporalFrames: 2, temporalClass: 'SCREEN_MONITOR', temporalP: 0.9789, temporalScreenFrames: 2, temporalMaxScreenP: 0.9789),
  _Case(id: '448810590EAD4311', mediaType: 'PHOTO', build: '79', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'REALITY_OUTDOOR', stillP: 0.3161, stillFull: 32, temporalFrames: 2, temporalClass: 'REALITY_ROOM', temporalP: 0.2258),
  _Case(id: '4665FA9FB25244E7', mediaType: 'PHOTO', build: '79', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'REALITY_ROOM', stillP: 0.0007, stillFull: 0, temporalFrames: 2, temporalClass: 'REALITY_ROOM', temporalP: 0.0033),
  _Case(id: '5DB33623FED24055', mediaType: 'PHOTO', build: '80', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'SCREEN_MONITOR', stillP: 0.9956, stillFull: 100, temporalFrames: 4, temporalClass: 'SCREEN_MONITOR', temporalP: 0.9960, temporalScreenFrames: 4, temporalMaxScreenP: 0.9960),
  _Case(id: '6E04193B772F404F', mediaType: 'PHOTO', build: '79', expectedSemantic: 'DISPLAY', signedDecision: 'NON_CONCLUSIVE', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'SCREEN_MONITOR', stillP: 0.5997, stillFull: 60, temporalFrames: 2, temporalClass: 'SCREEN_MONITOR', temporalP: 0.4660, temporalScreenFrames: 2, temporalMaxScreenP: 0.4660),
  _Case(id: '97F4B8A8B9164E14', mediaType: 'PHOTO', build: '79', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'SCREEN_MONITOR', stillP: 0.9881, stillFull: 99, temporalFrames: 2, temporalClass: 'SCREEN_MONITOR', temporalP: 0.9913, temporalScreenFrames: 2, temporalMaxScreenP: 0.9913),
  _Case(id: 'C8FFE4345CB14E5D', mediaType: 'PHOTO', build: '77', expectedSemantic: 'DISPLAY', signedDecision: 'NO_DISPLAY_EVIDENCE', method: 'VIDEO_EQUIVALENT_PRE_CAPTURE_TEMPORAL_ANALYSIS', stillClass: 'REALITY_OUTDOOR', stillP: 0.0747, stillFull: 7, temporalFrames: 2, temporalClass: 'REALITY_OUTDOOR', temporalP: 0.0642, historicalKnownFalseNegative: true),
  _Case(id: 'DCA14C8ADF644BF6', mediaType: 'PHOTO', build: '79', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'REALITY_ROOM', stillP: 0.0010, stillFull: 0, temporalFrames: 2, temporalClass: 'REALITY_ROOM', temporalP: 0.0010),
  _Case(id: 'E1FC5218B9B94E28', mediaType: 'PHOTO', build: '80', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'SCREEN_MONITOR', stillP: 0.9945, stillFull: 99, temporalFrames: 4, temporalClass: 'SCREEN_MONITOR', temporalP: 0.9871, temporalScreenFrames: 4, temporalMaxScreenP: 0.9883),
  _Case(id: 'E2F3DDC0B7D94647', mediaType: 'PHOTO', build: '80', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'SCREEN_MONITOR', stillP: 0.9941, stillFull: 99, temporalFrames: 4, temporalClass: 'SCREEN_MONITOR', temporalP: 0.9919, temporalScreenFrames: 4, temporalMaxScreenP: 0.9919),
  _Case(id: 'ED3F1D86B2024793', mediaType: 'PHOTO', build: '80', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'SCREEN_MONITOR', stillP: 0.9694, stillFull: 97, temporalFrames: 4, temporalClass: 'SCREEN_MONITOR', temporalP: 0.9959, temporalScreenFrames: 4, temporalMaxScreenP: 0.9959),
  _Case(id: 'F2A8DD8469B24E0B', mediaType: 'PHOTO', build: '80', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE', method: 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT', stillClass: 'REALITY_ROOM', stillP: 0.0096, stillFull: 1, temporalFrames: 4, temporalClass: 'REALITY_ROOM', temporalP: 0.0102),
  _Case(id: '0D2055159A694445', mediaType: 'VIDEO', build: '80', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK'),
  _Case(id: '1924254D8C6C4255', mediaType: 'VIDEO', build: '79', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE'),
  _Case(id: '226345025C444F00', mediaType: 'VIDEO', build: '79', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE'),
  _Case(id: '26D1506CA0C24992', mediaType: 'VIDEO', build: '79', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK'),
  _Case(id: '6AA2BFA25F2D4C11', mediaType: 'VIDEO', build: '79', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK'),
  _Case(id: '6E027CF857DB415E', mediaType: 'VIDEO', build: '80', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE'),
  _Case(id: '7A20B4B4DC3F44F0', mediaType: 'VIDEO', build: '80', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK'),
  _Case(id: '81523EE5E64F480E', mediaType: 'VIDEO', build: '79', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE'),
  _Case(id: '8341EFC5B4714B58', mediaType: 'VIDEO', build: '80', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK'),
  _Case(id: '990A8EE8708242A8', mediaType: 'VIDEO', build: '80', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK'),
  _Case(id: 'A5DF4EFBCF5B4993', mediaType: 'VIDEO', build: '80', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE'),
  _Case(id: 'BF2B9D5377464291', mediaType: 'VIDEO', build: '79', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK'),
  _Case(id: 'CBC7F856136347AE', mediaType: 'VIDEO', build: '79', expectedSemantic: 'REALITY', signedDecision: 'NO_DISPLAY_EVIDENCE'),
  _Case(id: 'E515C2D882B044E5', mediaType: 'VIDEO', build: '80', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK'),
  _Case(id: 'FD593107CB764856', mediaType: 'VIDEO', build: '79', expectedSemantic: 'DISPLAY', signedDecision: 'STRONG_DISPLAY_RISK'),
];

void main() {
  test('31-HCVPACK corpus: moderate PHOTO gate changes only 27FCD', () {
    expect(_cases.length, 31);
    final promoted = <String>[];

    for (final item in _cases) {
      final gate = HCVPhotoTemporalV2Policy.hasModerateCrossCaptureScreenAgreement(
        stillMl: item.stillMl,
        liveProbe: item.liveProbe,
      );
      final wouldPromote = item.mediaType == 'PHOTO' &&
          item.signedDecision == 'NO_DISPLAY_EVIDENCE' &&
          gate;
      if (wouldPromote) promoted.add(item.id);

      if (item.expectedSemantic == 'REALITY') {
        expect(wouldPromote, isFalse, reason: 'Reality regression ${item.id}');
      }
      if (item.mediaType == 'VIDEO') {
        expect(gate, isFalse, reason: 'Video must be outside PHOTO policy ${item.id}');
      }
    }

    expect(promoted, <String>['27FCD7449BD840D7']);
  });

  test('existing accepted decisions remain outside the promotion path', () {
    for (final item in _cases.where(
      (item) => item.signedDecision != 'NO_DISPLAY_EVIDENCE',
    )) {
      final gate = HCVPhotoTemporalV2Policy.hasModerateCrossCaptureScreenAgreement(
        stillMl: item.stillMl,
        liveProbe: item.liveProbe,
      );
      final wouldPromote = item.mediaType == 'PHOTO' &&
          item.signedDecision == 'NO_DISPLAY_EVIDENCE' &&
          gate;
      expect(wouldPromote, isFalse, reason: 'Must preserve ${item.id}');
    }
  });

  test('historical C8FF remains explicitly outside Temporal V2 recovery gate', () {
    final c8ff = _cases.singleWhere((item) => item.historicalKnownFalseNegative);
    expect(c8ff.id, 'C8FFE4345CB14E5D');
    expect(
      HCVPhotoTemporalV2Policy.hasModerateCrossCaptureScreenAgreement(
        stillMl: c8ff.stillMl,
        liveProbe: c8ff.liveProbe,
      ),
      isFalse,
    );
  });

  test('gate requires four-frame V2 plus independent still/temporal SCREEN', () {
    final target = _cases.singleWhere((item) => item.id == '27FCD7449BD840D7');
    expect(
      HCVPhotoTemporalV2Policy.hasModerateCrossCaptureScreenAgreement(
        stillMl: target.stillMl,
        liveProbe: target.liveProbe,
      ),
      isTrue,
    );

    final weakStill = Map<String, dynamic>.from(target.stillMl!)
      ..['screenProbability'] = 0.3999;
    expect(
      HCVPhotoTemporalV2Policy.hasModerateCrossCaptureScreenAgreement(
        stillMl: weakStill,
        liveProbe: target.liveProbe,
      ),
      isFalse,
    );
  });
}
