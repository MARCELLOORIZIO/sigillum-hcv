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
- 2026-09-30: audit hardening functional HEAD `538e99a456e12ef2a797e7e2c5b1c17287e014f2` validated GREEN by BUILD133 run `36693571786` (format, Flutter analyze, full Flutter tests, release architecture guard) and Verified Originals v0.2 app run `36693578015`. Backend companion remains unchanged at `e245435cc7982e3399048aff399817407bf2154a`, with closed-chain validation run `36687732436` GREEN. No TestFlight, Codemagic release build, Render deploy, or release merge performed.


## 2026-09-30 Live YouTube attestation, verification timing and crash-window closure

- Closed the remaining hard-kill window between certificate finalization and vault persistence. PHOTO and VIDEO now persist a durable pending-seal journal before the Registry outbox enqueue, then enqueue the certificate locally, then seal media + HCVPACK, and only after the local commit retry network synchronization.
- Startup recovery now re-enqueues recovered certificate files idempotently before retrying Registry synchronization. Deterministic same-owner stale/missing pending-seal entries and deterministic HCV conflicts are removed instead of looping forever.
- Public media verification now checks a dedicated backend live-reference endpoint before accepting the signed official-reference V3 fingerprint. A modern photo/video social verification fails closed as OFFICIAL REFERENCE UNAVAILABLE when the YouTube object cannot currently be attested as live/processed/unlisted/comments-disabled; legacy visual fallback is not used to manufacture a conforming verdict in that state.
- Exact SHA-256 original verification remains the strongest path and now avoids the YouTube live lookup entirely. For derived video copies, official V3 runs first and the signed audio fingerprint is evaluated only when the official visual verdict is conforming; legacy V1/V2 work is deferred unless the modern official-reference path is unavailable by certificate generation.
- Added end-to-end timing telemetry for Registry/live-reference check, local V3 comparison and total verification duration. The user-facing verification screen shows the measured total/YouTube/local times and the technical diagnostics retain millisecond values.
- OFFICIAL COPY VERIFIED / MODIFIED / INCONCLUSIVE / REFERENCE UNAVAILABLE are now first-class UI states. OFFICIAL COPY VERIFIED was also fixed so it is treated by the result shell as a verified result rather than falling through to an inconsistent presentation.
- Added IT/EN/ES/RU copy for live-reference availability and verification timing; contract tests require every new key in all four languages.
- Important YouTube API constraint recorded: the official YouTube Data API does not expose the transcoded media bytes of an uploaded video as a supported download endpoint. No scraper, yt-dlp or undocumented media extraction was introduced into SIGILLUM. Therefore the current compliant verification mode is YOUTUBE_LIVE_ATTESTED_SIGNED_V3: the backend attests that the actual YouTube object still exists in the required platform state, while the app compares the social file against the signed V3 representation generated from the exact trusted derivative uploaded to that object. Direct byte/media-frame comparison against a freshly downloaded YouTube transcode remains unimplemented unless a supported media-byte source becomes available.
- App BUILD133 validation GREEN at commit 27261515cba835828fcb9835308145a74d7fcddd: run 36700467776. PR workflow Verified Originals v0.2 app also GREEN at the same head: run 36700472819.
- No TestFlight/Codemagic release build, Render deploy, release merge or RSA-key migration was performed.


### 2026-09-30 final follow-up before device/live tests

