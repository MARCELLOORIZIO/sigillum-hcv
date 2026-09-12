from pathlib import Path

fusion_path = Path('lib/hcv_display_risk_fusion.dart')
classifier_path = Path('lib/hcv_ml_screen_replay_classifier.dart')
test_path = Path('test/weak_semantic_no_physical_resolution_test.dart')
sampling_test_path = Path('test/video_ml_adaptive_sampling_contract_test.dart')

fusion = fusion_path.read_text()

old_photo_call = """      if (!_isWeakPhotoStillSemantic(ml) ||\n          !_isWeakMultiFrameScreenSemantic(photoTemporalMl)) {\n"""
new_photo_call = """      if (!_isWeakPhotoStillSemantic(ml) ||\n          !_isWeakMultiFrameScreenSemantic(\n            photoTemporalMl,\n            minFrames: 4,\n          )) {\n"""
if fusion.count(old_photo_call) != 1:
    raise SystemExit('photo temporal helper call marker not found exactly once')
fusion = fusion.replace(old_photo_call, new_photo_call, 1)

old_photo_helper = """  static bool _isWeakPhotoStillSemantic(Map<String, dynamic>? ml) {\n    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;\n    final screenProbability =\n        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;\n    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 100;\n    final confidence =\n        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 1.0;\n    final predictedClass = ml['predictedClass']?.toString() ?? '';\n    final signals = _signals(ml);\n    final fullFrame = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 100;\n    final contentArea =\n        (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 100;\n\n    if (predictedClass.startsWith('REALITY_')) {\n      return screenProbability <= 0.20 && score <= 20;\n    }\n    return predictedClass.startsWith('SCREEN_') &&\n        screenProbability <= 0.70 &&\n        score <= 70 &&\n        confidence <= 0.60 &&\n        (fullFrame < 90 || contentArea < 85);\n  }\n\n  static bool _isWeakMultiFrameScreenSemantic(Map<String, dynamic>? ml) {\n    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;\n    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;\n    if (frames < 2) return false;\n    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;\n    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;\n    final average =\n        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;\n    final maxFrame =\n        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;\n    final screenProbability =\n        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;\n    final confidence =\n        (ml['predictedClassConfidence'] as num?)?.toDouble() ?? 1.0;\n\n    return medium == 0 &&\n        strong == 0 &&\n        average <= 65.0 &&\n        maxFrame <= 80 &&\n        screenProbability <= 0.80 &&\n        confidence <= 0.60;\n  }\n"""
new_photo_helper = """  static bool _isWeakPhotoStillSemantic(Map<String, dynamic>? ml) {\n    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;\n    final score = (ml['screenReplayRiskScore'] as num?)?.toInt() ?? 100;\n    final signals = _signals(ml);\n    final fullFrame = (signals['fullFrameRiskScore'] as num?)?.toInt() ?? 100;\n    final contentArea =\n        (signals['contentAreaRiskScore'] as num?)?.toInt() ?? 100;\n\n    // At this stage HFR and passive optical evidence have already been proven\n    // strictly negative. Do not let the semantic class label or its confidence\n    // become a second pseudo-physical gate: both shifted materially between\n    // BUILD100 and BUILD101 on the same real-world artwork/textile classes.\n    // Retain a conservative still ceiling and reject any strong regional score.\n    return score <= 70 && fullFrame < 90 && contentArea < 85;\n  }\n\n  static bool _isWeakMultiFrameScreenSemantic(\n    Map<String, dynamic>? ml, {\n    int minFrames = 2,\n  }) {\n    if (ml == null || ml['analysisStatus'] == 'NOT_ANALYZED') return false;\n    final frames = (ml['framesAnalyzed'] as num?)?.toInt() ?? 0;\n    if (frames < minFrames) return false;\n    final medium = (ml['mediumScreenFrameCount'] as num?)?.toInt() ?? 0;\n    final strong = (ml['strongScreenFrameCount'] as num?)?.toInt() ?? 0;\n    final average =\n        (ml['averageScreenReplayRiskScore'] as num?)?.toDouble() ?? 100.0;\n    final maxFrame =\n        (ml['maxFrameScreenReplayRiskScore'] as num?)?.toInt() ?? 100;\n    final screenProbability =\n        (ml['screenProbability'] as num?)?.toDouble() ?? 1.0;\n\n    // Confidence is top-class confidence, not independent display evidence.\n    // Persistence and bounded screen-family probability are the useful semantic\n    // constraints once strict physical evidence is negative.\n    return medium == 0 &&\n        strong == 0 &&\n        average <= 65.0 &&\n        maxFrame <= 80 &&\n        screenProbability <= 0.80;\n  }\n"""
if fusion.count(old_photo_helper) != 1:
    raise SystemExit('weak semantic helper block marker not found exactly once')
