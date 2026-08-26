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


# Materialize the historical RC2 chain once, then apply deterministic release
# finalizers in a fixed order. Decision architecture is finalized before the
# public verification scene mapping so the UI can never override the signed
# final display-fusion verdict with a lower-level geometry result.
run_python_script('tool/apply_media_specific_verification_picker_fix_20260822.py')
run_python_script('tool/apply_rc2_photo_parallax_and_media_verify_finalizer_20260825.py')
run_python_script('tool/apply_rc2_definitive_build_finalizer_20260825.py')
run_python_script('tool/apply_rc2_decision_architecture_fix_20260825.py')
run_python_script('tool/apply_rc2_verification_scene_priority_finalizer_20260826.py')
run_python_script('tool/normalize_registry_initial_status_20260825.py')
run_python_script('tool/verify_postpatch_release_20260825.py')
print('TestFlight release source finalized and verified')
