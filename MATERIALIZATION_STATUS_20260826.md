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

## Current status

The two real-world display regressions and the final-fusion-first verification UI contract are committed on this branch. A one-shot GitHub Actions workflow is present to materialize, validate, prove idempotence, and commit the final source tree. The branch remains non-release until that workflow successfully produces the materialization commit and the resulting tree is reviewed.
