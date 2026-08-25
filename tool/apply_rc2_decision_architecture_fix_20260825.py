from pathlib import Path
import re


LEGACY = Path('tool/apply_rc2_decision_architecture_fix_legacy_20260825.py')
if not LEGACY.exists():
    raise RuntimeError(f'decision architecture legacy finalizer missing: {LEGACY}')

# Historical photo patchers recognize only their original helper text and can
# therefore append another _hasRequiredParallax() after the stabilized helper
# has already been installed. Normalize that generated source before running
# the decision finalizer: when the stabilized helper exists, keep exactly that
# semantic implementation and remove every historical duplicate.
camera_path = Path('lib/camera_page.dart')
if camera_path.exists():
    camera_source = camera_path.read_text(encoding='utf-8')
    helper_pattern = re.compile(
        r"  bool _hasRequiredParallax\(Map<String, dynamic> probe\) \{.*?^  \}\n\n",
        re.MULTILINE | re.DOTALL,
    )
    matches = list(helper_pattern.finditer(camera_source))
    if len(matches) > 1:
        stabilized = [
            match.group(0)
            for match in matches
            if 'final realityGeometry = depthDispersion >= 0.28' in match.group(0)
            and 'final planarGeometry = depthDispersion <= 0.20' in match.group(0)
        ]
        if len(stabilized) != 1:
            raise RuntimeError(
                'parallax helper normalization could not identify exactly one '
                f'stabilized helper (helpers={len(matches)}, stabilized={len(stabilized)})'
            )
        insertion = matches[0].start()
        normalized = camera_source
        for match in reversed(matches):
            normalized = normalized[:match.start()] + normalized[match.end():]
        normalized = normalized[:insertion] + stabilized[0] + normalized[insertion:]
        camera_path.write_text(normalized, encoding='utf-8')
        print(
            f'Parallax helper normalized to one stabilized definition '
            f'(removed={len(matches) - 1})'
        )

source = LEGACY.read_text(encoding='utf-8')

old_helper = '''def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    source = file.read_text(encoding='utf-8')
    if new in source:
        print(f'{label}: already applied')
        return
    if source.count(old) != 1:
        raise RuntimeError(f'{label}: unexpected source state (old={source.count(old)}, new={source.count(new)})')
    file.write_text(source.replace(old, new, 1), encoding='utf-8')
    print(f'{label}: applied')
'''

new_helper = '''def _whitespace_insensitive_pattern(value: str) -> re.Pattern[str]:
    parts = re.split(r'(\\s+)', value)
    expression = ''.join(
        r'\\s+' if part.isspace() else re.escape(part)
        for part in parts
        if part
    )
    return re.compile(expression, re.MULTILINE)


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    source = file.read_text(encoding='utf-8')

    if new in source or _whitespace_insensitive_pattern(new).search(source):
        print(f'{label}: already applied')
        return

    old_pattern = _whitespace_insensitive_pattern(old)
    matches = list(old_pattern.finditer(source))
    if len(matches) != 1:
        raise RuntimeError(
            f'{label}: unexpected semantic source state '
            f'(old_matches={len(matches)}, new_match=0)'
        )

    match = matches[0]
    file.write_text(
        source[:match.start()] + new + source[match.end():],
        encoding='utf-8',
    )
    print(f'{label}: applied')
'''

if old_helper not in source:
    raise RuntimeError('decision architecture replace_once helper anchor missing')
source = source.replace(old_helper, new_helper, 1)

exec(
    compile(source, str(LEGACY), 'exec'),
    {'__name__': '__main__'},
)

# Fail closed if a historical patcher has still left more than one helper.
if camera_path.exists():
    final_camera = camera_path.read_text(encoding='utf-8')
    final_helpers = list(helper_pattern.finditer(final_camera))
    if len(final_helpers) != 1:
        raise RuntimeError(
            f'parallax helper final count must be 1; got {len(final_helpers)}'
        )
    if 'final realityGeometry = depthDispersion >= 0.28' not in final_helpers[0].group(0):
        raise RuntimeError('stabilized geometry-observable parallax helper missing')

print('RC2 formatting-insensitive decision finalizer PASS')
