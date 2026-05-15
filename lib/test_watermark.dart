import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:path/path.dart' as p;

Future<void> testWatermark(String inputPath) async {
  final input = File(inputPath);

  if (!await input.exists()) {
    throw Exception("Input video non trovato");
  }

  final outputPath = p.join(
    p.dirname(inputPath),
    "SIGILLUM_TEST.mp4",
  );

  final output = File(outputPath);

  if (await output.exists()) {
    await output.delete();
  }

  final command = '-y '
      '-i "$inputPath" '
      '-vf "'
      'drawbox=x=w-340:y=24:w=316:h=64:color=black@0.58:t=fill,'
      'drawbox=x=w-324:y=42:w=34:h=34:color=white@0.95:t=3,'
      'drawbox=x=w-314:y=52:w=14:h=14:color=white@0.95:t=2,'
      'drawtext=text=\'SIGILLUM\':x=w-278:y=42:fontsize=18:fontcolor=white,'
      'drawtext=text=\'HUMAN VERIFIED\':x=w-278:y=66:fontsize=11:fontcolor=white@0.80'
      '" '
      '-c:v libx264 '
      '-preset veryfast '
      '-crf 23 '
      '-c:a aac '
      '-b:a 128k '
      '"$outputPath"';

  final session = await FFmpegKit.execute(command);

  final returnCode = await session.getReturnCode();

  if (returnCode == null || !returnCode.isValueSuccess()) {
    final logs = await session.getAllLogsAsString();
    throw Exception("FFmpeg failed:\n$logs");
  }

  print("SIGILLUM watermark OK:");
  print(outputPath);
}
