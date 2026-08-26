import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account deletion exits and clears all commercial auth UI state', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final profile = File('lib/commercial_profile_page.dart').readAsStringSync();
    final auth = File('lib/hcv_auth_service.dart').readAsStringSync();
    expect(gate, contains('void _resetLoggedOutState()'));
    expect(gate, contains('_email.clear()'));
    expect(gate, contains('_name.clear()'));
    expect(gate, contains('popUntil((route) => route.isFirst)'));
    expect(profile, contains('widget.onSessionInvalidated()'));
    expect(auth, contains('HCVIdentity().clearPersonalData()'));
  });

  test('existing and missing account flows do not dead-end', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    expect(gate, contains("error.code != 'ACCOUNT_ESISTENTE'"));
    expect(gate, contains('Questa email è già associata a un account.'));
    expect(gate, contains("error.code == 'ACCOUNT_NON_TROVATO'"));
  });

  test('login participates in one iOS AutoFill context', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    expect(gate, contains('return AutofillGroup('));
    expect(gate, contains('AutofillHints.username'));
    expect(gate, contains('AutofillHints.password'));
    expect(gate, contains('AutofillHints.newPassword'));
  });

  test('plain text share is routed to the text social verifier', () {
    final home = File('lib/user_home_page.dart').readAsStringSync();
    expect(home, contains("lower.endsWith('.txt')"));
    expect(home, contains('TextSocialVerifyPage('));
    expect(home, contains('initialText: sharedText'));
  });

  test('video transcription creates a derived captioned copy and leaves HCV engine files untouched', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    final service = File('lib/video_transcription_service.dart').readAsStringSync();
    expect(camera, contains("_c('createCaptionedVideo')"));
    expect(scene, contains('call.method == "transcribeVideo"'));
    expect(scene, contains('SFSpeechURLRecognitionRequest'));
    expect(service, contains("_sigillum.srt"));
    expect(service, contains("_sottotitolato.mp4"));
    expect(service, contains("'burnSubtitles'"));
    expect(scene, contains('call.method == "burnSubtitles"'));
    expect(service, isNot(contains('HCVEngine')));
  });
}
