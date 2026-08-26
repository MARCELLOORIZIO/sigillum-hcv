import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recent account selector stores emails only and never passwords', () {
    final service = File('lib/recent_account_service.dart').readAsStringSync();
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    expect(service, contains('sigillum.recent.creator.emails.v1'));
    expect(service, isNot(contains('password')));
    expect(gate, contains('Account usati su questo iPhone'));
    expect(gate, contains('AutofillHints.username'));
    expect(gate, contains('AutofillHints.password'));
  });

  test('quick guide explains Files archive and derived subtitles', () {
    final guide = File('lib/sigillum_quick_guide_page.dart').readAsStringSync();
    expect(guide, contains('File > Sul mio iPhone > Fotocamera Sigillum'));
    expect(guide, contains('L’originale certificato non viene modificato'));
  });

  test('subtitle actions remain readable and save captioned copy to Photos', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final copy = File('lib/camera_ui_extended_copy.dart').readAsStringSync();
    expect(camera, contains("_c('saveCaptionedPhotos')"));
    expect(copy, contains("'saveCaptionedPhotos': 'SALVA VIDEO SOTTOTITOLATO IN FOTO'"));
    expect(camera, contains('minimumSize: const Size.fromHeight(64)'));
    expect(camera, contains("_c('captionedSavedPhotos')"));
    expect(copy, contains("'captionedSavedPhotos': 'Video sottotitolato salvato in Foto'"));
    expect(camera, contains("_c('filesPath')"));
    expect(copy, contains("'filesPath': 'File > Sul mio iPhone > Fotocamera Sigillum'"));
  });

  test('speech uses app language and keeps most complete cumulative result', () {
    final service = File('lib/video_transcription_service.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    expect(service, contains("'languageCode': languageCode"));
    expect(scene, contains('speechLocaleIdentifier'));
    expect(scene, contains('request.shouldReportPartialResults = true'));
    expect(scene, contains('bestCoverage'));
    expect(scene, contains('request.taskHint = .dictation'));
  });

  test('usability changes do not alter HCV engine or detector contracts', () {
    final service = File('lib/video_transcription_service.dart').readAsStringSync();
    final guide = File('lib/sigillum_quick_guide_page.dart').readAsStringSync();
    expect(service, isNot(contains('HCVEngine')));
    expect(service, isNot(contains('HCVDisplayRiskFusion')));
    expect(guide, isNot(contains('HCVDisplayRiskFusion')));
  });
}
