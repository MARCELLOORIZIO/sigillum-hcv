import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUILD147 closes GPS dead-end and photo false-conforming path', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final location = File('lib/hcv_capture_location.dart').readAsStringSync();
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final verify = File('lib/registry_verify_page.dart').readAsStringSync();
    final detail = File('lib/hcv_photo_detail_compare.dart').readAsStringSync();

    final versionMatch =
        RegExp(r'^version:\s*1\.0\.0\+(\d+)\s*$', multiLine: true)
            .firstMatch(pubspec);
    expect(versionMatch, isNotNull);
    expect(int.parse(versionMatch!.group(1)!), greaterThanOrEqualTo(147));

    expect(location, contains('Geolocator.requestPermission()'));
    expect(location, contains('Geolocator.openAppSettings()'));
    expect(location, contains('Geolocator.openLocationSettings()'));
    expect(location, contains('permissionDeniedForever'));

    expect(camera, contains('_showLocationError(error)'));
    expect(camera, contains("label: _c('openSettings')"));
    expect(camera, contains("label: _c('openLocationSettings')"));

    expect(verify, contains('Future<VerifiedPhotoCopyCheck> _matchesPhotoDetail'));
    expect(verify, contains('.verifyPhotoCopy('));
    expect(verify, contains('VerifiedPhotoCopyStatus.inconclusive'));
    expect(verify, isNot(contains('materializeEntitledReference(hcvId)')));
    expect(
      verify,
      contains('primaryVerdict == HCVReferenceVisualVerdict.modified'),
    );
    expect(detail, contains('static const int width = 256'));
    expect(detail, contains('localizedTamperTiles'));
  });
}
