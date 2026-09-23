# SIGILLUM — Original hard binding and signed derivation chain V1

Status: DESIGN / SECURITY GATE. This document does NOT claim the ledger or cryptographically attested social derivatives have been implemented. PR #117 implements only the immediate fail-closed public verification verdict.

## Security invariant

A fingerprint, OCR-visible HCV-ID, watermark, successful audio match, ML classifier, or Registry record proves neither byte identity nor absence of visual edits. **Only** valid original certificate signature AND exact SHA-256 match to the verified asset can yield `FORENSIC VERIFIED OK` with current implementation. A signed, validated output-hash provenance chain may eventually support a distinct verdict `ATTESTED DERIVATIVE`, never `ORIGINAL`.

HCVPACK is an archival transport for original media + signed HCV certificate. Its existence does not authenticate arbitrary copies that differ from the original hash. It only authenticates the exact original media when signature and hash are checked.

## Planned V1 actor/trust model

- Capture signer issues HCV-ID and signs the content SHA-256 plus claims. Registry stores the signed original certificate. The exact original may be held by its owner in HCVPACK; a server-side immutable, content-addressed original escrow is optional and requires explicit product/privacy decision.
- SIGILLUM trusted transcode service accepts original HCVPACK/media, verifies signature, matching SHA-256, source HCV-ID and legal entitlement. No end-user declared action is accepted as proof.
- The service performs *only* explicit, bounded non-editorial operations it controls, for example codec/container conversion, resizing, frame-rate conversion and audio transcoding. It computes the actual resulting SHA-256 over the final output **after** the transform.
- A dedicated server signing key signs the complete canonical derivation assertion. The verifier trusts only allowlisted/rotatable SIGILLUM transform signers and verifies every input and output hash and full chain.
- Edits such as adding or removing a UFO, subtitles, text, objects, images, audio substitution, frame insertion or deletion, color grading, or unknown actions are not covered by the `non_editorial` profile. If edits are intentionally supported, show an explicitly labeled **EDITED DERIVATIVE**, never original or non-editorially preserved.
- Unknown off-platform social recompressions with no independently signed transformation statement remain `VISUAL SIMILARITY / ORIGINAL NOT VERIFIED` even when perceptually similar. No classifier or threshold can close that cryptographic gap.

## Proposed canonical signed statement

```json
{
  "schema": "SIGILLUM_DERIVATION_V1",
  "hcvId": "HCV-...",
  "parent": {
    "kind": "original|derivative",
    "sha256": "<64 lower-case hex>",
    "signedCertificateDigest": "<64 lower-case hex>"
  },
  "output": {
    "sha256": "<64 lower-case hex>",
    "byteLength": 0,
    "mediaType": "photo|video"
  },
  "transform": {
    "operation": "transcode|resize|repackage",
    "editorialImpact": "non_editorial",
    "policyVersion": "SIGILLUM_NON_EDITORIAL_V1",
    "parametersDigest": "<64 lower-case hex>"
  },
  "issuer": {
    "keyId": "<allowlisted server signer key ID>",
    "serviceVersion": "<immutable build SHA>"
  },
  "createdAt": "<UTC timestamp>",
  "nonce": "<unique ID>",
  "signature": "<signature over canonical statement excluding signature>"
}
```

Field validation, canonical serialization, key rotation/revocation, replay defense, immutable event ordering, parent manifest digest, content-retention and expiry policy must be defined before deployment. A self-signed claim or a submitted JSON document is not an attestation.

## Public verdict contract

| Situation | Allowed result |
|---|---|
| Registry certificate cryptographically valid AND selected file SHA-256 equals signed original hash | `FORENSIC VERIFIED OK` (original file intact; NOT proof that scene depicts reality) |
| SHA differs, V2 and audio match, no trusted output-hash attestation | `VISUAL SIMILARITY / ORIGINAL NOT VERIFIED` (no green/original badge) |
| SHA differs, signature-valid trusted manifest's output SHA matches selected file, and chain reaches signed original | future `ATTESTED DERIVATIVE`, precise declared operations and no original label |
| SHA differs and perceptual match fails / audio changed / ID copied | `ID VALID / MEDIA NOT VERIFIED` |
| Legacy V1 only, SHA differs | `SOCIAL LIMITED` / integrity inconclusive |
| Missing, invalid or revoked root/chain key, unknown transform, altered manifest, edited frames, absent output binding | Fail closed: do NOT attest derivative |

The captured original itself may depict a TV, a staged scene or a real UFO-like object; capture integrity and scene credibility are separate axes.

## Mandatory acceptance gates

1. Real iPhone original PHOTO/VIDEO: signed HCVPACK hash equals the certificate, forensic verdict only for exact bytes.
2. Real edited PHOTO with inserted small/large/translucent text or object: never original or attested non-editorial derivative, even if fingerprint matches.
3. Real edited VIDEO with inserted UFO in 1 frame, unsampled time interval and persistent scene, preserved original audio and HCV-ID: never original or attested non-editorial derivative, even if sampled fingerprint matches.
4. Genuine off-platform Messenger/Instagram derivatives without an independently signed transform: only visual association/integrity unproven.
5. Server-created, auditable non-editorial rendition: original input validation + whitelisted transform + exact output hash + valid signed manifest => separate attested derivative status.
6. Tampered output, tampered parent reference, forged transform, copied HCV-ID, substituted media, valid signature but wrong output SHA, untrusted/revoked signer, registry unavailable: no attested derivative.
7. Present separate provenance, byte integrity, derivation proof and scene-credibility axes across IT/EN/ES/RU. Never display a green badge for visual similarity alone.

## References

- C2PA 2.3 specification, Section 9 (Hard vs Soft bindings), Sections 6/18 (actions and provenance): https://spec.c2pa.org/specifications/specifications/2.3/specs/C2PA_Specification
- C2PA 2.3 guidance (SHA-256 hard binding): https://spec.c2pa.org/specifications/specifications/2.3/guidance/Guidance.html
