import 'dart:math';

import 'package:image/image.dart' as img;

/// Signed, spatially localized colour/luminance fingerprint for new
/// PHOTO/VIDEO certificates. V1 aHash is retained separately for retrieval
/// and legacy comparison; V2 is required for a strong derived-media verdict.
///
/// Tile values are computed on a 64x64 average-resized RGB image. A 4x4
/// non-overlapping grid records mean R/G/B per tile. This preserves an
/// approximate location for significant overlays and tonal edits that
/// a global 16x16 grayscale aHash cannot distinguish.
class HCVSpatialFingerprintV2 {
  const HCVSpatialFingerprintV2._();

  static const String algorithm = 'SIGILLUM_SPATIAL_RGB_TILES_V2';
  static const int grid = 4;
  static const int samplesPerSide = 64;
  static const int _tileSize = samplesPerSide ~/ grid;

  /// Conservative provisional bounds; require calibration against the full
  /// frozen social/edited corpus before launch. Samples in archives 84/89
  /// and 82 demonstrate genuine re-encodes with tile differences near 0–2,
  /// versus large local X / grayscale / +/-30% brightness edits.
  static const double maxMeanLumaDifference = 6.0;
  static const double maxSingleTileLumaDifference = 18.0;
  static const double maxMeanChromaDifference = 8.0;
  static const double maxMeanRgbDifference = 8.0;

  static Map<String, dynamic> build(img.Image source) {
    final resized = img.copyResize(
      source,
      width: samplesPerSide,
      height: samplesPerSide,
      interpolation: img.Interpolation.average,
    );
    final tiles = <int>[];
    for (var ty = 0; ty < grid; ty++) {
      for (var tx = 0; tx < grid; tx++) {
        var red = 0.0;
        var green = 0.0;
        var blue = 0.0;
        for (var y = ty * _tileSize; y < (ty + 1) * _tileSize; y++) {
          for (var x = tx * _tileSize; x < (tx + 1) * _tileSize; x++) {
            final pixel = resized.getPixel(x, y);
            red += pixel.r.toDouble();
            green += pixel.g.toDouble();
            blue += pixel.b.toDouble();
          }
        }
        const pixels = _tileSize * _tileSize;
        tiles
          ..add((red / pixels).round().clamp(0, 255).toInt())
          ..add((green / pixels).round().clamp(0, 255).toInt())
          ..add((blue / pixels).round().clamp(0, 255).toInt());
      }
    }
    return <String, dynamic>{
      'algorithm': algorithm,
      'grid': grid,
      'tiles': tiles,
    };
  }

  static bool isValid(Object? raw) {
    if (raw is! Map) return false;
    if (raw['algorithm'] != algorithm || raw['grid'] != grid) return false;
    final tiles = raw['tiles'];
    return tiles is List &&
        tiles.length == grid * grid * 3 &&
        tiles.every((value) => value is int && value >= 0 && value <= 255);
  }

  static bool matches(Object? expected, Object? actual) {
    if (!isValid(expected) || !isValid(actual)) return false;
    final a = (expected as Map)['tiles'] as List;
    final b = (actual as Map)['tiles'] as List;
    var totalLuma = 0.0;
    var maximumLuma = 0.0;
    var totalChroma = 0.0;
    var totalRgb = 0.0;

    for (var i = 0; i < grid * grid; i++) {
      final at = <double>[
        (a[i * 3] as int).toDouble(),
        (a[i * 3 + 1] as int).toDouble(),
        (a[i * 3 + 2] as int).toDouble(),
      ];
      final bt = <double>[
        (b[i * 3] as int).toDouble(),
        (b[i * 3 + 1] as int).toDouble(),
        (b[i * 3 + 2] as int).toDouble(),
      ];
      double luma(List<double> rgb) =>
          0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
      double chroma(List<double> rgb) => rgb.reduce(max) - rgb.reduce(min);

      final lumaDifference = (luma(at) - luma(bt)).abs();
      totalLuma += lumaDifference;
      maximumLuma = max(maximumLuma, lumaDifference);
      totalChroma += (chroma(at) - chroma(bt)).abs();
      for (var j = 0; j < 3; j++) {
        totalRgb += (at[j] - bt[j]).abs();
      }
    }
    const tiles = grid * grid;
    return totalLuma / tiles <= maxMeanLumaDifference &&
        maximumLuma <= maxSingleTileLumaDifference &&
        totalChroma / tiles <= maxMeanChromaDifference &&
        totalRgb / (tiles * 3) <= maxMeanRgbDifference;
  }
}
