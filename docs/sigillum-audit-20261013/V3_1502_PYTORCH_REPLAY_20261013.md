# 1,502 PHOTO corpus V3 execution — exploratory replay

Date: 2026-10-13. Independent new framing labels: **NOT AVAILABLE**. This is a completed 1,502-image V3 score replay, **not** an independent generalization benchmark, and not mobile-TFLite parity verification.

Input archive: `SIGILLUM_build127_training_corpus_final_v1.zip` SHA256 `1d12bf594cec61616ef2b922915a31263f693b31d959ccea39914643b4c995f8`, 1,502 JPGs, individual hashes previously verified. Local model: `/SIGILLUM/V3/v3_multihead_best_epoch5.pt`, PyTorch 96x96 RGB letterbox bilinear, dual clean/hard softmax branches. Reconstructed the architecture and loaded original state dict; not the full deployed V3 TFLite with hard-negative head. Outputs saved in standalone audit pack, not certificate decisions.

| Legacy family | N | V3 max SCREEN >= 0.80 | BOTH clean/hard SCREEN < 0.20 |
|--|--:|--:|--:|
| SCREEN_MONITOR | 479 | 413 | 5 |
| SCREEN_PHONE | 65 | 22 | 11 |
| SCREEN_TABLET | 36 | 23 | 0 |
| REALITY_PAPER | 203 | 0 | 183 |
| REALITY_ROOM | 199 | 0 | 163 |
| REALITY_OBJECT | 334 | 1 | 274 |
| REALITY_OUTDOOR | 186 | 3 | 139 |
| **SCREEN total** | **580** | **458** | **16** |
| **REALITY total** | **922** | **4** | — |

The 458/580 and 4/922 are **in-sample model diagnostic threshold counts against legacy family labels**, not recall or false-positive measurements for deceptive recapture. The 580 legacy SCREEN labels include identifiable devices as ordinary objects, so many apparent V3 misses may be semantically appropriate under the NEW taxonomy. No threshold is to be promoted based on these counts.

Next required gates: independent full-image adjudication of monitor-as-object vs frame-filling deceptive screen; recompute V2 and deployed V3 TFLite with confirmed preprocessing and hard-negative head; add the new PHOTO model and strong physical signals on a held-out set; verify no harm to historic cases and four 2026-10-13 field photos. NO code or thresholds modified by this run.
