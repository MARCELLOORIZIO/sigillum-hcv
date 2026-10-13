# SIGILLUM build 157 — provenance rendering patch checkpoint (2026-10-13)

## Baseline and isolation

- Base commit: `f7023853bcdfce927fd760357fe427e9d92ad34b` (user-identified build 157 source).
- Patch branch: `fix/build157-provenance-localization-20261013`.
- Do not merge/deploy yet: this branch is a review candidate, **not** a publishable release.
- PHOTO MobileNetV3 remains diagnostic; no PHOTO/V2/V3 weights, camera scene thresholds, cryptographic algorithms, iOS source or backend were changed.

## Implemented now

1. `lib/registry_verify_page.dart`: provenance negation is evaluated before positive state, and positive text requires exact `verificata`. Provenance details now distinguish negative, unavailable/inconclusive/Registry warnings and verified results.
2. `lib/verification_ui_copy.dart`: adds negative and unavailable provenance detail text in IT/EN/ES/RU.
3. `test/registry_provenance_localization_regression_test.dart`: verifies distinct four-language strings and statically guards negation-before-positive order. This is **not** an end-to-end/widget test.

## Evidence / limits

- GitHub file reads after commit confirmed all three files and exact expected code anchors; comparison to f702 shows precisely those three changed files.
- No workflow run associated with the patch branch was available when queried (0 runs). **flutter test, flutter analyze, signed IPA, iPhone runtime, TestFlight and App Store checks have not passed in this patch session.**
- The full 1,359-file semantic audit is still incomplete. Do not increase `source-read-complete` counts merely because indexed references were consulted.
- The latest named user attachment `Testo incollato(8)(1).txt` was located in the file library as the 2026-10-13 version, not substituted with the 2026-10-12 version.

## Required before promoting

1. Run `flutter test test/registry_provenance_localization_regression_test.dart`, widget/flow tests for negative/inconclusive/network cases in all four languages, full `flutter test`, and `flutter analyze`.
2. Audit all formerly indexed-only and partially-read source groups, and add accurate per-file progress to FILE_INVENTORY.
3. Verify snapshot parity and the PHOTO asset hash inside signed IPA; test inference on physical iPhone.
4. Reproduce user media cases using actual media and signed evidence before changing decision policies; exercise subscription, captions, social import, consent/revoke/R2.
5. Confirm Codemagic credentials/IPA/sourceCommit/CFBundleVersion and a matching TestFlight build prior to App Store submission.

## Incremental verification (2026-10-13)

- GitHub Actions run [38393600718](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38393600718) completed successfully on the preceding revision of this branch, including full flutter test, parse check, postpatch verification, TFLite pin and flutter analyze with warnings/infos not fatal.
- Additional review of HCVRegistryException cases found that network/server/notFound/invalidResponse provenance state values remained hard-coded in Italian. A subsequent targeted change maps these values to the localized `verificationIncomplete` string (all four languages); static assertions updated. **This subsequent commit requires fresh CI** before merge.
- No new signed IPA, device runtime, TestFlight build, StoreKit live transaction or actual large-media connector acceptance test exists from this change.
