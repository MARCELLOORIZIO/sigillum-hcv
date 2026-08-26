import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public scene label cannot override signed final display fusion', () {
    final registry = File('lib/registry_verify_page.dart').readAsStringSync();

    const guard =
        "if (displayRiskDecision != 'NO_DISPLAY_EVIDENCE') return false;";
    const realityLabel =
        "if (axis == 'scene' && _signedRealityScene) return _v('realityDetected');";
    const uncertainLabel =
        "if (axis == 'scene' && value.contains('conclusiva')) return _v('sceneUncertain');";
    const uncertainDetail =
        "if (_isDisplayNonConclusive) return _v('uncertainDetail');";

    expect(registry, contains(guard));
    expect(registry, contains(realityLabel));
    expect(registry, contains(uncertainLabel));
    expect(registry, contains(uncertainDetail));

    // The signed final-fusion guard must execute before inspecting the live
    // probe's geometry. This locks the HCV-6052 regression: live REALITY may be
    // shown as technical evidence, but the public scene verdict remains
    // NON_CONCLUSIVE when the final signed fusion says so.
    final guardPos = registry.indexOf(guard);
    final livePos = registry.indexOf("final live = claims is Map ? claims['liveScreenProbe'] : null;");
    expect(guardPos, greaterThanOrEqualTo(0));
    expect(livePos, greaterThan(guardPos));
  });
}
