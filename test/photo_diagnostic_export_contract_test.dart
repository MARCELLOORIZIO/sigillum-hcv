import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PHOTO evidence is exported without changing legacy decision', () {
    final source = File('lib/screen_replay_diagnostics_page.dart').readAsStringSync();
    expect(source, contains("import 'hcv_photo_semantic_framing_inference.dart';"));
    expect(source, contains("if (!isVideo) {"));
    expect(source, contains('HCVPhotoSemanticFramingInference.instance.analyzePhoto(path)'));
    expect(source, contains("'photoSemanticFraming': data['photoSemanticFraming']"));
    expect(source, contains("_nestedValue('photoSemanticFraming', 'modelSha256')"));
    expect(source, contains("_nestedValue('photoSemanticFraming', 'confidence')"));
    expect(source, contains("_nestedValue('photoSemanticFraming', 'predictedClass')"));
    expect(source, contains('final data = _combine(staticData, mlData);'));
    expect(source, contains("'screenReplayRiskScore': score,"));
  });
}
