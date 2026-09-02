from pathlib import Path


def replace_once(path: Path, old: str, new: str, marker: str) -> None:
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{path}: expected source block not found for {marker}")
    path.write_text(text.replace(old, new, 1))


classifier = Path("lib/hcv_ml_screen_replay_classifier.dart")
temporal = Path("lib/hcv_temporal_capture_probe.dart")

replace_once(
    classifier,
    "  Future<Map<String, dynamic>> analyzeVideo(String videoPath) async {",
    """  Future<Map<String, dynamic>> analyzeVideo(
    String videoPath, {
    int frameIntervalSeconds = 3,
    int maxFrames = 8,
  }) async {""",
    "optional video sampling parameters",
)

replace_once(
    classifier,
    """      final framePattern = p.join(workDir.path, 'frame_%03d.jpg');
      final command = \"-y -i '$videoPath' \"
          \"-vf \\\"scale=720:720:force_original_aspect_ratio=decrease,\"
          \"pad=720:720:(ow-iw)/2:(oh-ih)/2,\"
          \"fps=1/3\\\" \"
          \"-frames:v 8 \"
          \"'$framePattern'\";""",
    """      final samplingIntervalSeconds = max(1, frameIntervalSeconds);
      final frameLimit = max(1, maxFrames);
      final framePattern = p.join(workDir.path, 'frame_%03d.jpg');
      final command = \"-y -i '$videoPath' \"
          \"-vf \\\"scale=720:720:force_original_aspect_ratio=decrease,\"
          \"pad=720:720:(ow-iw)/2:(oh-ih)/2,\"
          \"fps=1/$samplingIntervalSeconds\\\" \"
          \"-frames:v $frameLimit \"
          \"'$framePattern'\";""",
    "parameterized ffmpeg sampling",
)

replace_once(
    classifier,
    "        analysis['approxVideoSecond'] = i * 3;",
    "        analysis['approxVideoSecond'] = i * samplingIntervalSeconds;",
    "frame timestamp metadata",
)

replace_once(
    classifier,
    """      worst['averageScreenReplayRiskScore'] =
          averageScore == null ? null : _round(averageScore);
      worst['videoFrameAnalyses'] = analyses.take(12).toList();""",
    """      worst['averageScreenReplayRiskScore'] =
          averageScore == null ? null : _round(averageScore);
      worst['videoFrameSamplingIntervalSeconds'] = samplingIntervalSeconds;
      worst['videoFrameSamplingLimit'] = frameLimit;
      worst['videoFrameAnalyses'] = analyses.take(12).toList();""",
    "sampling audit metadata",
)

replace_once(
    temporal,
    """        mlAnalysis =
            await HCVMLScreenReplayClassifier.instance.analyzeVideo(
          temporaryVideoPath,
        );""",
    """        mlAnalysis =
            await HCVMLScreenReplayClassifier.instance.analyzeVideo(
          temporaryVideoPath,
          frameIntervalSeconds: 1,
          maxFrames: 2,
        );""",
    "photo-specific two-frame sampling",
)

Path("test/photo_temporal_two_frame_sampling_contract_test.dart").write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic video ML sampling keeps the existing 3-second default', () {
    final source =
        File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();

    expect(source, contains('int frameIntervalSeconds = 3'));
    expect(source, contains('int maxFrames = 8'));
    expect(source, contains('fps=1/$samplingIntervalSeconds'));
    expect(source, contains('-frames:v $frameLimit'));
    expect(
      source,
      contains(
        "worst['videoFrameSamplingIntervalSeconds'] = samplingIntervalSeconds;",
      ),
    );
  });

  test('photo mini-video requests two ML frames one second apart', () {
    final source = File('lib/hcv_temporal_capture_probe.dart').readAsStringSync();

    expect(source, contains('frameIntervalSeconds: 1'));
    expect(source, contains('maxFrames: 2'));
    expect(
      source,
      contains('static const Duration defaultDuration = Duration(milliseconds: 1800)'),
    );
  });
}
"""
)
