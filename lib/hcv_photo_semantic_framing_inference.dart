import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'hcv_photo_semantic_framing_contract.dart';

/// Experimental on-device PHOTO framing inference.
/// This class cannot issue a red/green risk decision; it only records evidence.
/// The checksum must match the trained model that passed TorchScript parity.
class HCVPhotoSemanticFramingInference {
  HCVPhotoSemanticFramingInference._();
  static final instance = HCVPhotoSemanticFramingInference._();

  static const assetPath = 'assets/ml/sigillum_photo_framing_v1.tflite';
  static const imageSize = 160;

  // Set only after the model is built and the TFLite/checkpoint parity gate
  // passes. An empty checksum forces a non-decisional NOT_ANALYZED result.
  static const parityApprovedSha256 = 'fb66682d213e15f2418ab802c3d00af375b57646e94c50fd0d18a8c8422c567f';

  Interpreter? _interpreter;
  String? _modelSha256;

  Future<Map<String, dynamic>> analyzePhoto(String path) async {
    if (parityApprovedSha256.isEmpty) {
      return HCVPhotoSemanticFramingContract.unavailable(
        'MOBILE_FRAMING_PARITY_NOT_APPROVED',
      );
    }
    try {
      final source = img.decodeImage(await File(path).readAsBytes());
      if (source == null) {
        return HCVPhotoSemanticFramingContract.unavailable(
          'PHOTO_FRAMING_DECODE_FAILED',
        );
      }
      await _ensureLoaded();
      final interpreter = _interpreter;
      if (interpreter == null) {
        return HCVPhotoSemanticFramingContract.unavailable(
          'PHOTO_FRAMING_MODEL_UNAVAILABLE',
        );
      }
      final resized = img.copyResize(
        img.bakeOrientation(source),
        width: imageSize,
        height: imageSize,
        interpolation: img.Interpolation.average,
      );
      // Explicit [N,C,H,W]: model input is NCHW, not the NHWC layout
      // used by the earlier SIGILLUM V2/V3 TFLite models.
      final input = <List<List<List<double>>>>[
        List<List<List<double>>>.generate(
          3,
          (c) => List<List<double>>.generate(
            imageSize,
            (y) => List<double>.generate(imageSize, (x) {
              final pixel = resized.getPixel(x, y);
              final v = c == 0 ? pixel.r : (c == 1 ? pixel.g : pixel.b);
              return v.toDouble() / 255.0;
            }),
          ),
        ),
      ];
      final output = <List<double>>[List<double>.filled(3, 0.0)];
      interpreter.run(input, output);
      return <String, dynamic>{
        ...HCVPhotoSemanticFramingContract.diagnosticProbabilities(
          output.first,
          modelParityVerified: true,
        ),
        'modelSha256': _modelSha256,
        'preprocess': 'RGB_NCHW_160_FLOAT32_AVERAGE_RESIZE',
        'preprocessParity': 'NOT_YET_INDEPENDENTLY_VERIFIED_ON_IOS',
      };
    } catch (e) {
      return <String, dynamic>{
        ...HCVPhotoSemanticFramingContract.unavailable(
          'PHOTO_SEMANTIC_MODEL_EXECUTION_ERROR',
        ),
        'error': e.toString(),
      };
    }
  }

  Future<void> _ensureLoaded() async {
    if (_interpreter != null) return;
    final bytes = await rootBundle.load(assetPath);
    final data = bytes.buffer.asUint8List(
      bytes.offsetInBytes, bytes.lengthInBytes,
    );
    final hash = sha256.convert(data).toString();
    if (hash != parityApprovedSha256) {
      throw StateError('Unverified PHOTO semantic framing model checksum');
    }
    _modelSha256 = hash;
    _interpreter = Interpreter.fromBuffer(data);
    final inputShape = _interpreter!.getInputTensor(0).shape;
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    if (inputShape.join(',') != '1,3,160,160' ||
        outputShape.join(',') != '1,3') {
      _interpreter!.close();
      _interpreter = null;
      throw StateError('PHOTO semantic framing model tensor layout mismatch');
    }
  }
}
