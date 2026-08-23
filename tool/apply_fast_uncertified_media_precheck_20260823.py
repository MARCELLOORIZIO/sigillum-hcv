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

# A missing HCV-ID is a clean negative pre-check, not a red forensic verdict.
negative_result_old = """result = 'NOT ANALYZED';
          status = 'Contenuto non certificato SIGILLUM.';"""
negative_result_new = """result = null;
          status = 'Contenuto non certificato SIGILLUM.';"""
if negative_result_old in source:
    source = source.replace(negative_result_old, negative_result_new, 1)

# Consumer-facing verification shell: match the public SIGILLUM visual language
# without altering Registry, signature, hash or fingerprint verification logic.
scaffold_old = """    return Scaffold(
      appBar: AppBar(
        title: Text(_t('verifyContentHeading')),
      ),
      body: Center("""
scaffold_new = """    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF35106F),
        elevation: 0,
        title: Text(
          _t('verifyContentHeading'),
          style: const TextStyle(
            color: Color(0xFF35106F),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Center("""
if scaffold_old in source:
    source = source.replace(scaffold_old, scaffold_new, 1)
elif scaffold_new not in source:
    raise RuntimeError('verification scaffold visual anchor missing')

# Do not expose iOS sandbox paths to the user.
media_path_block = """              if (mediaPath != null) ...[
                const SizedBox(height: 8),
                Text(
                  mediaPath!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
"""
if media_path_block in source:
    source = source.replace(media_path_block, '', 1)

select_button_old = """              ElevatedButton(
                onPressed: loading ? null : pickMedia,
                child: Text(_t('selectOriginalMedia')),
              ),"""
select_button_new = """              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25C2CE),
                    foregroundColor: const Color(0xFF35106F),
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  onPressed: loading ? null : pickMedia,
                  child: Text(_t('selectOriginalMedia')),
                ),
              ),"""
if select_button_old in source:
    source = source.replace(select_button_old, select_button_new, 1)
elif select_button_new not in source:
    raise RuntimeError('select-media button visual anchor missing')

verify_button_old = """              ElevatedButton(
                onPressed: loading ? null : verifyFromRegistry,
                child: Text(
                  loading ? _t('verifyingShort') : _t('verifyFromRegistry'),
                ),
              ),"""
verify_button_new = """              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25C2CE),
                    foregroundColor: const Color(0xFF35106F),
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  onPressed: loading ? null : verifyFromRegistry,
                  child: Text(
                    loading ? _t('verifyingShort') : _t('verifyFromRegistry'),
                  ),
                ),
              ),"""
if verify_button_old in source:
    source = source.replace(verify_button_old, verify_button_new, 1)
elif verify_button_new not in source:
    raise RuntimeError('verify button visual anchor missing')

card_old = """      decoration: BoxDecoration(
        color: const Color(0xFF111A17),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),"""
card_new = """      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E3F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),"""
if card_old in source:
    source = source.replace(card_old, card_new, 1)
elif card_new not in source:
    raise RuntimeError('verification card visual anchor missing')

required = [
    "'00:00:00.2'",
    "'00:00:00.8'",
    'if (!mounted) return null;',
    'withData: false,',
    "status = 'Controllo rapido SIGILLUM in corso...';",
    "status = 'Contenuto non certificato SIGILLUM.';",
    'backgroundColor: const Color(0xFFF8F7FB),',
    'backgroundColor: const Color(0xFF25C2CE),',
    'borderRadius: BorderRadius.circular(20),',
]
for token in required:
    if token not in source:
        raise RuntimeError(f'fast media/verification-shell token missing: {token}')

for forbidden in [
    "'00:00:01.5'",
    "'00:00:02.5'",
    "'00:00:04.0'",
    "'00:00:06.0'",
    "'00:00:08.0'",
    'withData: true,',
    'mediaPath!,\n                  textAlign: TextAlign.center,\n                  style: const TextStyle(fontSize: 11)',
]:
    if forbidden in source:
        raise RuntimeError(f'slow/technical verification token still present: {forbidden}')

path.write_text(source, encoding='utf-8')
print('Fast uncertified-media pre-check and consumer verification shell applied')
