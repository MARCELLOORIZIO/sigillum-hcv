import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual comparison is visual or auditory and links to subscription plans', () {
    final manual =
        File('lib/manual_reference_compare_page.dart').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final copy = File('lib/registry_verify_copy.dart').readAsStringSync();

    expect(
      copy,
      contains("'manualCompareTitle': 'CONFRONTO MANUALE VISIVO O AUDITIVO'"),
    );
    expect(
      copy,
      contains(
        "'manualCompareSubscribeAction': 'ATTIVA UN ABBONAMENTO'",
      ),
    );
    expect(
      copy,
      contains(
        'L’esito automatico è già disponibile. Il confronto manuale visivo o auditivo',
      ),
    );
    expect(
      manual,
      contains('CommercialGate(initialBillingMode: true)'),
    );
    expect(manual, contains("manualCompareSubscribeAction"));
    expect(manual, contains('await _load();'));
    expect(gate, contains('this.initialBillingMode = false'));
    expect(gate, contains('if (widget.initialBillingMode && mounted)'));
    expect(gate, contains('navigator.pop(true)'));

    // The existing three commercial products are intentionally preserved.
    final billing =
        File('lib/commercial_billing_service.dart').readAsStringSync();
    expect(billing, contains('sigillum_creator_weekly'));
    expect(billing, contains('sigillum_creator_monthly'));
    expect(billing, contains('sigillum_creator_annual'));
  });

  test('protected originals distinguish device original from R2 reference', () {
    final page = File('lib/secure_originals_page.dart').readAsStringSync();
    final copy = File('lib/sigillum_localization.dart').readAsStringSync();

    expect(
      copy,
      contains("'secureOriginalsDeviceSection': 'ORIGINALE SUL DISPOSITIVO'"),
    );
    expect(
      copy,
      contains(
        "'secureOriginalsReferenceSection': 'RIFERIMENTO PROTETTO SIGILLUM'",
      ),
    );
    expect(
      copy,
      contains(
        "'secureOriginalsOfficialCopy': 'APRI RIFERIMENTO PROTETTO'",
      ),
    );
    expect(page, contains("secureOriginalsDeviceSection"));
    expect(page, contains("secureOriginalsReferenceSection"));
    expect(page, contains('height: 56'));
    expect(
      page,
      contains('_publisher.materializeEntitledReference(record.hcvId)'),
    );
    expect(
      page,
      contains("materializeOriginal(refreshed, purpose: 'save')"),
    );
  });

  test('camera result actions use one stable size and opaque loading panel', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(camera, contains('ButtonStyle _resultActionButtonStyle()'));
    expect(camera, contains('width: 340'));
    expect(camera, contains('height: 64'));
    expect(camera, contains('color: Colors.black,'));
    expect(camera, contains('CircularProgressIndicator(strokeWidth: 2.2)'));

    final actionStart = camera.indexOf('  Widget _actionButtons() {');
    final actionEnd = camera.indexOf('\n  Widget _zoomButton(', actionStart);
    expect(actionStart, greaterThanOrEqualTo(0));
    expect(actionEnd, greaterThan(actionStart));
    final actions = camera.substring(actionStart, actionEnd);
    expect(actions, isNot(contains('width: 300')));
  });

  test('uncertain screen wording is amber semantics, strong wording is explicit', () {
    final page = File('lib/registry_verify_page.dart').readAsStringSync();
    final copy = File('lib/verification_ui_copy.dart').readAsStringSync();

    expect(
      copy,
      contains("'sceneUncertain': 'Possibile ripresa da schermo'"),
    );
    expect(
      copy,
      contains("'screenRisk': 'Forte rischio di ripresa da schermo'"),
    );
    expect(
      copy,
      contains(
        "'originalScene': 'Valutazione della scena al momento della certificazione'",
      ),
    );
    expect(page, contains('_isDisplayNonConclusive'));
    expect(page, contains('? Colors.orange'));
    expect(page, contains('_isStrongDisplayRisk'));
    expect(page, contains('? Colors.red'));
    expect(
      page,
      contains(
        'Piu segnali tecnici concordanti indicano un forte rischio di ripresa da schermo.',
      ),
    );
  });

  test('VIDEO initial-scene metadata and opening-preservation contract are present', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final visual =
        File('lib/hcv_reference_visual_fingerprint_v3.dart').readAsStringSync();
    final policy =
        File('lib/hcv_multi_evidence_display_policy.dart').readAsStringSync();

    expect(
      camera,
      contains('"type": "SIGILLUM_VIDEO_INITIAL_SCENE_POLICY_V1"'),
    );
    expect(camera, contains('"decisionWindowSeconds": 6'));
    expect(
      camera,
      contains('"laterVideoDisplayObservations": "DIAGNOSTIC_ONLY"'),
    );
    expect(camera, contains('"initialSegmentPreservationRequired": true'));

    expect(visual, contains('static const int initialAnchorFrames = 4'));
    expect(visual, contains('_maxConformingFrameCountDelta = 1'));
    expect(
      visual,
      contains('removes the opening segment must never become CONFORMING'),
    );
    expect(policy, contains('maxDecisionSecond: 6.0'));
    expect(policy, contains('_videoHfrPartialRealityConflict'));
  });
}