fusion = fusion.replace(old_photo_helper, new_photo_helper, 1)
fusion_path.write_text(fusion)

classifier = classifier_path.read_text()
old_interval = """      final num samplingIntervalSeconds = frameSamplingIntervalSeconds == null\n          ? max(1, frameIntervalSeconds)\n          : max(0.1, frameSamplingIntervalSeconds);\n"""
new_interval = """      num samplingIntervalSeconds = frameSamplingIntervalSeconds == null\n          ? max(1, frameIntervalSeconds)\n          : max(0.1, frameSamplingIntervalSeconds);\n      var samplingFallbackUsed = false;\n"""
if classifier.count(old_interval) != 1:
    raise SystemExit('sampling interval marker not found exactly once')
classifier = classifier.replace(old_interval, new_interval, 1)

old_frames = """      final frames = workDir\n          .listSync()\n          .whereType<File>()\n          .where((file) => file.path.toLowerCase().endsWith('.jpg'))\n          .toList()\n        ..sort((a, b) => a.path.compareTo(b.path));\n\n      if (frames.isEmpty) {\n        return _unknown('NOT_ENOUGH_VIDEO_FRAMES');\n      }\n"""
new_frames = """      var frames = workDir\n          .listSync()\n          .whereType<File>()\n          .where((file) => file.path.toLowerCase().endsWith('.jpg'))\n          .toList()\n        ..sort((a, b) => a.path.compareTo(b.path));\n\n      // Generic video analysis historically samples every three seconds. Very\n      // short real videos can therefore yield only one ML frame and can never\n      // satisfy the multi-frame decision contract. Retry only that narrow case\n      // with a denser one-second sampling. Photo Temporal V2 supplies its own\n      // explicit interval and is intentionally left unchanged.\n      if (frames.length < 2 && frameSamplingIntervalSeconds == null) {\n        const fallbackSamplingIntervalSeconds = 1.0;\n        final fallbackFramePattern =\n            p.join(workDir.path, 'fallback_%03d.jpg');\n        final fallbackCommand = \"-y -i '$videoPath' \"\n            \"-vf \\\"scale=720:720:force_original_aspect_ratio=decrease,\"\n            \"pad=720:720:(ow-iw)/2:(oh-ih)/2,\"\n            \"fps=1/$fallbackSamplingIntervalSeconds\\\" \"\n            \"-frames:v $frameLimit \"\n            \"'$fallbackFramePattern'\";\n        final fallbackSession = await FFmpegKit.execute(fallbackCommand);\n        final fallbackCode = await fallbackSession.getReturnCode();\n        if (fallbackCode != null && ReturnCode.isSuccess(fallbackCode)) {\n          final fallbackFrames = workDir\n              .listSync()\n              .whereType<File>()\n              .where(\n                (file) =>\n                    p.basename(file.path).startsWith('fallback_') &&\n                    file.path.toLowerCase().endsWith('.jpg'),\n              )\n              .toList()\n            ..sort((a, b) => a.path.compareTo(b.path));\n          if (fallbackFrames.length >= 2) {\n            frames = fallbackFrames;\n            samplingIntervalSeconds = fallbackSamplingIntervalSeconds;\n            samplingFallbackUsed = true;\n          }\n        }\n      }\n\n      if (frames.isEmpty) {\n        return _unknown('NOT_ENOUGH_VIDEO_FRAMES');\n      }\n"""
if classifier.count(old_frames) != 1:
    raise SystemExit('frame listing marker not found exactly once')
classifier = classifier.replace(old_frames, new_frames, 1)

old_meta = """      worst['videoFrameSamplingIntervalSeconds'] = samplingIntervalSeconds;\n      worst['videoFrameSamplingLimit'] = frameLimit;\n      worst['videoFrameAnalyses'] = analyses.take(12).toList();\n"""
new_meta = """      worst['videoFrameSamplingIntervalSeconds'] = samplingIntervalSeconds;\n      worst['videoFrameSamplingLimit'] = frameLimit;\n      worst['videoFrameSamplingFallbackUsed'] = samplingFallbackUsed;\n      worst['videoFrameAnalyses'] = analyses.take(12).toList();\n"""
if classifier.count(old_meta) != 1:
    raise SystemExit('video sampling metadata marker not found exactly once')
classifier = classifier.replace(old_meta, new_meta, 1)
classifier_path.write_text(classifier)

tests = test_path.read_text()
insert_marker = "\n  test('missing HFR keeps historical incompatible samples unchanged', () {\n"
if tests.count(insert_marker) != 1:
    raise SystemExit('test insertion marker not found exactly once')
