import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monitor display evidence is never erased by geometry reality', () {
    final scene = File('lib/hcv_scene_decision_fusion.dart').readAsStringSync();
    final fusion = File('lib/hcv_display_risk_fusion.dart').readAsStringSync();

    expect(
      scene,
      contains("ILLUMINATION_AND_GEOMETRY_EVIDENCE_CONFLICT"),
    );
    expect(scene, contains('final displayEvidence = rawDisplayEvidence;'));
    expect(fusion, contains("ACTIVE_DISPLAY_GEOMETRY_CONFLICT"));
  });

  test('HCVPACK final naming cannot delete a package when paths coincide', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();

    expect(
      camera,
      contains('p.normalize(currentFile.absolute.path)'),
    );
    expect(camera, contains('p.normalize(newFile.absolute.path)'));
    expect(
      camera,
      contains('HCVPACK source disappeared before final naming'),
    );
  });

  test('iOS original photo picker completes after dismissal and is reusable', () {
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    final import = File('lib/import_page.dart').readAsStringSync();

    expect(
      scene,
      contains('private func takePendingOriginalPhotoResult() -> FlutterResult?'),
    );
    expect(scene, contains('let flutterResult = pendingOriginalPhotoResult'));
    expect(scene, contains('pendingOriginalPhotoResult = nil'));
    expect(
      scene,
      contains('guard let flutterResult = takePendingOriginalPhotoResult() else {'),
    );
    expect(scene, contains('picker.dismiss(animated: true) { [weak self] in'));
    expect(
      scene,
      contains('self.resolveOriginalPhotoSelection(results, result: flutterResult)'),
    );
    expect(scene, contains('if let staleResult = pendingOriginalPhotoResult {'));
    expect(scene, contains('code: "PHOTO_PICK_STALE_RESET"'));
    expect(import, contains('bool _photoPickBusy = false;'));
    expect(import, contains('if (_photoPickBusy) return;'));
    expect(import, contains('setState(() => _photoPickBusy = false)'));
  });
}
