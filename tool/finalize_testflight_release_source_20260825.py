from pathlib import Path


def run_python_script(path: str) -> None:
    script = Path(path)
    if not script.exists():
        raise RuntimeError(f'release finalizer missing: {path}')
    exec(
        compile(script.read_text(encoding='utf-8'), str(script), 'exec'),
        {'__name__': '__main__'},
    )


def repair_registry_helper_if_needed() -> None:
    registry_path = Path('lib/registry_verify_page.dart')
    source = registry_path.read_text(encoding='utf-8')
    if "_v('registryHelper')" in source:
        return

    # A repeated Registry-layout normalizer can legitimately remove the old
    # hardcoded helper before the localized result-copy finalizer sees it. In
    # that state there is nothing unsafe to preserve: restore the localized
    # helper at the stable boundary immediately before the verification axes.
    if "String _v(String key)" not in source and "VerificationUiCopy.t(widget.languageCode, key)" not in source:
        raise RuntimeError('Registry localization helper unavailable during final release repair')

    old_helper = """              const Text(
                'Il certificato viene recuperato automaticamente dal Registry HCV. Devi selezionare SOLO il file originale.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),"""
    new_helper = """              Text(
                _v('registryHelper'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),"""

    if old_helper in source:
        source = source.replace(old_helper, new_helper, 1)
    else:
        anchor = "              if (_hasVerificationAxes) ...["
        if anchor not in source:
            raise RuntimeError('Registry helper stable insertion anchor missing')
        source = source.replace(anchor, new_helper + "\n" + anchor, 1)

    registry_path.write_text(source, encoding='utf-8')


# TestFlight must compile from one deterministic finalization pass performed in
# the same step as the archive. The legacy chain is almost idempotent, but one
# Registry presentation variant can remove the old helper before localization;
# recover only that presentation anchor, then re-run the complete finalizer.
try:
    run_python_script('tool/apply_media_specific_verification_picker_fix_20260822.py')
except RuntimeError as exc:
    if 'hardcoded Registry helper anchor missing' not in str(exc):
        raise
    repair_registry_helper_if_needed()
    run_python_script('tool/apply_media_specific_verification_picker_fix_20260822.py')

run_python_script('tool/verify_postpatch_release_20260825.py')
print('TestFlight release source finalized and verified')
