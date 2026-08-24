from pathlib import Path

path = Path('lib/registry_verify_page.dart')
source = path.read_text(encoding='utf-8')

# Keep the Registry verification screen on the exact public SIGILLUM theme.
theme_import = "import 'sigillum_theme.dart';\n"
if theme_import not in source:
    anchor = "import 'sigillum_localization.dart';\n"
    if anchor not in source:
        raise RuntimeError('SIGILLUM theme import anchor missing')
    source = source.replace(anchor, anchor + theme_import, 1)

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
old_missing_formatted = "status = 'File ricevuto, ma HCV-ID non rilevato automaticamente. Inseriscilo e premi VERIFICA DA REGISTRY.';"
new_missing = """status = 'Contenuto non certificato SIGILLUM.';"""
if old_missing in source:
    source = source.replace(old_missing, new_missing, 1)
elif old_missing_formatted in source:
    source = source.replace(old_missing_formatted, new_missing, 1)
elif new_missing not in source:
    raise RuntimeError('missing HCV-ID status anchor missing')

negative_result_old = """result = 'NOT ANALYZED';
          status = 'Contenuto non certificato SIGILLUM.';"""
negative_result_new = """result = null;
          status = 'Contenuto non certificato SIGILLUM.';"""
if negative_result_old in source:
    source = source.replace(negative_result_old, negative_result_new, 1)

# Exact visual shell used by the first public pages.
scaffold_old = """    return Scaffold(
      appBar: AppBar(
        title: Text(_t('verifyContentHeading')),
      ),
      body: Center("""
scaffold_legacy = """    return Scaffold(
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
scaffold_new = """    return Scaffold(
      backgroundColor: SigillumTheme.deep,
      appBar: AppBar(
        backgroundColor: SigillumTheme.panel,
        foregroundColor: SigillumTheme.ink,
        elevation: 0,
        title: Text(_t('verifyContentHeading')),
      ),
      body: Center("""
if scaffold_old in source:
    source = source.replace(scaffold_old, scaffold_new, 1)
elif scaffold_legacy in source:
    source = source.replace(scaffold_legacy, scaffold_new, 1)
elif scaffold_new not in source:
    raise RuntimeError('verification scaffold visual anchor missing')

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
select_button_custom = """              SizedBox(
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
select_button_new = """              FilledButton(
                onPressed: loading ? null : pickMedia,
                child: Text(_t('selectOriginalMedia')),
              ),"""
select_button_final = """              FilledButton(
                onPressed: loading ? null : pickMedia,
                child: Text(_v('selectOriginal')),
              ),"""
if select_button_old in source:
    source = source.replace(select_button_old, select_button_new, 1)
elif select_button_custom in source:
    source = source.replace(select_button_custom, select_button_new, 1)
elif select_button_new in source or select_button_final in source:
    pass
else:
    raise RuntimeError('select-media button visual anchor missing')

verify_button_old = """              ElevatedButton(
                onPressed: loading ? null : verifyFromRegistry,
                child: Text(
                  loading ? _t('verifyingShort') : _t('verifyFromRegistry'),
                ),
              ),"""
verify_button_custom = """              SizedBox(
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
verify_button_new = """              FilledButton(
                onPressed: loading ? null : verifyFromRegistry,
                child: Text(
                  loading ? _t('verifyingShort') : _t('verifyFromRegistry'),
                ),
              ),"""
verify_button_final = """              FilledButton(
                onPressed: loading ? null : verifyFromRegistry,
                child: Text(
                  loading ? _v('verifying') : _v('verifyRegistry'),
                ),
              ),"""
if verify_button_old in source:
    source = source.replace(verify_button_old, verify_button_new, 1)
elif verify_button_custom in source:
    source = source.replace(verify_button_custom, verify_button_new, 1)
elif verify_button_new in source or verify_button_final in source:
    pass
else:
    raise RuntimeError('verify button visual anchor missing')

card_old = """      decoration: BoxDecoration(
        color: const Color(0xFF111A17),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),"""
card_custom = """      decoration: BoxDecoration(
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
card_new = """      decoration: BoxDecoration(
        color: SigillumTheme.panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: SigillumTheme.border),
      ),"""
# The 24/08 Registry finalizer deliberately refines the same card to this
# final public shape. A later Codemagic re-application of this 23/08 patch must
# accept it as already valid rather than treating it as a missing anchor.
card_final = """      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: SigillumTheme.border),"""
if card_old in source:
    source = source.replace(card_old, card_new, 1)
elif card_custom in source:
    source = source.replace(card_custom, card_new, 1)
elif card_new in source or card_final in source:
    pass
else:
    raise RuntimeError('verification card visual anchor missing')

# Axis-card typography should use the same ink/muted colors as the public pages.
source = source.replace(
    "style: const TextStyle(\n                    fontSize: 13,\n                    color: Colors.grey,",
    "style: const TextStyle(\n                    fontSize: 13,\n                    color: SigillumTheme.muted,",
)
source = source.replace(
    "style: const TextStyle(fontSize: 14, height: 1.25),",
    "style: const TextStyle(\n                    color: SigillumTheme.ink,\n                    fontSize: 14,\n                    height: 1.25,\n                  ),",
)

required = [
    "'00:00:00.2'",
    "'00:00:00.8'",
    'if (!mounted) return null;',
    'withData: false,',
    "status = 'Controllo rapido SIGILLUM in corso...';",
    "status = 'Contenuto non certificato SIGILLUM.';",
    "import 'sigillum_theme.dart';",
    'backgroundColor: SigillumTheme.deep,',
    'backgroundColor: SigillumTheme.panel,',
    'FilledButton(',
    'border: Border.all(color: SigillumTheme.border),',
]
for token in required:
    if token not in source:
        raise RuntimeError(f'fast media/verification-shell token missing: {token}')

if card_new not in source and card_final not in source:
    raise RuntimeError('fast media/verification-shell token missing: approved Registry card shape')

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
print('Fast media pre-check and Registry verification shell aligned to SIGILLUM public theme')
