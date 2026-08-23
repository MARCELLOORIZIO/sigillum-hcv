from pathlib import Path

path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')

old_times = """    final times = [
      '00:00:00.2',
      '00:00:00.8',
      '00:00:01.5',
      '00:00:02.5',
      '00:00:04.0',
      '00:00:06.0',
      '00:00:08.0',
    ];"""
new_times = """    // Fast pre-check only: SIGILLUM watermark/HCV-ID should be visible
    // immediately. Do not scan the whole video when the ID is absent.
    final times = [
      '00:00:00.2',
      '00:00:00.8',
    ];"""
if old_times in source:
    source = source.replace(old_times, new_times, 1)
elif new_times not in source:
    raise RuntimeError('video OCR time-list anchor missing')

loop_old = """    for (final time in times) {
      try {"""
loop_new = """    for (final time in times) {
      if (!mounted) return null;
      try {"""
if loop_old in source:
    source = source.replace(loop_old, loop_new, 1)
elif loop_new not in source:
    raise RuntimeError('video OCR loop anchor missing')

# Avoid loading complete media files into RAM when the user selects a new file
# from the verification page.
if 'withData: true,' in source:
    source = source.replace('withData: true,', 'withData: false,', 1)
elif 'withData: false,' not in source:
    raise RuntimeError('FilePicker withData anchor missing')

old_start = "status = 'File ricevuto. Lettura HCV-ID e verifica automatica...';"
new_start = "status = 'Controllo rapido SIGILLUM in corso...';"
if old_start in source:
    source = source.replace(old_start, new_start, 1)
elif new_start not in source:
    raise RuntimeError('automatic verification start-status anchor missing')

old_missing = """status =
              'File ricevuto, ma HCV-ID non rilevato automaticamente. Inseriscilo e premi VERIFICA DA REGISTRY.';"""
new_missing = """status = 'Contenuto non certificato SIGILLUM.';"""
if old_missing in source:
    source = source.replace(old_missing, new_missing, 1)
elif new_missing not in source:
    raise RuntimeError('missing HCV-ID status anchor missing')

required = [
    "'00:00:00.2'",
    "'00:00:00.8'",
    'if (!mounted) return null;',
    'withData: false,',
    "status = 'Controllo rapido SIGILLUM in corso...';",
    "status = 'Contenuto non certificato SIGILLUM.';",
]
for token in required:
    if token not in source:
        raise RuntimeError(f'fast media pre-check token missing: {token}')

for forbidden in [
    "'00:00:01.5'",
    "'00:00:02.5'",
    "'00:00:04.0'",
    "'00:00:06.0'",
    "'00:00:08.0'",
    'withData: true,',
]:
    if forbidden in source:
        raise RuntimeError(f'slow media pre-check token still present: {forbidden}')

path.write_text(source, encoding='utf-8')
print('Fast uncertified-media pre-check applied: max two early video frames, no full-file RAM load')
