import 'dart:io';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'hcv_photo_semantic_framing_contract.dart';

/// Fail-closed experimental iPhone TFLite executor.
///
/// The asset must be independently parity-tested against TorchScript and
/// registered in pubspec.yaml before this executor may be enabled. Merely
/// finding a TFLite file does not make its predictions decision-grade.
class HCVPhotoSemanticFramingRunner {
  HCVPhotoSemanticFramingRunner._();
  static final instance = HCVPhotoSemanticFramingRunner._();

  static const assetPath = 'assets/ml/sigillum_photo_framing_v1.tflite';
  static const imageSize = 160;
  static const verifiedAssetSha256 =
      'fb66682d213e15f2418ab802c3d00af375b57646e94c50fd0d18a8c8422c567f';

  Interpreter? _interpreter;
  bool _parityVerified = false;

  Future<bool> initialize({required bool verifiedModelManifest}) async {
    if (!verifiedModelManifest) return false;
    if (_interpreter != null) return _parityVerified;
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(
          data.offsetInBytes, data.lengthInBytes);
      if (sha256.convert(bytes).toString() != verifiedAssetSha256) {
        return false;
      }
      final interpreter = Interpreter.fromBuffer(bytes);
      final inputs = interpreter.getInputTensors();
      final outputs = interpreter.getOutputTensors();
      if (inputs.length != 1 || outputs.length != 1 ||
          !_shapeEquals(inputs.single.shape, const [1, 3, 160, 160]) ||
          !_shapeEquals(outputs.single.shape, const [1, 3])) {
        interpreter.close();
        return false;
      }
      _interpreter = interpreter;
      _parityVerified = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> analyzePhoto(String path) async {
    if (!_parityVerified || _interpreter == null) {
      return HCVPhotoSemanticFramingContract.unavailable(
        'TFLITE_PARITY_NOT_VERIFIED_OR_NOT_INSTALLED',
      );
    }
    try {
      final bytes = await File(path).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) {
        return HCVPhotoSemanticFramingContract.unavailable('DECODE_FAILED');
      }
      // The conversion parity test must also validate this exact resizing
      // and RGB preprocessing against the Python reference (OpenCV AREA).
      final picture = img.copyResize(
        original, width: imageSize, height: imageSize,
        interpolation: img.Interpolation.average,
      );
      final channel = List.generate(
        3,
        (_) => List.generate(
          imageSize,
          (_) => List<double>.filled(imageSize, 0),
        ),
      );
      for (var y = 0; y < imageSize; y++) {
        for (var x = 0; x < imageSize; x++) {
          final pixel = picture.getPixel(x, y);
          channel[0][y][x] = pixel.r.toDouble() / 255.0;
          channel[1][y][x] = pixel.g.toDouble() / 255.0;
          channel[2][y][x] = pixel.b.toDouble() / 255.0;
        }
      }
      final out = <List<double>>[List.filled(3, 0.0)];
      _interpreter!.run([channel], out);
      return HCVPhotoSemanticFramingContract.diagnosticProbabilities(
        out.first, modelParityVerified: _parityVerified,
      );
    } catch (_) {
      return HCVPhotoSemanticFramingContract.unavailable(
        'TFLITE_INFERENCE_FAILED',
      );
    }
  }

  static bool _shapeEquals(List<int> found, List<int> expected) {
    if (found.length != expected.length) return false;
    for (var i = 0; i < found.length; i++) {
      if (found[i] != expected[i]) return false;
    }
    return true;
  }
}
