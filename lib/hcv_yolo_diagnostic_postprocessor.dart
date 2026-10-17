import 'dart:math' as math;

/// Experimental YOLOv8 raw-head postprocessor. Diagnostic output only.
///
/// Expected model output [1, 4 + classCount, candidates], *not* NMS output.
/// xywh coordinates are in letterboxed model-input pixels, subject to
/// reference-validation against both exported model binaries.
class HCVYoloDetection {
  const HCVYoloDetection(this.classId, this.confidence, this.left, this.top,
      this.right, this.bottom);
  final int classId;
  final double confidence;
  final double left, top, right, bottom;

  Map<String, Object> toDiagnosticMap(List<String> classes) => {
        'class': classes[classId],
        'confidence': confidence,
        'boxXYXY': [left, top, right, bottom],
      };
}

class HCVYoloPostprocessor {
  const HCVYoloPostprocessor._();

  /// [raw] is channel-major: four coordinates then per-class probabilities.
  /// The result is in ORIGINAL image pixels, not normalized coordinates.
  static List<HCVYoloDetection> decode({
    required List<List<double>> raw,
    required int classCount,
    required int modelSize,
    required int originalWidth,
    required int originalHeight,
    double confidenceThreshold = 0.25,
    double iouThreshold = 0.7,
    int maxDetections = 100,
  }) {
    if (classCount < 1 || modelSize < 1 ||
        originalWidth < 1 || originalHeight < 1 ||
        confidenceThreshold < 0 || confidenceThreshold > 1 ||
        iouThreshold < 0 || iouThreshold > 1 || maxDetections < 1) {
      throw ArgumentError('Invalid YOLO configuration');
    }
    if (raw.length != 4 + classCount || raw.isEmpty) {
      throw ArgumentError('Incompatible YOLO channel count');
    }
    final candidates = raw[0].length;
    if (candidates < 1 || raw.any((v) => v.length != candidates)) {
      throw ArgumentError('Incompatible YOLO candidate dimensions');
    }

    // Ultralytics letterbox geometry: integer resized dimensions and center pad.
    final scale = math.min(modelSize / originalWidth, modelSize / originalHeight);
    final resizedWidth = (originalWidth * scale).round();
    final resizedHeight = (originalHeight * scale).round();
    // Ultralytics LetterBox(center=true) uses half-padding minus 0.1
    // for the left/top integer border; simple round() differs by one pixel
    // for odd padding and misaligns decoded boxes.
    final padLeft = ((modelSize - resizedWidth) / 2 - 0.1).round();
    final padTop = ((modelSize - resizedHeight) / 2 - 0.1).round();
    final results = <HCVYoloDetection>[];

    for (var i = 0; i < candidates; i++) {
      final x = raw[0][i], y = raw[1][i];
      final w = raw[2][i], h = raw[3][i];
      if (![x, y, w, h].every((n) => n.isFinite) || w <= 0 || h <= 0) {
        continue;
      }
      var bestClass = -1;
      var bestScore = confidenceThreshold;
      for (var c = 0; c < classCount; c++) {
        final score = raw[4 + c][i];
        if (score.isFinite && score >= bestScore &&
            (bestClass == -1 || score > bestScore)) {
          bestClass = c;
          bestScore = score;
        }
      }
      if (bestClass < 0) continue;
      final left = ((x - w / 2 - padLeft) / scale).clamp(0.0, originalWidth.toDouble());
      final top = ((y - h / 2 - padTop) / scale).clamp(0.0, originalHeight.toDouble());
      final right = ((x + w / 2 - padLeft) / scale).clamp(0.0, originalWidth.toDouble());
      final bottom = ((y + h / 2 - padTop) / scale).clamp(0.0, originalHeight.toDouble());
      if (right <= left || bottom <= top) continue;
      results.add(HCVYoloDetection(bestClass, bestScore, left, top, right, bottom));
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    final retained = <HCVYoloDetection>[];
    for (final candidate in results) {
      if (retained.every((other) => other.classId != candidate.classId ||
          _iou(other, candidate) <= iouThreshold)) {
        retained.add(candidate);
        if (retained.length >= maxDetections) break;
      }
    }
    return retained;
  }

  static double _iou(HCVYoloDetection a, HCVYoloDetection b) {
    final width = math.max(0.0, math.min(a.right, b.right) - math.max(a.left, b.left));
    final height = math.max(0.0, math.min(a.bottom, b.bottom) - math.max(a.top, b.top));
    final intersection = width * height;
    final areaA = (a.right - a.left) * (a.bottom - a.top);
    final areaB = (b.right - b.left) * (b.bottom - b.top);
    final union = areaA + areaB - intersection;
    return union > 0 ? intersection / union : 0;
  }
}
