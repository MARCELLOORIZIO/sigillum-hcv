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

## Recent-account picker four-language follow-up (2026-10-13)

- Audited `CommercialGate._recentAccountPicker` and its four in-file locale maps; found two hardcoded Italian widget texts.
- Updated `lib/commercial_gate.dart` to resolve `recentAccountsTitle` and `recentAccountsHint` via `_t` with IT/EN/ES/RU entries; added `test/commercial_recent_accounts_localization_test.dart` static regression.
- This is localized UI only; account ownership, purchase flows, subscription policy, KYC, storage and cryptography unchanged. The long `commercial_gate.dart` file remains **not certified semantically read in full**; do not upgrade inventory status.
- All newer commits require successful CI after the previous green run 38393600718.

## Signed-IPA PHOTO proof hardening

- Read the exact packaging stage of `tool/build_testflight_ipa_rc2_20260825.sh` and confirmed it compared V1/V2/V3 only. Added `assets/ml/sigillum_photo_framing_v1.tflite` to source SHA attestation and archived `App.framework/flutter_assets` byte-level comparison.
- Added `test/build157_photo_ipa_proof_contract_test.dart` guarding all four model paths and comparison tokens.
- **This only enhances future IPA validation.** No IPA has been produced by this patch; PHOTO iPhone inference/parity remains untested here. This script is macOS/Codemagic-specific and was not executed in a signed archive environment.
- Keep PR draft until final-HEAD CI passes and signed IPA, PHOTO device runtime and remaining media/subscription regressions are established.

## Final Flutter CI and independent unsigned iOS build (2026-10-13)

- Full app workflow [38395494551](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38395494551) **SUCCESS** on `1a8b898a10288f20783f784da6a4316fb7ee6c3a`, after the Dart test shell-literal fix.
- Introduced isolated workflow `.github/workflows/build157-candidate-ios-unsigned.yml` to compile the User edition on macOS without signing, then `cmp` the packaged PHOTO model against the tracked source asset. Run [38395953513](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38395953513) was **QUEUED** at the time of checkpoint; do not report it green without checking the run.
- Unsigned iOS build is not an IPA, StoreKit/iPhone test, PHOTO runtime parity or TestFlight evidence. The PR remains a draft and no merge/Render deploy is authorized by the mere successful Flutter CI.

## CI verification after iOS workflow execution (2026-10-13)

- [Unsigned iOS build + PHOTO bundle byte check run 38395953513](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38395953513): **SUCCESS**, commit `88a7139a1e85c70c55c624d96d27147a75d5a6a4`.
- [Full Flutter run 38395961028](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38395961028): **SUCCESS**, commit `88a7139a1e85c70c55c624d96d27147a75d5a6a4`.
- [Latest documentation-head Flutter run 38396005997](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38396005997): **SUCCESS**, commit `037658c52f26de20ec9aca4c70996a869659c56e`.
- Compiled model byte identity has now been exercised in unsigned iOS CI, but **neither a signed IPA nor a TestFlight installation/device inference/Apple IAP test has been executed**. No release or Render deploy in this turn.

## Vault deletion parity audit (2026-10-13)

- Read `lib/hcv_secure_media_vault.dart` deletion and subtitle materialization intervals, and relevant `camera_page.dart` save path. Found that `wipeAccountVault` enumerated encrypted captioned media + subtitle but fallback `wipeCreatorVault` deleted only media, pack, certificate.
- Implemented matching deletion of both encrypted derivative files for Creator fallback (`2be2ed6c`); added static contract test `test/creator_vault_subtitle_cleanup_contract_test.dart` (`9883c6d3`). No changes to cipher, keys, signing, reference R2, matching or display thresholds.
- This is source-level deletion parity, not a demonstrated end-to-end account-delete trial. Verify integration/call-site and ephemeral materialization hygiene before considering lifecycle closed. Historical inventory total read coverage must not be overstated.
- Independent observation: `saveContentToGallery` detects captioned media by filename `_sottotitolato`, but `materializeCaptionedVideo(... purpose: 'subtitle-save')` uses another suffix. The Snackbar displays the captioned save sentence; a separate registryStatus line may nevertheless use the original label. Diagnose widget-visible behavior before changing labels.

## Captioned-video save status correction (2026-10-13)

- Previous vault fix validated by full workflows [38401491151](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38401491151), [38401519103](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38401519103), and [38401562057](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38401562057), all **SUCCESS**.
- Confirmed `materializeCaptionedVideo(purpose: 'subtitle-save')` generates a temporary filename not containing `_sottotitolato`, whereas `saveContentToGallery` inferred captioned media only via that filename marker. Corrected UI categorization by passing explicit `isCaptionedVideo: true` from subtitle-save action, leaving older filename recognition and iOS save behavior untouched.
- Added `test/captioned_video_photo_save_label_contract_test.dart` (static contract). The patch fixes only status copy; it is not proof that all captions reach the video end or that saving succeeds on every iPhone.

## Subtitle no-timing fallback audit (2026-10-13)

- Previous captioned save status CI [38402003175](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38402003175), [38402026743](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38402026743) and [38402066745](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38402066745): **SUCCESS**.
- Source review of `lib/video_transcription_service.dart` found that when Apple Speech provides nonempty full text but **no word timing segments**, `_captionSegments` fabricated a single 10-second caption; `_captionSegmentsWithFullCoverage` then accepted it as 100% text-covered even for longer media. Added a guarded use of the known actual `mediaDuration` to lay out the *recognized* text across the full video, preserving the 10-second legacy fallback if duration is unavailable. Commit `a19d0234` plus static regression `test/subtitle_untimed_duration_contract_test.dart` at `a47d2d18`.
- This is a narrow fallback fix, not a solution for Apple's truncated speech transcript with missing words, and does not establish iPhone rendering parity or accurate word timestamps. Existing tail retries remain as-is; no changes to model weights, display thresholds or certificates.

## StoreKit purchase stream error handling (2026-10-13)

- Three subtitle CI runs [38403124766](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38403124766), [38403157659](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38403157659), and [38403196246](https://github.com/MARCELLOORIZIO/sigillum-hcv/actions/runs/38403196246) **SUCCESS**.
- Read complete `lib/commercial_billing_service.dart` and relevant purchase handler/listener in `lib/commercial_gate.dart`. Billing forwards purchase stream errors with `_purchaseController.addError(error, stackTrace)` while Gate subscribed with no `onError` callback. Added handler rendering existing safe localized `purchaseFailed` without exception text; test `test/storekit_purchase_stream_error_contract_test.dart` guards contract. Commits `dca6d213` and `05e147d8`.
- No change to Apple entitlement verification, transaction completion, purchases, recovery, pricing, product IDs, or access control. Physical Sandbox/TestFlight subscription lifecycle remains unverified and is a release gate.

## StoreKit restore-button error recovery (2026-10-13)

- Found that the Restore button called `CommercialBillingService.instance.restore()` without `_run`; unlike purchases it had no guarded busy/error UI path for asynchronous `restorePurchases` rejection. Routed restore through the existing `_run` handler to prevent duplicate taps and display safe localized errors. This does not grant entitlement or bypass verification; purchase stream still drives entitlement decisions.
- Regression: `test/storekit_restore_busy_error_contract_test.dart`; commits `dd34fa72`, `6eabec0c`. Confirmed `_localizedError` maps unknown errors to a generic translated operation failure rather than showing raw exception text.
- iPhone/TestFlight StoreKit Sandbox buy, restore, cancel and foreign-Apple-ID flows remain untested; full CI for latest commits must complete before release qualification.
