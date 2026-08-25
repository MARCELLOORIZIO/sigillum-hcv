from pathlib import Path


def run_python_script(path: str) -> None:
    script = Path(path)
    if not script.exists():
        raise RuntimeError(f'definitive finalizer missing: {path}')
    try:
        exec(
            compile(script.read_text(encoding='utf-8'), str(script), 'exec'),
            {'__name__': '__main__'},
        )
    except SystemExit as exc:
        code = 0 if exc.code is None else exc.code
        if code != 0:
            raise
        print(f'Nested definitive finalizer completed via SystemExit(0): {path}')


# Single entry point used by Linux validation, the exact macOS/Codemagic chain
# and the final IPA proof. First preserve every approved historical RC2 release
# contract, then apply the stabilized real-world decision architecture. Both
# scripts are idempotent, so repeated pre-test/pre-IPA execution must converge
# to the same source tree.
run_python_script(
    'tool/apply_rc2_definitive_build_finalizer_legacy_20260825.py'
)
run_python_script('tool/apply_rc2_decision_architecture_fix_20260825.py')

print('RC2 definitive-build wrapper PASS')
