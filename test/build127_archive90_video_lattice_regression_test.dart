import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

void main() {
  group('BUILD127 archive 90 VIDEO native lattice and uncertainty', () {
    test('archive90 6741 textile 10.25x is NON_CONCLUSIVE, not DISPLAY', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(),
        ml: _videoMl(0.9586, <int>[96, 89]),
        passiveOptical: _optical(flat: true, rgbPhase: 0.0),
      );
      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('BUILD127_VIDEO_LOW_INFORMATION_SEMANTIC_ONLY'),
      );
    });

    test('archive90 10A4 textile 15x is NON_CONCLUSIVE, not REALITY', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(displayCells: 3),
        ml: _videoMl(0.8963, <int>[90, 88, 79]),
        passiveOptical: _optical(flat: true, rgbPhase: 0.0),
      );
      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('ABSENCE_OF_DISPLAY_PROOF_IS_NOT_POSITIVE_REALITY_PROOF'),
      );
    });

    test('archive90 F1C3 monitor 1x remains STRONG_DISPLAY_RISK', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(),
        ml: _videoMl(0.9906, <int>[99, 99, 99, 98]),
        passiveOptical: _optical(flat: false, rgbPhase: 0.8143),
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_VIDEO_PERSISTENT_STRONG_DISPLAY'),
      );
    });

    test('archive90 98C6 monitor 8.35x remains STRONG_DISPLAY_RISK', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(),
        ml: _videoMl(0.9820, <int>[98, 96]),
        passiveOptical: _optical(flat: false, rgbPhase: 0.0),
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });

    test('full-frame HFR overrides low-information guard', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(fullFrame: true),
        ml: _videoMl(0.96, <int>[96, 92, 90]),
        passiveOptical: _optical(flat: true, rgbPhase: 0.0),
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.reasons, contains('BUILD124_HFR_FULL_FRAME_DISPLAY'));
    });

    test('confirmed structural optical display blocks downgrade', () {
      final optical = _optical(flat: true, rgbPhase: 0.0);
      (optical['signals'] as Map<String, dynamic>)['structuralDisplayTrace'] =
          true;
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(),
        ml: _videoMl(0.96, <int>[96, 92]),
        passiveOptical: optical,
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });

    test('absent or failed optical analysis does not invent reality evidence', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _hfr(),
        ml: _videoMl(0.96, <int>[96, 92]),
      );
      expect(result.decision, 'STRONG_DISPLAY_RISK');
    });

    test('VIDEO frame extraction preserves aspect ratio and 3-frame bound', () {
      final source =
          File('lib/hcv_screen_replay_analyzer.dart').readAsStringSync();
      expect(source, contains('_analyzeNativeVideoLattice('));
      expect(source, contains('ORIGINAL_ASPECT_RATIO_NO_LETTERBOX'));
      expect(source, contains("scale='min(iw,720)':-2:flags=lanczos"));
      expect(source, contains('-frames:v 3 -q:v 2'));
      expect(source, contains('legacyPaddedLatticeEvidence'));
      expect(source, contains('nativeVideoLattice'));
      // Legacy optical sampling is retained, not replaced.
      expect(source, contains('fps=10,scale=720:720:force_original_aspect_ratio=decrease'));
      expect(source, contains('pad=720:720:(ow-iw)/2:(oh-ih)/2'));
    });
  });
}

Map<String, dynamic> _optical({
  required bool flat,
  required double rgbPhase,
}) => <String, dynamic>{
      'scanMode': 'EVERY_15_SECONDS_FAST_SAMPLE',
      'screenReplayRiskScore': 20,
      'signals': <String, dynamic>{
        'flatSceneUniformity': flat,
        'lowMicroVariation': true,
        'rgbPhaseConsistencyScore': rgbPhase,
        'strongDisplayTrace': false,
        'structuralDisplayTrace': false,
        'confirmedDisplayTrace': false,
        'physicalRepeatingTextureLikely': false,
      },
    };

Map<String, dynamic> _videoMl(double probability, List<int> scores) =>
    <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'SCREEN_MONITOR',
      'screenProbability': probability,
      'videoFrameAnalyses': <Map<String, dynamic>>[
        for (final score in scores)
          <String, dynamic>{
            'predictedClass': 'SCREEN_MONITOR',
            'signals': <String, dynamic>{
              'fullFrameRiskScore': score,
              'contentAreaRiskScore': score,
            },
          },
      ],
    };

Map<String, dynamic> _hfr({
  bool fullFrame = false,
  int displayCells = 0,
}) => <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'hfrSpatialComparability': 'COMPARABLE',
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': fullFrame,
        'displayLikeCellCount': fullFrame ? 9 : displayCells,
        'realityLikeCellCount': 0,
      },
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'periodicCellCount': fullFrame ? 9 : 0,
        'stableCellCount': fullFrame ? 9 : 0,
        'medianCellPeriodicityStrength': fullFrame ? 0.24 : 0.02,
      },
    };
