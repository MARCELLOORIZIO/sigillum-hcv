import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class HCVMLV3PhotoResidual {
  HCVMLV3PhotoResidual._();

  static final HCVMLV3PhotoResidual instance = HCVMLV3PhotoResidual._();

  static const assetPath =
      'assets/ml/sigillum_screen_replay_v3_multihead.tflite';
  static const imageSize = 96;
  static const v2HighThreshold = 0.80;
  static const realityVetoThreshold = 0.25;

  static const classes = <String>[
    'SCREEN_MONITOR',
    'SCREEN_PHONE',
    'SCREEN_TABLET',
    'REALITY_PAPER',
    'REALITY_ROOM',
    'REALITY_OBJECT',
    'REALITY_OUTDOOR',
  ];

  Interpreter? _interpreter;
  String? _modelSha256;
  String? _loadError;

  static bool shouldVetoStrongV2({
    required double v2ScreenProbability,
    required double v3CleanScreenProbability,
    required double v3HardScreenProbability,
  }) {
    final maxV3 = v3CleanScreenProbability > v3HardScreenProbability
        ? v3CleanScreenProbability
        : v3HardScreenProbability;
    return v2ScreenProbability >= v2HighThreshold &&
        maxV3 < realityVetoThreshold;
  }

  Future<Map<String, dynamic>> analyzePhoto(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return _notAnalyzed('V3_IMAGE_NOT_FOUND');
    }

    try {
      final decoded = img.decodeImage(await file.readAsBytes());
      if (decoded == null) {
        return _notAnalyzed('V3_IMAGE_DECODE_FAILED');
      }

      await _ensureLoaded();
      final interpreter = _interpreter;
      if (interpreter == null) {
        return _notAnalyzed('V3_MODEL_NOT_LOADED');
      }

      final inputImage = _letterbox(decoded);
      final input = _imageToInput(inputImage);
      final output0 = [List<double>.filled(classes.length, 0.0)];
      final output1 = [List<double>.filled(classes.length, 0.0)];

      interpreter.runForMultipleInputs(
        <Object>[input],
        <int, Object>{0: output0, 1: output1},
      );

      // The parity-verified converter fixes TFLite output order as:
      // output_0 = hard head, output_1 = clean head.
      final hard = output0.first;
      final clean = output1.first;
      final hardScreen = _screenProbability(hard);
      final cleanScreen = _screenProbability(clean);
      final maxScreen = hardScreen > cleanScreen ? hardScreen : cleanScreen;

      return <String, dynamic>{
        'type': 'SIGILLUM_V3_PHOTO_RESIDUAL_V1',
        'analysisStatus': 'ANALYZED',
        'model': 'sigillum_screen_replay_v3_multihead',
        'modelVersion': 'v3-multihead-photo-residual',
        'modelSha256': _modelSha256,
        'inputSize': imageSize,
        'outputOrder': const <String>['hard', 'clean'],
        'hardScreenProbability': _round(hardScreen),
        'cleanScreenProbability': _round(cleanScreen),
        'maxScreenProbability': _round(maxScreen),
        'hardPredictedClass': classes[_topIndex(hard)],
        'cleanPredictedClass': classes[_topIndex(clean)],
        'hardClassProbabilities': <String, double>{
          for (var i = 0; i < classes.length; i++) classes[i]: _round(hard[i]),
        },
        'cleanClassProbabilities': <String, double>{
          for (var i = 0; i < classes.length; i++) classes[i]: _round(clean[i]),
        },
        'policy': const <String, dynamic>{
          'role': 'PHOTO_V2_FALSE_POSITIVE_VETO_ONLY',
          'v2HighThreshold': v2HighThreshold,
          'v3RealityVetoThreshold': realityVetoThreshold,
          'cannotOverrideHfrDisplay': true,
          'cannotAffectVideo': true,
        },
      };
    } catch (e) {
      return _notAnalyzed('V3_ANALYSIS_ERROR', e);
    }
  }

  Map<String, dynamic> decorateV2PhotoAnalysis(
    Map<String, dynamic> v2,
    Map<String, dynamic>? v3,
  ) {
    final result = Map<String, dynamic>.from(v2);
    final signals = v2['signals'] is Map
        ? Map<String, dynamic>.from(v2['signals'] as Map)
        : <String, dynamic>{};

    var veto = false;
    if (v3 != null && v3['analysisStatus'] == 'ANALYZED') {
      final v2p = (v2['screenProbability'] as num?)?.toDouble();
      final clean = (v3['cleanScreenProbability'] as num?)?.toDouble();
      final hard = (v3['hardScreenProbability'] as num?)?.toDouble();
      if (v2p != null && clean != null && hard != null) {
        veto = shouldVetoStrongV2(
          v2ScreenProbability: v2p,
          v3CleanScreenProbability: clean,
          v3HardScreenProbability: hard,
        );
      }
    }

    signals['v3PhotoResidualAvailable'] =
        v3?['analysisStatus'] == 'ANALYZED';
    signals['v3RealityVeto'] = veto;
    signals['v3ResidualCannotOverrideHfrDisplay'] = true;
    result['signals'] = signals;
    result['v3PhotoResidualAnalysis'] = v3;
    result['v3RealityVeto'] = veto;
    result['v3ResidualPolicy'] = 'PHOTO_V2_FALSE_POSITIVE_VETO_ONLY';
    return result;
  }

  Future<void> _ensureLoaded() async {
    if (_interpreter != null) return;
    try {
      final asset = await rootBundle.load(assetPath);
      final bytes = asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      );
      _modelSha256 = sha256.convert(bytes).toString();
      _interpreter = Interpreter.fromBuffer(bytes);
      _loadError = null;
    } catch (e) {
      _loadError = e.toString();
      _interpreter = null;
      rethrow;
    }
  }

  img.Image _letterbox(img.Image source) {
    final oriented = img.bakeOrientation(source);
    final scale = imageSize /
        (oriented.width > oriented.height
            ? oriented.width
            : oriented.height);
    final width =
        (oriented.width * scale).round().clamp(1, imageSize).toInt();
    final height =
        (oriented.height * scale).round().clamp(1, imageSize).toInt();
    final resized = img.copyResize(
      oriented,
      width: width,
      height: height,
      interpolation: img.Interpolation.linear,
    );
    final canvas = img.Image(width: imageSize, height: imageSize);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
    img.compositeImage(
      canvas,
      resized,
      dstX: ((imageSize - width) / 2).floor(),
      dstY: ((imageSize - height) / 2).floor(),
    );
    return canvas;
  }

  List<List<List<List<double>>>> _imageToInput(img.Image image) {
    return <List<List<List<double>>>>[
      List<List<List<double>>>.generate(
        imageSize,
        (y) => List<List<double>>.generate(imageSize, (x) {
          final pixel = image.getPixel(x, y);
          return <double>[
            pixel.r.toDouble() / 255.0,
            pixel.g.toDouble() / 255.0,
            pixel.b.toDouble() / 255.0,
          ];
        }),
      ),
    ];
  }

  double _screenProbability(List<double> probabilities) =>
      probabilities.take(3).fold<double>(0.0, (a, b) => a + b);

  int _topIndex(List<double> values) {
    var index = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[index]) index = i;
    }
    return index;
  }

  double _round(double value) => double.parse(value.toStringAsFixed(6));

  Map<String, dynamic> _notAnalyzed(String reason, [Object? error]) {
    return <String, dynamic>{
      'type': 'SIGILLUM_V3_PHOTO_RESIDUAL_V1',
      'analysisStatus': 'NOT_ANALYZED',
      'reason': reason,
      'model': 'sigillum_screen_replay_v3_multihead',
      'modelVersion': 'v3-multihead-photo-residual',
      'modelSha256': _modelSha256,
      if (_loadError != null) 'modelLoadError': _loadError,
      if (error != null) 'error': error.toString(),
    };
  }
}
