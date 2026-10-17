import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_iphone/hcv_yolo_diagnostic_postprocessor.dart';

void main() {
  test('decodes center xywh and suppresses same-class duplicate', () {
    final result = HCVYoloPostprocessor.decode(
      raw: [
        [208, 210], [208, 210], [104, 104], [104, 104],
        [0.95, 0.8],
      ],
      classCount: 1, modelSize: 416, originalWidth: 416,
      originalHeight: 416,
    );
    expect(result.length, 1);
    expect(result.single.classId, 0);
    expect(result.single.left, closeTo(156, 0.001));
    expect(result.single.top, closeTo(156, 0.001));
    expect(result.single.right, closeTo(260, 0.001));
  });

  test('maps coordinates back from letterboxed image', () {
    // 800x400 -> 416x208, centered vertically with 104px top padding.
    final result = HCVYoloPostprocessor.decode(
      raw: [[208], [208], [104], [104], [0.9]],
      classCount: 1, modelSize: 416, originalWidth: 800,
      originalHeight: 400,
    );
    expect(result.length, 1);
    expect(result.single.left, closeTo(300, 0.001));
    expect(result.single.top, closeTo(100, 0.001));
    expect(result.single.right, closeTo(500, 0.001));
    expect(result.single.bottom, closeTo(300, 0.001));
  });

  test('keeps distinct classes even with overlapping boxes', () {
    final result = HCVYoloPostprocessor.decode(
      raw: [
        [304, 304], [304, 304], [120, 120], [120, 120],
        [0.9, 0.1], [0.1, 0.92],
      ],
      classCount: 2, modelSize: 608, originalWidth: 608,
      originalHeight: 608,
    );
    expect(result.length, 2);
    expect(result.map((e) => e.classId).toSet(), {0, 1});
  });

  test('invalid dimensions rejected and non-finite scores ignored', () {
    expect(() => HCVYoloPostprocessor.decode(
      raw: [[0], [0], [5]], classCount: 1, modelSize: 416,
      originalWidth: 416, originalHeight: 416,
    ), throwsArgumentError);
    final result = HCVYoloPostprocessor.decode(
      raw: [[208], [208], [104], [104], [double.nan]],
      classCount: 1, modelSize: 416, originalWidth: 416,
      originalHeight: 416,
    );
    expect(result, isEmpty);
  });

  test('diagnostics do not contain authenticity verdicts', () {
    final result = HCVYoloPostprocessor.decode(
      raw: [[208], [208], [104], [104], [0.9]],
      classCount: 1, modelSize: 416, originalWidth: 416,
      originalHeight: 416,
    );
    final fields = result.single.toDiagnosticMap(['PHONE_DEVICE']);
    expect(fields['class'], 'PHONE_DEVICE');
    expect(fields.containsKey('displayRiskDecision'), isFalse);
  });
}
