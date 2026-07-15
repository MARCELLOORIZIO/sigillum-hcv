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

import 'hcv_ml_model_store.dart';

class HCVMLScreenReplayClassifier {
  HCVMLScreenReplayClassifier._();

  static final HCVMLScreenReplayClassifier instance =
      HCVMLScreenReplayClassifier._();

  static const _imageSize = 224;

  Interpreter? _interpreter;
  List<String>? _classes;
  String _modelSource = 'UNKNOWN';
  String? _modelLoadError;

  void resetLoadedModel() {
    try {
      _interpreter?.close();
    } catch (_) {}
    _interpreter = null;
    _classes = null;
    _modelSource = 'UNKNOWN';
    _modelLoadError = null;
  }

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
      final framePattern = p.join(workDir.path, 'frame_%03d.jpg');
      final command = "-y -i '$videoPath' "
          "-vf \"scale=720:720:force_original_aspect_ratio=decrease,"
          "pad=720:720:(ow-iw)/2:(oh-ih)/2,"
          "fps=1/3\" "
          "-frames:v 8 "
          "'$framePattern'";

      final session = await FFmpegKit.execute(command);
      final code = await session.getReturnCode();
      if (code == null || !ReturnCode.isSuccess(code)) {
        return _unknown('FRAME_EXTRACTION_FAILED');
      }

      final frames = workDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.jpg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      if (frames.isEmpty) {
        return _unknown('NOT_ENOUGH_VIDEO_FRAMES');
      }

      final analyses = <Map<String, dynamic>>[];
      for (var i = 0; i < frames.length; i++) {
        final analysis = await analyzeImage(frames[i].path);
        analysis['videoFrameIndex'] = i;
        analysis['approxVideoSecond'] = i * 3;
        analyses.add(analysis);
      }

      analyses.sort((a, b) {
        final bScore = (b['screenReplayRiskScore'] as num?)?.toInt() ?? -1;
        final aScore = (a['screenReplayRiskScore'] as num?)?.toInt() ?? -1;
        return bScore.compareTo(aScore);
      });

      final worst = Map<String, dynamic>.from(analyses.first);
      final scores = analyses
          .map((item) => (item['screenReplayRiskScore'] as num?)?.toInt())
          .whereType<int>()
          .toList();
      final maxScore = scores.isEmpty ? null : scores.reduce(max);
      final averageScore = scores.isEmpty
          ? null
          : scores.reduce((a, b) => a + b) / scores.length;
      final strongFrameCount = scores.where((score) => score >= 92).length;
      final mediumFrameCount = scores.where((score) => score >= 88).length;
      final finalScore = _persistentVideoRiskScore(
        maxScore: maxScore,
        averageScore: averageScore,
        strongFrameCount: strongFrameCount,
        mediumFrameCount: mediumFrameCount,
      );