- HCVPACK export now revalidates the live YouTube reference immediately before decrypt/materialize/share. A stale local `hasReference` flag is insufficient: export requires REFERENCE_AVAILABLE + youtubeLive + commentsDisabled, otherwise it remains blocked.
- Hard-kill recovery now requeues only certificates for records newly sealed during that recovery pass. Already-indexed historical vault records are not redundantly re-enqueued.
- Audio fingerprint extraction is bounded to the first 15 seconds / existing 29-frame analysis window, preventing FFmpeg from decoding an entire long soundtrack when the verifier only consumes the bounded fingerprint.
- Messenger/extensionless import is locked by regression coverage for JPEG, PNG and ISO-BMFF `ftyp` magic-byte normalization to .jpg/.png/.mp4; native iPhone verification is still required.
- Production copy maps now have permanent exact-key parity coverage across IT/EN/ES/RU. Current key counts are equal in each language for the principal copy modules.
- Live-reference hardening is validated on pull requests as well as the feature-branch workflow. Exact feature HEAD before this documentation-only checkpoint: `a4c2c1d62315ba140fb4805c0f840b9cec8cbc92`; Verified Originals v0.2 app run `36701958172` GREEN.
- Current branch is 179 commits ahead and 0 behind `release/testflight-final-20260827`.
- Render production inspection: `sigillum-registry-production` tracks `release/reconciled-prelaunch-backend-clean-20260824`, has auto-deploy OFF, and its live deploy is still commit `3e62c5afc2c94f2585dbfefbe7c0981a1233b083` from 2026-09-25. None of the 2026-09-30 feature-branch changes were deployed.
- Remaining work is intentionally external/device-bound: controlled hard-kill tests on iPhone, subtitle E2E on iPhone, real Messenger/Instagram/Facebook/WhatsApp generations, measured iPhone verification timing, live YouTube OAuth/channel/comments-off publication test, then final backend reconciliation + Render deploy + one consolidated TestFlight build.
- No TestFlight/Codemagic release build, Render deploy, production environment-variable mutation, release merge/rebase, or RSA-key migration was performed.

## 2026-09-30 Final hardening pass — live export gate, bounded media work and validated recovery

- Pending-seal recovery is now staged before the Registry outbox write for both PHOTO and VIDEO. The local ordering is `stagePendingSeal -> enqueueCertificateFile -> seal -> network retry`, so a hard process kill cannot occur in the former journal-less gap between Registry enqueue and vault sealing.
- Startup recovery snapshots the vault IDs before `recoverPendingSeals()` and re-enqueues only records newly created by recovery. This covers a kill after journal staging but before Registry enqueue without redundantly re-enqueueing every already-indexed protected original.
- Deterministic same-owner pending-seal failures are cleaned: malformed/missing staged sources and immutable HCV conflicts no longer leave an endless recovery loop.
- Protected-original export now revalidates the live official YouTube reference when Registry says a reference exists. Export fails closed unless the backend reports `REFERENCE_AVAILABLE`, `youtubeLive=true` and `commentsDisabled=true`.
- HCVPACK export applies the same live-reference revalidation before decrypting/materializing the encrypted package, then deletes the temporary clear copy after the share handoff.
- `VERIFICA CONTENUTO` uses `YOUTUBE_LIVE_ATTESTED_SIGNED_V3` for modern social photo/video verification. Exact SHA-256 originals skip the YouTube check; modern derived copies check the live reference first and do not downgrade to legacy similarity if that official-reference path is unavailable.
- Verification timing is now visible and retained in technical diagnostics: total duration, backend/YouTube live-reference time and local V3 comparison time.
- Audio fingerprint extraction is bounded to the first 15 seconds, matching the existing 29-frame / 500 ms-hop fingerprint window. This removes unnecessary full-track FFmpeg extraction without changing the fingerprint data that the matcher actually uses.
- Messenger/extensionless import contract coverage now explicitly requires JPEG, PNG and ISO Base Media `ftyp` magic-byte routing.
- Backend V3 real-media regression now covers four consecutive social-like recompression generations for both photo and video. Generations 1–4 remain conforming; small-object insertion, hue, brightness and crop remain modified.
- App validation is GREEN at functional HEAD `a4c2c1d62315ba140fb4805c0f840b9cec8cbc92`: BUILD133 run `36701953799` passed formatting, Flutter analyze, the complete Flutter test suite and the release architecture guard; expanded Verified Originals v0.2 app run `36701958172` also passed, including the new live-reference/recovery contract.
- PR #123 remains open/draft against `release/testflight-final-20260827`. No TestFlight/Codemagic release build, release merge, Render deploy or production credential change was performed in this pass.

