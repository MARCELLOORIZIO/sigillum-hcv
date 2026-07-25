import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  group('HCVSceneGeometryClassifier', () {
    test('multi-depth parallax is reality evidence', () {
      final result = HCVSceneGeometryClassifier.classify(
        motionMagnitude: 0.42,
        flowReliability: 0.78,
        directionCoherence: 0.64,
        depthDispersion: 0.46,
        planarCoherence: 0.27,
        matchedRegions: 9,
      );

      expect(result.sceneClass, 'REALITY');
      expect(result.realityEvidence, isTrue);
      expect(result.planarEvidence, isFalse);
      expect(result.reasons, contains('MULTI_DEPTH_PARALLAX_DETECTED'));
    });

    test('coherent planar motion is corroboration only', () {
      final result = HCVSceneGeometryClassifier.classify(
        motionMagnitude: 0.38,
        flowReliability: 0.82,
        directionCoherence: 0.91,
        depthDispersion: 0.08,
        planarCoherence: 0.79,
        matchedRegions: 10,
      );

      expect(result.sceneClass, 'PLANAR');
      expect(result.realityEvidence, isFalse);
      expect(result.planarEvidence, isTrue);
      expect(result.reasons, contains('PLANARITY_IS_CORROBORATION_ONLY'));
    });

    test('insufficient camera motion stays unknown', () {
      final result = HCVSceneGeometryClassifier.classify(
        motionMagnitude: 0.05,
        flowReliability: 0.84,
        directionCoherence: 0.90,
        depthDispersion: 0.05,
        planarCoherence: 0.82,
        matchedRegions: 10,
      );

      expect(result.sceneClass, 'UNKNOWN');
      expect(result.realityEvidence, isFalse);
      expect(result.planarEvidence, isFalse);
      expect(result.reasons, contains('GEOMETRY_MOTION_TOO_SMALL'));
    });

    test('unreliable dynamic content cannot become reality evidence', () {
      final result = HCVSceneGeometryClassifier.classify(
        motionMagnitude: 0.58,
        flowReliability: 0.28,
        directionCoherence: 0.42,
        depthDispersion: 0.72,
        planarCoherence: 0.10,
        matchedRegions: 8,
      );

      expect(result.sceneClass, 'UNKNOWN');
      expect(result.realityEvidence, isFalse);
      expect(result.reasons, contains('GEOMETRY_FLOW_NOT_RELIABLE'));
    });
  });
}
