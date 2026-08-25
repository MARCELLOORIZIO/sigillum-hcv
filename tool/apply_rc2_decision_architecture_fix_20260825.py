from pathlib import Path


LEGACY = Path('tool/apply_rc2_decision_architecture_fix_legacy_20260825.py')
if not LEGACY.exists():
    raise RuntimeError(f'decision architecture legacy finalizer missing: {LEGACY}')

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

print('RC2 formatting-insensitive decision finalizer PASS')