### Protected Originals recovery completion

- Recovery is now complete even when the first screen opened after a hard kill is `Originali protetti`, not the camera. `SecureOriginalsPage` snapshots existing vault IDs, runs `recoverPendingSeals()`, persists newly recovered certificate paths into the Registry outbox, and then retries synchronization asynchronously.
- The focused live-reference/recovery contract explicitly covers this Protected Originals path, including the Registry enqueue and retry.
- Final functional app HEAD for this pass is `213cd3e1250654cbcc5e64515df73277982feb45`. BUILD133 run `36702677669` is GREEN (format, analyze, complete Flutter tests, release architecture guard) and expanded Verified Originals v0.2 app run `36702682364` is GREEN.
- At validated functional HEAD `213cd3e1250654cbcc5e64515df73277982feb45`, the app branch comparison was 184 commits ahead and 0 behind `release/testflight-final-20260827`; later checkpoint-only commits do not change the functional delta. PR #123 remains open, draft and mergeable. No release merge or TestFlight build was created.

## 2026-09-30 Subscriber manual visual/audio comparison

- Added `ManualReferenceComparePage` for photo/video verification results. The user can inspect the received file locally and then open the official SIGILLUM YouTube copy for a human visual/audio comparison.
- VIDEO comparison includes local playback, scrubber, play/pause and audio mute/unmute. Opening the official YouTube copy preserves the current local timestamp through the YouTube `t=` parameter, so the user can compare the same moment in both versions.
- PHOTO comparison shows the received image locally and opens the corresponding official SIGILLUM YouTube reference for visual inspection.
- Manual comparison remains subscriber-only. The page checks `CommercialAccountService.billingStatus()` and obtains the locator only through authenticated `/api/verified-originals/:hcvId/view`; free discovery still never exposes the YouTube URL.
- Added `entitledLiveReference()`: before returning the paid `/view` reference, the app requires live YouTube attestation (`REFERENCE_AVAILABLE`, `youtubeLive=true`, `commentsDisabled=true`). The existing `CERCA COPIA UFFICIALE -> visualizza` flow now uses the same live gate.
- `RegistryVerifyPage` exposes `CONFRONTA MANUALMENTE` only for photo/video with a loaded certificate and a valid HCV-ID, and suppresses it when the official reference is already known as unavailable.
- New comparison UI/copy is complete in IT/EN/ES/RU and is covered by the BUILD133 live-reference contract.
- Functional app HEAD `1737f2067b490d708e633f7308c7f5574782f88d` validated GREEN: BUILD133 run `36709783319` and Verified Originals v0.2 app run `36709788936`.
- No TestFlight/Codemagic release build was created by this pass.


## 2026-09-30 Live YouTube correction — comments are advisory diagnostics

- The real OAuth/channel demo succeeded and a real YouTube API upload was processed successfully as `unlisted`; `videos.delete` also succeeded.
- The same API upload reported comments enabled even though both YouTube Studio upload defaults and channel moderation defaults were already configured with comments Off. The app must therefore not treat comment state as an availability/security gate.
- Modern social verification remains fail-closed on the official YouTube object itself: backend `REFERENCE_AVAILABLE`, `youtubeLive=true`, successful processing and `unlisted` privacy. Signed V3 is still disclosed only while that official reference is live.
- `commentsDisabled` remains visible in technical diagnostics when YouTube can report it, but false/unknown no longer produces OFFICIAL REFERENCE UNAVAILABLE.
- Protected-original share, HCVPACK export, paid `/view` access and manual visual/audio comparison still require a live official reference; only the unsupported comments hard-gate was removed.
- No TestFlight/Codemagic build, release merge, Render deploy, production-flag mutation or RSA-key migration was performed by this correction.
