import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_multi_evidence_display_policy.dart';

void main() {
  group('PHOTO HFR partial conflict guard', () {
    test('F3B dual REALITY conflict downgrades HFR partial to NON_CONCLUSIVE', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _partialHfr(),
        stillMl: _stillReality(0.0088),
        temporalMl: _temporalReality(0.0065),
        stillOptical: _noStrongOptical(),
        temporalOptical: _noStrongOptical(),
        videoEquivalentDisplayRisk: const <String, dynamic>{
          'decision': 'NO_DISPLAY_EVIDENCE',
        },
      );

      expect(result.decision, 'NON_CONCLUSIVE');
      expect(
        result.reasons,
        contains('PHOTO_HFR_PARTIAL_CONFLICT_WITH_DUAL_REALITY_EVIDENCE'),
      );
    });

    test('archive99 TV partial HFR remains STRONG', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _partialHfr(),
        stillMl: _stillReality(0.0697),
        temporalMl: _temporalReality(0.4815),
        stillOptical: _noStrongOptical(),
        temporalOptical: _noStrongOptical(),
        videoEquivalentDisplayRisk: const <String, dynamic>{
          'decision': 'NO_DISPLAY_EVIDENCE',
        },
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_HFR_PARTIAL_CORROBORATED_DISPLAY'),
      );
    });

    test('HFR full-frame display remains authoritative', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _partialHfr(fullFrame: true),
        stillMl: _stillReality(0.0088),
        temporalMl: _temporalReality(0.0065),
        stillOptical: _noStrongOptical(),
        temporalOptical: _noStrongOptical(),
        videoEquivalentDisplayRisk: const <String, dynamic>{
          'decision': 'NO_DISPLAY_EVIDENCE',
        },
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(result.reasons, contains('BUILD124_HFR_FULL_FRAME_DISPLAY'));
    });

    test('strong optical display trace prevents the F3B exception', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolvePhoto(
        temporalFrequencyProbe: _partialHfr(),
        stillMl: _stillReality(0.0088),
        temporalMl: _temporalReality(0.0065),
        stillOptical: _strongOptical(),
        temporalOptical: _noStrongOptical(),
        videoEquivalentDisplayRisk: const <String, dynamic>{
          'decision': 'NO_DISPLAY_EVIDENCE',
        },
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_HFR_PARTIAL_CORROBORATED_DISPLAY'),
      );
    });

    test('VIDEO HFR partial path is unchanged', () {
      final result = HCVMultiEvidenceDisplayPolicy.resolveVideo(
        temporalFrequencyProbe: _partialHfr(),
        ml: _temporalReality(0.0065),
        passiveOptical: _noStrongOptical(),
      );

      expect(result.decision, 'STRONG_DISPLAY_RISK');
      expect(
        result.reasons,
        contains('BUILD124_HFR_PARTIAL_CORROBORATED_DISPLAY'),
      );
    });
  });
}

Map<String, dynamic> _partialHfr({bool fullFrame = false}) =>
    <String, dynamic>{
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V3_2',
      'analysisStatus': 'ANALYZED',
      'hfrSpatialComparability': 'COMPARABLE',
      'displayRealityEvidenceV3': <String, dynamic>{
        'fullFrameDisplay': fullFrame,
        'displayLikeCellCount': 5,
        'realityLikeCellCount': 0,
        'spatialFamilyCellCount': 9,
        'harmonicAwareSpatialFamilyCellCount': 9,
        'rowTimeFamilyCellCount': 9,
      },
      'coherentDisplayPeriodicityEvidence': <String, dynamic>{
        'periodicCellCount': 6,
        'stableCellCount': 5,
        'medianCellPeriodicityStrength': 0.15,
      },
    };

Map<String, dynamic> _stillReality(double probability) => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'REALITY_ROOM',
      'screenProbability': probability,
      'signals': const <String, dynamic>{
        'fullFrameRiskScore': 0,
        'contentAreaRiskScore': 0,
      },
    };

Map<String, dynamic> _temporalReality(double probability) => <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'predictedClass': 'REALITY_ROOM',
      'screenProbability': probability,
      'videoFrameAnalyses': const <Map<String, dynamic>>[
        <String, dynamic>{
          'predictedClass': 'REALITY_ROOM',
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 0,
            'contentAreaRiskScore': 0,
          },
        },
        <String, dynamic>{
          'predictedClass': 'REALITY_ROOM',
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 0,
            'contentAreaRiskScore': 0,
          },
        },
        <String, dynamic>{
          'predictedClass': 'REALITY_ROOM',
          'signals': <String, dynamic>{
            'fullFrameRiskScore': 0,
            'contentAreaRiskScore': 0,
          },
        },
      ],
    };

Map<String, dynamic> _noStrongOptical() => const <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'signals': <String, dynamic>{
        'strongDisplayTrace': false,
        'structuralDisplayTrace': false,
        'confirmedDisplayTrace': false,
      },
    };

Map<String, dynamic> _strongOptical() => const <String, dynamic>{
      'analysisStatus': 'ANALYZED',
      'signals': <String, dynamic>{
        'strongDisplayTrace': true,
        'structuralDisplayTrace': false,
        'confirmedDisplayTrace': false,
      },
    };
