import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class HCVMLScreenReplayClassifier {
  HCVMLScreenReplayClassifier._();

  static final HCVMLScreenReplayClassifier instance =
      HCVMLScreenReplayClassifier._();

  static const _modelPath = 'assets/ml/sigillum_screen_replay_v1.tflite';
  static const _labelsPath = 'assets/ml/sigillum_screen_replay_v1_labels.json';
  static const _imageSize = 224;

  Interpreter? _interpreter;
  List<String>? _classes;

  Future<Map<String, dynamic>> analyzeVideo(String videoPath) async {
    final file = File(videoPath);
    if (!await file.exists()) {
      return _unknown('VIDEO_NOT_FOUND');
    }

    final tempDir = await getTemporaryDirectory();
    final workDir = Directory(
      p.join(
        tempDir.path,
        'hcv_ml_screen_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );

    try {
      await workDir.create(recursive: true);
      final framePath = p.join(workDir.path, 'frame.jpg');
      final command = "-y -ss 0 -i '$videoPath' "
          "-frames:v 1 "
          "-vf \"scale=720:720:force_original_aspect_ratio=decrease,"
          "pad=720:720:(ow-iw)/2:(oh-ih)/2\" "
          "'$framePath'";

      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();
      if (code == null || !ReturnCode.isSuccess(code)) {
        return _unknown('FRAME_EXTRACTION_FAILED');
      }

      final analysis = await analyzeImage(framePath);
      analysis['scanMode'] = 'VIDEO_FRAME_ML_CLASSIFIER';
      analysis['videoFrameSecond'] = 0;
      return analysis;
    } catch (e) {
      return _unknown('VIDEO_ML_ANALYSIS_ERROR', e);
    } finally {
      try {
        if (await workDir.exists()) {
          await workDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> analyzeImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return _unknown('IMAGE_NOT_FOUND');
    }

    try {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) {
        return _unknown('IMAGE_DECODE_FAILED');
      }

      await _ensureLoaded();
      final interpreter = _interpreter;
      final classes = _classes;
      if (interpreter == null || classes == null || classes.isEmpty) {
        return _unknown('MODEL_NOT_LOADED');
      }

      final inputImage = _letterbox(decoded);
      final input = _imageToInput(inputImage);
      final output = [List<double>.filled(classes.length, 0.0)];

      interpreter.run(input, output);

      final probabilities = output.first;
      final screenProbability = _screenProbability(classes, probabilities);
      final topIndex = _topIndex(probabilities);
      final riskScore = (screenProbability * 100).round().clamp(0, 100).toInt();

      return {
        'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
        'model': 'sigillum_screen_replay_v1',
        'scanMode': 'STILL_IMAGE_ML_CLASSIFIER',
        'framesAnalyzed': 1,
        'screenReplayRisk': _riskLabel(riskScore),
        'screenReplayRiskScore': riskScore,
        'screenProbability': _round(screenProbability),
        'predictedClass': classes[topIndex],
        'predictedClassConfidence': _round(probabilities[topIndex]),
        'classProbabilities': {
          for (var i = 0; i < classes.length; i++)
            classes[i]: _round(probabilities[i]),
        },
        'signals': {
          'mlScreenClass': classes[topIndex].startsWith('SCREEN_'),
          'mlScreenProbabilityHigh': screenProbability >= 0.60,
          'mlScreenProbabilityMedium': screenProbability >= 0.35,
        },
        'note':
            'Local ML screen replay classifier trained from Sigillum calibration samples. It supports the signal but is not absolute proof.',
      };
    } catch (e) {
      return _unknown('ML_ANALYSIS_ERROR', e);
    }
  }

  Future<void> _ensureLoaded() async {
    if (_interpreter != null && _classes != null) return;

    _interpreter = await Interpreter.fromAsset(_modelPath);
    final rawLabels = await rootBundle.loadString(_labelsPath);
    final decoded = jsonDecode(rawLabels);
    final classes = decoded is Map ? decoded['classes'] : null;
    if (classes is List) {
      _classes = classes.map((value) => value.toString()).toList();
    } else {
      _classes = const [];
    }
  }

  img.Image _letterbox(img.Image source) {
    final oriented = img.bakeOrientation(source);
    final scale = min(
      _imageSize / oriented.width,
      _imageSize / oriented.height,
    );
    final width = max(1, (oriented.width * scale).round());
    final height = max(1, (oriented.height * scale).round());
    final resized = img.copyResize(
      oriented,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
    final canvas = img.Image(width: _imageSize, height: _imageSize);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
    img.compositeImage(
      canvas,
      resized,
      dstX: ((_imageSize - width) / 2).floor(),
      dstY: ((_imageSize - height) / 2).floor(),
    );
    return canvas;
  }

  List<List<List<List<double>>>> _imageToInput(img.Image image) {
    return [
      List.generate(
        _imageSize,
        (y) => List.generate(
          _imageSize,
          (x) {
            final pixel = image.getPixel(x, y);
            return [
              pixel.r.toDouble(),
              pixel.g.toDouble(),
              pixel.b.toDouble(),
            ];
          },
        ),
      ),
    ];
  }

  double _screenProbability(List<String> classes, List<double> probabilities) {
    var score = 0.0;
    for (var i = 0; i < classes.length && i < probabilities.length; i++) {
      if (classes[i].startsWith('SCREEN_')) {
        score += probabilities[i];
      }
    }
    return score.clamp(0.0, 1.0).toDouble();
  }

  int _topIndex(List<double> values) {
    var index = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[index]) {
        index = i;
      }
    }
    return index;
  }

  Map<String, dynamic> _unknown(String reason, [Object? error]) {
    final data = {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'screenReplayRisk': 'UNKNOWN',
      'screenReplayRiskScore': null,
      'reason': reason,
    };
    if (error != null) {
      data['error'] = error.toString();
    }
    return data;
  }

  String _riskLabel(int riskScore) {
    return riskScore >= 60
        ? 'HIGH'
        : riskScore >= 35
            ? 'MEDIUM'
            : 'LOW';
  }

  double _round(double value) => double.parse(value.toStringAsFixed(4));
}
