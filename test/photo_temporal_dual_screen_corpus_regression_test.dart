import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/photo_temporal_screen_concordance.dart';

Map<String, dynamic> _still({
  required String predictedClass,
  required double screenProbability,
  double? confidence,
}) => <String, dynamic>{
  'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
  'analysisStatus': 'ANALYZED',
  'scanMode': 'STILL_IMAGE_ML_CLASSIFIER',
  'framesAnalyzed': 1,
  'predictedClass': predictedClass,
  'screenProbability': screenProbability,
  'predictedClassConfidence': confidence ?? screenProbability,
};

Map<String, dynamic> _live({
  required List<(String, double, double)> frames,
}) => <String, dynamic>{
  'type': 'SIGILLUM_LIVE_SCREEN_PROBE_V1',
  'photoDecisionMethod': 'PHOTO_TEMPORAL_V2_PRE_CAPTURE_AUTO_SHOT',
  'photoTemporalVideoProbe': <String, dynamic>{
    'type': 'SIGILLUM_PHOTO_TEMPORAL_VIDEO_PROBE_V2',
    'mlScreenReplayAnalysis': <String, dynamic>{
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'analysisStatus': 'ANALYZED',
      'captureSource': 'PHOTO_TECHNICAL_MINI_VIDEO_V2',
      'framesAnalyzed': frames.length,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (final frame in frames)
          <String, dynamic>{
            'predictedClass': frame.$1,
            'screenProbability': frame.$2,
            'predictedClassConfidence': frame.$3,
          },
      ],
    },
  },
};

