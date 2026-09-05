import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter camera explicitly rearms autofocus after native HFR handoff', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    final start =
        source.indexOf('  Future<Map<String, dynamic>> _captureTemporalFrequencyNativeIsolated()');
    final end = source.indexOf('  Future<void> _settleCameraAfterLiveProbe()', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final handoff = source.substring(start, end);

    final initialized = handoff.indexOf('await replacement.initialize();');
    final zoom = handoff.indexOf('await replacement.setZoomLevel(restoredZoom);');
    final focusMode = handoff.indexOf('await replacement.setFocusMode(FocusMode.auto);', zoom + 1);
    final focusPoint = handoff.indexOf('await replacement.setFocusPoint(null);', focusMode + 1);
    final exposureMode = handoff.indexOf(
      'await replacement.setExposureMode(ExposureMode.auto);',
      focusPoint + 1,
    );
    final exposurePoint = handoff.indexOf('await replacement.setExposurePoint(null);', exposureMode + 1);
    final settle = handoff.indexOf(
      'await Future.delayed(const Duration(milliseconds: 650));',
      exposurePoint + 1,
    );

    expect(initialized, greaterThanOrEqualTo(0));
    expect(zoom, greaterThan(initialized));
    expect(focusMode, greaterThan(zoom));
    expect(focusPoint, greaterThan(focusMode));
    expect(exposureMode, greaterThan(focusPoint));
    expect(exposurePoint, greaterThan(exposureMode));
    expect(settle, greaterThan(exposurePoint));
  });
}
