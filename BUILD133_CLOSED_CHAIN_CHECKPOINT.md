# BUILD133 Closed-Chain / Verified Originals checkpoint

Date: 2026-09-25
Status: IN PROGRESS
Base branch: release/testflight-final-20260827
Feature branch: feature/build133-closed-chain-vault-youtube-20260925

## Product decisions locked before implementation

1. Screen-replay classification is NOT a publication gate. NO_DISPLAY_EVIDENCE, NON_CONCLUSIVE and STRONG_DISPLAY_RISK remain signed technical evidence only.
2. Photo/video created by SIGILLUM must not be saved in the iOS Photos library as the canonical original.
3. Canonical original media and HCVPACK are to be stored encrypted locally inside the app.
4. Viewing/exporting a canonical original must go through SIGILLUM.
5. On external sharing, SIGILLUM must verify the decrypted bytes against the signed HCV certificate and Registry before export.
6. Before the social share sheet is opened, SIGILLUM must create/register the official Verified Original reference through the SIGILLUM backend/YouTube path. If reference publication fails, social export fails closed.
7. External social copies may later be modified; those modifications are outside the closed SIGILLUM chain and must never inherit exact-original status.
8. Verified Originals public verification must support HCV-ID lookup and file-based verification/import; creator publication must not trust an arbitrary library selection.
9. UI/copy/legal changes must remain complete in IT/EN/ES/RU.
10. YouTube is the public reference/vitrine. HCVPACK cannot be attached as a YouTube file; its SHA-256 and Registry linkage are to be bound to the publication record/reference metadata.

## Implementation plan

A. Add encrypted local media vault using AES-256-GCM, with master secret stored through HCVSecureStore/Keychain.
B. Seal canonical media + HCVPACK after successful HCV creation/verification and remove plaintext canonical copies.
C. Add secure SIGILLUM Originals library/player/share flow.
D. Make social share fail closed until backend reference publication succeeds.
E. Add backend server-side capture provenance gate, photo-reference support and HCVPACK hash binding.
F. Update Verified Originals lookup to allow file-based identification/verification.
G. Localize all affected screens and messages in IT/EN/ES/RU.
H. Update Privacy/Terms/guide/external pages for encrypted local originals and YouTube reference publication.
I. Add regression/contract tests and run CI before promotion.

## Progress log

- 2026-09-25: architecture agreed.
- 2026-09-25: feature branch created from BUILD132 release branch.
- 2026-09-25: backend companion branch created from reconciled prelaunch backend.
- 2026-09-25: implementation started; release branches intentionally left untouched.
- 2026-09-25: added AES-256-GCM chunked local vault (`lib/hcv_secure_media_vault.dart`) with master secret in HCVSecureStore/Keychain, encrypted canonical media + HCVPACK, SHA-256 verification and temporary cleartext materialization.
- 2026-09-25: camera success paths now seal PHOTO/VIDEO + HCVPACK and no longer auto-save canonical originals to iOS Photos.
- 2026-09-25: added fail-closed reference publication service and protected-originals viewer/share page. Social share runs only after the backend reference is available.
- 2026-09-25: Creator home now uses Protected Originals instead of the old per-file publication screen.
- 2026-09-25: Verified Originals lookup now accepts HCV-ID or a selected file; selected files enter the existing verification router.
- 2026-09-25: new closed-chain/Verified Originals UI copy added for IT/EN/ES/RU; public/LAB entry points updated.
- 2026-09-25: replaced stale Verified Originals v2 contract tests with BUILD133 closed-chain invariants.
- 2026-09-25: added `.github/workflows/build133-closed-chain-validation.yml`; workflow now pins the iOS TFLite 2.17.0 runtime before the release guard.
- 2026-09-25: full Flutter analyzer and test suite reached GREEN on run `36119100437`; only the release guard failed there because the validation workflow had not yet run the existing TFLite pin script. Workflow corrected; a new validation is running.
- 2026-09-25: camera processing paths on iOS moved from Documents to private Application Support so canonical media is not exposed through iOS Files before vault sealing.
- 2026-09-25: Terms/Privacy acceptance revision bumped to 2026-09-25. In-app legal copy and the four-language quick guide now describe encrypted originals and official YouTube reference publication.
- 2026-09-25: encrypted originals are bound to the active Creator ID. Local vault/key wipe implemented and wired to Creator account removal from the profile flow.
- 2026-09-25: reference withdrawal added to Protected Originals; backend takedown is called first, then local reference state is cleared. UI/copy supplied in IT/EN/ES/RU.
- 2026-09-25: vault-aware caption workflow restored. Certified video is materialized only temporarily from the encrypted vault for transcription/subtitle burn-in; the temporary original is deleted afterward. The captioned output remains an explicit derivative and may be saved to Photos.
- 2026-09-25: reference withdrawal UI/service added; successful server takedown clears local reference state without deleting HCV verification.
- 2026-09-25: vault hardening completed. Any decrypt/MAC/binding/hash failure deletes partial cleartext; sealing is idempotent and conflict-safe and no longer risks erasing an already-valid vault record.
- 2026-09-25: account-deletion cleanup is Creator-scoped. Records are bound to `ownerCreatorId`; deleting one Creator removes only that Creator’s encrypted media/HCVPACK/certificate files and deletes the shared vault key only when no vault records remain.
- 2026-09-25: BUILD133 validation run `36121390997` GREEN at commit `34cbb100e1192cb5e980cfb639e6eb9b653a8581`: Flutter setup/dependencies, formatting, analyzer, complete Flutter test suite and release architecture guard all passed.
- 2026-09-25: post-repair validation run `36125056157` GREEN at commit `c04f570812ab78d5f189384309faef72a655ffbf`: formatter, analyzer, complete Flutter test suite and release architecture guard all passed.\n- 2026-09-25: draft PR `#123` opened from this branch into `release/testflight-final-20260827`; intentionally not merged.
- 2026-09-25: TestFlight candidate branch `release/testflight-build133-closed-chain-20260925` created from the validated feature branch. Its `codemagic.yaml` now includes that branch in the `ios-testflight` trigger. Candidate commit after trigger update: `76000311ef61308c0c406435813e4a0952d0b25e`. Codemagic/TestFlight result still needs to be confirmed.\n- Remaining before release: controlled device-level regression on iPhone for photo/video vault materialization + reference-first social share/withdrawal; live YouTube compliance/upload test; align deployed TERMS_VERSION/PRIVACY_VERSION with 2026-09-25 before production deploy. No release/deploy yet.

