# SIGILLUM PHONE_DEVICE V4 — exported candidate verification (2026-10-17)

Status: **EXPERIMENTAL / NOT INTEGRATED / NOT iPHONE VALIDATED**.

## Provenance (observed locally by owner)
- Training dataset YAML: `V4_PHONE_DEVICE_DATASET/data.yaml`; class `0: PHONE_DEVICE`.
- Training: YOLOv8n, 40 epochs, `imgsz=416`.
- Training weights: `V4_TRAINING/phone_device_v1/weights/best.pt`.
- Export: Ultralytics 8.4.178, Python 3.12.15, torch 2.11.0, litert-torch 0.9.4, `format=litert imgsz=416 device=cpu nms=False`.
- Output: `V4_TRAINING/phone_device_v1/weights/best.tflite` (local Windows drive only; **not committed**).
- Exported model SHA-256: `69a68829f3328f3580dcd3fca7326f4b363c3579a58d558d9ffe0bfa1957ae85`.
- File: approximately 12.1 MB according to exporter (13M rounded by `ls -lh`).

## Actual LiteRT tensor contract (confirmed via interpreter)
- Input: `[1, 3, 416, 416]`, `float32`, NCHW, no quantization.
- Output: `[1, 5, 3549]`, `float32`, no quantization.
- One class. Each spatial candidate has four box values and one class confidence.
- `nms=False`: filtering and non-maximum suppression are not embedded in model; must be implemented/verified separately.
- Preprocessing must match Ultralytics letterbox, color order, scaling and channel organization. **Do not reuse** the 224x224 screen-replay classifier's preprocessing/output allocation.
- Confirm actual output coordinate convention against reference Python predictions before writing any Dart postprocessing; avoid inferring coordinate-space solely from output shape.

## Owner-supplied validation (same 828-image / 1014-instance split)
| Metric | Original best.pt | Exported best.tflite |
| --- | ---: | ---: |
| Precision | 0.931 | 0.935 |
| Recall | 0.833 | 0.836 |
| mAP50 | 0.902 | 0.900 |
| mAP50-95 | 0.665 | 0.664 |

TFLite validation: Ultralytics CLI, CPU, batch=1, 416px; reported average CPU inference 12.8ms/image. This is **not** iPhone latency and does not validate iOS interpreter compatibility or per-image equivalence.

## Guardrails for integration
1. Create an independent YOLO PHONE_DEVICE detection component. Do not replace `sigillum_screen_replay_v1/v2.tflite`, `hcv_ml_screen_replay_classifier.dart`, or their class-label contracts.
2. Initially expose only diagnostic spatial detections: boxes, confidences, asset hash/version, per-frame timing, analysis status.
3. Distinguish **phone/display object present** from **camera recaptured a display**. Device presence or its absence must never by itself imply authenticity, tampering or recapture.
4. Hold unchanged: provenance and integrity results; PHOTO multi-evidence arbitration, HFR comparability, temporal probes, threshold values, existing certificates and production pipeline.
5. The PHOTO arbitration conflict tracked in draft PR #145 must be resolved using evidence before connecting any V4 signal to decisions.
6. Before iPhone build: obtain the actual candidate binary by deliberate transfer, check SHA-256, confirm bundle loading and delegate support with `tflite_flutter`, perform reference cross-runtime output/NMS tests and regressions on real scene samples (screen in scene, full-frame recapture, physical patterned surfaces, difficult crops). Record explicit unknown/not-analyzed on load failures; never treat failure as clean scene.
7. No automatic production deployment or TestFlight promotion until device testing and owner approval.

## Repository context checked
On branch `experiment/phone-device-v4-export-20261016`, the existing `HCVMLScreenReplayClassifier` uses 224px classification and a one-vector probability result. `HCVMLModelStore` handles its specific bundled screen-replay models and label bundles. This is a different model contract than YOLO V4.

This report records owner-shared terminal results; it does not claim the cloud repository can access local drive G: or the exported model bytes.
