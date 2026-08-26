# SIGILLUM RC2 source materialization — 2026-08-26

This branch exists to replace the TestFlight build-time patch chain with committed release source.

## Acceptance gates

The branch must not replace `release/testflight-rc2-20260825` until all of these are true:

1. `tool/finalize_testflight_release_source_20260825.py` has been executed on the branch.
2. The generated source has been committed as `RC2: materialize finalized release source`.
3. Running the finalizer a second time produces a byte-identical staged diff.
4. `flutter analyze --no-fatal-infos --no-fatal-warnings` passes on the materialized tree.
5. `flutter test` passes on the same tree.
6. HCV-6052 regression: strong `SCREEN_MONITOR` ML conflicting with REALITY geometry remains `NON_CONCLUSIVE`, score 69.
7. HCV-3F31 regression: a 3D mixed scene containing monitor evidence cannot resolve to `NO_DISPLAY_EVIDENCE`; expected `NON_CONCLUSIVE`, score 69.
8. Public verification UI follows the signed final fusion: `NON_CONCLUSIVE` must never be rendered as `Realtà rilevata` solely because the lower-level live geometry says REALITY.
9. Photo HCVPACK same-path naming and repeated iOS original-photo picker lifecycle regressions remain covered by the RC2 runtime finalizer.
10. Native StoreKit storefront prices remain enabled; the purchase sheet and SIGILLUM paywall must use the same storefront currency.
11. Materialization reproduces the exact Codemagic patcher order and targeted `dart format` file lists; broad `dart format lib test` is forbidden.
12. The materialization commit must contain substantive release-source changes including `lib/registry_verify_page.dart` and `lib/hcv_display_risk_fusion.dart`, and must leave a clean working tree.

## Current status

Draft PR #22 targets `release/testflight-rc2-20260825` from `release/testflight-materialized-clean-20260826`. The PR is mergeable but intentionally remains draft and must not be merged yet.

The two real-world display regressions and the final-fusion-first verification UI contract are committed. The UI finalizer and contract test now require the final-fusion guard in the exact `_signedRealityScene` getter, preventing unrelated occurrences of the same condition from satisfying the release gate.

The one-shot materialization workflow now mirrors Codemagic's actual pre-archive source transformations, including the same targeted formatting commands, two finalizer passes, idempotence comparison, pre-archive analyze/test, postpatch verification, and a substantive materialized-commit gate.

GitHub Actions is currently not providing an executable path for this new branch workflow: the last created run terminated with `startup_failure` before any job was created, and subsequent branch updates have not produced a new run. The active TestFlight branch and its current Codemagic patch chain therefore remain unchanged. No promotion is permitted until the materialization commit and validation evidence exist.
