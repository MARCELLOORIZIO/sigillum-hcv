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
# contract, then apply the stabilized decision architecture, photo-byte/package
# integrity contracts, generated policy regressions, localized StoreKit prices,
# the Creator 7-day/monthly/annual commercial ladder, installed-build runtime
# regression guards, and finally the native iOS storefront price bridge. Every
# stage is idempotent so repeated pre-test/pre-IPA execution converges to one
# source tree.
run_python_script(
    'tool/apply_rc2_definitive_build_finalizer_legacy_20260825.py'
)
run_python_script('tool/apply_rc2_decision_architecture_fix_20260825.py')
run_python_script('tool/apply_rc2_photo_integrity_wrapper_20260825.py')
run_python_script('tool/apply_rc2_photo_package_camera_finalizer_20260825.py')
run_python_script('tool/apply_rc2_policy_test_alignment_20260825.py')
run_python_script('tool/apply_storekit_localized_price_ui_fix_20260826.py')
run_python_script('tool/apply_creator_weekly_subscription_20260826.py')
run_python_script('tool/apply_rc2_runtime_regressions_finalizer_20260826.py')
run_python_script('tool/apply_rc2_native_storefront_price_finalizer_20260826.py')

print('RC2 definitive-build wrapper PASS')
