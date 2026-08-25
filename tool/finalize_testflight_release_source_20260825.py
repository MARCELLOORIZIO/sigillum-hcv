from pathlib import Path


def run_python_script(path: str) -> None:
    script = Path(path)
    if not script.exists():
        raise RuntimeError(f'release finalizer missing: {path}')
    try:
        exec(
            compile(script.read_text(encoding='utf-8'), str(script), 'exec'),
            {'__name__': '__main__'},
        )
    except SystemExit as exc:
        # Some historical patchers intentionally use SystemExit(0) after a
        # successful deterministic fast-path. When executed via exec() inside
        # this release finalizer, that clean exit must terminate only the nested
        # patcher, not the outer RC2 finalization chain. Non-zero exits remain
        # hard failures.
        code = 0 if exc.code is None else exc.code
        if code != 0:
            raise
        print(f'Nested finalizer completed via SystemExit(0): {path}')


# One deterministic finalization pass only. Older verification patchers are
# still invoked by the historical chain and one of them appends the same
# localized Registry init status on every pass. Normalize that legacy artifact
# immediately after the chain so repeated release finalization converges to the
# exact same source tree.
run_python_script('tool/apply_media_specific_verification_picker_fix_20260822.py')
run_python_script('tool/normalize_registry_initial_status_20260825.py')
run_python_script('tool/verify_postpatch_release_20260825.py')
print('TestFlight release source finalized and verified')
