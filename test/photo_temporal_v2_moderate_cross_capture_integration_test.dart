import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('camera wires moderate cross-capture gate only into PHOTO decision path', () {
    final source = File('lib/camera_page.dart').readAsStringSync();

    expect(source, contains("import 'hcv_photo_temporal_v2_policy.dart';"));
    expect(
      source,
      contains('HCVPhotoTemporalV2Policy.hasModerateCrossCaptureScreenAgreement'),
    );
    expect(
      source,
      contains('PHOTO_TEMPORAL_V2_MODERATE_SCREEN_CROSS_CAPTURE_AGREEMENT'),
    );
    expect(source, contains("decision: 'NON_CONCLUSIVE'"));
    expect(source, contains("risk: 'MEDIUM'"));

    final photoStart = source.indexOf(
      'HCVDisplayRiskResult combinePhotoDisplayRiskFromPreCaptureEvidence(',
    );
    final gate = source.indexOf(
      'HCVPhotoTemporalV2Policy.hasModerateCrossCaptureScreenAgreement',
      photoStart,
    );
    final videoStart = source.indexOf(
      'HCVDisplayRiskResult combineVideoDisplayRiskFromCaptureEvidence(',
      photoStart,
    );

    expect(photoStart, greaterThanOrEqualTo(0));
    expect(gate, greaterThan(photoStart));
    expect(videoStart, greaterThan(gate));
    expect(
      source.indexOf(
        'HCVPhotoTemporalV2Policy.hasModerateCrossCaptureScreenAgreement',
        videoStart,
      ),
      -1,
      reason: 'VIDEO path must not use the PHOTO recovery gate',
    );
  });
}
