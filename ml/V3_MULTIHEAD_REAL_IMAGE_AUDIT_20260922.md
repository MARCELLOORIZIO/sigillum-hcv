# BUILD127 V3 multi-head real-image audit — 2026-09-22

## Scope

PHOTO only. VIDEO, HFR, FOV comparability and BUILD126 persistence logic remain unchanged.

This audit verifies the saved V3 multi-head checkpoint and FP16 weight transport against the actual 28-image evaluation set used during BUILD127 work.

## Evaluation set

The 28 source JPEGs were recovered from the persistent SIGILLUM photo-mining corpus by HCV-ID:

- 13 EVAL_FROZEN
- 15 BUILD126 HOLDOUT
- 17 SCREEN-family ground truth
- 11 REALITY-family ground truth

Every extracted JPEG matched the SHA-256 recorded in the mining manifest.

Persistent source artifacts:

- `SIGILLUM_hcv_photo_mining_v1.zip`
  - SHA-256: `842c868542d61bd5d78cfe5c4511bad869852f14140a3b857b4fc9260d495e4b`
- `v3_multihead_benchmark_28of28.csv`
  - SHA-256: `6cb442b07a612ff2f48959592b5c82b02ac52e21ff6a57f358434aa450610ec4`
- `v3_multihead_fp16_benchmark_28of28.csv`
  - SHA-256: `c94b718763640c507a7edbb1615a5de6b4dfd6b554318886c09c655e85076c49`
- `v3_multihead_best_epoch5.pt`
  - SHA-256: `f9a38066ac3c2f6a504022b23390e08e5dc407a2c0fa9e0c00f8c74bd8b1f5fb`
- `v3_multihead_weights_fp16.json`
  - SHA-256: `50e294892cded345fb7a107d16df32e3d00b17634dcac0db93d22d1ced37dba1`

## Checkpoint replay

The epoch-5 PyTorch checkpoint was replayed from the recovered JPEGs using the production-equivalent 96x96 black-letterbox preprocessing.

Maximum absolute difference versus `v3_multihead_benchmark_28of28.csv`:

- clean SCREEN-family probability: `1.3411045080014006e-07`
- hard SCREEN-family probability: `1.1920928955078125e-07`

This independently reproduces the saved real-image benchmark.

## FP16 transport replay

The model was rebuilt from `v3_multihead_weights_fp16.json` and replayed on the same 28 source JPEGs.

Maximum absolute difference versus `v3_multihead_fp16_benchmark_28of28.csv`:

- clean SCREEN-family probability: `1.1920928955078125e-07`
- hard SCREEN-family probability: `1.7881393432617188e-07`

Therefore the FP16 weight transport preserves the saved multi-head real-image outputs to numerical precision.

## 28/28 benchmark rule

The saved benchmark prediction rule is:

- if V2 >= 0.80:
  - REALITY only when max(clean, hard) < 0.25
  - otherwise SCREEN
- if V2 <= 0.15:
  - REALITY
- otherwise:
  - SCREEN when max(clean, hard) >= 0.50
  - otherwise REALITY

Applied to the FP16 outputs, this rule gives:

- frozen: 13 / 13
- BUILD126 holdout: 15 / 15
- combined: 28 / 28

## Production Flutter policy is intentionally more conservative

The current Flutter integration does NOT install the full benchmark classifier rule.

`HCVMLV3PhotoResidual` is limited to `PHOTO_V2_FALSE_POSITIVE_VETO_ONLY`:

- V2 high threshold: 0.80
- V3 reality veto threshold: 0.20
- no V3 positive SCREEN promotion
- no VIDEO effect
- no ability to override decisive HFR DISPLAY evidence

Using the 28-case FP16 outputs, the current Flutter veto fires in exactly one case:

- `HCV-581449500C1846FC` — REALITY_OBJECT, perforated BMW seat

It fires in zero of the 17 SCREEN-family cases.

A Dart regression test locks this property:
`test/build127_v3_photo_residual_28case_gate_test.dart`.

The difficult SCREEN cases with low or misleading V2 family classification remain the responsibility of the already-validated BUILD126 HFR / temporal / multi-evidence path; V3 does not replace those independent evidence channels.

## TFLite status

The committed TFLite is generated from the FP16 multi-head weights and the conversion workflow verifies numerical Keras/TFLite parity on deterministic tensors.

This audit independently verifies the real-image PyTorch checkpoint and FP16 transported weights. It does not claim a separate local 28-image TFLite runtime execution because a native TensorFlow Lite runtime was not available in the audit environment.

The remaining release gate is therefore:

1. CI green with the conservative PHOTO-only V3 integration;
2. direct app/device retest on the BUILD126 physical holdout;
3. confirm BMW seat resolves away from STRONG_DISPLAY_RISK;
4. confirm difficult monitors remain STRONG_DISPLAY_RISK through V2/HFR/multi-evidence;
5. keep VIDEO behavior unchanged.
