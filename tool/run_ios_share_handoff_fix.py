from pathlib import Path
import re
import runpy

patch_path = Path("tool/apply_ios_share_handoff_fix.py")
source = patch_path.read_text()

unsafe = "updated, count = re.subn(pattern, replacement, source, count=1, flags=re.S)"
safe = "updated, count = re.subn(pattern, lambda _: replacement, source, count=1, flags=re.S)"

if unsafe in source:
    source = source.replace(unsafe, safe, 1)
elif safe not in source:
    raise RuntimeError("Unable to install safe regex replacement mode")

patch_path.write_text(source)
runpy.run_path(str(patch_path), run_name="__main__")

swift_path = Path("ios/SigillumShareExtension/ShareViewController.swift")
swift = swift_path.read_text()

# A Share Extension is not permitted to open its containing app reliably.
# Keep the shared file pending and instruct the user to close the sheet and
# open Fotocamera Sigillum, which consumes the pending path automatically.
manual_handoff_block = r'''  private func openHostAppAndFinish() {
    DispatchQueue.main.async {
      self.statusLabel?.text =
        "Contenuto salvato in Fotocamera Sigillum.\nTocca CHIUDI, poi apri Fotocamera Sigillum: la verifica partirà automaticamente."
      self.openButton?.setTitle("CHIUDI", for: .normal)
      self.openButton?.isHidden = false
      self.openButton?.isEnabled = true
    }
  }

  @objc private func openButtonTapped() {
    finish()
  }

'''

pattern = (
    r"  private func openHostAppAndFinish\(\) \{.*?"
    r"\n  private func showOpenFailed\(\)"
)
swift, count = re.subn(
    pattern,
    lambda _: manual_handoff_block + "  private func showOpenFailed()",
    swift,
    count=1,
    flags=re.S,
)
if count != 1:
    raise RuntimeError("Unable to replace unsupported Share Extension app opening")

swift = swift.replace("  private var pendingOpenUrl: URL?\n", "")
swift = swift.replace(
    'button.setTitle("APRI SIGILLUM", for: .normal)',
    'button.setTitle("CHIUDI", for: .normal)',
)

failed_pattern = r"  private func showOpenFailed\(\) \{.*?\n  \}\n\n  private func finish"
failed_replacement = r'''  private func showOpenFailed() {
    statusLabel?.text =
      "Contenuto salvato in Fotocamera Sigillum.\nTocca CHIUDI, poi apri Fotocamera Sigillum: la verifica partirà automaticamente."
    openButton?.setTitle("CHIUDI", for: .normal)
    openButton?.isHidden = false
    openButton?.isEnabled = true
  }

  private func finish'''
swift, count = re.subn(
    failed_pattern,
    lambda _: failed_replacement,
    swift,
    count=1,
    flags=re.S,
)
if count != 1:
    raise RuntimeError("Unable to install reliable Share Extension completion state")

swift_path.write_text(swift)

bad_fragments = [
    'extensionContext?.open(',
    'openUrlViaResponderChain',
    'NSSelectorFromString("openURL:")',
    'APRI SIGILLUM',
]
for fragment in bad_fragments:
    if fragment in swift:
        raise RuntimeError(
            f"Unsupported app-opening code remains in Share Extension: {fragment}"
        )

required_fragments = [
    '"Contenuto salvato in Fotocamera Sigillum.\\nTocca CHIUDI, poi apri Fotocamera Sigillum: la verifica partirà automaticamente."',
    'button.setTitle("CHIUDI", for: .normal)',
    "defaults?.set(destination.path, forKey: sharedPathKey)",
]
for fragment in required_fragments:
    if fragment not in swift:
        raise RuntimeError(
            f"Expected reliable Share Extension fragment not generated: {fragment}"
        )

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

    test('share extension does not attempt an unsupported app launch', () {
      expect(extension, isNot(contains('extensionContext?.open(')));
      expect(extension, isNot(contains('openUrlViaResponderChain')));
      expect(extension, isNot(contains('NSSelectorFromString("openURL:")')));
      expect(extension, isNot(contains('APRI SIGILLUM')));
    });

    test('share extension saves the file and presents a clear close action', () {
      expect(extension, contains('Contenuto salvato in Fotocamera Sigillum'));
      expect(extension, contains('la verifica partirà automaticamente'));
      expect(extension, contains('setTitle("CHIUDI", for: .normal)'));
      expect(
        extension,
        contains('defaults?.set(destination.path, forKey: sharedPathKey)'),
      );
    });

    test('native path remains pending until Flutter acquires it', () {
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

print(
    "Reliable iOS share handoff installed: pending file plus automatic verification on app open"
)
