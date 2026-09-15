from pathlib import Path
import re

ROOT = Path('lib')
PAGE_FILES = sorted({
    *ROOT.glob('*_page.dart'),
    ROOT / 'commercial_gate.dart',
    ROOT / 'home_page.dart',
    ROOT / 'user_home_page.dart',
})
PAGE_FILES = [p for p in PAGE_FILES if p.exists()]
LANGS = ('it','en','es','ru')


def section(text: str, marker: str) -> str:
    pos = text.find(marker)
    if pos < 0:
        return ''
    brace = text.find('{', pos + len(marker))
    if brace < 0:
        return ''
    depth = 0
    in_string = False
    escaped = False
    quote = ''
    for i in range(brace, len(text)):
        c = text[i]
        if in_string:
            if escaped:
                escaped = False
            elif c == '\\':
                escaped = True
            elif c == quote:
                in_string = False
            continue
        if c in "'\"":
            in_string = True
            quote = c
            continue
        if c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return text[brace:i+1]
    return ''


def keys_for_map(path: Path):
    text = path.read_text(encoding='utf-8')
    result = {}
    for lang in LANGS:
        s = section(text, f"'{lang}':")
        result[lang] = set(re.findall(r"(?m)^\s*'([^']+)'\s*:", s))
    return result


def report_parity(label, path):
    maps = keys_for_map(path)
    if not any(maps.values()):
        return None
    print(f'\n## {label}')
    print('counts', {k: len(v) for k,v in maps.items()})
    base = maps['en']
    for lang in LANGS:
        missing = sorted(base - maps[lang])
        extra = sorted(maps[lang] - base)
        print(f'{lang}: ' + ('key parity OK' if not missing and not extra else f'missing={missing} extra={extra}'))
    return maps

sig_maps = report_parity('SigillumCopy key parity', ROOT/'sigillum_localization.dart')
ver_maps = report_parity('VerificationUiCopy key parity', ROOT/'verification_ui_copy.dart')

print('\n## Local page/gate language-map parity')
for p in PAGE_FILES:
    text = p.read_text(encoding='utf-8')
    if all(f"'{lang}':" in text for lang in LANGS):
        maps = keys_for_map(p)
        if any(maps.values()):
            base = maps['en']
            problems=[]
            for lang in LANGS:
                missing=sorted(base-maps[lang]); extra=sorted(maps[lang]-base)
                if missing or extra: problems.append(f'{lang}:missing={missing},extra={extra}')
            print(p.as_posix(), {k:len(v) for k,v in maps.items()}, 'OK' if not problems else ' | '.join(problems))

print('\n## Page inventory')
for p in PAGE_FILES:
    print(p.as_posix())

all_sig_keys = set.intersection(*(sig_maps[l] for l in LANGS)) if sig_maps else set()
all_ver_keys = set.intersection(*(ver_maps[l] for l in LANGS)) if ver_maps else set()

print('\n## Central-copy references that are actually missing')
for p in PAGE_FILES:
    text = p.read_text(encoding='utf-8')
    # Pages with their own _copy map resolve _t locally; do not misclassify them as SigillumCopy.
    has_local_copy = "static const Map<String, Map<String, String>> _copy" in text
    sig = set(re.findall(r"SigillumCopy\.t\([^,]+,\s*'([^']+)'\)", text))
    if not has_local_copy:
        sig |= set(re.findall(r"_t\('([^']+)'\)", text))
    ver = set(re.findall(r"VerificationUiCopy\.t\([^,]+,\s*'([^']+)'\)", text))
    ver |= set(re.findall(r"_v\('([^']+)'\)", text))
    ms=sorted(sig-all_sig_keys); mv=sorted(ver-all_ver_keys)
    if ms or mv:
        print(p.as_posix(), 'SigillumCopy', ms, 'VerificationUiCopy', mv)

