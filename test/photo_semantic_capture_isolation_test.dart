import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PHOTO semantic inference is captured once and stored once', () {
    final source = File('lib/camera_page.dart').readAsStringSync();
    expect(RegExp(r'final semanticFramingDiagnostic\s*=').allMatches(source).length, 1);
    expect(RegExp(r'"photoSemanticFramingDiagnostic"\s*:').allMatches(source).length, 1);
    expect(source.contains('HCVPhotoSemanticFramingInference.instance.analyzePhoto(savedPhotoPath)'), isTrue);
  });

  test('PHOTO model has fixed provenance and can only diagnose framing', () {
    final source = File('lib/hcv_photo_semantic_framing_inference.dart').readAsStringSync();
    final contract = File('lib/hcv_photo_semantic_framing_contract.dart').readAsStringSync();
    final policy = File('lib/hcv_multi_evidence_display_policy.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(source.contains('fb66682d213e15f2418ab802c3d00af375b57646e94c50fd0d18a8c8422c567f'), isTrue);
    expect(source.contains("preprocessParity"), isTrue);
    expect(contract.contains("'decisionRole': 'DIAGNOSTIC_ONLY'"), isTrue);
    expect(contract.contains("'sceneFraming': 'UNKNOWN'"), isTrue);
    expect(policy.contains('photoSemanticFramingDiagnostic'), isFalse);
    expect(pubspec.contains('assets/ml/sigillum_photo_framing_v1.tflite'), isTrue);
  });
}
