import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUILD145 hardens social video verification chain', () {
    final quick = File('lib/quick_hcv_media_gate_page.dart').readAsStringSync();
    final verify = File('lib/registry_verify_page.dart').readAsStringSync();
    final v3 =
        File('lib/hcv_reference_visual_fingerprint_v3.dart').readAsStringSync();

    expect(quick, contains('const sampleSeconds = <double>[0.2, 0.8]'));
    expect(quick, contains('allowFocusedFallback: true'));
    expect(quick, isNot(contains('One frame only.')));

    expect(v3, contains('_alignmentLocalFeatureDistance'));
    expect(v3, contains('previousMatchedIndex'));
    expect(v3, contains('localDistance < bestLocalDistance'));

    expect(verify, contains('authorizedReferenceSeen'));
    expect(verify, contains('authorizedInconclusive'));
    expect(
      verify,
      contains(
        'primaryVerdict = HCVReferenceVisualVerdict.inconclusive',
      ),
    );
  });
}
