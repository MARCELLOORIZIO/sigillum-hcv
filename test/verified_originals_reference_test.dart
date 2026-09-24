import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/verified_originals_reference.dart';

void main() {
  const id = 'HCV-0123456789ABCDEF';
  final valid = <String, dynamic>{
    'hcvId': id,
    'availability': 'REFERENCE_AVAILABLE',
    'certificateVerdict': 'CERTIFICATE_RECORD_VERIFIED',
    'socialFileVerdict': 'NOT_VERIFIED',
    'publicationStatus': 'PUBLISHED',
    'platform': 'youtube',
    'publicUrl': 'https://www.youtube.com/watch?v=AbCdEfGhI_1',
    'originalContentSha256': List.filled(64, 'a').join(),
    'referenceSha256': List.filled(64, 'b').join(),
    'derivationType': 'video_transcode_h264_aac_v1',
  };

  test('discovery returns a locator, not a social integrity verdict', () {
    final ref = VerifiedOriginalsReference.fromRegistry(
      valid,
      requestedHcvId: id,
    );
    expect(ref, isNotNull);
    expect(ref!.publicUrl.host, 'www.youtube.com');
    expect(ref.platform, 'youtube');
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

  test('blocks open redirects and non-canonical platform references', () {
    for (final url in [
      'https://evil.example/watch?v=AbCdEfGhI_1',
      'http://www.youtube.com/watch?v=AbCdEfGhI_1',
      'https://www.youtube.com/watch?v=AbCdEfGhI_1&redirect=x',
      'https://www.youtube.com/watch?v=../',
    ]) {
      expect(
        VerifiedOriginalsReference.fromRegistry(
          {...valid, 'publicUrl': url},
          requestedHcvId: id,
        ),
        isNull,
      );
    }
    expect(
      VerifiedOriginalsReference.fromRegistry(
        {...valid, 'platform': 'arbitrary'},
        requestedHcvId: id,
      ),
      isNull,
    );
  });
}
