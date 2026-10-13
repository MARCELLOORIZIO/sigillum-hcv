# SIGILLUM — PHOTO framing policy reconstruction (2026-10-13)

## Objective and scope

This is a **proposed decision specification**, not a trained model, a corpus result, or a production-policy change. Preserve Build 157 V2/V3/HFR/optical baselines until the full regression gate passes. Do not change classifier thresholds on the strength of four field samples.

### Historic evidence baseline

- `ml/hard_negative_sets/build127_training_corpus_final_v1.json`: 1,502 images, 580 legacy SCREEN and 922 REALITY, seven legacy families. The effective V3 development corpus after removing BUILD126 held-out BMW examples was 1,500.
- The historic SCREEN vs REALITY dataset describes source/family appearance, not the new **human-visible screen-as-object vs deceptive screen-recapture** ground truth. Do **not** relabel all 580 legacy SCREEN images as deceptive recaptures.
- `ml/V3_BENCHMARK_20260921.md`: frozen 13, independent physical holdout 15, no V3 full replacement unless screen recall retained, reality false positives reduced and fresh holdout passed.
- `test/build127_v3_photo_residual_28case_gate_test.dart`: independent 28-case regression set and hard-negative BMW veto requirement.
- `ml/sigillum_photo_framing_v1_PARITY.json`: PHOTO TFLite parity passes numerically; training classifications are PRELIMINARY_NOT_INDEPENDENTLY_VALIDATED and PHOTO role remains DIAGNOSTIC_ONLY until independently evaluated.

## Distinct outputs (do not collapse them)

1. **SCENE_WITH_IDENTIFIABLE_DISPLAY_OBJECT**: an observable monitor/phone/tablet is recognizably a *physical object* by its silhouette, bezel, stand, 3D perspective, occlusion, surrounding room, credible boundaries, or independent multi-depth geometry. This is a REAL_PHYSICAL_SCENE framing verdict, **not** an assertion that the displayed pixels or the overall document are authentic.
2. **POSSIBLE_DECEPTIVE_FULL_FRAME_DISPLAY**: screen content fills the frame such that an observer cannot distinguish display pixels from a live scene; no reliable device/room context, screen border or physical framing remains. This is a *risk/hypothesis*, not proof of screen recapture.
3. **PHYSICAL_SURFACE_OR_SCENE**: no display is evidenced, or an ordinary surface is physically supported.
4. **UNDETERMINED**: visual framing ambiguous or independent signals conflict; never force green or red.

## Ordered evaluation rules — intended future policy

A. Evaluate provenance/integrity and physical screen/scene risk as **independent axes**. Never infer provenance from PHOTO scores.
B. Evaluate visual object framing first, from actual visible geometry. A detected screen is a *visible object* only if there is independent, interpretable context (e.g. bezel + stand/room, consistent perspective/occlusion, or validated multi-depth scene evidence). A single rectangle, window, painting, UI box, or image border is **not** sufficient.
C. For corroborated screen-as-object in a scene, set framing to `SCENE_WITH_IDENTIFIABLE_DISPLAY_OBJECT`. Do not raise **full-frame deceptive recapture** solely because V2/V3 or semantic PHOTO recognizes SCREEN. Persist separate field `screenObjectVisible=true` (if independently corroborated).
D. For likely full-frame screen imagery with no identifiable device-object context, combine V2 semantics, V3 residual (hard/clean), HFR physical evidence, passive optical evidence, and semantic PHOTO `POSSIBLE_FULL_FRAME_DISPLAY`. A semantic classifier by itself cannot assert recapture. Use the established physical corroboration paths before declaring strong risk; contradictory/low-quality cases remain `UNDETERMINED`.
E. V3 remains an anti-false-positive residual; **a veto must not convert a visually/physically supported full-frame display into certain REALITY**. A conflict among strong independent display evidence and V3 moves to `UNDETERMINED` until the whole corpus and physical holdout demonstrate a safe alternative. Existing hard-negative textile/skin/paper cases must remain protected.
F. For ordinary physical texture (fabric, perforated seat, skin, printed paper), require corroborated physical evidence to avoid a screen alarm; do not treat absence of a bezel as affirmative display evidence.
G. If HFR is non-comparable or unavailable, do not read its absence as no screen. Conclude `UNDETERMINED` when other independent observations remain conflicting.
H. VIDEO retains the pre-existing initial-window rules; PHOTO framing changes must not silently affect VIDEO.

## Field regression examples — manually observed 2026-10-13

- `HCV-320B7BFFF0AB41CC`: desk with two unmistakable monitors, `SCENE_WITH_IDENTIFIABLE_DISPLAY_OBJECT`. Semantic PHOTO DISPLAY_IN_REAL_SCENE ~0.9633; V2 REALITY_ROOM ~0.0129 screen probability. *Current final NO_DISPLAY_EVIDENCE is not necessarily an incorrect full-frame verdict; however it fails to explicitly report screen-as-object.*
- `HCV-A0320ADC213C460C`: close-up of pixels/UI without recognizable screen hardware, candidate `POSSIBLE_DECEPTIVE_FULL_FRAME_DISPLAY`. Semantic PHOTO possible full-frame ~0.8326; V2 screen ~0.9437, V3 hard-negative reality ~0.999807. This is an important conflict: do not force either certain REALITY or certain recapture without independent proof.
- `HCV-6FD2FFCD6CDF438C`: blue display-like textured area, semantic PHOTO possible full-frame ~0.9753, V2 screen ~0.9617, but positive embedded context contradicts. `UNDETERMINED` pending human framing/physical corroboration; do not overrule the conflict blindly.
- `HCV-56D4B022D9C34A77`: physical balcony at night, no visible screen; PHYSICAL_SURFACE_OR_SCENE and no recapture alarm.

## Mandatory corpus gate before production wiring

1. Obtain the referenced 1,502-image archive by its verified SHA-256. Confirm metadata and deduplication, preserve original annotations and train/holdout split. The GitHub manifest **is not** the image bytes.
2. Independently annotate every relevant image with **screenObjectVisible**, **deviceFramingRecognizable**, **fullFrameDeceptiveAppearance**, **independentPhysicalEvidence**, and **humanUncertain**; adjudicate ambiguous images separately. Do not recycle the legacy V2 predictions as truth.
3. Evaluate the original 580 SCREEN/922 REALITY families plus the new visual-framing labels. Report matrices separately for (i) object-screen detection, (ii) deceptive recapture risk, (iii) real physical textures. Distinguish missing labels from negatives.
4. Compare frozen BUILD157 baseline, proposed rules and unchanged V2/V3/PHOTO scores on exactly the same images, without re-training or threshold tuning on holdout.
5. Require no loss of known screen-recognition cases; no reintroduced previously eliminated real-texture false positives; correct handling of distinguishable physical monitors; and no HIGH-deception classifications based on semantic probabilities alone. Fail closed to UNDETERMINED on uncovered conflicts.
6. Re-test the historical frozen 13, BUILD126 holdout 15, 28-case residual gate, and fresh camera/iPhone cases. Only then approve production rule rewiring; do not auto-ship or auto-upload to TestFlight.

## Implementation boundary

The current PHOTO semantic model is diagnostic. Implementation needs new **orthogonal** object-framing and deceptive-recapture fields rather than overwriting legacy `displayRiskDecision` without a validated migration. Do not change historic V2/V3 model assets, thresholds, signature or certificate integrity logic.
