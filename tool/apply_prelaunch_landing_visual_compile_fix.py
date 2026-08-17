from pathlib import Path

path = Path('lib/commercial_gate.dart')
source = path.read_text(encoding='utf-8')

# re.sub replacement processing in the visual patch may materialize the intended
# Dart \n escape as a physical newline inside the single-quoted demo HCV-ID.
# Normalize only that presentation literal; no capture/HCV/Registry code touched.
broken = "'ID SIGILLUM\nF80B0A573FBB4940'"
fixed = "'ID SIGILLUM\\nF80B0A573FBB4940'"

if broken in source:
    source = source.replace(broken, fixed, 1)

if fixed not in source:
    raise RuntimeError('approved landing HCV-ID display literal missing')

path.write_text(source, encoding='utf-8')
print('Approved landing visual Dart literal compile fix applied')
