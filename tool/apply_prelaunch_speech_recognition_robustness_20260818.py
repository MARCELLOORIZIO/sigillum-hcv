from pathlib import Path
import re


def replace_regex(source: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count == 1:
        return updated
    if replacement in source:
        return source
    raise RuntimeError(f'{label}: regex anchor missing')


# Normalize presentation-only Dart escaping produced by the preceding regex
# patch before the formatter/analyzer sees the generated camera page.
escape_fix = Path('tool/apply_prelaunch_camera_generated_escape_fix_20260818.py')
if not escape_fix.exists():
    raise RuntimeError('camera generated escape fix missing')
exec(
    compile(escape_fix.read_text(encoding='utf-8'), str(escape_fix), 'exec'),
    {'__name__': '__main__'},
)

path = Path('ios/Runner/SceneDelegate.swift')
source = path.read_text(encoding='utf-8')

source = source.replace(
    'self.transcribeVideo(path: path, result: result)',
    'self.transcribeVideo(\n          path: path,\n          languageCode: (args["languageCode"] as? String) ?? "it",\n          result: result\n        )',
    1,
)

pattern = r'''  private func transcribeVideo\(path: String, result: @escaping FlutterResult\) \{.*?\n  \}\n\n  private func exportAudioForSpeech'''
replacement = r'''  private func speechLocaleIdentifier(_ languageCode: String) -> String {
    let normalized = languageCode.lowercased()
    if normalized.hasPrefix("it") { return "it-IT" }
    if normalized.hasPrefix("en") { return "en-US" }
    if normalized.hasPrefix("fr") { return "fr-FR" }
    if normalized.hasPrefix("de") { return "de-DE" }
    if normalized.hasPrefix("es") { return "es-ES" }
    if normalized.hasPrefix("ro") { return "ro-RO" }
    return Locale.preferredLanguages.first ?? "it-IT"
  }

  private func transcribeVideo(
    path: String,
    languageCode: String,
    result: @escaping FlutterResult
  ) {
    SFSpeechRecognizer.requestAuthorization { status in
      guard status == .authorized else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "SPEECH_PERMISSION_DENIED",
            message: "Autorizza Riconoscimento vocale nelle impostazioni di iPhone.",
            details: nil
          ))
        }
        return
      }

      let videoURL = URL(fileURLWithPath: path)
      self.exportAudioForSpeech(videoURL: videoURL) { audioURL, exportError in
        if let exportError = exportError {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "AUDIO_EXPORT_ERROR",
              message: exportError.localizedDescription,
              details: nil
            ))
          }
          return
        }
        guard let audioURL = audioURL else {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "AUDIO_EXPORT_ERROR",
              message: "Audio del video non disponibile.",
              details: nil
            ))
          }
          return
        }

        let localeIdentifier = self.speechLocaleIdentifier(languageCode)
        guard let recognizer = SFSpeechRecognizer(
          locale: Locale(identifier: localeIdentifier)
        ), recognizer.isAvailable else {
          try? FileManager.default.removeItem(at: audioURL)
          DispatchQueue.main.async {
            result(FlutterError(
              code: "SPEECH_UNAVAILABLE",
              message: "Riconoscimento vocale non disponibile in questo momento.",
              details: ["locale": localeIdentifier]
            ))
          }
          return
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(iOS 16.0, *) {
          request.addsPunctuation = true
        }

        var completed = false
        var bestText = ""
        var bestSegments = [[String: Any]]()
        var bestCoverage = -1.0
        var bestCharacterCount = 0

        // Partial hypotheses from Apple Speech may revise themselves while the
        // file is still being processed. Keep a timestamped timeline as well
        // as the best cumulative hypothesis so words from an earlier portion
        // of the video cannot disappear simply because a later partial result
        // starts farther forward.
        var timeline = [Int: [String: Any]]()

        func capture(_ response: SFSpeechRecognitionResult) {
          let transcription = response.bestTranscription
          let text = transcription.formattedString.trimmingCharacters(
            in: .whitespacesAndNewlines
          )
          let segments = transcription.segments.map { segment in
            return [
              "text": segment.substring,
              "start": segment.timestamp,
              "duration": segment.duration,
            ] as [String: Any]
          }

          for segment in transcription.segments {
            // 80 ms buckets absorb small timestamp shifts between successive
            // hypotheses. Newer recognizer output replaces the same moment;
            // moments omitted by a later partial remain preserved.
            let bucket = Int((segment.timestamp / 0.08).rounded())
            timeline[bucket] = [
              "text": segment.substring,
              "start": segment.timestamp,
              "duration": segment.duration,
            ]
          }

          let coverage = transcription.segments.last.map {
            $0.timestamp + $0.duration
          } ?? 0
          let characterCount = text.count
          if coverage > bestCoverage + 0.05 ||
             (abs(coverage - bestCoverage) <= 0.05 && characterCount > bestCharacterCount) ||
             characterCount > bestCharacterCount + 12 {
            bestText = text
            bestSegments = segments
            bestCoverage = coverage
            bestCharacterCount = characterCount
          }
        }

        func mergedTimeline() -> [[String: Any]] {
          return timeline.values.sorted { left, right in
            let a = left["start"] as? Double ?? 0
            let b = right["start"] as? Double ?? 0
            return a < b
          }
        }

        func mergedText(_ segments: [[String: Any]]) -> String {
          return segments.compactMap { item in
            (item["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
          }.filter { !$0.isEmpty }.joined(separator: " ")
        }

        func finishSuccess() {
          if completed { return }
          completed = true
          try? FileManager.default.removeItem(at: audioURL)
          self.speechTask = nil

          let timelineSegments = mergedTimeline()
          let timelineText = mergedText(timelineSegments)
          let selectedSegments = timelineSegments.count >= bestSegments.count
            ? timelineSegments
            : bestSegments
          let selectedText = timelineText.count >= bestText.count
            ? timelineText
            : bestText
          let sourceDuration = AVURLAsset(url: videoURL).duration.seconds

          DispatchQueue.main.async {
            result([
              "text": selectedText,
              "segments": selectedSegments,
              "locale": localeIdentifier,
              "duration": sourceDuration.isFinite ? sourceDuration : 0,
            ])
          }
        }

        self.speechTask?.cancel()
        self.speechTask = recognizer.recognitionTask(with: request) { response, error in
          if completed { return }
          if let response = response {
            capture(response)
            if response.isFinal {
              finishSuccess()
              return
            }
          }
          if let error = error {
            if !bestText.isEmpty || !bestSegments.isEmpty || !timeline.isEmpty {
              finishSuccess()
              return
            }
            completed = true
            try? FileManager.default.removeItem(at: audioURL)
            self.speechTask = nil
            DispatchQueue.main.async {
              result(FlutterError(
                code: "SPEECH_RECOGNITION_ERROR",
                message: error.localizedDescription,
                details: ["locale": localeIdentifier]
              ))
            }
          }
        }

        // File recognition should be allowed to cover the whole source. Some
        // recognitions return useful cumulative partials without a final event,
        // so finish only after a duration-based grace period.
        let audioDuration = AVURLAsset(url: audioURL).duration.seconds
        let timeout = max(12.0, min(120.0, audioDuration + 20.0))
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
          if completed { return }
          if !bestText.isEmpty || !bestSegments.isEmpty || !timeline.isEmpty {
            self.speechTask?.finish()
            finishSuccess()
          } else {
            self.speechTask?.cancel()
            completed = true
            try? FileManager.default.removeItem(at: audioURL)
            self.speechTask = nil
            result(FlutterError(
              code: "NO_SPEECH",
              message: "Non è stato rilevato parlato nel video.",
              details: ["locale": localeIdentifier]
            ))
          }
        }
      }
    }
  }

  private func exportAudioForSpeech'''
source = replace_regex(source, pattern, replacement, 'complete Apple Speech transcription')

for token in [
    'speechLocaleIdentifier',
    'request.shouldReportPartialResults = true',
    'request.taskHint = .dictation',
    'bestCoverage',
    'var timeline = [Int: [String: Any]]()',
    'segment.timestamp / 0.08',
    'audioDuration + 20.0',
    '"duration": sourceDuration.isFinite ? sourceDuration : 0',
    '(args["languageCode"] as? String) ?? "it"',
]:
    if token not in source:
        raise RuntimeError(f'Apple Speech robustness token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Apple Speech preserves cumulative text plus a complete timestamped timeline across partial revisions')