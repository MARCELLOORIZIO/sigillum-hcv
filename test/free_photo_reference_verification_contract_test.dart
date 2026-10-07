import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PHOTO automatic reference verification is free and server-side', () {
    final service =
        File('lib/verified_originals_publish_service.dart').readAsStringSync();
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();

    expect(
      service,
      contains(
        r"'$_base/api/verified-originals/$hcvId/verify-photo-copy'",
      ),
    );
    expect(service, contains('VerifiedPhotoCopyStatus.networkError'));
    expect(service, contains('VerifiedPhotoCopyStatus.providerUnavailable'));
    expect(service, contains('VerifiedPhotoCopyStatus.technicalError'));

    final photoMethodStart =
        registry.indexOf('Future<VerifiedPhotoCopyCheck> _matchesPhotoDetail');
    final photoMethodEnd = registry.indexOf(
      'Future<HCVReferenceVisualVerdict?> _matchesOfficialReferenceVisualFingerprint',
      photoMethodStart,
    );
    expect(photoMethodStart, greaterThanOrEqualTo(0));
    expect(photoMethodEnd, greaterThan(photoMethodStart));
    final photoMethod = registry.substring(photoMethodStart, photoMethodEnd);

    expect(photoMethod, contains('.verifyPhotoCopy('));
    expect(photoMethod, isNot(contains('materializeEntitledReference')));
    expect(photoMethod, isNot(contains('HCVPhotoDetailComparator')));
  });

  test('verification errors are not converted into forensic inconclusive', () {
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();

    expect(registry, contains('OFFICIAL REFERENCE CHECK ERROR'));
    expect(registry, contains('VerifiedPhotoCopyStatus.networkError'));
    expect(registry, contains('VerifiedPhotoCopyStatus.providerUnavailable'));
    expect(registry, contains('VerifiedPhotoCopyStatus.technicalError'));
    expect(
      registry,
      isNot(contains('catch (_) {\n      // Never upgrade a SHA-different photo')),
    );
  });
}