void main() {
  test('Temporal V2 corpus: all known display recaptures pass dual-stage gate when needed', () {
    final cases = <({
      String id,
      bool display,
      String stillClass,
      double stillProbability,
      double stillConfidence,
      List<(String, double, double)> frames,
    })>[
      // Build 79 sanitized vectors.
      (id: '4288', display: true, stillClass: 'SCREEN_TABLET', stillProbability: .9915, stillConfidence: .98, frames: [('SCREEN_MONITOR', .9897, .98), ('SCREEN_MONITOR', .9877, .98)]),
      (id: '434A', display: true, stillClass: 'SCREEN_PHONE', stillProbability: .9167, stillConfidence: .90, frames: [('SCREEN_MONITOR', .9789, .95), ('SCREEN_PHONE', .8707, .85)]),
      (id: '6E041', display: true, stillClass: 'SCREEN_MONITOR', stillProbability: .5997, stillConfidence: .58, frames: [('SCREEN_MONITOR', .4660, .45), ('SCREEN_MONITOR', .4628, .44)]),
      (id: '97F4', display: true, stillClass: 'SCREEN_MONITOR', stillProbability: .9881, stillConfidence: .97, frames: [('SCREEN_MONITOR', .9913, .98), ('SCREEN_MONITOR', .9908, .98)]),
      (id: '3F78', display: false, stillClass: 'REALITY_OUTDOOR', stillProbability: .0051, stillConfidence: .98, frames: [('REALITY_OUTDOOR', .0086, .97), ('REALITY_OUTDOOR', .0023, .99)]),
      (id: '4488-mixed-room-tv', display: false, stillClass: 'REALITY_OUTDOOR', stillProbability: .3161, stillConfidence: .64, frames: [('REALITY_ROOM', .2258, .70), ('REALITY_ROOM', .2156, .71)]),
      (id: '4665', display: false, stillClass: 'REALITY_ROOM', stillProbability: .0007, stillConfidence: .99, frames: [('REALITY_ROOM', .0033, .99), ('REALITY_ROOM', .0008, .99)]),
      (id: 'DCA1', display: false, stillClass: 'REALITY_ROOM', stillProbability: .0010, stillConfidence: .99, frames: [('REALITY_ROOM', .0010, .99), ('REALITY_ROOM', .0007, .99)]),

      // Build 80 sanitized vectors.
      (id: '27FCD', display: true, stillClass: 'SCREEN_MONITOR', stillProbability: .4534, stillConfidence: .4471, frames: [('REALITY_OBJECT', .1113, .80), ('SCREEN_MONITOR', .4184, .4106), ('REALITY_OBJECT', .2691, .6189), ('REALITY_OBJECT', .1163, .7826)]),
      (id: '5DB3', display: true, stillClass: 'SCREEN_MONITOR', stillProbability: .9956, stillConfidence: .99, frames: [('SCREEN_MONITOR', .9960, .99), ('SCREEN_MONITOR', .9947, .99), ('SCREEN_MONITOR', .9930, .99), ('SCREEN_MONITOR', .9860, .98)]),
      (id: 'E1FC', display: true, stillClass: 'SCREEN_MONITOR', stillProbability: .9945, stillConfidence: .99, frames: [('SCREEN_MONITOR', .9871, .98), ('SCREEN_MONITOR', .9883, .98), ('SCREEN_MONITOR', .9800, .97), ('SCREEN_MONITOR', .9750, .97)]),
      (id: 'E2F3', display: true, stillClass: 'SCREEN_MONITOR', stillProbability: .9941, stillConfidence: .99, frames: [('SCREEN_MONITOR', .9919, .99), ('SCREEN_MONITOR', .9909, .99), ('SCREEN_MONITOR', .9890, .98), ('SCREEN_MONITOR', .9880, .98)]),
      (id: 'ED3F', display: true, stillClass: 'SCREEN_MONITOR', stillProbability: .9694, stillConfidence: .96, frames: [('SCREEN_MONITOR', .9959, .99), ('SCREEN_MONITOR', .9904, .99), ('SCREEN_MONITOR', .9880, .98), ('SCREEN_MONITOR', .9850, .98)]),
      (id: '2842', display: false, stillClass: 'REALITY_OUTDOOR', stillProbability: .0010, stillConfidence: .99, frames: [('REALITY_OUTDOOR', .0009, .99), ('REALITY_OUTDOOR', .0005, .99), ('REALITY_OUTDOOR', .0013, .99), ('REALITY_OUTDOOR', .0007, .99)]),
      (id: 'F2A8', display: false, stillClass: 'REALITY_ROOM', stillProbability: .0096, stillConfidence: .97, frames: [('REALITY_ROOM', .0102, .96), ('REALITY_ROOM', .0125, .96), ('REALITY_ROOM', .0080, .97), ('REALITY_ROOM', .0090, .97)]),
    ];

    for (final c in cases) {
      final result = PhotoTemporalScreenConcordance.evaluate(
        _still(
          predictedClass: c.stillClass,
          screenProbability: c.stillProbability,
          confidence: c.stillConfidence,
        ),
        _live(frames: c.frames),
      );
      if (c.display) {
        expect(result?.decision, 'STRONG_DISPLAY_RISK', reason: c.id);
      } else {
        expect(result, isNull, reason: c.id);
      }
    }
  });

  test('gate is Temporal V2 only and cannot promote one isolated source', () {
    final still = _still(
      predictedClass: 'SCREEN_MONITOR',
      screenProbability: .60,
      confidence: .58,
    );
    final live = _live(frames: [('SCREEN_MONITOR', .47, .45), ('REALITY_ROOM', .10, .90)]);

    final wrongMethod = Map<String, dynamic>.from(live)
      ..['photoDecisionMethod'] = 'VIDEO_EQUIVALENT_PRE_CAPTURE_TEMPORAL_ANALYSIS';
    expect(PhotoTemporalScreenConcordance.evaluate(still, wrongMethod), isNull);

    expect(
      PhotoTemporalScreenConcordance.evaluate(
        _still(predictedClass: 'REALITY_ROOM', screenProbability: .30, confidence: .60),
        live,
      ),
      isNull,
    );
    expect(
      PhotoTemporalScreenConcordance.evaluate(
        still,
        _live(frames: [('REALITY_ROOM', .30, .60), ('REALITY_ROOM', .20, .70)]),
      ),
      isNull,
    );
  });
}
