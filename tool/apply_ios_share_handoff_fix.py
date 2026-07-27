from pathlib import Path
import re


def replace_regex(path_name: str, pattern: str, replacement: str, marker: str) -> None:
    path = Path(path_name)
    source = path.read_text()
    if marker in source:
        return
    updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(
            f"{path_name}: expected one match for share handoff patch, found {count}"
        )
    path.write_text(updated)


def replace_text(path_name: str, old: str, new: str, marker: str) -> None:
    path = Path(path_name)
    source = path.read_text()
    if marker in source:
        return
    if source.count(old) != 1:
        raise RuntimeError(
            f"{path_name}: expected one exact match for share handoff patch"
        )
    path.write_text(source.replace(old, new, 1))


# Share extension: never auto-close before a real user gesture.
replace_regex(
    "ios/SigillumShareExtension/ShareViewController.swift",
    r"  private func openHostAppAndFinish\(\) \{.*?\n  \}\n\n  @objc private func openButtonTapped",
    '''  private func openHostAppAndFinish() {
    DispatchQueue.main.async {
      guard let url = URL(string: "\\(self.urlScheme)://shared") else {
        self.showOpenFailed()
        return
      }

      self.pendingOpenUrl = url
      self.statusLabel?.text = "Contenuto pronto.\\nTocca APRI SIGILLUM per verificare."
      self.openButton?.isHidden = false
      self.openButton?.isEnabled = true
    }
  }

  @objc private func openButtonTapped''',
    "self.openButton?.isEnabled = true\n    }\n  }\n\n  @objc private func openButtonTapped",
)

replace_regex(
    "ios/SigillumShareExtension/ShareViewController.swift",
    r"  @objc private func openButtonTapped\(\) \{.*?\n  \}\n\n  private func openUrlViaResponderChain",
    '''  @objc private func openButtonTapped() {
    guard let url = pendingOpenUrl else {
      showOpenFailed()
      return
    }

    statusLabel?.text = "Apertura di SIGILLUM..."
    openButton?.isEnabled = false
    openUrl(url)
  }

  private func openUrl(_ url: URL) {
    extensionContext?.open(url) { success in
      DispatchQueue.main.async {
        if success {
          self.statusLabel?.text = "SIGILLUM in apertura..."
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.finish()
          }
          return
        }

        if self.openUrlViaResponderChain(url) {
          self.statusLabel?.text = "SIGILLUM in apertura..."
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if self.view.window != nil {
              self.showOpenFailed()
            }
          }
        } else {
          self.showOpenFailed()
        }
      }
    }
  }

  private func openUrlViaResponderChain''',
    "private func openUrl(_ url: URL)",
)

replace_regex(
    "ios/SigillumShareExtension/ShareViewController.swift",
    r"  private func showOpenFailed\(\) \{.*?\n  \}\n\n  private func finish",
    '''  private func showOpenFailed() {
    statusLabel?.text =
      "Contenuto salvato.\\nTocca di nuovo APRI SIGILLUM oppure apri SIGILLUM manualmente."
    openButton?.isHidden = false
    openButton?.isEnabled = true
  }

  private func finish''',
    "Tocca di nuovo APRI SIGILLUM",
)

# Native handoff: keep the path pending until Flutter explicitly acknowledges it.
scene_handler_old = '''      if call.method == "getSharedPath" {
        if let path = self.consumeSharedPath() {
          self.lastDeliveredSharedPath = path
          result(path)
        } else {
          result(nil)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
'''
scene_handler_new = '''      if call.method == "getSharedPath" {
        if let path = self.consumeSharedPath() {
          self.lastDeliveredSharedPath = path
          result(path)
        } else {
          result(nil)
        }
      } else if call.method == "ackSharedPath" {
        let args = call.arguments as? [String: Any]
        let acknowledgedPath = args?["path"] as? String
        let pendingPath = UserDefaults.standard.string(forKey: "hcv.sharedPath")
        if acknowledgedPath == nil || acknowledgedPath == pendingPath {
          UserDefaults.standard.removeObject(forKey: "hcv.sharedPath")
        }
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
'''
replace_text(
    "ios/Runner/SceneDelegate.swift",
    scene_handler_old,
    scene_handler_new,
    'call.method == "ackSharedPath"',
)

replace_regex(
    "ios/Runner/SceneDelegate.swift",
    r"  override func sceneDidBecomeActive\(_ scene: UIScene\) \{.*?\n  \}\n\n  private func installIntentChannel",
    '''  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    installIntentChannel()
    stageSharedPathFromAppGroupIfNeeded()

    if let path = UserDefaults.standard.string(forKey: "hcv.sharedPath"),
       !path.isEmpty {
      deliverSharedPath(path)
    }
  }

  private func installIntentChannel''',
    "stageSharedPathFromAppGroupIfNeeded()",
)