new_tests = r'''

  test('build101 reflective artwork photo resolves semantic class drift', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 1,
        predictedClass: 'REALITY_PAPER',
        p: 0.4959,
        confidence: 0.4194,
        score: 50,
        fullFrame: 50,
        contentArea: 46,
      ),
      temporalFrequencyProbe: negativeHfr(),
      photoTemporalMl: ml(
        frames: 4,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.7633,
        confidence: 0.6884,
        score: 76,
        average: 58.5,
        maxFrame: 76,
        fullFrame: 76,
        contentArea: 68,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test('build101 textile photo resolves despite unstable class confidence', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 1,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.6942,
        confidence: 0.5749,
        score: 69,
        fullFrame: 69,
        contentArea: 13,
      ),
      temporalFrequencyProbe: negativeHfr(),
      photoTemporalMl: ml(
        frames: 4,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.7889,
        confidence: 0.6354,
        score: 79,
        average: 62.25,
        maxFrame: 79,
        fullFrame: 79,
        contentArea: 65,
      ),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });

  test('photo temporal resolver requires all four BUILD100+ samples', () {
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 1,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.69,
        confidence: 0.55,
        score: 69,
        fullFrame: 69,
        contentArea: 30,
      ),
      temporalFrequencyProbe: negativeHfr(),
      photoTemporalMl: ml(
        frames: 3,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.79,
        confidence: 0.70,
        score: 79,
        average: 60.0,
        maxFrame: 79,
      ),
    );
    expect(identical(result, base), isTrue);
  });

  test('photo temporal max frame above 80 blocks downgrade', () {
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 1,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.69,
        confidence: 0.55,
        score: 69,
        fullFrame: 69,
        contentArea: 30,
      ),
      temporalFrequencyProbe: negativeHfr(),
      photoTemporalMl: ml(
        frames: 4,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.81,
        confidence: 0.70,
        score: 81,
        average: 60.0,
        maxFrame: 81,
      ),
    );
    expect(identical(result, base), isTrue);
  });

  test('photo temporal average above 65 blocks downgrade', () {
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 1,
        predictedClass: 'REALITY_PAPER',
        p: 0.50,
        confidence: 0.42,
        score: 50,
        fullFrame: 50,
        contentArea: 46,
      ),
      temporalFrequencyProbe: negativeHfr(),
      photoTemporalMl: ml(
        frames: 4,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.78,
        confidence: 0.69,
        score: 78,
        average: 66.0,
        maxFrame: 78,
      ),
    );
    expect(identical(result, base), isTrue);
  });

  test('one medium screen frame blocks photo downgrade', () {
    final base = unresolved();
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: base,
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 1,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.69,
        confidence: 0.55,
        score: 69,
        fullFrame: 69,
        contentArea: 30,
      ),
      temporalFrequencyProbe: negativeHfr(),
      photoTemporalMl: ml(
        frames: 4,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.79,
        confidence: 0.70,
        score: 79,
        medium: 1,
        average: 60.0,
        maxFrame: 79,
      ),
    );
    expect(identical(result, base), isTrue);
  });

  test('adaptive multi-frame video is not gated by class confidence', () {
    final result = HCVDisplayRiskFusion.resolveWeakSemanticOnlyWithNegativeHfr(
      base: unresolved(),
      passiveOptical: cleanOptical(),
      ml: ml(
        frames: 4,
        predictedClass: 'SCREEN_MONITOR',
        p: 0.70,
        confidence: 0.72,
        score: 70,
        average: 54.0,
        maxFrame: 70,
        fullFrame: 70,
        contentArea: 68,
      ),
      temporalFrequencyProbe: negativeHfr(),
    );
    expect(result.decision, 'NO_DISPLAY_EVIDENCE');
  });
'''
tests = tests.replace(insert_marker, new_tests + insert_marker, 1)
test_path.write_text(tests)

sampling_test_path.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic video ML retries one-frame captures at one-second cadence', () {
    final source = File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();

    expect(source, contains('int frameIntervalSeconds = 3'));
    expect(
      source,
      contains('frames.length < 2 && frameSamplingIntervalSeconds == null'),
    );
    expect(source, contains('fallbackSamplingIntervalSeconds = 1.0'));
    expect(source, contains("'fallback_%03d.jpg'"));
    expect(source, contains("'videoFrameSamplingFallbackUsed'"));
  });

  test('photo Temporal V2 explicit sampling is excluded from fallback', () {
    final source = File('lib/hcv_ml_screen_replay_classifier.dart').readAsStringSync();

    expect(
      source,
      contains('frameSamplingIntervalSeconds == null'),
      reason: 'fallback must apply only to generic video analysis',
    );
  });
}
''')

print('Applied BUILD101 bounded photo/video weak-semantic patch.')
