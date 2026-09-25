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

## Resume rule

Do not start again from the design discussion. Resume from the first unfinished item in the implementation plan, inspect this file plus the backend checkpoint, and preserve the locked product decisions above.
