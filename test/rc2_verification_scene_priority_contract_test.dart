import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public scene label cannot override signed final display fusion', () {
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();
    final finalizer = File(
      'tool/apply_rc2_verification_scene_priority_finalizer_20260826.py',
    ).readAsStringSync();

    const baseRealityGetter =
        "  bool get _signedRealityScene {\n"
        "    final cert = certificate;\n";
    const signedRealityGetter =
        "  bool get _signedRealityScene {\n"
        "    if (displayRiskDecision != 'NO_DISPLAY_EVIDENCE') return false;\n"
        "    final cert = certificate;\n";
    const finalFusionGuard =
        "if (displayRiskDecision != 'NO_DISPLAY_EVIDENCE') return false;";
    const realityLabel =
        "if (axis == 'scene' && _signedRealityScene) return _v('realityDetected');";
    const uncertainDetail =
        "if (_isDisplayNonConclusive) return _v('uncertainDetail');";
    const liveProbeRead =
        "final live = claims is Map ? claims['liveScreenProbe'] : null;";

    // This test runs both before and after the release finalizer. Before
    // finalization the localized Registry helper legitimately has the base
    // getter; the release finalizer must define the exact fail-closed
    // transformation. After finalization the guarded getter must be present.
    expect(
      registry.contains(baseRealityGetter) || registry.contains(signedRealityGetter),
      isTrue,
    );
    expect(registry, contains(realityLabel));
    expect(registry, contains(uncertainDetail));

    expect(finalizer, contains(baseRealityGetter));
    expect(finalizer, contains(signedRealityGetter));
    expect(finalizer, contains(finalFusionGuard));

    if (registry.contains(signedRealityGetter)) {
      final getterPos = registry.indexOf(signedRealityGetter);
      final guardPos = registry.indexOf(finalFusionGuard, getterPos);
      final livePos = registry.indexOf(liveProbeRead, getterPos);
      expect(getterPos, greaterThanOrEqualTo(0));
      expect(guardPos, greaterThanOrEqualTo(getterPos));
      expect(livePos, greaterThan(guardPos));
    } else {
      final getterPos = registry.indexOf(baseRealityGetter);
      final livePos = registry.indexOf(liveProbeRead, getterPos);
      expect(getterPos, greaterThanOrEqualTo(0));
      expect(livePos, greaterThan(getterPos));
    }
  });
}
