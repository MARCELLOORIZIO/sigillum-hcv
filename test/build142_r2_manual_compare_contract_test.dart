import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual comparison reports subscription before reference availability',
      () {
    final publisher =
        File('lib/verified_originals_publish_service.dart').readAsStringSync();

    final start = publisher.indexOf(
      'Future<Map<String, dynamic>> entitledLiveReference(String hcvId)',
    );
    final end = publisher.indexOf(
      'Future<String> _ensureConsent(',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final method = publisher.substring(start, end);
    final entitledView = method.indexOf(
      r"'/api/verified-originals/$hcvId/view'",
    );
    final liveCheck = method.indexOf('verificationReference(hcvId)');

    expect(entitledView, greaterThanOrEqualTo(0));
    expect(liveCheck, greaterThan(entitledView));
    expect(
      method,
      contains(
        'subscription errors take\n    // precedence over reference availability',
      ),
    );
  });

  test('manual and Registry user copy no longer describes YouTube as reference',
      () {
    final copy = File('lib/registry_verify_copy.dart').readAsStringSync();
    final verifier = File('lib/registry_verify_page.dart').readAsStringSync();

    expect(copy.toLowerCase(), isNot(contains('youtube')));
    expect(
      copy,
      contains(
        'Il riferimento ufficiale SIGILLUM non è ancora disponibile. '
        'Se la registrazione è in corso, riprova tra poco.',
      ),
    );
    expect(
      copy,
      contains(
        'Questa funzione richiede un abbonamento SIGILLUM attivo.',
      ),
    );

    expect(
      verifier,
      contains(
        'il riferimento ufficiale SIGILLUM non è disponibile '
        'in questo momento.',
      ),
    );
    expect(
      verifier,
      isNot(
        contains(
          'il riferimento YouTube ufficiale non è verificabile '
          'in questo momento.',
        ),
      ),
    );
  });
}
