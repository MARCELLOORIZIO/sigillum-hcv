from pathlib import Path
import re

ROOT=Path('lib'); LANGS=('it','en','es','ru')
PAGE_FILES=sorted({*ROOT.glob('*_page.dart'),ROOT/'commercial_gate.dart',ROOT/'home_page.dart',ROOT/'user_home_page.dart'})
PAGE_FILES=[p for p in PAGE_FILES if p.exists()]

def section(text,marker):
    pos=text.find(marker)
    if pos<0:return ''
    brace=text.find('{',pos+len(marker))
    if brace<0:return ''
    depth=0;ins=False;esc=False;q=''
    for i in range(brace,len(text)):
        c=text[i]
        if ins:
            if esc:esc=False
            elif c=='\\':esc=True
            elif c==q:ins=False
            continue
        if c in "'\"":ins=True;q=c;continue
        if c=='{':depth+=1
        elif c=='}':
            depth-=1
            if depth==0:return text[brace:i+1]
    return ''

def maps(path):
    t=path.read_text(encoding='utf-8');out={}
    for l in LANGS:
        s=section(t,f"'{l}':")
        out[l]=set(re.findall(r"(?m)^\s*'([^']+)'\s*:",s))
    return out

def parity(path,label=None):
    m=maps(path)
    if not any(m.values()):return None
    base=m['en'];problems=[]
    for l in LANGS:
        miss=sorted(base-m[l]);extra=sorted(m[l]-base)
        if miss or extra:problems.append(f'{l}:missing={miss},extra={extra}')
    print((label or path.as_posix()),{l:len(m[l]) for l in LANGS},'OK' if not problems else ' | '.join(problems))
    return m

print('## ALL MULTILINGUAL COPY MODULES')
copy_candidates=sorted({*ROOT.glob('*copy*.dart'),ROOT/'sigillum_localization.dart',ROOT/'verification_ui_copy.dart'})
for p in copy_candidates:
    parity(p)

print('\n## LOCAL PAGE/GATE MAPS')
for p in PAGE_FILES:
    t=p.read_text(encoding='utf-8')
    if all(f"'{l}':" in t for l in LANGS):parity(p)

print('\n## PAGE INVENTORY')
for p in PAGE_FILES: print(p.as_posix())

print('\n## HARDCODED LIKELY USER COPY')
assign=re.compile(r"(?:status|result|_error|_message|message|helperText|labelText|hintText|tooltip)\s*=\s*'([^']{3,})'|(?:status|result|_error|_message|message|helperText|labelText|hintText|tooltip)\s*:\s*'([^']{3,})'")
textpat=re.compile(r"\bText\(\s*'([^']{3,})'")
for p in PAGE_FILES:
    for i,line in enumerate(p.read_text(encoding='utf-8').splitlines(),1):
        vals=[];m=assign.search(line)
        if m:vals.append(m.group(1) or m.group(2))
        m=textpat.search(line)
        if m:vals.append(m.group(1))
        for v in vals:
            if '$' not in v and not v.startswith(('HCV-','http','SIGILLUM_')):print(f'{p.as_posix()}:{i}: {v}')

print('\n## STALE FLOW')
for phrase in ['muovi leggermente','move the phone slightly','mueve ligeramente','слегка перемещ','manual parallax','parallasse manuale']:
    for p in PAGE_FILES:
        if phrase.lower() in p.read_text(encoding='utf-8').lower():print(p.as_posix(),phrase)

print('\n## HUMAN/FORENSIC/SOCIAL VISIBLE TOKENS')
for p in PAGE_FILES+[ROOT/'camera_ui_copy.dart',ROOT/'verification_ui_copy.dart']:
    if not p.exists():continue
    for i,line in enumerate(p.read_text(encoding='utf-8').splitlines(),1):
        if any(k in line for k in ('HUMAN VERIFIED','FORENSIC VERIFIED','SOCIAL VERIFIED','MEDIA NOT VERIFIED')):print(f'{p.as_posix()}:{i}: {line.strip()}')

print('\n## QUALITY PROBES')
probes={'No determinable':"'compatible': 'No determinable'",'Espanol':"name: 'Espanol'",'Identita':"'identity': 'Identita'"}
for label,needle in probes.items():print(label,[p.name for p in ROOT.glob('*.dart') if needle in p.read_text(encoding='utf-8')])
print('AUDIT_DONE')
