import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FOTO and VIDEO use one uncropped preview at nominal 1x', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    final bodyStart = source.indexOf('body: Stack(');
    final resultOverlay = source.indexOf('if (result != null)', bodyStart);

    expect(bodyStart, greaterThanOrEqualTo(0));
    expect(resultOverlay, greaterThan(bodyStart));

    final preview = source.substring(bodyStart, resultOverlay);
    expect(preview, contains('if (ok)'));
    expect(
      RegExp(r'CameraPreview\(controller!\)').allMatches(preview).length,
      1,
    );
    expect(preview, contains('fit: BoxFit.contain'));
    expect(preview, isNot(contains('BoxFit.cover')));
    expect(preview, isNot(contains('OverflowBox(')));
    expect(preview, isNot(contains('if (ok && photoMode)')));
    expect(preview, isNot(contains('if (ok && !photoMode)')));
  });

  test('both modes preserve orientation and high capture preset', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(source, contains('OrientationBuilder('));
    expect(
      source,
      contains('final isPortrait = orientation == Orientation.portrait;'),
    );
    expect(
      source,
      contains('isPortrait ? previewSize.height : previewSize.width'),
    );
    expect(
      source,
      contains('isPortrait ? previewSize.width : previewSize.height'),
    );
    expect(source, contains('return ResolutionPreset.high;'));
    expect(source, contains('_resolutionPresetForMode(nextPhotoMode)'));
    expect(source, contains('await replacement.setZoomLevel(restoredZoom);'));
  });
}