print('\n## Hard-coded likely user-facing strings outside language maps')
assignment_re = re.compile(r"(?:status|result|_error|_message|message|helperText|labelText|hintText|tooltip)\s*=\s*'([^']{3,})'|(?:status|result|_error|_message|message|helperText|labelText|hintText|tooltip)\s*:\s*'([^']{3,})'")
text_re = re.compile(r"\bText\(\s*'([^']{3,})'")
for p in PAGE_FILES:
    lines=p.read_text(encoding='utf-8').splitlines()
    # Skip language-map bodies only heuristically by reporting strings that occur outside known lang blocks less often;
    # dedupe by line/value and leave manual classification to audit.
    for i,line in enumerate(lines,1):
        vals=[]
        m=assignment_re.search(line)
        if m: vals.append(m.group(1) or m.group(2))
        m=text_re.search(line)
        if m: vals.append(m.group(1))
        for v in vals:
            if '$' in v or v.startswith(('HCV-','http','SIGILLUM_')): continue
            print(f'{p.as_posix()}:{i}: {v}')

print('\n## Explicit verification/result hardcoded copy')
for p in [ROOT/'registry_verify_page.dart', ROOT/'hcvpack_player_page.dart', ROOT/'video_verify_page.dart', ROOT/'video_player_verify_page.dart', ROOT/'verifier_page.dart', ROOT/'verify_page.dart']:
    if not p.exists(): continue
    for i,line in enumerate(p.read_text(encoding='utf-8').splitlines(),1):
        if any(k in line for k in ('FORENSIC VERIFIED','SOCIAL VERIFIED','HUMAN VERIFIED','MEDIA NOT VERIFIED','VALID\\n','INVALID\\n')):
            print(f'{p.as_posix()}:{i}: {line.strip()}')

print('\n## Stale/manual-flow phrases')
stale = [
    'muovi leggermente', 'move the phone slightly', 'mueve ligeramente', 'слегка перемещ',
    'manual parallax', 'parallasse manuale',
]
for p in PAGE_FILES:
    text=p.read_text(encoding='utf-8').lower()
    for phrase in stale:
        if phrase.lower() in text: print(p.as_posix(),'contains',phrase)

print('\n## Verification wording touching social/fingerprint/audio')
for p in [ROOT/'sigillum_localization.dart', ROOT/'verification_ui_copy.dart', ROOT/'sigillum_quick_guide_page.dart', ROOT/'registry_verify_page.dart', ROOT/'hcvpack_player_page.dart']:
    if not p.exists(): continue
    for i,line in enumerate(p.read_text(encoding='utf-8').splitlines(),1):
        low=line.lower()
        if any(k in low for k in ('fingerprint','impronta','huella','отпечат','social verified','forensic','audio')):
            print(f'{p.as_posix()}:{i}: {line.strip()}')

print('\n## External URLs and routes')
seen=set()
for p in PAGE_FILES:
    text=p.read_text(encoding='utf-8')
    for u in re.findall(r'https?://[^\s\'\"\)]+',text):
        if u not in seen:
            seen.add(u); print(p.as_posix(),u)
    for route in re.findall(r"'(/(?:privacy|terms|support|delete-data|verify)[^']*)'",text):
        print(p.as_posix(),'API_ROUTE',route)

print('\n## Language declarations and quality probes')
loc=(ROOT/'sigillum_localization.dart').read_text(encoding='utf-8')
print(re.findall(r"SigillumLanguage\(code: '([^']+)', name: '([^']+)'",loc))
probes={
 'English grammar typo No determinable':"'compatible': 'No determinable'",
 'Spanish language name without tilde':"name: 'Espanol'",
 'Italian identity without accent':"'identity': 'Identita'",
}
for label,needle in probes.items():
    hits=[p.name for p in ROOT.glob('*.dart') if needle in p.read_text(encoding='utf-8')]
    print(label,hits)

print('\nAUDIT_DONE')