- 2026-09-25: post-audit release hardening applied on the app branch. Protected originals are account-subject bound in addition to Creator ID; crash-left plaintext is purged at startup; iOS watermark/photo-HCVPACK intermediates avoid Documents; camera plugin source plaintext is explicitly removed; provenance logs are transient; existing references are re-bound to media/HCVPACK hashes; HCVPACK publication binding is signed by the device key; local reference state is retained until platform takedown reports COMPLETED; and the current in-memory video packaging path is capped at 200 MiB. Backend companion hardening is being applied separately. No merge/deploy.

## Resume rule

Do not start again from the design discussion. Resume from the first unfinished item in the implementation plan, inspect this file plus the backend checkpoint, and preserve the locked product decisions above.


## 2026-09-25 UX official-copy naming hardening

- Replaced ambiguous "Verified Originals / watch original" user copy with function-based actions:
  - VERIFICA CONTENUTO
  - APRI ORIGINALI PROTETTI
  - CERCA COPIA UFFICIALE
  - VISUALIZZA ORIGINALE / CONDIVIDI ORIGINALE
  - VISUALIZZA COPIA UFFICIALE
- Official-copy search is HCV-ID-only and no longer duplicates file verification or protected-original selection.
- Fixed Russian landing-copy syntax regression and updated obsolete Verified Originals contract tests.
- BUILD133 formatter materialized the UX changes before TestFlight sync.

## 2026-09-29 Official-copy local verification V3

- Added `HCVReferenceVisualFingerprintV3`: 128x72 grayscale normalization, 16x9 local grid, mean/range/edge tile features, 64-bit global frame hash, 2 fps video sampling, temporal alignment and three-way verdict (`conforming`, `modified`, `inconclusive`).
- Regression contract: social-like recompression remains conforming while a small synthetic UFO inserted into a local region is detected as modified, including when present only in a subset of video frames.
- Public `VERIFICA CONTENUTO` now prefers the signed official-copy V3 fingerprint when available; exact SHA-256 original verification remains the strongest path and legacy fingerprints remain fallback-only.
- User-facing outcomes added in IT/EN/ES/RU: COPIA CONFORME, COPIA MODIFICATA, VERIFICA NON CONCLUSIVA.
- Cross-language golden locked with backend: globalHash `03030f0f1f1f7f7f`; local-feature SHA-256 `4ae46d0f4d9b9f5ef680cb4c6eda75b67a2a1a3a4037e336efe34b748265bcd4`.
- App CI GREEN before this documentation-only checkpoint: focused Verified Originals suite and full BUILD133 suite (format, analyze, tests, architecture guard).
- No TestFlight build created. Accumulate fixes for one consolidated build later.

## 2026-09-30 V3 RGB hardening

