import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HCVTemporalFrequencyClip {
  const HCVTemporalFrequencyClip({
    required this.path,
    required this.captureDurationMs,
    required this.requestedTargetFps,
    required this.configuredState,
    required this.shortExposureState,
  });

  final String path;
  final int captureDurationMs;
  final double requestedTargetFps;
  final Map<String, dynamic> configuredState;
  final Map<String, dynamic> shortExposureState;
}

/// Shadow-only physical probe for display refresh / PWM periodicity.
///
/// This probe is intentionally never supplied to production display fusion.
/// It captures consecutive frames at the highest iOS camera frame rate that
/// can be configured up to [targetMaxFps], with a short shutter, then measures
/// periodic row-profile changes and frame-to-frame luminance modulation.
class HCVTemporalFrequencyProbe {
  const HCVTemporalFrequencyProbe();

  static const MethodChannel _channel = MethodChannel('hcv.cameraProbe');
  static const Duration defaultCaptureDuration = Duration(milliseconds: 650);
  static const double targetMaxFps = 240.0;
  static const double requestedShortExposureSeconds = 1.0 / 1000.0;
  static const int maximumExtractedFrames = 180;
  static const int rowProfileBins = 96;

  Future<HCVTemporalFrequencyClip> capture(
    CameraController controller, {
    Duration duration = defaultCaptureDuration,
  }) async {
    if (!Platform.isIOS) throw StateError('IOS_ONLY');
    if (!controller.value.isInitialized) throw StateError('CAMERA_NOT_READY');
    if (controller.value.isStreamingImages) {
      throw StateError('IMAGE_STREAM_ACTIVE');
    }
    if (controller.value.isRecordingVideo) {
      throw StateError('CAMERA_ALREADY_RECORDING');
    }

    final uniqueId = controller.description.name;
    final originalFlash = controller.value.flashMode;
    Map<String, dynamic>? originalState;
    Map<String, dynamic>? configuredState;
    Map<String, dynamic>? shortExposureState;
    String? temporaryVideoPath;
    var recordingStarted = false;
    final stopwatch = Stopwatch();

    try {
      originalState = await _invokeMap('snapshotCameraState', {
        'deviceUniqueId': uniqueId,
      });
      if (originalState == null) throw StateError('CAMERA_STATE_UNAVAILABLE');

      await controller.setFlashMode(FlashMode.off);
      // Session-safety hotfix: never mutate AVCaptureDevice.activeFormat or
      // active frame durations behind Flutter camera's active AVCaptureSession.
      // BUILD 87 crashed on both PHOTO and VIDEO because the plugin controller
      // retained outputs configured for its original format while the native
      // bridge changed the device format underneath it.
      configuredState = Map<String, dynamic>.from(originalState);
      configuredState['configurationMode'] =
          'PLUGIN_ACTIVE_FORMAT_PRESERVED_SESSION_SAFE';
      configuredState['requestedTargetMaxFps'] = targetMaxFps;
      configuredState['configuredFrameRate'] = null;
      configuredState['highFpsFormatMutationSkipped'] = true;

      // Keep only the previously validated physical intervention: short shutter.
      // The actual encoded cadence is measured from the disposable clip rather
      // than forcing a new device format/frame duration while Flutter owns it.
      shortExposureState = await _invokeMap('applyShortExposure', {
        'deviceUniqueId': uniqueId,
        'targetDurationSeconds': requestedShortExposureSeconds,
      });
      if (shortExposureState == null) {
        throw StateError('SHORT_EXPOSURE_UNAVAILABLE');
      }
      await Future.delayed(const Duration(milliseconds: 70));

      stopwatch.start();
      await controller.startVideoRecording();
      recordingStarted = true;
      await Future.delayed(duration);
      final captured = await controller.stopVideoRecording();
      recordingStarted = false;
      stopwatch.stop();
      temporaryVideoPath = captured.path;

      return HCVTemporalFrequencyClip(
        path: temporaryVideoPath,
        captureDurationMs: stopwatch.elapsedMilliseconds,
        requestedTargetFps: targetMaxFps,
        configuredState: configuredState,
        shortExposureState: shortExposureState,
      );
    } catch (_) {
      if (recordingStarted && controller.value.isRecordingVideo) {
        try {
          final captured = await controller.stopVideoRecording();
          temporaryVideoPath ??= captured.path;
        } catch (_) {}
      }
      if (temporaryVideoPath != null) await discard(temporaryVideoPath);
      rethrow;
    } finally {
      if (originalState != null) {
        try {
          // Do not allow restoreCameraState to reassign activeFormat or frame
          // durations either. Only exposure/focus/WB/zoom state is restored.
          final sessionSafeRestoreState =
              Map<String, dynamic>.from(originalState)
                ..remove('activeFormatIndex')
                ..remove('activeVideoMinFrameDurationSeconds')
                ..remove('activeVideoMaxFrameDurationSeconds');
          await _channel.invokeMethod<void>('restoreCameraState', {
            'deviceUniqueId': uniqueId,
            'state': sessionSafeRestoreState,
          });
        } catch (_) {}
      }
      try {
        await controller.setFlashMode(originalFlash);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 220));
    }
  }

  Future<Map<String, dynamic>> analyzeCapturedClip(
    HCVTemporalFrequencyClip clip,
  ) async {
    var path = clip.path;
    final root = Directory(
      p.join(
        (await getTemporaryDirectory()).path,
        'hcv_temporal_frequency_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );

    try {
      if (!await File(path).exists()) {
        return unavailable('TEMPORAL_FREQUENCY_VIDEO_NOT_FOUND');
      }
      await root.create(recursive: true);
      final frameFiles = await _extractConsecutiveFrames(path, root);
      if (frameFiles.length < 6) {
        return {
          ...unavailable('NOT_ENOUGH_CONSECUTIVE_FRAMES'),
          'framesExtracted': frameFiles.length,
          'configuredState': clip.configuredState,
          'shortExposureState': clip.shortExposureState,
        };
      }

      final cellSequences = List.generate(
        9,
        (_) => <List<double>>[],
        growable: false,
      );
      final frameLuma = <double>[];
      int? frameWidth;
      int? frameHeight;
      var framesDecoded = 0;

      for (final file in frameFiles) {
        final decoded = img.decodeImage(await file.readAsBytes());
        if (decoded == null) continue;
        frameWidth ??= decoded.width;
        frameHeight ??= decoded.height;
        final perCell = _rowProfiles(decoded);
        if (perCell.length != 9) continue;
        for (var cell = 0; cell < 9; cell++) {
          cellSequences[cell].add(perCell[cell]);
        }
        final allValues = perCell.expand((values) => values).toList();
        frameLuma.add(_mean(allValues));
        framesDecoded++;
      }

      if (framesDecoded < 6) {
        return unavailable('NOT_ENOUGH_DECODED_FRAMES');
      }

      final cellResults = <Map<String, dynamic>>[];
      for (var cell = 0; cell < 9; cell++) {
        final result = HCVTemporalFrequencyMath.analyzeRowProfileSequence(
          cellSequences[cell],
        );
        cellResults.add({
          'row': cell ~/ 3,
          'column': cell % 3,
          ...result,
        });
      }

      final durationSeconds = max(0.001, clip.captureDurationMs / 1000.0);
      final approximateEncodedFps = framesDecoded / durationSeconds;
      final configuredFps =
          (clip.configuredState['configuredFrameRate'] as num?)?.toDouble();
      final temporalLuma =
          HCVTemporalFrequencyMath.analyzeScalarSequence(frameLuma);

      final periodicityStrengths = cellResults
          .map((e) => (e['periodicityStrength'] as num?)?.toDouble())
          .whereType<double>()
          .toList()
        ..sort();
      final frequencyStabilities = cellResults
          .map((e) => (e['dominantFrequencyStability'] as num?)?.toDouble())
          .whereType<double>()
          .toList()
        ..sort();
      final phaseConsistencies = cellResults
          .map((e) => (e['phaseStepConsistency'] as num?)?.toDouble())
          .whereType<double>()
          .toList()
        ..sort();

      final deleted = await discard(path);
      if (deleted) path = '';

      return {
        'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V1',
        'analysisStatus': 'ANALYZED',
        'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
        'productionDecisionChanged': false,
        'captureSource': 'DISPOSABLE_HIGH_FPS_SHORT_SHUTTER_PRE_CAPTURE',
        'captureDurationMs': clip.captureDurationMs,
        'requestedTargetFps': clip.requestedTargetFps,
        'configuredFrameRate': configuredFps,
        'approximateEncodedFrameRate': approximateEncodedFps,
        'configuredHighSpeedFormatWidth':
            clip.configuredState['activeFormatWidth'],
        'configuredHighSpeedFormatHeight':
            clip.configuredState['activeFormatHeight'],
        'configuredFormatMaxSupportedFrameRate':
            clip.configuredState['activeFormatMaxSupportedFrameRate'],
        'requestedShortExposureSeconds': requestedShortExposureSeconds,
        'actualShortExposureSeconds':
            clip.shortExposureState['exposureDurationSeconds'],
        'shortExposureISO': clip.shortExposureState['iso'],
        'shortExposureISOClamped':
            clip.shortExposureState['isoCompensationClamped'] == true,
        'framesExtracted': frameFiles.length,
        'framesAnalyzed': framesDecoded,
        'frameWidth': frameWidth,
        'frameHeight': frameHeight,
        'consecutiveFrameExtraction': true,
        'ffmpegFrameResamplingApplied': false,
        'globalFrameLumaTemporalSpectrum': temporalLuma,
        'cellResults': cellResults,
        'minimumCellPeriodicityStrength':
            periodicityStrengths.isEmpty ? null : periodicityStrengths.first,
        'medianCellPeriodicityStrength': _median(periodicityStrengths),
        'minimumCellFrequencyStability':
            frequencyStabilities.isEmpty ? null : frequencyStabilities.first,
        'medianCellFrequencyStability': _median(frequencyStabilities),
        'minimumCellPhaseStepConsistency':
            phaseConsistencies.isEmpty ? null : phaseConsistencies.first,
        'medianCellPhaseStepConsistency': _median(phaseConsistencies),
        'spatialPolicy': const {
          'gridRows': 3,
          'gridColumns': 3,
          'requiredCoverageCellsForFutureDisplayDecision': 9,
          'allowedRealityEscapeCellsForFutureDisplayDecision': 0,
          'decisionEnabled': false,
        },
        'temporaryVideoDeletedAfterAnalysis': deleted,
        'note':
            'Measures periodic row-profile phase changes and full-frame luminance modulation from native consecutive encoded frames. No score from this probe participates in BUILD 80 display fusion.',
      };
    } catch (error) {
      return {
        ...unavailable('TEMPORAL_FREQUENCY_ANALYSIS_FAILED'),
        'error': error.toString(),
        'configuredState': clip.configuredState,
        'shortExposureState': clip.shortExposureState,
      };
    } finally {
      if (path.isNotEmpty) await discard(path);
      try {
        if (await root.exists()) await root.delete(recursive: true);
      } catch (_) {}
    }
  }

  static Map<String, dynamic> unavailable(
    String reason, {
    Object? error,
  }) {
    return {
      'type': 'SIGILLUM_TEMPORAL_FREQUENCY_PROBE_V1',
      'analysisStatus': 'NOT_ANALYZED',
      'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',
      'productionDecisionChanged': false,
      'reason': reason,
      if (error != null) 'error': error.toString(),
    };
  }

  Future<List<File>> _extractConsecutiveFrames(
    String videoPath,
    Directory root,
  ) async {
    final pattern = p.join(root.path, 'frame_%04d.png');
    final command =
        "-y -i ${_quote(videoPath)} -an -vsync 0 -frames:v $maximumExtractedFrames ${_quote(pattern)}";
    final session = await FFmpegKit.execute(command);
    final code = await session.getReturnCode();
    if (code == null || !ReturnCode.isSuccess(code)) return <File>[];
    final files = root
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  List<List<double>> _rowProfiles(img.Image image) {
    final result = <List<double>>[];
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        final x0 = (image.width * column / 3).floor();
        final x1 = (image.width * (column + 1) / 3).floor();
        final y0 = (image.height * row / 3).floor();
        final y1 = (image.height * (row + 1) / 3).floor();
        final profile = <double>[];
        final xStep = max(1, (x1 - x0) ~/ 64);
        for (var bin = 0; bin < rowProfileBins; bin++) {
          final by0 = y0 + ((y1 - y0) * bin / rowProfileBins).floor();
          final by1 = max(
            by0 + 1,
            y0 + ((y1 - y0) * (bin + 1) / rowProfileBins).floor(),
          );
          var sum = 0.0;
          var count = 0;
          for (var y = by0; y < min(y1, by1); y++) {
            for (var x = x0; x < x1; x += xStep) {
              sum += _luma(image.getPixel(x, y));
              count++;
            }
          }
          profile.add(count == 0 ? 0.0 : sum / count);
        }
        result.add(profile);
      }
    }
    return result;
  }

  Future<Map<String, dynamic>?> _invokeMap(
    String method,
    Map<String, dynamic> args,
  ) async {
    final value = await _channel.invokeMapMethod<String, dynamic>(method, args);
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  Future<bool> discard(String? path) async {
    if (path == null || path.isEmpty) return true;
    try {
      final file = File(path);
      if (!await file.exists()) return true;
      await file.delete();
      return !await file.exists();
    } catch (_) {
      return false;
    }
  }

  String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

  double _luma(img.Pixel pixel) {
    final r = pixel.r.toDouble();
    final g = pixel.g.toDouble();
    final b = pixel.b.toDouble();
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
  }

  double _mean(List<double> values) =>
      values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

  double? _median(List<double> sorted) {
    if (sorted.isEmpty) return null;
    final i = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2;
  }
}

class HCVTemporalFrequencyMath {
  const HCVTemporalFrequencyMath._();

  static Map<String, dynamic> analyzeRowProfileSequence(
    List<List<double>> frames,
  ) {
    if (frames.length < 3 || frames.any((profile) => profile.length < 16)) {
      return const {
        'analysisStatus': 'NOT_ANALYZED',
        'reason': 'ROW_PROFILE_SEQUENCE_TOO_SHORT',
      };
    }

    final spectra = <Map<String, double>>[];
    final differenceRms = <double>[];
    for (var i = 1; i < frames.length; i++) {
      final n = min(frames[i - 1].length, frames[i].length);
      final difference = List<double>.generate(
        n,
        (j) => frames[i][j] - frames[i - 1][j],
      );
      final mean = _mean(difference);
      for (var j = 0; j < difference.length; j++) {
        difference[j] -= mean;
      }
      final rms = sqrt(
        difference.fold<double>(0.0, (sum, x) => sum + x * x) /
            difference.length,
      );
      differenceRms.add(rms);
      spectra.add(_dominantSpatialSpectrum(difference));
    }

    final weightedBins = <int, double>{};
    for (var i = 0; i < spectra.length; i++) {
      final bin = spectra[i]['bin']?.round() ?? 0;
      if (bin <= 0) continue;
      final weight =
          (spectra[i]['concentration'] ?? 0.0) * (differenceRms[i] + 1e-9);
      weightedBins[bin] = (weightedBins[bin] ?? 0.0) + weight;
    }
    var modalBin = 0;
    var modalWeight = -1.0;
    for (final entry in weightedBins.entries) {
      if (entry.value > modalWeight) {
        modalWeight = entry.value;
        modalBin = entry.key;
      }
    }

    final matching = <int>[];
    for (var i = 0; i < spectra.length; i++) {
      final bin = spectra[i]['bin']?.round() ?? 0;
      if (modalBin > 0 && (bin - modalBin).abs() <= 1) matching.add(i);
    }
    final frequencyStability =
        spectra.isEmpty ? 0.0 : matching.length / spectra.length;

    final phases = matching
        .map((index) => spectra[index]['phase'] ?? 0.0)
        .toList(growable: false);
    final phaseStepConsistency = _phaseStepConsistency(phases);
    final concentrations =
        spectra.map((s) => s['concentration'] ?? 0.0).toList()..sort();
    differenceRms.sort();
    final medianConcentration = _median(concentrations) ?? 0.0;
    final medianDifferenceRms = _median(differenceRms) ?? 0.0;
    final periodicityStrength =
        medianConcentration * frequencyStability * phaseStepConsistency;

    return {
      'analysisStatus': 'ANALYZED',
      'framePairCount': spectra.length,
      'dominantRowFrequencyBin': modalBin,
      'approximateDominantPeriodRows':
          modalBin <= 0 ? null : frames.first.length / modalBin,
      'dominantFrequencyStability': frequencyStability,
      'medianSpatialSpectralConcentration': medianConcentration,
      'phaseStepConsistency': phaseStepConsistency,
      'medianTemporalDifferenceRms': medianDifferenceRms,
      'periodicityStrength': periodicityStrength,
    };
  }

  static Map<String, dynamic> analyzeScalarSequence(List<double> values) {
    if (values.length < 6) {
      return const {
        'analysisStatus': 'NOT_ANALYZED',
        'reason': 'SCALAR_SEQUENCE_TOO_SHORT',
      };
    }
    final mean = _mean(values);
    final sorted = List<double>.from(values)..sort();
    final p10 = sorted[((sorted.length - 1) * 0.10).round()];
    final p90 = sorted[((sorted.length - 1) * 0.90).round()];
    final modulationDepth =
        mean.abs() < 1e-9 ? 0.0 : (p90 - p10).abs() / mean.abs();
    final centered = values.map((v) => v - mean).toList();
    final spectrum = _dominantTemporalSpectrum(centered);
    return {
      'analysisStatus': 'ANALYZED',
      'meanLuma': mean,
      'robustFrameLumaModulationDepth': modulationDepth,
      'dominantTemporalFrequencyBin': spectrum['bin']?.round(),
      'temporalSpectralConcentration': spectrum['concentration'],
      'dominantTemporalPhase': spectrum['phase'],
    };
  }

  static Map<String, double> _dominantSpatialSpectrum(List<double> values) {
    final n = values.length;
    if (n < 16) return const {'bin': 0, 'concentration': 0, 'phase': 0};
    final maxBin = min(32, n ~/ 3);
    return _dominantSpectrum(values, minBin: 2, maxBin: maxBin);
  }

  static Map<String, double> _dominantTemporalSpectrum(List<double> values) {
    final n = values.length;
    if (n < 6) return const {'bin': 0, 'concentration': 0, 'phase': 0};
    return _dominantSpectrum(values, minBin: 1, maxBin: max(1, n ~/ 2));
  }

  static Map<String, double> _dominantSpectrum(
    List<double> values, {
    required int minBin,
    required int maxBin,
  }) {
    final n = values.length;
    var totalPower = 0.0;
    var bestPower = -1.0;
    var bestBin = 0;
    var bestPhase = 0.0;
    for (var k = minBin; k <= maxBin; k++) {
      var re = 0.0;
      var im = 0.0;
      for (var j = 0; j < n; j++) {
        final angle = 2 * pi * k * j / n;
        re += values[j] * cos(angle);
        im -= values[j] * sin(angle);
      }
      final power = re * re + im * im;
      totalPower += power;
      if (power > bestPower) {
        bestPower = power;
        bestBin = k;
        bestPhase = atan2(im, re);
      }
    }
    return {
      'bin': bestBin.toDouble(),
      'concentration': totalPower <= 1e-18 ? 0.0 : bestPower / totalPower,
      'phase': bestPhase,
    };
  }

  static double _phaseStepConsistency(List<double> phases) {
    if (phases.length < 3) return 0.0;
    var sumCos = 0.0;
    var sumSin = 0.0;
    var count = 0;
    for (var i = 1; i < phases.length; i++) {
      final delta = _wrapAngle(phases[i] - phases[i - 1]);
      sumCos += cos(delta);
      sumSin += sin(delta);
      count++;
    }
    if (count == 0) return 0.0;
    return sqrt(sumCos * sumCos + sumSin * sumSin) / count;
  }

  static double _wrapAngle(double value) {
    var x = value;
    while (x > pi) x -= 2 * pi;
    while (x < -pi) x += 2 * pi;
    return x;
  }

  static double _mean(List<double> values) =>
      values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

  static double? _median(List<double> sorted) {
    if (sorted.isEmpty) return null;
    final i = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[i] : (sorted[i - 1] + sorted[i]) / 2;
  }
}
