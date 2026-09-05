from pathlib import Path
import re

CAMERA = Path('lib/camera_page.dart')
TEST = Path('test/camera_capture_lifecycle_contract_test.dart')

source = CAMERA.read_text(encoding='utf-8')


def sub_once(pattern: str, replacement: str, label: str, flags: int = 0) -> None:
    global source
    source, count = re.subn(pattern, replacement, source, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')


sub_once(
    r"^\s*var restoredFlashStateBeforeCapture = 'NOT_ATTEMPTED';\n",
    '',
    'remove HFR flash metadata state',
    re.MULTILINE,
)

sub_once(
    r"(?P<i>\s*)try \{\n"
    r"(?P=i)  await replacement\.setFlashMode\(savedFlash\);\n"
    r"(?P=i)  restoredFlashStateBeforeCapture =\n"
    r"(?P=i)      savedFlash == FlashMode\.torch \? 'torch' : 'off';\n"
    r"(?P=i)\} catch \(error\) \{\n"
    r"(?P=i)  restoredFlashStateBeforeCapture = 'RESTORE_FAILED';\n"
    r"(?P=i)  throw StateError\('USER_FLASH_RESTORE_AFTER_NATIVE_PROBE_FAILED: \$error'\);\n"
    r"(?P=i)\}",
    "      try {\n        await replacement.setFlashMode(savedFlash);\n      } catch (_) {}",
    'restore native probe flash behavior',
)

sub_once(
    r"\s*probe = <String, dynamic>\{\n"
    r"\s*\.\.\.probe,\n"
    r"\s*'requestedFlashStateBeforeProbe':\n"
    r"\s*savedFlash == FlashMode\.torch \? 'torch' : 'off',\n"
    r"\s*'actualTorchStateDuringProbe': 'NOT_VERIFIED_NATIVE_SESSION',\n"
    r"\s*'restoredFlashStateBeforeCapture': restoredFlashStateBeforeCapture,\n"
    r"\s*if \(savedFlash == FlashMode\.torch\) \.\.\.\{\n"
    r"\s*'captureLightingComparable': false,\n"
    r"\s*'nonComparableReason':\n"
    r"\s*'USER_TORCH_ACTIVE_NATIVE_HFR_LIGHTING_NOT_VERIFIED',\n"
    r"\s*'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL',\n"
    r"\s*\},\n"
    r"\s*\};\n"
    r"\s*return probe;",
    "\n    return probe;",
    'remove HFR torch metadata',
)

sub_once(
    r"\} catch \(error\) \{\n\s*throw StateError\('USER_FLASH_RESTORE_BEFORE_PHOTO_FAILED: \$error'\);\n\s*\}",
    '} catch (_) {}',
    'restore photo flash behavior',
)

for forbidden in (
    'actualTorchStateDuringProbe',
    'captureLightingComparable',
    'USER_TORCH_ACTIVE_NATIVE_HFR_LIGHTING_NOT_VERIFIED',
    'USER_FLASH_RESTORE_AFTER_NATIVE_PROBE_FAILED',
    'USER_FLASH_RESTORE_BEFORE_PHOTO_FAILED',
):
    if forbidden in source:
        raise SystemExit(f'out-of-scope torch/HFR marker still present: {forbidden}')

CAMERA.write_text(source, encoding='utf-8')

t = TEST.read_text(encoding='utf-8')
t = t.replace(
    "test('capture controls and torch handoff are guarded', () {",
    "test('capture controls are guarded', () {",
)
lines = []
for line in t.splitlines(keepends=True):
    if any(
        marker in line
        for marker in (
            'actualTorchStateDuringProbe',
            "'decisionRole': 'SHADOW_ONLY_NEVER_DECISIONAL'",
            'USER_FLASH_RESTORE_AFTER_NATIVE_PROBE_FAILED',
            'USER_FLASH_RESTORE_BEFORE_PHOTO_FAILED',
        )
    ):
        continue
    lines.append(line)
TEST.write_text(''.join(lines), encoding='utf-8')

print('Restored HFR/torch behavior to BUILD92 scope')
