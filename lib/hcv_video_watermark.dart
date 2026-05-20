import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
      // social-friendly background box
      "drawbox=x=18:y=h-118:w=330:h=98:color=black@0.62:t=fill",

      // outer square
      "drawbox=x=30:y=h-100:w=22:h=22:color=white@0.95:t=2",

      // inner square
      "drawbox=x=36:y=h-94:w=10:h=10:color=white@0.95:t=fill",

      // SIGILLUM VERIFIED
      "drawtext=fontfile=$fontFile:text='SIGILLUM VERIFIED':"
          "x=62:y=h-104:"
          "fontsize=16:"
          "fontcolor=white@0.98",

      // HUMAN VERIFIED
      "drawtext=fontfile=$fontFile:text='HUMAN VERIFIED':"
          "x=62:y=h-82:"
          "fontsize=11:"
          "fontcolor=white@0.85",

      // HCV-ID visible for social reposts
      "drawtext=fontfile=$fontFile:text='HCV-ID\\: $safeHcvId':"
          "x=62:y=h-62:"
          "fontsize=10:"
          "fontcolor=white@0.92",

      // Verify URL visible
      "drawtext=fontfile=$fontFile:text='VERIFY\\: $safeVerify':"
          "x=62:y=h-44:"
          "fontsize=8:"
          "fontcolor=white@0.70",
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

    return await getApplicationDocumentsDirectory();
  }
}
