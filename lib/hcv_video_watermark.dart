import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;

class HCVVideoWatermark {
  Future<String> createPublishedVideo({
    required String inputPath,
    required String hcvId,
    String? verificationUrl,
  }) async {
    final inputFile = File(inputPath);

    if (!await inputFile.exists()) {
      throw Exception("Video non trovato: $inputPath");
    }

    final ext = p.extension(inputPath).toLowerCase();

    if (ext != ".mp4" && ext != ".mov" && ext != ".m4v") {
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
      "${baseName}_SIGILLUM_VERIFIED.mp4",
    );

    final outputFile = File(outputPath);

    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final safeInput = _escapePath(inputPath);
    final safeOutput = _escapePath(outputPath);
    final safeHcvId = _escapeText(hcvId);
    final safeVerify = _escapeText(
      verificationUrl ??
          "https://hcv-registry-server.onrender.com/verify/$hcvId",
    );

    const fontFile = "/system/fonts/Roboto-Regular.ttf";

    final filter = [
      // background
      "drawbox=x=18:y=h-66:w=210:h=46:color=black@0.42:t=fill",

      // outer square
      "drawbox=x=28:y=h-52:w=14:h=14:color=white@0.92:t=2",

      // inner square
      "drawbox=x=32:y=h-48:w=6:h=6:color=white@0.92:t=fill",

      // SIGILLUM
      "drawtext=fontfile=$fontFile:text='SIGILLUM':"
          "x=52:y=h-56:"
          "fontsize=11:"
          "fontcolor=white@0.95",

      // HUMAN VERIFIED
      "drawtext=fontfile=$fontFile:text='HUMAN VERIFIED':"
          "x=52:y=h-42:"
          "fontsize=8:"
          "fontcolor=white@0.72",

      // HCV-ID
      "drawtext=fontfile=$fontFile:text='$safeHcvId':"
          "x=52:y=h-30:"
          "fontsize=7:"
          "fontcolor=white@0.58",
    ].join(",");

    final command = "-y "
        "-i '$safeInput' "
        "-vf \"$filter\" "
        "-c:v libx264 "
        "-preset veryfast "
        "-crf 23 "
        "-c:a aac "
        "-b:a 128k "
        "-movflags +faststart "
        "'$safeOutput'";

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (returnCode == null || !ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getAllLogsAsString();
      throw Exception("SIGILLUM watermark failed:\n$logs");
    }

    if (!await outputFile.exists()) {
      throw Exception("SIGILLUM watermark output not created");
    }

    final length = await outputFile.length();
    if (length <= 0) {
      throw Exception("SIGILLUM watermark output empty");
    }

    return outputPath;
  }

  String _escapePath(String value) {
    return value.replaceAll("'", r"'\''");
  }

  String _escapeText(String value) {
    return value
        .replaceAll("\\", r"\\")
        .replaceAll(":", r"\:")
        .replaceAll("'", r"\'")
        .replaceAll("\n", " ")
        .replaceAll("\r", " ");
  }

  Future<Directory> _getOutputDirectory() async {
    if (Platform.isAndroid) {
      return Directory("/storage/emulated/0/Download");
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment["USERPROFILE"];
      if (userProfile != null && userProfile.isNotEmpty) {
        return Directory(p.join(userProfile, "Documents"));
      }
    }

    return Directory.systemTemp;
  }
}
