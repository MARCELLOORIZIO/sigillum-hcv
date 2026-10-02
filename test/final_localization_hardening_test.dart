import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('final Creator and text Registry runtime copy is localized', () {
    final home = File('lib/user_home_page.dart').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final text = File('lib/text_cert_page.dart').readAsStringSync();
    final copy = File('lib/sigillum_localization.dart').readAsStringSync();
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(home, contains("_t('creatorEntitlementUnavailable')"));
    expect(
      home,
      isNot(
        contains(
          'Impossibile verificare l’abbonamento Creator. Riprova quando la connessione è disponibile.',
        ),
      ),
    );

    for (final key in <String>[
      'kycProcessingMessage',
      'kycAdditionalStep',
      'kycCanceled',
      'kycStatus',
      'identityVerifiedAction',
      'identityProcessingAction',
      'identityContinueAction',
      'identityRetryAction',
    ]) {
      expect(
        RegExp("'$key'").allMatches(gate).length,
        greaterThanOrEqualTo(5),
        reason: '$key must be defined for 4 languages and used at runtime',
      );
    }

    for (final key in <String>[
      'creatorEntitlementUnavailable',
      'registryUploadInProgress',
      'registryUploadOk',
      'registryQueuedOffline',
      'genericError',
    ]) {
      expect(
        RegExp("'$key'").allMatches(copy).length,
        4,
        reason: '$key must exist for IT, EN, ES and RU',
      );
    }

    expect(text, contains("_t('registryUploadInProgress')"));
    expect(text, contains("_t('registryUploadOk')"));
    expect(text, contains("_t('registryQueuedOffline')"));
    expect(text, contains("_t('genericError')"));
    expect(
      text,
      isNot(contains('Uploading certificate to registry...')),
    );
    expect(
      text,
      isNot(
        contains(
          'Registry non disponibile: certificato conservato e accodato per il nuovo invio.',
        ),
      ),
    );

    expect(
      camera,
      contains("text: '\${_t('shareOfflinePack')}\\nHCV-ID: \${securedRecord.hcvId}'"),
    );
  });
}
