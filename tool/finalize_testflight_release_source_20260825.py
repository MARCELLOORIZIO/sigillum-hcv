from pathlib import Path


def run_python_script(path: str) -> None:
    script = Path(path)
    if not script.exists():
        raise RuntimeError(f'release finalizer missing: {path}')
    exec(
        compile(script.read_text(encoding='utf-8'), str(script), 'exec'),
        {'__name__': '__main__'},
    )


# One deterministic finalization pass only. The Registry helper normalizer is
# now part of the language-finalizer chain and makes repeated invocations safe;
# no exception-driven repair or second pass is allowed here.
run_python_script('tool/apply_media_specific_verification_picker_fix_20260822.py')
run_python_script('tool/verify_postpatch_release_20260825.py')
print('TestFlight release source finalized and verified')
