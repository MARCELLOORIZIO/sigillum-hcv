from pathlib import Path

# The Registry finalizer repairs/replaces any legacy diagnostic layout left by
# previous build-time patchers before language assertions are evaluated.
registry_finalizer = Path('tool/apply_verification_registry_finalizer_20260824.py')
if not registry_finalizer.exists():
    raise RuntimeError('Registry verification finalizer missing')
exec(
    compile(registry_finalizer.read_text(encoding='utf-8'), str(registry_finalizer), 'exec'),
    {'__name__': '__main__'},
)

# Verification hub buttons must follow the selected IT/EN/ES/RU language.
path = Path('lib/import_page.dart')
source = path.read_text(encoding='utf-8')
if "import 'verification_ui_copy.dart';" not in source:
    anchor = "import 'sigillum_theme.dart';\n"
    if anchor not in source:
        raise RuntimeError('verification hub theme import missing')
    source = source.replace(anchor, anchor + "import 'verification_ui_copy.dart';\n", 1)
if "String _v(String key)" not in source:
    anchor = "  String _t(String key) => SigillumCopy.t(widget.languageCode, key);\n"
    if anchor not in source:
        raise RuntimeError('verification hub localization helper missing')
    source = source.replace(
        anchor,
        anchor + "  String _v(String key) => VerificationUiCopy.t(widget.languageCode, key);\n",
        1,
    )
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                        ? 'VERIFICA TESTO'\n                        : 'VERIFY TEXT'),",
    "label: Text(_v('verifyText')),",
)
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                        ? 'VERIFICA FOTO'\n                        : 'VERIFY PHOTO'),",
    "label: Text(_v('verifyPhoto')),",
)
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                        ? 'VERIFICA VIDEO'\n                        : 'VERIFY VIDEO'),",
    "label: Text(_v('verifyVideo')),",
)
# Formatter variants used by the legacy fallback.
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                    ? 'VERIFICA TESTO'\n                    : 'VERIFY TEXT'),",
    "label: Text(_v('verifyText')),",
)
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                    ? 'VERIFICA FOTO'\n                    : 'VERIFY PHOTO'),",
    "label: Text(_v('verifyPhoto')),",
)
source = source.replace(
    "label: Text(widget.languageCode == 'it'\n                    ? 'VERIFICA VIDEO'\n                    : 'VERIFY VIDEO'),",
    "label: Text(_v('verifyVideo')),",
)
source = source.replace(
    "widget.languageCode == 'it'\n                        ? 'Scegli il tipo di contenuto da verificare.'\n                        : 'Choose the type of content to verify.'",
    "_v('verifyTitle')",
)
if 'VERIFICA TESTO / DOCUMENTO' in source:
    raise RuntimeError('obsolete long verification label survived finalizer')
for token in ["_v('verifyText')", "_v('verifyPhoto')", "_v('verifyVideo')"]:
    if token not in source:
        raise RuntimeError(f'verification hub translation token missing: {token}')
path.write_text(source, encoding='utf-8')

# Ensure the quick gate contains no residual binary IT/EN selector.
quick = Path('lib/quick_hcv_media_gate_page.dart')
quick_source = quick.read_text(encoding='utf-8')
if '_isItalian' in quick_source:
    raise RuntimeError('quick verification gate still uses IT/EN-only language branching')

# Registry, router and HCVPACK must all receive the original chosen language.
for file_name in [
    'lib/registry_verify_page.dart',
    'lib/hcv_import_router_page.dart',
    'lib/hcvpack_player_page.dart',
]:
    text = Path(file_name).read_text(encoding='utf-8')
    if "VerificationUiCopy.t(widget.languageCode, key)" not in text:
        raise RuntimeError(f'{file_name}: selected-language verification copy missing')

# Remove any residual raw Italian status from the public localized result.
result_copy_finalizer = Path('tool/apply_verification_result_copy_finalizer_20260824.py')
if not result_copy_finalizer.exists():
    raise RuntimeError('Verification result-copy finalizer missing')
exec(
    compile(
        result_copy_finalizer.read_text(encoding='utf-8'),
        str(result_copy_finalizer),
        'exec',
    ),
    {'__name__': '__main__'},
)

# Apply severity colors only after the localized public Registry UI is final.
severity_finalizer = Path('tool/apply_verification_severity_colors_20260824.py')
if not severity_finalizer.exists():
    raise RuntimeError('Verification severity color finalizer missing')
exec(
    compile(
        severity_finalizer.read_text(encoding='utf-8'),
        str(severity_finalizer),
        'exec',
    ),
    {'__name__': '__main__'},
)

print('Verification language, public result copy and severity now propagate through hub, quick check, Registry, router and HCVPACK')
