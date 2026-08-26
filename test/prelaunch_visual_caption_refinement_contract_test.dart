import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'landing has one creator-registration entry and matching visual shell',
    () {
      final gate = File('lib/commercial_gate.dart').readAsStringSync();
      expect(gate, contains("title: _lv('loginTitle')"));
      expect(gate, contains("title: _lv('creatorTitle')"));
      expect(gate, isNot(contains("title: _lv('createTitle')")));
      expect(gate, contains('Color(0xFFEAFBFF)'));
      expect(gate, contains('BorderRadius.circular(30)'));
    },
  );

  test('verification hub exposes dedicated published-text verification', () {
    final page = File('lib/import_page.dart').readAsStringSync();
    expect(page, contains("VerificationUiCopy.t(widget.languageCode, key)"));
    expect(page, contains("_v('verifyText')"));
    expect(page, contains("_v('verifyPhoto')"));
    expect(page, contains("_v('verifyVideo')"));
  });

  test('camera status is white and proceed control is double height', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    expect(
      camera,
      contains('_parallaxRetryRequired ? Colors.redAccent : Colors.white'),
    );
    expect(camera, contains("status = _c('parallaxRequired')"));
    expect(camera, contains('minimumSize: const Size(0, 56)'));
  });

  test('captioned video is a derived synchronized copy', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final service =
        File('lib/video_transcription_service.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    expect(camera, contains("_c('shareCaptionedVideo')"));
    expect(camera, contains("_c('captionExplanation')"));
    expect(service, contains('captionedVideoPath'));
    expect(service, contains("'burnSubtitles'"));
    expect(scene, contains('call.method == "burnSubtitles"'));
    expect(scene, contains('AVVideoCompositionCoreAnimationTool'));
    expect(scene, contains('CATextLayer()'));
  });

  test('final refinement does not alter HCV engine contracts', () {
    final service =
        File('lib/video_transcription_service.dart').readAsStringSync();
    expect(service, isNot(contains('HCVEngine')));
    expect(service, isNot(contains('HCVDisplayRiskFusion')));
    expect(service, isNot(contains('setClaims(')));
  });
}
