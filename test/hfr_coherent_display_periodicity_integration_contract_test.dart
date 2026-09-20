import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('photo and video final decisions consume real-schema HFR evidence', () {
    final cameraSource = File('lib/camera_page.dart').readAsStringSync();
    final policySource =
        File('lib/hcv_multi_evidence_display_policy.dart').readAsStringSync();

    expect(
      RegExp(r'HCVMultiEvidenceDisplayPolicy\\.resolvePhoto\\(')
          .allMatches(cameraSource)
          .length,
      equals(1),
    );
    expect(
      RegExp(r'HCVMultiEvidenceDisplayPolicy\\.resolveVideo\\(')
          .allMatches(cameraSource)
          .length,
      equals(1),
    );
    expect(
      RegExp(r'temporalFrequencyProbe:\\s*temporalFrequencyProbe')
          .allMatches(cameraSource)
          .length,
      equals(2),
    );

    expect(policySource, contains("probe['displayRealityEvidenceV3']"));
    expect(
      policySource,
      contains("probe['coherentDisplayPeriodicityEvidence']"),
    );
    expect(policySource, contains("coherent['periodicCellCount']"));
    expect(policySource, contains("coherent['stableCellCount']"));
    expect(policySource, contains('displayLike >= 5'));
    expect(policySource, contains('realityLike == 0'));
    expect(policySource, contains('periodic >= 6'));
    expect(policySource, contains('stable >= 5'));
    expect(policySource, contains('spatial == 9'));
    expect(policySource, contains('harmonic == 9'));
    expect(policySource, contains('rowTime == 9'));
    expect(policySource, contains('medianPeriodicity >= 0.15'));
  });
}
