import 'package:flutter_test/flutter_test.dart';
import 'package:hcv_app/verified_originals_reference.dart';

void main() {
  const id = 'HCV-0123456789ABCDEF';
  final valid = <String, dynamic>{
    'hcvId': id,
    'availability': 'REFERENCE_AVAILABLE',
    'certificateVerdict': 'CERTIFICATE_RECORD_VERIFIED',
    'socialFileVerdict': 'NOT_VERIFIED',
    'youtubeUrl': 'https://www.youtube.com/watch?v=AbCdEfGhI_1',
    'originalSha256': 'a' * 64,
    'renditionSha256': 'b' * 64,
  };

  test('discovery returns a locator, not a social integrity verdict', () {
    final ref = VerifiedOriginalsReference.fromRegistry(
      valid,
      requestedHcvId: id,
    );
    expect(ref, isNotNull);
    expect(ref!.youtubeUrl.host, 'www.youtube.com');
  });

  test('never accepts a copied ID as an integrity assertion', () {
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

  test('does not display missing, invalid or withdrawn reference', () {
    for (final availability in [
      'REFERENCE_NOT_AVAILABLE',
      'WITHDRAWN',
      'PENDING',
    ]) {
      expect(
        VerifiedOriginalsReference.fromRegistry(
          {...valid, 'availability': availability},
          requestedHcvId: id,
        ),
        isNull,
      );
    }
  });

  test('blocks open redirects and bad digest lengths', () {
    for (final url in [
      'https://evil.example/watch?v=AbCdEfGhI_1',
      'http://www.youtube.com/watch?v=AbCdEfGhI_1',
      'https://www.youtube.com/watch?v=AbCdEfGhI_1&redirect=x',
      'https://www.youtube.com/watch?v=../',
    ]) {
      expect(
        VerifiedOriginalsReference.fromRegistry(
          {...valid, 'youtubeUrl': url},
          requestedHcvId: id,
        ),
        isNull,
      );
    }
    expect(
      VerifiedOriginalsReference.fromRegistry(
        {...valid, 'renditionSha256': 'bad'},
        requestedHcvId: id,
      ),
      isNull,
    );
  });
}
