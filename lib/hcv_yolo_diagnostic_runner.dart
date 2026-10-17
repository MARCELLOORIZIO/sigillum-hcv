import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'hcv_phone_device_v4_contract.dart';
import 'hcv_screen_detection_contract.dart';
import 'hcv_yolo_diagnostic_postprocessor.dart';

/// Opt-in experimental service, intentionally not wired to camera or PHOTO
/// decisions. Loads ONLY an explicitly supplied local model file.
class HCVYoloDiagnosticRunner {
  const HCVYoloDiagnosticRunner._();

  static Future<Map<String, Object?>> inspectImage({
    required String modelFilePath,
    required String imageFilePath,
    required bool useScreenDetection,
    double confidenceThreshold = 0.25,
  }) async {
    final names = useScreenDetection
        ? HCVScreenDetectionContract.classNames
        : const <String>['PHONE_DEVICE'];
    final inputShape = useScreenDetection
        ? HCVScreenDetectionContract.inputShape
        : HCVPhoneDeviceV4Contract.inputShape;
    final outputShape = useScreenDetection
        ? HCVScreenDetectionContract.outputShape
        : HCVPhoneDeviceV4Contract.outputShape;
    final expectedSha = useScreenDetection
        ? HCVScreenDetectionContract.expectedSha256
        : HCVPhoneDeviceV4Contract.modelSha256;

    Map<String, Object?> unavailable(String reason) => <String, Object?>{
          'type': 'SIGILLUM_YOLO_DIAGNOSTIC_EXPERIMENT',
          'analysisStatus': 'NOT_ANALYZED',
          'decisionRole': 'DIAGNOSTIC_ONLY',
          'reason': reason,
          'modelSha256Expected': expectedSha,
          'devicePresent': null,
          'displayRiskDecision': null,
          'physicalRecaptureProven': false,
        };

    Interpreter? interpreter;
    try {
      final modelFile = File(modelFilePath);
      final imageFile = File(imageFilePath);
      if (!await modelFile.exists()) return unavailable('MODEL_NOT_FOUND');
      if (!await imageFile.exists()) return unavailable('IMAGE_NOT_FOUND');
      final bytes = await modelFile.readAsBytes();
      if (sha256.convert(bytes).toString() != expectedSha) {
        return unavailable('MODEL_SHA256_MISMATCH');
      }
      final decoded = img.decodeImage(await imageFile.readAsBytes());
      if (decoded == null) return unavailable('IMAGE_DECODE_FAILED');
      interpreter = Interpreter.fromFile(modelFile);
      interpreter.allocateTensors();
      final actualInput = interpreter.getInputTensor(0);
      final actualOutput = interpreter.getOutputTensor(0);
      if (!_same(actualInput.shape, inputShape) ||
          !_same(actualOutput.shape, outputShape) ||
          actualInput.type != TensorType.float32 ||
          actualOutput.type != TensorType.float32) {
        return unavailable('TENSOR_CONTRACT_MISMATCH');
      }

      final side = inputShape[2];
      final oriented = img.bakeOrientation(decoded);
      final rawInput = _prepare(oriented, side);
      final channels = outputShape[1];
      final count = outputShape[2];
      // tflite_flutter's run API expects a nested Dart tensor matching shape.
      final input = <List<List<List<double>>>>[
        List.generate(3, (channel) =>
          List.generate(side, (y) =>
            List.generate(side, (x) => rawInput[(channel * side + y) * side + x])))
      ];
      final output = <List<List<double>>>[
        List.generate(channels, (_) => List<double>.filled(count, 0))
      ];
      interpreter.run(input, output);

      final detections = HCVYoloPostprocessor.decode(
        raw: output[0],
        classCount: names.length,
        modelSize: side,
        originalWidth: oriented.width,
        originalHeight: oriented.height,
        confidenceThreshold: confidenceThreshold,
      );
      return <String, Object?>{
        'type': 'SIGILLUM_YOLO_DIAGNOSTIC_EXPERIMENT',
        'analysisStatus': 'ANALYZED',
        'decisionRole': 'DIAGNOSTIC_ONLY',
        'modelSha256': expectedSha,
        'modelFamily': useScreenDetection ? 'SCREEN_DETECTION' : 'PHONE_DEVICE_V4',
        'devicePresent': detections.isNotEmpty,
        'detections': detections.map((d) => d.toDiagnosticMap(names)).toList(),
        'displayRiskDecision': null,
        'physicalRecaptureProven': false,
      };
    } catch (e) {
      return unavailable('INFERENCE_ERROR: ${e.runtimeType}');
    } finally {
      interpreter?.close();
    }
  }

  static bool _same(List<int> actual, List<int> expected) {
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }

  static Float32List _prepare(img.Image source, int side) {
    final scale = math.min(side / source.width, side / source.height);
    final w = math.max(1, (source.width * scale).round());
    final h = math.max(1, (source.height * scale).round());
    final resized = img.copyResize(source, width: w, height: h,
        interpolation: img.Interpolation.linear);
    final left = ((side - w) / 2 - 0.1).round();
    final top = ((side - h) / 2 - 0.1).round();
    final buffer = Float32List(3 * side * side);
    buffer.fillRange(0, buffer.length, 114 / 255);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final pixel = resized.getPixel(x, y);
        final pos = (top + y) * side + left + x;
        buffer[pos] = pixel.r / 255;
        buffer[side * side + pos] = pixel.g / 255;
        buffer[2 * side * side + pos] = pixel.b / 255;
      }
    }
    return buffer;
  }
}
