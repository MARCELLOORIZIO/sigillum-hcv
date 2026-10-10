import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// An intentionally non-decisional IMAGE-ONLY framing diagnostic.
/// A rectangular edge may be a bezel, a painting, paper, a window or UI.
/// It MUST NOT establish physical scene reality or suppress an HFR verdict.
class HCVPhotoVisualFraming {
  const HCVPhotoVisualFraming._();

  static Future<Map<String, dynamic>> analyzeFile(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return _unavailable('DECODE_FAILED');
      return analyzeImage(image);
    } catch (_) {
      return _unavailable('IMAGE_UNAVAILABLE');
    }
  }

  static Map<String, dynamic> analyzeImage(img.Image image) {
    if (image.width < 96 || image.height < 96) {
      return _unavailable('IMAGE_TOO_SMALL');
    }
    final small = img.copyResize(
      image,
      width: image.width >= image.height ? 224 : null,
      height: image.height > image.width ? 224 : null,
      interpolation: img.Interpolation.average,
    );
    final w = small.width;
    final h = small.height;
    final lum = List<double>.filled(w * h, 0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = small.getPixel(x, y);
        lum[y * w + x] = 0.2126 * p.r.toDouble() +
            0.7152 * p.g.toDouble() + 0.0722 * p.b.toDouble();
      }
    }

    // Measure coherent vertical/horizontal boundaries at inset positions.
    // Ignore actual photo borders and screen UI lines shorter than 65%.
    final columns = <Map<String, dynamic>>[];
    final rows = <Map<String, dynamic>>[];
    for (var x = math.max(4, (w * .045).round());
        x < (w * .35).round();
        x += 2) {
      final left = _columnEdge(lum, w, h, x);
      final right = _columnEdge(lum, w, h, w - 1 - x);
      if (left >= .65) columns.add({'side': 'left', 'inset': x / w, 'coherence': left});
      if (right >= .65) columns.add({'side': 'right', 'inset': x / w, 'coherence': right});
    }
    for (var y = math.max(4, (h * .045).round());
        y < (h * .35).round();
        y += 2) {
      final top = _rowEdge(lum, w, h, y);
      final bottom = _rowEdge(lum, w, h, h - 1 - y);
      if (top >= .65) rows.add({'side': 'top', 'inset': y / h, 'coherence': top});
      if (bottom >= .65) rows.add({'side': 'bottom', 'inset': y / h, 'coherence': bottom});
    }
    final verticalSides = columns.map((x) => x['side']).toSet();
    final horizontalSides = rows.map((x) => x['side']).toSet();
    final possibleInsetRectangle =
        verticalSides.contains('left') &&
        verticalSides.contains('right') &&
        horizontalSides.contains('top') &&
        horizontalSides.contains('bottom');
    return <String, dynamic>{
      'type': 'SIGILLUM_PHOTO_VISUAL_FRAMING_DIAGNOSTIC_V1',
      'analysisStatus': 'ANALYZED',
      'decisionRole': 'DIAGNOSTIC_ONLY',
      'sceneFraming': 'UNKNOWN',
      'possibleInsetRectangle': possibleInsetRectangle,
      'verticalBoundaryCandidates': columns.length,
      'horizontalBoundaryCandidates': rows.length,
      'reason': possibleInsetRectangle
          ? 'RECTANGULAR_EDGES_NOT_UNIQUE_TO_SCREEN_BEZEL'
          : 'NO_UNAMBIGUOUS_VISUAL_FRAMING_EVIDENCE',
    };
  }

  static double _columnEdge(List<double> lum, int w, int h, int x) {
    var valid = 0;
    var total = 0;
    for (var y = (h * .12).round(); y < (h * .88).round(); y += 2) {
      total++;
      final a = lum[y * w + x - 2];
      final b = lum[y * w + x + 2];
      if ((a - b).abs() >= 25) valid++;
    }
    return total == 0 ? 0 : valid / total;
  }

  static double _rowEdge(List<double> lum, int w, int h, int y) {
    var valid = 0;
    var total = 0;
    for (var x = (w * .12).round(); x < (w * .88).round(); x += 2) {
      total++;
      final a = lum[(y - 2) * w + x];
      final b = lum[(y + 2) * w + x];
      if ((a - b).abs() >= 25) valid++;
    }
    return total == 0 ? 0 : valid / total;
  }

  static Map<String, dynamic> _unavailable(String reason) => {
    'type': 'SIGILLUM_PHOTO_VISUAL_FRAMING_DIAGNOSTIC_V1',
    'analysisStatus': 'NOT_ANALYZED',
    'decisionRole': 'DIAGNOSTIC_ONLY',
    'sceneFraming': 'UNKNOWN',
    'reason': reason,
  };
}