      worst['scanMode'] = 'VIDEO_MULTI_FRAME_ML_CLASSIFIER';
      worst['framesAnalyzed'] = analyses.length;
      worst['screenReplayRiskScore'] = finalScore;
      worst['screenReplayRisk'] =
          finalScore == null ? 'UNKNOWN' : _riskLabel(finalScore);
      worst['videoFrameSecond'] = worst['approxVideoSecond'];
      worst['maxFrameScreenReplayRiskScore'] = maxScore;
      worst['strongScreenFrameCount'] = strongFrameCount;
      worst['mediumScreenFrameCount'] = mediumFrameCount;
      worst['displayRiskDecision'] = _displayRiskDecision(
        finalScore: finalScore,
        maxScore: maxScore,
        strongFrameCount: strongFrameCount,
        mediumFrameCount: mediumFrameCount,
      );
      worst['averageScreenReplayRiskScore'] =
          averageScore == null ? null : _round(averageScore);
      worst['videoFrameAnalyses'] = analyses.take(12).toList();
      return worst;
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
        return _unknown('MODEL_NOT_LOADED', _modelLoadError);
      }

      var result = _runImageAnalysis(interpreter, classes, decoded);
      final cropped = _runImageAnalysis(
        interpreter,
        classes,
        _cropTop(decoded, 0.24),
      );
      final fullScore = result.riskScore;
      final croppedScore = cropped.riskScore;
      final overlayCorrected = fullScore >= 70 && croppedScore <= 55;
      if (overlayCorrected) {
        result = cropped;
      }

      return {
        'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
        'model': 'sigillum_screen_replay',
        'modelSource': _modelSource,
        'scanMode': 'STILL_IMAGE_ML_CLASSIFIER',
        'analysisStatus': 'ANALYZED',
        'framesAnalyzed': 1,
        'screenReplayRisk': _riskLabel(result.riskScore),
        'screenReplayRiskScore': result.riskScore,
        'screenProbability': _round(result.screenProbability),
        'predictedClass': classes[result.topIndex],
        'predictedClassConfidence':
            _round(result.probabilities[result.topIndex]),
        'classProbabilities': {
          for (var i = 0; i < classes.length; i++)
            classes[i]: _round(result.probabilities[i]),
        },
        'signals': {
          'mlScreenClass': classes[result.topIndex].startsWith('SCREEN_'),
          'mlScreenProbabilityHigh': result.screenProbability >= 0.85,
          'mlScreenProbabilityMedium': result.screenProbability >= 0.70,
          'sigillumOverlayCorrected': overlayCorrected,
          'fullFrameRiskScore': fullScore,
          'contentAreaRiskScore': croppedScore,
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

    final bundle = await HCVMLModelStore.instance.loadCurrentBundle();
    try {
      _loadBundle(bundle);
      return;
    } catch (e) {
      _modelLoadError = '${bundle.source}: $e';
      resetLoadedModel();
      _modelLoadError = '${bundle.source}: $e';
    }

    if (bundle.source == 'BUNDLED_ASSET_MODEL') {
      throw Exception(_modelLoadError);
    }

    try {
      final fallback = await HCVMLModelStore.instance.loadBundledBundle();
      _loadBundle(fallback);
    } catch (e) {
      _modelLoadError = '${_modelLoadError ?? ''}; BUNDLED_ASSET_MODEL: $e';
      resetLoadedModel();
      _modelLoadError = '${bundle.source}: unable to load local model; '
          'BUNDLED_ASSET_MODEL: $e';
      throw Exception(_modelLoadError);
    }
  }

  void _loadBundle(HCVMLModelBundle bundle) {
    _interpreter = Interpreter.fromFile(bundle.modelFile);
    _classes = bundle.labels;
    _modelSource = bundle.source;
    _modelLoadError = null;
  }

  int? _persistentVideoRiskScore({
    required int? maxScore,
    required double? averageScore,
    required int strongFrameCount,
    required int mediumFrameCount,
  }) {
    if (maxScore == null) return null;

    if (strongFrameCount >= 2) return maxScore;
    if (mediumFrameCount >= 3 && averageScore != null && averageScore >= 88) {
      return min(maxScore, 91);
    }

    if (maxScore >= 88) return 54;
    return maxScore;
  }

  String _displayRiskDecision({
    required int? finalScore,
    required int? maxScore,
    required int strongFrameCount,
    required int mediumFrameCount,
  }) {
    if (finalScore == null) return 'NOT_ANALYZED';
    if (finalScore >= 88) return 'STRONG_DISPLAY_RISK';
    if ((maxScore ?? 0) >= 88 ||
        strongFrameCount == 1 ||
        mediumFrameCount > 0) {
      return 'NON_CONCLUSIVE';
    }
    return 'NO_DISPLAY_EVIDENCE';
  }

  _MLImageResult _runImageAnalysis(
    Interpreter interpreter,
    List<String> classes,
    img.Image image,
  ) {
    final inputImage = _letterbox(image);
    final input = _imageToInput(inputImage);
    final output = [List<double>.filled(classes.length, 0.0)];

    interpreter.run(input, output);

    final probabilities = output.first;
    final screenProbability = _screenProbability(classes, probabilities);
    final topIndex = _topIndex(probabilities);
    final riskScore = (screenProbability * 100).round().clamp(0, 100).toInt();
    return _MLImageResult(
      probabilities: probabilities,
      screenProbability: screenProbability,
      topIndex: topIndex,
      riskScore: riskScore,
    );
  }

  img.Image _cropTop(img.Image source, double fraction) {
    final oriented = img.bakeOrientation(source);
    final maxTop = max(0, oriented.height - 1);
    final top =
        min(max((oriented.height * fraction).round(), 0), maxTop).toInt();
    return img.copyCrop(
      oriented,
      x: 0,
      y: top,
      width: oriented.width,
      height: oriented.height - top,
    );
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
    final Map<String, dynamic> data = {
      'type': 'SIGILLUM_SCREEN_REPLAY_ML_ANALYSIS_V1',
      'screenReplayRisk': 'UNKNOWN',
      'screenReplayRiskScore': null,
      'reason': reason,
      'analysisStatus': 'NOT_ANALYZED',
      'modelSource': _modelSource,
    };
    if (error != null) {
      data['error'] = error.toString();
    }
    return data;
  }

  String _riskLabel(int riskScore) {
    return riskScore >= 92
        ? 'HIGH'
        : riskScore >= 88
            ? 'MEDIUM'
            : 'LOW';
  }

  double _round(double value) => double.parse(value.toStringAsFixed(4));
}

class _MLImageResult {
  const _MLImageResult({
    required this.probabilities,
    required this.screenProbability,
    required this.topIndex,
    required this.riskScore,
  });

  final List<double> probabilities;
  final double screenProbability;
  final int topIndex;
  final int riskScore;
}
