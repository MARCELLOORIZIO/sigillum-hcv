import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_engine.dart';

void main() {
  test('public certificate identity excludes private Stripe recovery state', () {
    final public = publicHcvIdentity({
      'creatorId': 'ACC-ABC',
      'creatorName': 'Verified Creator',
      'devicePublicKeyFingerprint': 'a' * 64,
      'identityFingerprint': 'b' * 64,
      'trustLevel': 'LEGAL_IDENTITY_VERIFIED',
      'identityAssuranceLevel': 'KYC_DOCUMENT_VERIFIED',
      'legalIdentityStatus': 'VERIFIED',
      'kycProvider': 'stripe_identity',
      'kycStatus': 'verified',
      'kycSessionId': 'vs_private_session',
      'kycRecoveryError': 'private server error',
      'publicKey': const {'modulus': 'private-copy', 'exponent': 'AQAB'},
      'localDeviceHash': 'private-local-device-hash',
      'legacyCreatorIdMigrated': true,
    });

    expect(public['creatorName'], 'Verified Creator');
    expect(public['kycStatus'], 'verified');
    expect(public['publicDisclosure'], 'MINIMIZED_CERTIFICATE_IDENTITY_V1');
    expect(public.containsKey('kycSessionId'), isFalse);
    expect(public.containsKey('kycRecoveryError'), isFalse);
    expect(public.containsKey('publicKey'), isFalse);
    expect(public.containsKey('localDeviceHash'), isFalse);
    expect(public.containsKey('legacyCreatorIdMigrated'), isFalse);
  });
}
