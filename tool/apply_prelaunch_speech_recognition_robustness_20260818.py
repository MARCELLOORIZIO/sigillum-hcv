from pathlib import Path
import re


def replace_regex(source: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count == 1:
        return updated
    if replacement in source:
        return source
    raise RuntimeError(f'{label}: regex anchor missing')


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

        func finishSuccess() {
          if completed { return }
          completed = true
          try? FileManager.default.removeItem(at: audioURL)
          self.speechTask = nil
          DispatchQueue.main.async {
            result([
              "text": bestText,
              "segments": bestSegments,
              "locale": localeIdentifier,
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
            if !bestText.isEmpty || !bestSegments.isEmpty {
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

        // Some file recognitions emit a useful cumulative partial result but no
        // final callback. Preserve the most complete result rather than only
        // the first words or an indefinite wait.
        let audioDuration = AVURLAsset(url: audioURL).duration.seconds
        let timeout = max(12.0, min(90.0, audioDuration + 15.0))
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
          if completed { return }
          if !bestText.isEmpty || !bestSegments.isEmpty {
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
    'audioDuration + 15.0',
    '(args["languageCode"] as? String) ?? "it"',
]:
    if token not in source:
        raise RuntimeError(f'Apple Speech robustness token missing: {token}')

path.write_text(source, encoding='utf-8')
print('Apple Speech now uses app language and preserves the most complete cumulative transcript')
