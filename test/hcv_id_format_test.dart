import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_engine.dart';
import 'package:sigillum_iphone/hcv_registry_service.dart';

void main() {
  test('new HCV IDs contain exactly sixteen hexadecimal characters', () {
    for (var i = 0; i < 50; i++) {
      expect(HCVEngine().hcvId, matches(RegExp(r'^HCV-[A-F0-9]{16}$')));
    }
  });

  test('certificate parser rejects legacy eight-character IDs', () {
    const registry = HCVRegistryService();
    expect(
      registry.extractHcvIdFromCertificate({
        'meta': {'hcvId': 'HCV-1234ABCD'},
      }),
      isNull,
    );
  });

  test('certificate parser accepts only a sixteen-character ID', () {
    const registry = HCVRegistryService();
    expect(
      registry.extractHcvIdFromCertificate({
        'meta': {'hcvId': 'HCV-1234ABCD5678EF90'},
      }),
      'HCV-1234ABCD5678EF90',
    );
  });
}
