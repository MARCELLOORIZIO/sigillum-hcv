from pathlib import Path
import re


def replace_once(source: str, old: str, new: str, label: str) -> str:
    if new in source:
        return source
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one anchor, found {count}')
    return source.replace(old, new, 1)


def replace_regex(source: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count == 1:
        return updated
    if replacement in source:
        return source
    raise RuntimeError(f'{label}: regex anchor missing')


# ---------------------------------------------------------------------------
# Account/login UX. These changes affect only commercial account state and UI.
# ---------------------------------------------------------------------------
gate_path = Path('lib/commercial_gate.dart')
gate = gate_path.read_text(encoding='utf-8')

register_pattern = re.compile(
    r"  Future<void> _register\(\) async \{.*?\n  \}\n\n  Future<void> _verifyEmail",
    re.S,
)
register_replacement = r'''  Future<void> _register() async {
    if (_name.text.trim().isEmpty ||
        !_email.text.contains('@') ||
        _password.text.length < 12) {
      setState(() => _message =
          'Inserisci nome, email valida e una password di almeno 12 caratteri.');
      return;
    }
    if (!_acceptTerms || !_ackPrivacy || !_adult) {
      setState(() => _message =
          'Per creare un account Creator devi completare le tre conferme richieste.');
      return;
    }
    await _run(() async {
      try {
        await _account.register(
          email: _email.text,
          password: _password.text,
          creatorName: _name.text,
          acceptTerms: _acceptTerms,
          acknowledgePrivacy: _ackPrivacy,
          adultConfirmed: _adult,
        );
      } on CommercialAccountException catch (error) {
        if (error.code != 'ACCOUNT_ESISTENTE') rethrow;
        if (!mounted) return;
        TextInput.finishAutofillContext(shouldSave: false);
        setState(() {
          _loginMode = true;
          _forgotMode = false;
          _password.clear();
          _message =
              'Questa email è già associata a un account. Accedi oppure usa Password dimenticata.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _stage = _GateStage.verifyEmail;
        _message = 'Ti abbiamo inviato un codice di 6 cifre.';
      });
    });
  }

  Future<void> _verifyEmail'''
gate, count = register_pattern.subn(register_replacement, gate, count=1)
if count != 1 and 'Questa email è già associata a un account.' not in gate:
    raise RuntimeError('register existing-account recovery anchor missing')

login_pattern = re.compile(
    r"  Future<void> _login\(\) async \{.*?\n  \}\n\n  Future<void> _forgot",
    re.S,
)
login_replacement = r'''  Future<void> _login() async {
    await _run(() async {
      try {
        final envelope =
            await _account.login(email: _email.text, password: _password.text);
        _applyEnvelope(envelope);
        TextInput.finishAutofillContext(shouldSave: true);
        await _routeAuthenticated();
      } on CommercialAccountException catch (error) {
        if (error.code == 'EMAIL_NON_VERIFICATA') {
          await _account.resendEmailCode(_email.text);
          if (!mounted) return;
          setState(() {
            _stage = _GateStage.verifyEmail;
            _message =
                'Email non ancora verificata. Ti abbiamo inviato un nuovo codice.';
          });
          return;
        }
        if (error.code == 'ACCOUNT_NON_TROVATO') {
          if (!mounted) return;
          TextInput.finishAutofillContext(shouldSave: false);
          setState(() {
            _loginMode = false;
            _forgotMode = false;
            _password.clear();
            _message =
                'Non esiste un account con questa email. Puoi crearne uno nuovo.';
          });
          return;
        }
        rethrow;
      }
    });
  }

  Future<void> _forgot'''
gate, count = login_pattern.subn(login_replacement, gate, count=1)
if count != 1 and 'Non esiste un account con questa email.' not in gate:
    raise RuntimeError('login missing-account recovery anchor missing')

session_pattern = re.compile(
    r"  void _onSessionInvalidated\(\) \{.*?\n  \}\n\n  Future<void> _logout\(\) async \{.*?\n  \}\n\n  void _openVerify",
    re.S,
)
session_replacement = r'''  void _resetLoggedOutState() {
    if (!mounted) return;
    TextInput.finishAutofillContext(shouldSave: false);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    setState(() {
      _accountData = const {};
      _name.clear();
      _email.clear();
      _password.clear();
      _code.clear();
      _newPassword.clear();
      _loginMode = false;
      _forgotMode = false;
      _acceptTerms = false;
      _ackPrivacy = false;
      _adult = false;
      _obscure = true;
      _storeAvailable = false;
      _products = const [];
      _message = '';
      _stage = _GateStage.landing;
    });
  }

  void _onSessionInvalidated() {
    _resetLoggedOutState();
  }

  Future<void> _logout() async {
    await _account.logout();
    _resetLoggedOutState();
  }

  void _openVerify'''
gate, count = session_pattern.subn(session_replacement, gate, count=1)
if count != 1 and 'void _resetLoggedOutState()' not in gate:
    raise RuntimeError('full logged-out reset anchor missing')

# Put all authentication text fields in one iOS AutoFill context.
if 'return AutofillGroup(' not in gate:
    build_pattern = re.compile(
        r"(    return Scaffold\(\n      body: SafeArea\(.*?\n      \),\n    \);)(\n  \}\n\n  Widget _content\(\))",
        re.S,
    )
    match = build_pattern.search(gate)
    if not match:
        raise RuntimeError('commercial gate scaffold anchor missing')
    block = match.group(1)
    block = block.replace(
        '    return Scaffold(\n',
        '    return AutofillGroup(\n      child: Scaffold(\n',
        1,
    )
    block = block.rsplit('\n    );', 1)[0] + '\n      ),\n    );'
    gate = gate[:match.start(1)] + block + gate[match.end(1):]

for token in [
    'AutofillHints.username',
    'AutofillHints.password',
    'AutofillHints.newPassword',
    'return AutofillGroup(',
    'void _resetLoggedOutState()',
    'Questa email è già associata a un account.',
]:
    if token not in gate:
        raise RuntimeError(f'commercial account refinement token missing: {token}')

gate_path.write_text(gate, encoding='utf-8')


# ---------------------------------------------------------------------------
# Account deletion must immediately invalidate the visible app session.
# Local identity cleanup is already installed by the preceding KYC patch.
# ---------------------------------------------------------------------------
profile_path = Path('lib/commercial_profile_page.dart')
profile = profile_path.read_text(encoding='utf-8')
material_import = "import 'package:flutter/material.dart';\n"
services_import = "import 'package:flutter/services.dart';\n"
if services_import not in profile:
    profile = replace_once(
        profile,
        material_import,
        material_import + services_import,
        'profile services import',
    )

profile = replace_once(
    profile,
    """      await _auth.deleteAccount(password: value);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSessionInvalidated();
""",
    """      await _auth.deleteAccount(password: value);
      if (!mounted) return;
      TextInput.finishAutofillContext(shouldSave: false);
      widget.onSessionInvalidated();
""",
    'delete account immediate invalidation',
)
profile = replace_once(
    profile,
    """      await _auth.logout();
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSessionInvalidated();
""",
    """      await _auth.logout();
      if (!mounted) return;
      TextInput.finishAutofillContext(shouldSave: false);
      widget.onSessionInvalidated();
""",
    'logout immediate invalidation',
)
profile_path.write_text(profile, encoding='utf-8')


# ---------------------------------------------------------------------------
# Shared plain text: Messenger/iOS Share -> SIGILLUM text verifier directly.
# This is transport/UI routing only; the text integrity verifier is unchanged.
# ---------------------------------------------------------------------------
home_path = Path('lib/user_home_page.dart')
home = home_path.read_text(encoding='utf-8')
if "import 'dart:io';" not in home:
    home = "import 'dart:io';\n\n" + home
if "import 'text_social_verify_page.dart';" not in home:
    home = replace_once(
        home,
        "import 'text_cert_page.dart';\n",
        "import 'text_cert_page.dart';\nimport 'text_social_verify_page.dart';\n",
        'text verifier import',
    )

text_route = """    if (lower.endsWith('.txt')) {
      File(path).readAsString().then((sharedText) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TextSocialVerifyPage(
              languageCode: languageCode,
              initialText: sharedText,
            ),
          ),
        );
      }).catchError((_) {});
      return;
    }

"""
if "lower.endsWith('.txt')" not in home.split('void _openImportedPath', 1)[1].split('void _open(', 1)[0]:
    home = replace_once(
        home,
        "    final lower = path.toLowerCase();\n",
        "    final lower = path.toLowerCase();\n" + text_route,
        'shared text direct routing',
    )
home_path.write_text(home, encoding='utf-8')


# ---------------------------------------------------------------------------
# Make the text-verification result screen coherent with the approved light UI.
# ---------------------------------------------------------------------------
text_verify_path = Path('lib/text_social_verify_page.dart')
text_verify = text_verify_path.read_text(encoding='utf-8')
if "import 'sigillum_theme.dart';" not in text_verify:
    text_verify = replace_once(
        text_verify,
        "import 'hcv_verifier.dart';\n",
        "import 'hcv_verifier.dart';\nimport 'sigillum_theme.dart';\n",
        'text verifier theme import',
    )
text_verify = text_verify.replace('return Colors.red;', 'return SigillumTheme.danger;')
text_verify = text_verify.replace('return Colors.green;', 'return SigillumTheme.verified;')
text_verify = text_verify.replace('return Colors.lightGreen;', 'return SigillumTheme.verified;')
text_verify = text_verify.replace('return Colors.orange;', 'return SigillumTheme.warning;')
text_verify = text_verify.replace(
    'color: hasResult ? _resultColor().withValues(alpha: 0.16) : Colors.white10,',
    'color: hasResult ? _resultColor().withValues(alpha: 0.12) : SigillumTheme.panel,',
)
text_verify = text_verify.replace(
    'border: Border.all(color: hasResult ? _resultColor() : Colors.white24),',
    'border: Border.all(color: hasResult ? _resultColor() : SigillumTheme.border),',
)
text_verify = text_verify.replace(
    'color: hasResult ? _resultColor() : Colors.white70,',
    'color: hasResult ? _resultColor() : SigillumTheme.muted,',
)
text_verify = text_verify.replace(
    'color: hasResult ? _resultColor() : Colors.white,',
    'color: hasResult ? _resultColor() : SigillumTheme.ink,',
)
text_verify = text_verify.replace(
    "style: const TextStyle(color: Colors.white60, fontSize: 12),",
    "style: const TextStyle(color: SigillumTheme.muted, fontSize: 12),",
)
text_verify_path.write_text(text_verify, encoding='utf-8')


# ---------------------------------------------------------------------------
# Native iOS speech recognition. It creates only transcript/SRT companions;
# the certified video file, its hash, HCV claims and Registry record are never
# modified by this feature.
# ---------------------------------------------------------------------------
scene_path = Path('ios/Runner/SceneDelegate.swift')
scene = scene_path.read_text(encoding='utf-8')
if 'import Speech\n' not in scene:
    scene = replace_once(
        scene,
        'import Security\n',
        'import Security\nimport Speech\n',
        'Speech framework import',
    )
if 'private var speechTask: SFSpeechRecognitionTask?' not in scene:
    scene = replace_once(
        scene,
        '  private var mediaChannel: FlutterMethodChannel?\n',
        '  private var mediaChannel: FlutterMethodChannel?\n  private var speechTask: SFSpeechRecognitionTask?\n',
        'speech task state',
    )

media_else = '''      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    mediaChannel = channel
'''
media_transcription = '''      } else if call.method == "transcribeVideo" {
        guard
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          !path.isEmpty
        else {
          result(FlutterError(code: "INVALID_PATH", message: "Path is empty", details: nil))
          return
        }
        self.transcribeVideo(path: path, result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    mediaChannel = channel
'''
if 'call.method == "transcribeVideo"' not in scene:
    scene = replace_once(
        scene,
        media_else,
        media_transcription,
        'media transcription channel',
    )

speech_methods = r'''  private func transcribeVideo(path: String, result: @escaping FlutterResult) {
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

        guard let recognizer = SFSpeechRecognizer(locale: Locale.current), recognizer.isAvailable else {
          try? FileManager.default.removeItem(at: audioURL)
          DispatchQueue.main.async {
            result(FlutterError(
              code: "SPEECH_UNAVAILABLE",
              message: "Riconoscimento vocale non disponibile in questo momento.",
              details: nil
            ))
          }
          return
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        var completed = false
        self.speechTask?.cancel()
        self.speechTask = recognizer.recognitionTask(with: request) { response, error in
          if completed { return }
          if let response = response, response.isFinal {
            completed = true
            let transcription = response.bestTranscription
            let segments = transcription.segments.map { segment in
              return [
                "text": segment.substring,
                "start": segment.timestamp,
                "duration": segment.duration,
              ] as [String: Any]
            }
            try? FileManager.default.removeItem(at: audioURL)
            self.speechTask = nil
            DispatchQueue.main.async {
              result([
                "text": transcription.formattedString,
                "segments": segments,
              ])
            }
            return
          }
          if let error = error {
            completed = true
            try? FileManager.default.removeItem(at: audioURL)
            self.speechTask = nil
            DispatchQueue.main.async {
              result(FlutterError(
                code: "SPEECH_RECOGNITION_ERROR",
                message: error.localizedDescription,
                details: nil
              ))
            }
          }
        }
      }
    }
  }

  private func exportAudioForSpeech(
    videoURL: URL,
    completion: @escaping (URL?, Error?) -> Void
  ) {
    let asset = AVURLAsset(url: videoURL)
    guard let exporter = AVAssetExportSession(
      asset: asset,
      presetName: AVAssetExportPresetAppleM4A
    ) else {
      completion(nil, NSError(
        domain: "SIGILLUM",
        code: 20,
        userInfo: [NSLocalizedDescriptionKey: "Impossibile preparare l'audio del video."]
      ))
      return
    }

    let output = FileManager.default.temporaryDirectory.appendingPathComponent(
      "sigillum_speech_\(Int(Date().timeIntervalSince1970 * 1000)).m4a"
    )
    try? FileManager.default.removeItem(at: output)
    exporter.outputURL = output
    exporter.outputFileType = .m4a
    exporter.exportAsynchronously {
      switch exporter.status {
      case .completed:
        completion(output, nil)
      case .failed, .cancelled:
        completion(nil, exporter.error ?? NSError(
          domain: "SIGILLUM",
          code: 21,
          userInfo: [NSLocalizedDescriptionKey: "Estrazione audio non riuscita."]
        ))
      default:
        completion(nil, NSError(
          domain: "SIGILLUM",
          code: 22,
          userInfo: [NSLocalizedDescriptionKey: "Estrazione audio non completata."]
        ))
      }
    }
  }

'''
if 'private func transcribeVideo(path: String' not in scene:
    scene = replace_once(
        scene,
        '  private func installKeystoreChannelIfNeeded() {\n',
        speech_methods + '  private func installKeystoreChannelIfNeeded() {\n',
        'native speech methods',
    )
scene_path.write_text(scene, encoding='utf-8')


# ---------------------------------------------------------------------------
# Camera UI: add a post-certification transcription/subtitle action only.
# This patch deliberately does not alter capture, hashes, HCV claims, detector,
# signatures, Registry publication or verifier decisions.
# ---------------------------------------------------------------------------
camera_path = Path('lib/camera_page.dart')
camera = camera_path.read_text(encoding='utf-8')
if "import 'video_transcription_service.dart';" not in camera:
    camera = replace_once(
        camera,
        "import 'sigillum_localization.dart';\n",
        "import 'sigillum_localization.dart';\nimport 'video_transcription_service.dart';\n",
        'camera transcription service import',
    )
if 'bool _transcribingAudio = false;' not in camera:
    camera = replace_once(
        camera,
        '  String? createdContentKind;\n',
        '''  String? createdContentKind;
  bool _transcribingAudio = false;
  String? _videoTranscript;
  String? _subtitlePath;
''',
        'camera transcript state',
    )

transcription_methods = r'''  Future<void> _transcribeCreatedVideo() async {
    final path = videoPath;
    if (path == null || createdContentKind != 'video' || _transcribingAudio) return;
    setState(() {
      _transcribingAudio = true;
      status = 'TRASCRIZIONE AUDIO...';
    });
    try {
      final transcript = await const VideoTranscriptionService().transcribe(path);
      if (!mounted) return;
      setState(() {
        _videoTranscript = transcript.text;
        _subtitlePath = transcript.subtitlePath;
        status = 'TRASCRIZIONE PRONTA';
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Trascrizione audio'),
          content: SingleChildScrollView(
            child: SelectableText(
              transcript.text.isEmpty
                  ? 'Sottotitoli creati.'
                  : transcript.text,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CHIUDI'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => status = 'TRASCRIZIONE NON RIUSCITA: $error');
    } finally {
      if (mounted) setState(() => _transcribingAudio = false);
    }
  }

  Future<void> _shareSubtitleFile() async {
    final path = _subtitlePath;
    if (path == null) return;
    await Share.shareXFiles(
      [XFile(path, mimeType: 'application/x-subrip')],
      text: _videoTranscript == null || _videoTranscript!.isEmpty
          ? 'Sottotitoli SIGILLUM'
          : _videoTranscript!,
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }

'''
if 'Future<void> _transcribeCreatedVideo()' not in camera:
    camera = replace_once(
        camera,
        '  @override\n  void dispose() {\n',
        transcription_methods + '  @override\n  void dispose() {\n',
        'camera transcription methods',
    )

share_pack_block = '''        if (packagePath != null) ...[
          SizedBox(
            width: 300,
            child: ElevatedButton.icon(
              onPressed: sharePackage,
              icon: const Icon(Icons.inventory_2),
              label: Text(_t('shareOfflinePack')),
            ),
          ),
          const SizedBox(height: 10),
        ],
'''
transcript_buttons = '''        if (createdContentKind == 'video' && videoPath != null && Platform.isIOS) ...[
          SizedBox(
            width: 340,
            child: ElevatedButton.icon(
              onPressed: _transcribingAudio ? null : _transcribeCreatedVideo,
              icon: const Icon(Icons.subtitles_rounded),
              label: Text(
                _transcribingAudio
                    ? 'TRASCRIZIONE IN CORSO...'
                    : 'TRASCRIVI AUDIO / CREA SOTTOTITOLI',
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_subtitlePath != null)
            SizedBox(
              width: 340,
              child: OutlinedButton.icon(
                onPressed: _shareSubtitleFile,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('CONDIVIDI SOTTOTITOLI .SRT'),
              ),
            ),
          if (_subtitlePath != null) const SizedBox(height: 10),
        ],
'''
if 'TRASCRIVI AUDIO / CREA SOTTOTITOLI' not in camera:
    camera = replace_once(
        camera,
        share_pack_block,
        share_pack_block + transcript_buttons,
        'camera transcript buttons',
    )

# Safety assertions: this patch is auxiliary and must not rewrite HCV logic.
for token in [
    'VideoTranscriptionService',
    'TRASCRIVI AUDIO / CREA SOTTOTITOLI',
    'Future<void> _shareSubtitleFile()',
]:
    if token not in camera:
        raise RuntimeError(f'camera transcription token missing: {token}')
for forbidden in [
    'HCVDisplayRiskFusion.combine =',
    'HCVEngine().setClaims =',
    'verifyFile =',
]:
    if forbidden in camera:
        raise RuntimeError(f'engine mutation marker found: {forbidden}')
camera_path.write_text(camera, encoding='utf-8')


# Contract coverage generated after build-time patches are applied.
Path('test/prelaunch_product_refinement_contract_test.dart').write_text(
    r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account deletion exits and clears all commercial auth UI state', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    final profile = File('lib/commercial_profile_page.dart').readAsStringSync();
    final auth = File('lib/hcv_auth_service.dart').readAsStringSync();
    expect(gate, contains('void _resetLoggedOutState()'));
    expect(gate, contains('_email.clear()'));
    expect(gate, contains('_name.clear()'));
    expect(gate, contains('popUntil((route) => route.isFirst)'));
    expect(profile, contains('widget.onSessionInvalidated()'));
    expect(auth, contains('HCVIdentity().clearPersonalData()'));
  });

  test('existing and missing account flows do not dead-end', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    expect(gate, contains("error.code != 'ACCOUNT_ESISTENTE'"));
    expect(gate, contains('Questa email è già associata a un account.'));
    expect(gate, contains("error.code == 'ACCOUNT_NON_TROVATO'"));
  });

  test('login participates in one iOS AutoFill context', () {
    final gate = File('lib/commercial_gate.dart').readAsStringSync();
    expect(gate, contains('return AutofillGroup('));
    expect(gate, contains('AutofillHints.username'));
    expect(gate, contains('AutofillHints.password'));
    expect(gate, contains('AutofillHints.newPassword'));
  });

  test('plain text share is routed to the text social verifier', () {
    final home = File('lib/user_home_page.dart').readAsStringSync();
    expect(home, contains("lower.endsWith('.txt')"));
    expect(home, contains('TextSocialVerifyPage('));
    expect(home, contains('initialText: sharedText'));
  });

  test('video transcription is a sidecar and leaves HCV engine files untouched', () {
    final camera = File('lib/camera_page.dart').readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    final service = File('lib/video_transcription_service.dart').readAsStringSync();
    expect(camera, contains('TRASCRIVI AUDIO / CREA SOTTOTITOLI'));
    expect(scene, contains('call.method == "transcribeVideo"'));
    expect(scene, contains('SFSpeechURLRecognitionRequest'));
    expect(service, contains("_sigillum.srt"));
    expect(service, isNot(contains('HCVEngine')));
  });
}
''',
    encoding='utf-8',
)

print('Prelaunch account, text sharing, AutoFill and transcription refinements applied')
