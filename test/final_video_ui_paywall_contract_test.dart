import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('final VIDEO / UI / premium comparison contracts', () {
    test('manual comparison uses the agreed visual-or-auditory wording', () {
      final copy = File('lib/registry_verify_copy.dart').readAsStringSync();

      expect(copy, contains("'manualCompareTitle': 'CONFRONTO MANUALE VISIVO O AUDITIVO'"));
      expect(copy, contains("'manualCompareAction': 'CONFRONTO VISIVO O AUDITIVO'"));
      expect(copy, contains("'manualCompareSubscribeAction': 'ATTIVA UN ABBONAMENTO'"));
      expect(
        copy,
        contains(
          'L’esito automatico è già disponibile. Il confronto manuale visivo o auditivo',
        ),
      );
    });

    test('manual comparison paywall returns to the comparison after purchase', () {
      final compare =
          File('lib/manual_reference_compare_page.dart').readAsStringSync();
      final gate = File('lib/commercial_gate.dart').readAsStringSync();

      expect(compare, contains('initialBillingMode: true'));
      expect(compare, contains('returnAfterSubscriptionActivation: true'));
      expect(compare, contains("billingStatus != 'active' && billingStatus != 'grace'"));
      expect(gate, contains('returnAfterSubscriptionActivation'));
      expect(gate, contains('Navigator.of(context).pop(true)'));
    });

    test('camera result actions share one size and hide stale cards while busy',
        () {
      final camera = File('lib/camera_page.dart').readAsStringSync();

      expect(camera, contains('Widget _resultActionButton({'));
      expect(camera, contains('width: 340'));
      expect(camera, contains('height: 64'));
      expect(camera, contains('_c(\'createCaptionedVideo\')'));
      expect(camera, contains('_t(\'shareOfflinePack\')'));
      expect(
        camera,
        contains(
          'if (_transcribingAudio || _subtitlePublishing || registryStatus == null)',
        ),
      );
      expect(
        camera,
        contains('if (_transcribingAudio || _subtitlePublishing) {'),
      );
    });

    test('protected originals clearly separate local file and R2 reference', () {
      final copy = File('lib/sigillum_localization.dart').readAsStringSync();
      final page = File('lib/secure_originals_page.dart').readAsStringSync();

      expect(copy, contains("'secureOriginalsDeviceSection': 'ORIGINALE SUL DISPOSITIVO'"));
      expect(copy, contains("'secureOriginalsReferenceSection': 'RIFERIMENTO PROTETTO SIGILLUM'"));
      expect(copy, contains("'secureOriginalsOfficialCopy': 'APRI RIFERIMENTO PROTETTO'"));
      expect(page, contains("_t('secureOriginalsDeviceSection')"));
      expect(page, contains("_t('secureOriginalsReferenceSection')"));
    });

    test('possible screen recapture is amber; strong risk is separately named',
        () {
      final copy = File('lib/verification_ui_copy.dart').readAsStringSync();
      final page = File('lib/registry_verify_page.dart').readAsStringSync();

      expect(copy, contains("'sceneUncertain': 'Possibile ripresa da schermo'"));
      expect(copy, contains("'screenRisk': 'Forte rischio di ripresa da schermo'"));
      expect(page, contains('_isDisplayNonConclusive'));
      expect(page, contains('? Colors.orange'));
      expect(page, contains('_isStrongDisplayRisk'));
      expect(page, contains('? Colors.red'));
    });
  });
}
