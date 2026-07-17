import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class HCVVideoWatermark {
  Future<String> createPublishedVideo({
    required String inputPath,
    required String hcvId,
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
      "${baseName}_SIGILLUM_CAPTURE.mp4",
    );

    final outputFile = File(outputPath);

    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final safeInput = _escapePath(inputPath);
    final safeOutput = _escapePath(outputPath);
    final safeHcvId = _escapeText(hcvId);

    final fontFile = Platform.isIOS
        ? "/System/Library/Fonts/Core/Avenir.ttc"
        : "/system/fonts/Roboto-Regular.ttf";

    final filter = [
      // social-friendly background box
      //"drawbox=x=18:y=h-92:w=300:h=72:color=black@0.42:t=fill",

      // outer square
      "drawbox=x=22:y=24:w=16:h=16:color=white@0.92:t=2",

      // inner square
      "drawbox=x=27:y=29:w=7:h=7:color=white@0.92:t=fill",

      // SIGILLUM capture marker. Verification happens in the app/registry.
      "drawtext=fontfile=$fontFile:text='SIGILLUM CAPTURE':"
          "x=46:y=20:"
          "fontsize=12:"
          "fontcolor=white@0.94",

      // Visible reminder that the overlay alone is not proof.
      "drawtext=fontfile=$fontFile:text='VERIFY IN APP':"
          "x=46:y=38:"
          "fontsize=8:"
          "fontcolor=white@0.78",

      // HCV-ID visible for social reposts
      "drawtext=fontfile=$fontFile:text='$safeHcvId':"
          "x=22:y=56:"
          "fontsize=22:"
          "fontcolor=yellow:"
          "box=1:"
          "boxcolor=black@0.58:"
          "boxborderw=7",
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
