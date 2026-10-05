import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUILD148 adds bounded high-detail photo tamper recovery', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final detail = File('lib/hcv_photo_detail_compare.dart').readAsStringSync();
    final verify = File('lib/registry_verify_page.dart').readAsStringSync();

    expect(pubspec, contains('version: 1.0.0+148'));
    expect(detail, contains('static const int highDetailWidth = 512'));
    expect(detail, contains('static const int _fineGridColumns = 64'));
    expect(detail, contains('_fineMaximumSuspiciousTiles = 32'));
    expect(detail, contains('detectsHighResolutionLocalizedTamper'));
    expect(detail, contains('largestCluster >= _fineMinimumClusterTiles'));

    // BUILD147 coarse semantics remain the first gate.
    expect(detail, contains('static const int width = 256'));
    expect(detail, contains('final coarse = compareNormalizedRgb'));
    expect(
      detail,
      contains(
        'if (coarse.verdict == HCVPhotoDetailVerdict.modified) return coarse',
      ),
    );

    // The exact entitled R2 reference remains the comparison source.
    expect(verify, contains('materializeEntitledReference(hcvId)'));
    expect(verify, contains('HCVPhotoDetailComparator.compareFiles'));
  });
}
