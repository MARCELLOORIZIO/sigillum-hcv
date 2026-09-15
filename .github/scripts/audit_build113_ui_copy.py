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


def print_key_parity(title, path):
    maps = keys_for_map(path)
    base = maps['en']
    print(f'\n## {title}')
    print('counts', {k: len(v) for k,v in maps.items()})
    for lang in LANGS:
        missing = sorted(base - maps[lang])
        extra = sorted(maps[lang] - base)
        if missing or extra:
            print(f'{lang}: missing={missing} extra={extra}')
        else:
            print(f'{lang}: key parity OK')
    return maps

sig_maps = print_key_parity('SigillumCopy key parity', ROOT/'sigillum_localization.dart')
ver_maps = print_key_parity('VerificationUiCopy key parity', ROOT/'verification_ui_copy.dart')

print('\n## Page inventory')
for p in PAGE_FILES:
    print(p.as_posix())

all_sig_keys = set.intersection(*(sig_maps[l] for l in LANGS))
all_ver_keys = set.intersection(*(ver_maps[l] for l in LANGS))
used_sig = set()
used_ver = set()

print('\n## Missing localized keys referenced by pages')
missing_any = False
for p in PAGE_FILES:
    text = p.read_text(encoding='utf-8')
    sig = set(re.findall(r"(?:_t|SigillumCopy\.t\([^,]+,)\(?'([^']+)'\)?", text))
    # robust explicit patterns
    sig |= set(re.findall(r"_t\('([^']+)'\)", text))
    sig |= set(re.findall(r"SigillumCopy\.t\([^,]+,\s*'([^']+)'\)", text))
    ver = set(re.findall(r"_v\('([^']+)'\)", text))
    ver |= set(re.findall(r"VerificationUiCopy\.t\([^,]+,\s*'([^']+)'\)", text))
    used_sig |= sig
    used_ver |= ver
    ms = sorted(sig - all_sig_keys)
    mv = sorted(ver - all_ver_keys)
    if ms or mv:
        missing_any = True
        print(p.as_posix(), 'SigillumCopy missing', ms, 'VerificationUiCopy missing', mv)
if not missing_any:
    print('No missing referenced keys across IT/EN/ES/RU')

print('\n## Hard-coded user-facing strings in page/gate files')
patterns = [
    re.compile(r"\bText\(\s*'([^']{3,})'"),
    re.compile(r"\bText\(\s*\"([^\"]{3,})\""),
    re.compile(r"(?:labelText|hintText|helperText|tooltip|message|title)\s*:\s*'([^']{3,})'"),
]
for p in PAGE_FILES:
    lines = p.read_text(encoding='utf-8').splitlines()
    for idx,line in enumerate(lines,1):
        for pat in patterns:
            m = pat.search(line)
            if m:
                value = m.group(1)
                if '$' in value or value.startswith(('HCV-','http','SIGILLUM_')):
                    continue
                print(f'{p.as_posix()}:{idx}: {value}')

print('\n## Stale/manual-flow phrases')
stale = [
    'muovi leggermente', 'move the phone slightly', 'mueve ligeramente', 'слегка перемещ',
    'PROSEGUI', 'CONTINUE', 'CONTINUAR', 'ПРОДОЛЖИТЬ',
    'manual parallax', 'parallasse manuale',
]
for p in PAGE_FILES:
    text = p.read_text(encoding='utf-8')
    low = text.lower()
    for phrase in stale:
        if phrase.lower() in low:
            print(p.as_posix(), 'contains', phrase)

print('\n## Verification wording touching social/fingerprint/audio')
for p in [ROOT/'sigillum_localization.dart', ROOT/'verification_ui_copy.dart', ROOT/'sigillum_quick_guide_page.dart', ROOT/'registry_verify_page.dart', ROOT/'hcvpack_player_page.dart', ROOT/'hcvpack_provenance_gate_page.dart']:
    text = p.read_text(encoding='utf-8').splitlines()
    for idx,line in enumerate(text,1):
        low = line.lower()
        if any(k in low for k in ('fingerprint','impronta','huella','отпечат','social verified','forensic','audio')):
            print(f'{p.as_posix()}:{idx}: {line.strip()}')

print('\n## External URLs referenced by app pages/gates')
seen = set()
for p in PAGE_FILES:
    text = p.read_text(encoding='utf-8')
    for u in re.findall(r'https?://[^\s\'\"\)]+', text):
        if u not in seen:
            seen.add(u)
            print(p.as_posix(), u)
    for route in re.findall(r"'(/(?:privacy|terms|support|delete-data|verify)[^']*)'", text):
        print(p.as_posix(), 'API_ROUTE', route)

print('\n## Language declarations')
loc = (ROOT/'sigillum_localization.dart').read_text(encoding='utf-8')
langs = re.findall(r"SigillumLanguage\(code: '([^']+)', name: '([^']+)'", loc)
print(langs)

print('\n## Known copy-quality probes')
probes = {
    'English grammar typo No determinable': "'compatible': 'No determinable'",
    'Spanish language name without tilde': "name: 'Espanol'",
    'Italian identity without accent': "'identity': 'Identita'",
    'Legacy HUMAN VERIFIED wording': 'HUMAN VERIFIED',
    'Legacy standalone VALID wording': "'VALID'",
}
for label,needle in probes.items():
    hits=[]
    for p in ROOT.glob('*.dart'):
        text=p.read_text(encoding='utf-8')
        if needle in text:
            hits.append(p.name)
    print(label, hits)

print('\nAUDIT_DONE')