- V3 upgraded from grayscale-only local features to RGB-aware local features: algorithm `SIGILLUM_LOCAL_RGB_GRID_V3`, 6 bytes/tile (luma mean/range/edge + mean R/G/B), 16x9 grid on normalized 128x72 RGB24 frames.
- Exact original SHA-256 remains the strongest verification path. For derived/social copies the order is: signed official-copy V3 -> legacy fallback.
- Local Dart regression now requires: social-like recompression = conforming; small inserted UFO = modified; colour-only edit = modified; brightness edit = modified; geometric translation = modified.
- App and backend cross-language golden updated: feature SHA-256 `f5df80936c5d9050b35e5a606c92b55a7eb2bec873f5805f9c81d37f14a4afbc`.
- Both Flutter workflows GREEN after RGB hardening. No TestFlight build created.

## 2026-09-30 Closed-chain subtitles, compact vault UX, and offline-safe finalization

- Protected Originals cards now use compact ~132 px 16:9 previews beside HCV-ID/date/status so long vault lists remain usable.
- Camera finalization is now fail-closed around local persistence: certificate upload is queued locally first, original media + HCVPACK are sealed into the encrypted vault before Registry network retry, and camera exit/back is blocked while the vault commit is still critical.
- Added persistent `pending_seals.json` journal and `recoverPendingSeals()`; interrupted seals are retried on camera/open-vault startup. Recovery also routes already-indexed items back through `seal()` so plaintext staged files are deleted after a crash between index commit and cleanup.
- Direct camera sharing before vault commit has been removed. Original sharing becomes available only from a valid secure-vault record and then flows through Protected Originals, where the official reference gate applies.
- Caption workflow changed to closed chain: captioned MP4 + SRT are produced in private Application Support, encrypted into the vault, plaintext working files removed, and Save to Photos / Share captioned video / Share SRT all require a confirmed official derived reference first.
- Captioned publication is device-bound with `SIGILLUM_SUBTITLE_DERIVATION_BINDING_V1`, including HCV-ID, original SHA-256, captioned-video SHA-256, SRT SHA-256 and HCVPACK SHA-256.
- iOS App Store warning ITMS-90683 addressed by adding `NSLocationAlwaysAndWhenInUseUsageDescription` while keeping the geolocator Always bypass and explicitly stating that SIGILLUM does not continuously track location in background.
- App CI was GREEN after the functional/security fixes; a final documentation/hardening-test commit follows without creating TestFlight.
- No TestFlight build created.

## 2026-09-30 Full branch audit hardening — HCVPACK export and early seal journal

- Re-read both feature checkpoints, verified exact branch HEADs/CI, and traversed the complete recursive Git trees before changing code.
- App audit found one stale camera bypass: `sharePackage()` could expose the plaintext HCVPACK during the interval after package creation but before secure-vault commit. The HCVPACK contains the canonical media, so this violated the closed-chain rule even though direct original sharing was already blocked.
- `sharePackage()` is now fail-closed: it refuses during critical finalization, requires a valid secure-vault record and a confirmed original reference, materializes the encrypted HCVPACK only temporarily, opens the share sheet from that temporary copy, then deletes it.
- The old result-screen condition `packagePath != null` no longer exposes the pre-seal plaintext package action; the action is tied to a completed secure-vault record.
- `pending_seals.json` is now written before SHA-256 calculation of potentially large media. A crash during hashing therefore leaves recovery metadata already persisted. Deterministic hash/empty-source validation failures remove the journal entry; transient interruption leaves it for startup recovery.
- Contract tests now cover the HCVPACK path explicitly and assert journal-before-hash ordering.
- Verified during audit: subtitle MP4/SRT export remains derived-reference-gated; `activeReference()` filters only `ORIGINAL_REFERENCE`; withdrawal revokes original + derived publications and app clears local reference state only after completed platform takedown; V3 decision order remains exact SHA-256 -> official signed V3 -> legacy fallback; V3 Dart/Node golden remains `f5df80936c5d9050b35e5a606c92b55a7eb2bec873f5805f9c81d37f14a4afbc`.
- Repository hygiene note: many historical source copies remain outside the active `lib/` runtime tree (`MODIFICHE/`, `VERSIONE FUNZIONANTE*/`, `hcv_modifiche_complete/`). They were not deleted because they are archival and may still be useful for forensic comparison.
- Backend branch is currently 22 commits ahead and 1 commit behind `release/reconciled-prelaunch-backend-clean-20260824` (diverged). No merge/rebase/deploy performed; reconcile only when preparing the final consolidated release.
- iOS audit note: current `SceneDelegate.swift` generates a 2048-bit RSA device key. This was not changed because key-size migration affects enrolled device identity and existing certificate/account bindings.
- No TestFlight build, Codemagic build, Render deploy, or release-branch merge was created by this hardening pass.

