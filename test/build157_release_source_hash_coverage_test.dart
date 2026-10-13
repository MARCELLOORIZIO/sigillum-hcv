import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TestFlight source attestation includes updated billing, subtitles and vault', () {
    final script = File('tool/build_testflight_ipa_rc2_20260825.sh').readAsStringSync();
    final hashes = script.split('release_source_hashes() {')[1].split('\n}')[0];
    for (final file in [
      'lib/commercial_gate.dart',
      'lib/commercial_billing_service.dart',
      'lib/hcv_secure_media_vault.dart',
      'lib/video_transcription_service.dart',
      'lib/registry_verify_page.dart',
      'assets/ml/sigillum_photo_framing_v1.tflite',
    ]) {
      expect(hashes, contains(file), reason: 'Missing release-source SHA-256 proof: $file');
    }
    expect(script, contains('release_source_hashes > "$AUDIT_DIR/release-source-after-build.sha256"'));
  });
}
