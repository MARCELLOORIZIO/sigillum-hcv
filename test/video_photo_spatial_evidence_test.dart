import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_video_photo_spatial_evidence.dart';

Map<String, dynamic> _frame({
  required int index,
  required String predictedClass,
  required double screenProbability,
  required int fullFrame,
  required int contentArea,
  double confidence = 0.95,
}) => <String, dynamic>{
  'analysisStatus': 'ANALYZED',
  'videoFrameIndex': index,
  'approxVideoSecond': index.toDouble(),
  'predictedClass': predictedClass,
  'predictedClassConfidence': confidence,
  'screenProbability': screenProbability,
  'screenReplayRiskScore': (screenProbability * 100).round(),
  'signals': <String, dynamic>{
    'fullFrameRiskScore': fullFrame,
    'contentAreaRiskScore': contentArea,
  },
};

void main() {
  test('HCV-4A2F-like frames form stable PHOTO-like full-frame evidence', () {
    final evidence = HCVVideoPhotoSpatialEvidence.analyze(
      <Map<String, dynamic>>[
        _frame(
          index: 0,
          predictedClass: 'SCREEN_MONITOR',
          screenProbability: 0.9578,
          fullFrame: 96,
          contentArea: 75,
        ),
        _frame(
          index: 1,
          predictedClass: 'SCREEN_MONITOR',
          screenProbability: 0.9225,
          fullFrame: 92,
          contentArea: 76,
        ),
        _frame(
          index: 2,
          predictedClass: 'SCREEN_MONITOR',
          screenProbability: 0.9179,
          fullFrame: 92,
          contentArea: 59,
        ),
      ],
    );

    expect(evidence['sceneContinuity'], 'STABLE_SCREEN');
    expect(evidence['sceneTransitionDetected'], false);
    expect(evidence['spatiallySupportedScreenFrameCount'], 2);
    expect(evidence['strictPhotoSpatialFrameCount'], 0);
    expect(evidence['medianFullFrameRiskScore'], 92.0);
    expect(evidence['medianContentAreaRiskScore'], 75.0);
    expect(evidence['stableFullFrameScreenCorroboration'], true);
  });

  test(
    'archive-60-like sequence remains stable despite one strict PHOTO frame',
    () {
      final evidence = HCVVideoPhotoSpatialEvidence.analyze(
        <Map<String, dynamic>>[
          _frame(
            index: 0,
            predictedClass: 'SCREEN_MONITOR',
            screenProbability: 0.9903,
            fullFrame: 99,
            contentArea: 82,
          ),
          _frame(
            index: 1,
            predictedClass: 'SCREEN_MONITOR',
            screenProbability: 0.9787,
            fullFrame: 98,
            contentArea: 81,
          ),
          _frame(
            index: 2,
            predictedClass: 'SCREEN_MONITOR',
            screenProbability: 0.9819,
            fullFrame: 98,
            contentArea: 89,
          ),
        ],
      );

      expect(evidence['strictPhotoSpatialFrameCount'], 1);
      expect(evidence['stableFullFrameScreenCorroboration'], true);
      expect(evidence['medianContentAreaRiskScore'], 82.0);
    },
  );

  test('chronology is reconstructed from videoFrameIndex before transition analysis', () {
    final evidence = HCVVideoPhotoSpatialEvidence.analyze(
      <Map<String, dynamic>>[
        _frame(
          index: 2,
          predictedClass: 'REALITY_ROOM',
          screenProbability: 0.03,
          fullFrame: 5,
          contentArea: 7,
        ),
        _frame(
          index: 0,
          predictedClass: 'SCREEN_MONITOR',
          screenProbability: 0.94,
          fullFrame: 94,
          contentArea: 80,
        ),
        _frame(
          index: 1,
          predictedClass: 'REALITY_ROOM',
          screenProbability: 0.05,
          fullFrame: 8,
          contentArea: 10,
        ),
      ],
    );

    final sequence = (evidence['frameSequence'] as List)
        .map((item) => (item as Map)['semanticFamily'])
        .toList();
    expect(sequence, <String>['SCREEN', 'REALITY', 'REALITY']);
    expect(evidence['sceneContinuity'], 'TRANSITION');
    expect(evidence['sceneTransitionDetected'], true);
    expect(evidence['stableFullFrameScreenCorroboration'], false);
  });

  test(
    'stable all-reality sequence is recorded without display corroboration',
    () {
      final evidence = HCVVideoPhotoSpatialEvidence.analyze(
        <Map<String, dynamic>>[
          for (var i = 0; i < 4; i++)
            _frame(
              index: i,
              predictedClass: 'REALITY_ROOM',
              screenProbability: 0.08 + i * 0.01,
              fullFrame: 10,
              contentArea: 12,
            ),
        ],
      );

      expect(evidence['sceneContinuity'], 'STABLE_REALITY');
      expect(evidence['stableRealityCorroboration'], true);
      expect(evidence['stableFullFrameScreenCorroboration'], false);
    },
  );
}
