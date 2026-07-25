import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_active_display_classifier.dart';
import 'package:sigillum_iphone/hcv_scene_decision_fusion.dart';
import 'package:sigillum_iphone/hcv_scene_geometry_classifier.dart';

void main() {
  group('HCVSceneDecisionFusion', () {
    test('archive 20 reality profile is resolved by strong parallax', () {
      final result = HCVSceneDecisionFusion.fuse(
        illumination: _displayLikeIllumination(),
        geometry: _geometry(
          sceneClass: 'REALITY',
          reality: true,
          motion: 0.44,
          reliability: 0.76,
          direction: 0.63,
          dispersion: 0.47,
          planar: 0.25,
        ),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.risk, 'LOW');
      expect(result.score, 20);
      expect(result.sceneClass, 'REALITY');
      expect(result.realityEvidence, isTrue);
      expect(result.displayEvidence, isFalse);
    });

    test('planar geometry corroborates display illumination without becoming strong', () {
      final result = HCVSceneDecisionFusion.fuse(
        illumination: _displayLikeIllumination(),
        geometry: _geometry(
          sceneClass: 'PLANAR',
          planarEvidence: true,
          motion: 0.39,
          reliability: 0.81,
          direction: 0.92,
          dispersion: 0.08,
          planar: 0.80,
        ),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.score, 45);
      expect(result.sceneClass, 'DISPLAY_SUSPECTED');
      expect(result.displayEvidence, isTrue);
      expect(result.reasons,
          contains('PLANAR_GEOMETRY_CORROBORATES_DISPLAY_HYPOTHESIS'));
    });

    test('planarity alone never proves a display', () {
      final result = HCVSceneDecisionFusion.fuse(
        illumination: const HCVActiveDisplayClassification(
          decision: 'NO_DISPLAY_EVIDENCE',
          risk: 'LOW',
          score: 20,
          displayProbability: 0.18,
          illuminationResponseScore: 0.72,
          emissiveIndependenceScore: 0.28,
          electronicCueScore: 0.25,
          reasons: <String>[],
        ),
        geometry: _geometry(
          sceneClass: 'PLANAR',
          planarEvidence: true,
          motion: 0.36,
          reliability: 0.80,
          direction: 0.90,
          dispersion: 0.09,
          planar: 0.78,
        ),
      );

      expect(result.decision, 'NO_DISPLAY_EVIDENCE');
      expect(result.displayEvidence, isFalse);
      expect(result.sceneClass, 'UNKNOWN');
    });

    test('weak parallax conflicting with display cues stays non-conclusive', () {
      final result = HCVSceneDecisionFusion.fuse(
        illumination: _displayLikeIllumination(),
        geometry: _geometry(
          sceneClass: 'REALITY',
          reality: true,
          motion: 0.25,
          reliability: 0.50,
          direction: 0.55,
          dispersion: 0.30,
          planar: 0.50,
        ),
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(result.sceneClass, 'UNKNOWN');
      expect(result.reasons,
          contains('ILLUMINATION_AND_GEOMETRY_EVIDENCE_CONFLICT'));
    });
  });
}

HCVActiveDisplayClassification _displayLikeIllumination() {
  return const HCVActiveDisplayClassification(
    decision: 'NON_CONCLUSIVE',
    risk: 'MEDIUM',
    score: 45,
    displayProbability: 0.66,
    illuminationResponseScore: 0.45,
    emissiveIndependenceScore: 0.55,
    electronicCueScore: 0.63,
    reasons: <String>[
      'EMISSIVE_SCENE_RESISTS_DIFFUSE_TORCH',
      'ELECTRONIC_DISPLAY_CUES_PRESENT',
    ],
  );
}

HCVSceneGeometryClassification _geometry({
  required String sceneClass,
  bool reality = false,
  bool planarEvidence = false,
  required double motion,
  required double reliability,
  required double direction,
  required double dispersion,
  required double planar,
}) {
  return HCVSceneGeometryClassification(
    sceneClass: sceneClass,
    realityEvidence: reality,
    planarEvidence: planarEvidence,
    motionMagnitude: motion,
    flowReliability: reliability,
    directionCoherence: direction,
    depthDispersion: dispersion,
    planarCoherence: planar,
    matchedRegions: 9,
    reasons: const <String>[],
  );
}
