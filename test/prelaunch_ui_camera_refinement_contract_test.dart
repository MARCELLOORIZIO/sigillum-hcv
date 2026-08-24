import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('password recovery exposes a reactive reset action', () {
    final source = File('lib/commercial_gate.dart').readAsStringSync();
    expect(source, contains("'REIMPOSTA PASSWORD'"));
    expect(source, contains('onChanged: (_) => setState(() {})'));
    expect(source, contains('final updatedPassword = _newPassword.text;'));
    expect(source, contains('TextInput.finishAutofillContext(shouldSave: true)'));
  });

  test('camera UX is capped at 10x and video waits for explicit REC', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, contains('deviceMaxZoom.clamp(minZoom, 10.0)'));
    expect(source, contains('PRONTO — PREMI REGISTRA PER INIZIARE'));
    expect(source, contains('bool _videoArmed = false;'));

    final probe = source.indexOf(
      'pendingLiveScreenProbe = await _analyzeLiveScreenProbeWithoutFlash();',
    );
    final ready = source.indexOf('PRONTO — PREMI REGISTRA PER INIZIARE');
    final record = source.indexOf('await controller!.startVideoRecording();');
    expect(probe, greaterThanOrEqualTo(0));
    expect(ready, greaterThan(probe));
    expect(record, greaterThan(ready));
  });

  test('consumer theme enlarges primary CTAs and iOS domains are configured', () {
    final theme = File('lib/sigillum_theme.dart').readAsStringSync();
    final entitlements =
        File('ios/Runner/Runner.entitlements').readAsStringSync();

    expect(theme, contains('static const Color accentAlt'));
    expect(theme, contains('InputDecorationTheme('));
    expect(theme, contains('minimumSize: const Size.fromHeight(58)'));
    expect(
      theme,
      contains('padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)'),
    );
    expect(theme, contains('borderRadius: BorderRadius.circular(18)'));
    expect(theme, contains('DialogThemeData('));
    expect(entitlements, contains('webcredentials:sigillum-hcv.com'));
    expect(entitlements, contains('applinks:sigillum-hcv.com'));
  });
}
