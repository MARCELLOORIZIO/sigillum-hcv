# SIGILLUM diagnostic field observations — six HCV photos (2026-10-17)

**Experimental only.** Visual review of owner-shared screenshots with detector overlays, cross-referenced with owner-supplied Ultralytics LiteRT outputs. No change to PHOTO/HFR verdicts or inference thresholds.

| HCV ID prefix | Screen Detection (5 classes) | Phone V4 | Visible observation |
|---|---|---|---|
| B3461FFB | none | none | Dog on tiled floor; no visible phone |
| C8FFE434 | none | 3 boxes (0.394, 0.343, 0.327) | Television/TV content; V4 small boxes on details within displayed content, not visibly phones |
| D2BEECE9 | none | 1 box (0.532) | Computer monitor ASUS; V4 falsely calls region a phone |
| D320B452 | none | 1 box (0.369) | Street lamp and outdoor scene; V4 wrongly calls lamp a phone |
| D4E1E525 | none | none | Artwork/image on surface, no visible phone |
| E68BE510 | none | none | Person in front of curtains; no visible phone |

Observed Screen Detection omissions on images containing displays do not by themselves diagnose conversion degradation, training-label failures, or a capture-at-display verdict. V4 emitted 5 apparent false phone detections over 3 photos. The sample is tiny, not a statistical estimate.

**Important:** Uploaded images are *rendered copies with SIGILLUM capture overlays*. We cannot assess the influence of overlay text, compression, or model input parity without unoverlaid originals and coordinate-aligned reference data. The lack of a screen detection is NOT proof no screen was photographed. Detection of a screen is NOT proof of full-frame recapture.

## Regression expectations
1. On current screenshot copies, compare model outputs to the recorded detections at conf=0.25, IoU=0.7 (including the lamp false positive).
2. Evaluate variants with and without capture overlays from the same exact original only if real originals are made available, never synthesize expected authentic originals.
3. Record spatial position, confidence and model hashes; independently label visible objects and whether full-frame recapture can be established. Set UNKNOWN when undeterminable.
4. Shadow mode only. Never change production PHOTO decisions, HFR thresholds, PR #145 arbitration, or original files based on these six images.
5. Before iPhone parity claims, verify actual Flutter preprocessing, bounding-box transform and iPhone TFLite outputs numerically against Python for identical image bytes.

This is an observational audit record, **not** proof that either model is fit for production.
