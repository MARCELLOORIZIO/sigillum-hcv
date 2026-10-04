import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BUILD147 closes GPS dead-end and photo false-conforming path', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final location = File('lib/hcv_capture_location.dart').readAsStringSync();
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final verify = File('lib/registry_verify_page.dart').readAsStringSync();
    final detail =
        File('lib/hcv_photo_detail_compare.dart').readAsStringSync();

    expect(pubspec, contains('version: 1.0.0+147'));

    expect(location, contains('Geolocator.requestPermission()'));
    expect(location, contains('Geolocator.openAppSettings()'));
    expect(location, contains('Geolocator.openLocationSettings()'));
    expect(location, contains('permissionDeniedForever'));

    expect(camera, contains('_showLocationError(error)'));
    expect(camera, contains("label: _c('openSettings')"));
    expect(camera, contains("label: _c('openLocationSettings')"));

    expect(verify, contains('HCVPhotoDetailComparator.compareFiles'));
    expect(verify, contains('materializeEntitledReference(hcvId)'));
    expect(
      verify,
      contains(
        'coarse V3 similarity alone to certify a SHA-different photo as conforming',
      ),
    );
    expect(detail, contains('static const int width = 256'));
    expect(detail, contains('localizedTamperTiles'));
  });
}
