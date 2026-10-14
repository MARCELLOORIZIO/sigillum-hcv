import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/verification_ui_copy.dart';

void main() {
  test('provenance outcome explanations remain distinct in all languages', () {
    for (final language in ['it', 'en', 'es', 'ru']) {
      final verified = VerificationUiCopy.t(language, 'provenanceOkDetail');
      final failed = VerificationUiCopy.t(language, 'provenanceFailedDetail');
      final unavailable = VerificationUiCopy.t(language, 'provenanceUnavailableDetail');
      expect(failed, isNot('provenanceFailedDetail'));
      expect(unavailable, isNot('provenanceUnavailableDetail'));
      expect(failed, isNot(verified));
      expect(unavailable, isNot(verified));
      expect(unavailable, isNot(failed));
      expect(VerificationUiCopy.t(language, 'notVerified'), isNot(VerificationUiCopy.t(language, 'verified')));
    }
  });

  test('provenance mapper evaluates negation before successful verification', () {
    // Static guard only. A separate device/widget regression is still required.
    final source = File('lib/registry_verify_page.dart').readAsStringSync();
    final negative = source.indexOf("if (axis == 'provenance' && value.contains('non verificata'))");
    final positive = source.indexOf("if (axis == 'provenance' && value.trim() == 'verificata')");
    expect(negative, greaterThanOrEqualTo(0));
    expect(positive, greaterThan(negative));
    expect(source, contains("return _v('provenanceFailedDetail');"));
    expect(source, contains("return _v('provenanceUnavailableDetail');"));
    expect(source, contains("value.contains('non raggiungibile')"));
    expect(source, contains("value.contains('non presente online')"));
    expect(source, contains("value.contains('incompleta')"));
    expect(source, contains("return _v('verificationIncomplete');"));

  });
}
