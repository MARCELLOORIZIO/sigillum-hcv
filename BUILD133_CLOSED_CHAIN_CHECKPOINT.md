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
