# V3 PHOTO residual candidate — 2026-09-22

## Scope

PHOTO only. VIDEO remains unchanged on the stable V2 + HFR + persistence path.

## Architecture

Stable V2 remains the primary classifier.

Two compact binary V3 residual models are evaluated only for PHOTO:

- `clean_final.pt`
- `hard_final.pt`

The residual logic uses only SCREEN-family probabilities.

## Frozen rule

The rule was frozen before external evaluation:

- If V2 screen probability >= 0.85:
  - veto to REALITY only when:
    - clean < 0.20
    - hard < 0.40
    - hard - clean <= 0.10
- If V2 <= 0.20:
  - REALITY
- If 0.20 < V2 < 0.85:
  - promote to SCREEN only when V2 >= 0.30 and hard >= 0.90
  - otherwise REALITY

## Internal derivation

The veto boundary was derived from 276 internal cases with V2 >= 0.85:

- 267 true SCREEN
- 9 false-positive REALITY

Within the candidate veto region `clean < 0.20 && hard < 0.40`, the first true SCREEN appears at:

`delta = hard - clean = 0.1092699319`

The production candidate uses the round, more conservative limit:

`delta <= 0.10`

The BUILD126 holdout was not used to choose this threshold.

## External benchmark

Frozen PHOTO corpus:

- 13 / 13 correct
- SCREEN: 8 / 8
- REALITY: 5 / 5

BUILD126 PHOTO holdout:

- 15 / 15 correct
- SCREEN: 9 / 9
- REALITY: 6 / 6

Key cases:

- BMW perforated seat HCV-581449500C1846FC -> REALITY
- E9F75F00F6134AF7 high-zoom monitor -> SCREEN
- BD06C9FD69284BB6 high-zoom monitor -> SCREEN
- AEAFD4855C0B416E difficult monitor -> SCREEN
- DE79FC815C55453F real eye 15x -> REALITY
- 6AE8CBFD1D404588 real cockpit with embedded display -> REALITY

## Candidate package

Library:

`/SIGILLUM/SIGILLUM_V3_photo_residual_candidate_v1.zip`

ZIP SHA-256:

`04a15ba710ccc501cc796509ad6c06cb15a1d261cfa7429889c76b2fc53cd0e9`

## Status

OFFLINE CANDIDATE PASSED PHOTO GATE.

Not yet integrated into Flutter. Next gate is conversion to mobile TFLite, parity test against the PyTorch outputs, then app regression and physical retest.
