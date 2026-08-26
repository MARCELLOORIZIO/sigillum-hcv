import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public scene label cannot override signed final display fusion', () {
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();

    const signedRealityGetter =
        "  bool get _signedRealityScene {\n"
        "    if (displayRiskDecision != 'NO_DISPLAY_EVIDENCE') return false;\n"
        "    final cert = certificate;\n";
    const realityLabel =
        "if (axis == 'scene' && _signedRealityScene) return _v('realityDetected');";
    const uncertainLabel =
        "if (axis == 'scene' && value.contains('conclusiva')) return _v('sceneUncertain');";
    const uncertainDetail =
        "if (_isDisplayNonConclusive) return _v('uncertainDetail');";

    expect(registry, contains(signedRealityGetter));
    expect(registry, contains(realityLabel));
    expect(registry, contains(uncertainLabel));
    expect(registry, contains(uncertainDetail));

    // Lock the exact execution order inside _signedRealityScene: the signed
    // final display fusion is checked before any lower-level live geometry is
    // inspected. This is the HCV-6052 UI regression contract.
    final getterPos = registry.indexOf(signedRealityGetter);
    final livePos = registry.indexOf(
      "final live = claims is Map ? claims['liveScreenProbe'] : null;",
      getterPos,
    );
    expect(getterPos, greaterThanOrEqualTo(0));
    expect(livePos, greaterThan(getterPos));
  });
}