replace_regex(
    "ios/Runner/SceneDelegate.swift",
    r"  private func deliverSharedPath\(_ path: String\) \{.*?\n  \}\n\n  private func consumeSharedPath",
    '''  private func deliverSharedPath(_ path: String) {
    guard !path.isEmpty else {
      return
    }

    UserDefaults.standard.removeObject(forKey: sharedPathKey)
    UserDefaults.standard.set(path, forKey: "hcv.sharedPath")
    UserDefaults.standard.synchronize()
    lastDeliveredSharedPath = path

    guard intentChannel != nil else {
      return
    }

    intentChannel?.invokeMethod("onSharedPath", arguments: path)
  }

  private func stageSharedPathFromAppGroupIfNeeded() {
    guard
      let defaults = UserDefaults(suiteName: appGroupId),
      let path = defaults.string(forKey: sharedPathKey),
      !path.isEmpty
    else {
      return
    }

    UserDefaults.standard.set(path, forKey: "hcv.sharedPath")
    UserDefaults.standard.synchronize()
    defaults.removeObject(forKey: sharedPathKey)
  }

  private func consumeSharedPath''',
    "private func stageSharedPathFromAppGroupIfNeeded()",
)

# Flutter receivers: acknowledge warm-app delivery and suppress duplicate navigation.
for file_name in ["lib/user_home_page.dart", "lib/home_page.dart"]:
    path = Path(file_name)
    source = path.read_text()

    channel_line = "  static const MethodChannel _intentChannel = MethodChannel('hcv.intent');\n"
    if "String? _lastOpenedSharedPath;" not in source:
        if source.count(channel_line) != 1:
            raise RuntimeError(f"{file_name}: intent channel declaration not found")
        source = source.replace(
            channel_line,
            channel_line + "  String? _lastOpenedSharedPath;\n",
            1,
        )

    if "'ackSharedPath'" not in source:
        handler_pattern = (
            r"  Future<dynamic> _handleNativeIntent\(MethodCall call\) async \{"
            r".*?"
            r"\n  \}\n\n  Future<void> _checkInitialIntent"
        )
        handler_replacement = '''  Future<dynamic> _handleNativeIntent(MethodCall call) async {
    if (call.method == 'onSharedPath') {
      final path = call.arguments as String?;
      if (path != null && path.isNotEmpty) {
        _openImportedPath(path);
        try {
          await _intentChannel.invokeMethod<bool>(
            'ackSharedPath',
            {'path': path},
          );
        } catch (_) {}
      }
    }
  }

  Future<void> _checkInitialIntent'''
        source, count = re.subn(
            handler_pattern,
            handler_replacement,
            source,
            count=1,
            flags=re.S,
        )
        if count != 1:
            raise RuntimeError(f"{file_name}: native intent handler not found")

    if "_lastOpenedSharedPath == path" not in source:
        open_pattern = (
            r"(  void _openImportedPath\(String path\) \{\n)"
            r"    if \(!mounted\) return;"
        )
        open_replacement = (
            r"\1"
            "    if (!mounted || path.isEmpty || _lastOpenedSharedPath == path) return;\n"
            "    _lastOpenedSharedPath = path;"
        )
        source, count = re.subn(open_pattern, open_replacement, source, count=1)
        if count != 1:
            raise RuntimeError(f"{file_name}: imported path guard not found")

    path.write_text(source)

Path("test/ios_share_handoff_contract_test.dart").write_text(
    '''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iOS share handoff', () {
    final extension = File(
      'ios/SigillumShareExtension/ShareViewController.swift',
    ).readAsStringSync();
    final scene = File('ios/Runner/SceneDelegate.swift').readAsStringSync();
    final userHome = File('lib/user_home_page.dart').readAsStringSync();
    final labHome = File('lib/home_page.dart').readAsStringSync();

    test('extension waits for an explicit user tap', () {
      expect(extension, contains('Tocca APRI SIGILLUM'));
      expect(extension, contains('openButton?.isEnabled = true'));
      expect(extension, isNot(contains('.now() + 0.6')));
      expect(extension, isNot(contains('finishOnSuccess')));
    });

    test('native path remains pending until Flutter acknowledges it', () {
      expect(scene, contains('stageSharedPathFromAppGroupIfNeeded'));
      expect(scene, contains('ackSharedPath'));
      expect(
        scene,
        contains('UserDefaults.standard.set(path, forKey: "hcv.sharedPath")'),
      );
    });

    test('both Flutter entry pages acknowledge and deduplicate the path', () {
      for (final source in [userHome, labHome]) {
        expect(source, contains("'ackSharedPath'"));
        expect(source, contains('_lastOpenedSharedPath'));
        expect(source, contains("{'path': path}"));
      }
    });
  });
}
'''
)

print("Reliable iOS share handoff patch applied")
