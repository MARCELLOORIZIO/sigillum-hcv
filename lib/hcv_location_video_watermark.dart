import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'hcv_capture_location.dart';
import 'hcv_capture_timestamp.dart';

class HCVLocationVideoWatermark {
  Future<String> createPublishedVideo({
    required String inputPath,
    required String hcvId,
    required DateTime capturedAt,
    HCVCaptureLocation? captureLocation,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw Exception('Video non trovato: $inputPath');
    }

    final ext = p.extension(inputPath).toLowerCase();
    if (ext != '.mp4' && ext != '.mov' && ext != '.m4v') {
      return inputPath;
    }

    final outputDir = await _getOutputDirectory();
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final baseName = p
        .basenameWithoutExtension(inputPath)
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final outputPath = p.join(
      outputDir.path,
      '${baseName}_SIGILLUM_CAPTURE.mp4',
    );
    final outputFile = File(outputPath);

    final safeInput = _escapePath(inputPath);
    final safeOutput = _escapePath(outputPath);
    final safeHcvId = _escapeText(hcvId);
    final safeCapturedAt = _escapeText(HCVCaptureTimestamp.format(capturedAt));
    final safeLocation = captureLocation == null
        ? null
        : _escapeText(captureLocation.watermarkText);

    String? lastLogs;
    for (final fontFile in _fontCandidates()) {
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      final command = _buildCommand(
        safeInput: safeInput,
        safeOutput: safeOutput,
        safeHcvId: safeHcvId,
        safeCapturedAt: safeCapturedAt,
        safeLocation: safeLocation,
        fontFile: fontFile,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      if (returnCode != null && ReturnCode.isSuccess(returnCode)) {
        if (!await outputFile.exists() || await outputFile.length() <= 0) {
          throw Exception('SIGILLUM watermark output non valido');
        }
        return outputPath;
      }

      final logs = await session.getAllLogsAsString() ?? '';
      lastLogs = logs;

      // Archive 42 exposed a device-only iOS failure while resolving the
      // hard-coded drawtext font. Retry only font-related failures so that
      // unrelated FFmpeg failures are not repeated several times.
      if (!_isFontResolutionFailure(logs)) {
        break;
      }
    }

    throw Exception(
      'SIGILLUM watermark failed: ${_summarizeFfmpegFailure(lastLogs ?? '')}',
    );
  }

  String _buildCommand({
    required String safeInput,
    required String safeOutput,
    required String safeHcvId,
    required String safeCapturedAt,
    required String? safeLocation,
    required String fontFile,
  }) {
    final hasLocation = safeLocation != null;
    final hcvY = hasLocation ? 72 : 56;

    final filterParts = <String>[
      'drawbox=x=22:y=24:w=16:h=16:color=white@0.92:t=2',
      'drawbox=x=27:y=29:w=7:h=7:color=white@0.92:t=fill',
      "drawtext=fontfile=$fontFile:text='SIGILLUM CAPTURE':x=46:y=20:fontsize=12:fontcolor=white@0.94",
      "drawtext=fontfile=$fontFile:text='$safeCapturedAt':x=46:y=38:fontsize=8:fontcolor=white@0.78",
      if (safeLocation != null)
        "drawtext=fontfile=$fontFile:text='$safeLocation':x=22:y=52:fontsize=8:fontcolor=white@0.82:box=1:boxcolor=black@0.35:boxborderw=4",
      "drawtext=fontfile=$fontFile:text='$safeHcvId':x=22:y=$hcvY:fontsize=22:fontcolor=yellow:box=1:boxcolor=black@0.58:boxborderw=7",
    ];

    return '-y '
        "-i '$safeInput' "
        '-vf "${filterParts.join(',')}" '
        '-c:v libx264 '
        '-preset veryfast '
        '-crf 23 '
        '-c:a aac '
        '-b:a 128k '
        '-movflags +faststart '
        "'$safeOutput'";
  }

  List<String> _fontCandidates() {
    if (Platform.isIOS) {
      return const [
        '/System/Library/Fonts/Avenir.ttc',
        '/System/Library/Fonts/Core/Avenir.ttc',
        '/System/Library/Fonts/Helvetica.ttc',
        '/System/Library/Fonts/Core/Helvetica.ttc',
        '/System/Library/Fonts/HelveticaNeue.ttc',
        '/System/Library/Fonts/Core/HelveticaNeue.ttc',
      ];
    }
    return const ['/system/fonts/Roboto-Regular.ttf'];
  }

  bool _isFontResolutionFailure(String logs) {
    final lower = logs.toLowerCase();
    if (lower.contains("no such filter: 'drawtext'") ||
        lower.contains('no such filter: drawtext')) {
      return false;
    }
    return lower.contains('could not load font') ||
        lower.contains('cannot find a valid font') ||
        lower.contains('cannot find valid font') ||
        (lower.contains('error initializing filter') &&
            lower.contains('drawtext')) ||
        (lower.contains('error applying option') && lower.contains('font'));
  }

  String _summarizeFfmpegFailure(String logs) {
    final lines = logs
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) {
          final lower = line.toLowerCase();
          return !lower.startsWith('ffmpeg version') &&
              !lower.startsWith('copyright') &&
              !lower.startsWith('built with') &&
              !lower.startsWith('configuration:') &&
              !RegExp(r'^lib[a-z0-9_]+\s+').hasMatch(lower);
        })
        .toList();

    if (lines.isEmpty) return 'errore FFmpeg senza dettagli';
    final tail = lines.length <= 6 ? lines : lines.sublist(lines.length - 6);
    return tail.join(' | ');
  }

  String _escapePath(String value) => value.replaceAll("'", r"'\''");

  String _escapeText(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll(':', r'\:')
        .replaceAll("'", r"\'")
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
  }

  Future<Directory> _getOutputDirectory() async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    }
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        return Directory(p.join(userProfile, 'Documents'));
      }
    }
    return getApplicationDocumentsDirectory();
  }
}
