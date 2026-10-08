import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/verified_originals_reference.dart';

void main() {
  const id = 'HCV-0123456789ABCDEF';
  final valid = <String, dynamic>{
    'hcvId': id,
    'availability': 'REFERENCE_AVAILABLE',
    'access': 'ENTITLED',
    'certificateVerdict': 'CERTIFICATE_RECORD_VERIFIED',
    'socialFileVerdict': 'NOT_VERIFIED',
    'publicationStatus': 'PUBLISHED',
    'platform': 'r2',
    'referenceAccess': 'SHORT_LIVED_AUTHORIZATION',
    'originalContentSha256': List.filled(64, 'a').join(),
    'referenceSha256': List.filled(64, 'b').join(),
    'derivationType': 'primary_reference_identity_v1',
  };

  test('free discovery accepts R2 availability without a locator', () {
    final free = <String, dynamic>{
      'hcvId': id,
      'availability': 'REFERENCE_AVAILABLE',
      'certificateVerdict': 'CERTIFICATE_RECORD_VERIFIED',
      'socialFileVerdict': 'NOT_VERIFIED',
      'publicationStatus': 'PUBLISHED',
      'platform': 'r2',
      'viewAccess': 'SUBSCRIPTION_REQUIRED',
    };
    expect(
      VerifiedOriginalsReference.isAvailable(
        free,
        requestedHcvId: id,
      ),
      isTrue,
    );
    expect(
      VerifiedOriginalsReference.isAvailable(
        {...free, 'publicUrl': 'https://example.invalid/reference'},
        requestedHcvId: id,
      ),
      isFalse,
    );
    expect(
      VerifiedOriginalsReference.isAvailable(
        {...free, 'platform': 'youtube'},
        requestedHcvId: id,
      ),
      isFalse,
    );
  });

  test('paid view accepts only private short-lived R2 access', () {
    final ref = VerifiedOriginalsReference.fromRegistry(
      valid,
      requestedHcvId: id,
    );
    expect(ref, isNotNull);
    expect(ref!.platform, 'r2');
    expect(ref.isPrivateR2, isTrue);
    expect(ref.publicUrl, isNull);
  });

  test('never accepts copied ID or positive social integrity assertion', () {
    expect(
      VerifiedOriginalsReference.fromRegistry(
        {...valid, 'socialFileVerdict': 'VERIFIED'},
        requestedHcvId: id,
      ),
      isNull,
    );
    expect(
      VerifiedOriginalsReference.fromRegistry(
        {...valid, 'hcvId': 'HCV-FFFFFFFFFFFFFFFF'},
        requestedHcvId: id,
      ),
      isNull,
    );
  });

  test('requires active publication and trusted hash fields', () {
    for (final status in ['REVOKED', 'UNAVAILABLE', 'PENDING']) {
      expect(
        VerifiedOriginalsReference.fromRegistry(
          {...valid, 'publicationStatus': status},
          requestedHcvId: id,
        ),
        isNull,
      );
    }
    expect(
      VerifiedOriginalsReference.fromRegistry(
        {...valid, 'referenceSha256': 'bad'},
        requestedHcvId: id,
      ),
      isNull,
    );
    expect(
      VerifiedOriginalsReference.fromRegistry(
        {...valid, 'derivationType': ''},
        requestedHcvId: id,
      ),
      isNull,
    );
  });

  test('rejects public locators and every non-R2 platform', () {
    expect(
      VerifiedOriginalsReference.fromRegistry(
        {...valid, 'publicUrl': 'https://example.invalid/reference'},
        requestedHcvId: id,
      ),
      isNull,
    );
    expect(
      VerifiedOriginalsReference.fromRegistry(
        {...valid, 'platformPostId': 'legacy'},
        requestedHcvId: id,
      ),
      isNull,
    );
    for (final platform in ['youtube', 'arbitrary', '']) {
      expect(
        VerifiedOriginalsReference.fromRegistry(
          {...valid, 'platform': platform},
          requestedHcvId: id,
        ),
        isNull,
      );
    }
  });
}
