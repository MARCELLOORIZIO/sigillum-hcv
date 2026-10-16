# SIGILLUM V4 PHOTO — external training (research only)

This isolated pipeline uses two different YOLO detectors instead of merging incompatible labels:

1. **Mobile Detection v4**: device localization.
2. **Screen Detection YOLOv8**: screen/monitor/laptop/tablet localization.

A screen bounding box alone **does not establish recapture**. A photographed screen may be embedded in a legitimate real-world scene. V2/V3/HFR remain authoritative and unchanged.

## Training on a working GPU machine

Install Python 3.10+ and a compatible PyTorch/CUDA stack. Then:

```bash
pip install ultralytics py7zr multivolumefile pillow pyyaml
python research/v4_photo/train_external_yolo.py \
  --mobile-first "/path/Mobile Detection v4.v1i.yolov8.7z.001" \
  --screen-zip "/path/Screen Detection YOLOv8.zip" \
  --inspect-only
```

After inspecting `audit.json` and confirming appropriate data rights:

```bash
python research/v4_photo/train_external_yolo.py \
  --mobile-first "/path/Mobile Detection v4.v1i.yolov8.7z.001" \
  --screen-zip "/path/Screen Detection YOLOv8.zip" \
  --epochs 60 --imgsz 640 --batch 16 --device 0
```

Both 7z volumes must share a directory. ZIP extraction is path-checked. Third-party dataset `best.pt` is intentionally **not loaded** because pickle-based PyTorch checkpoints can execute untrusted code. Training starts from official Ultralytics `yolov8n.pt` downloaded by Ultralytics. Review installation, model provenance, licenses, and training environment security.

Results: `sigillum_v4_external_training/audit.json`, `results.json`, and separate weights in `runs/device_detector` and `runs/screen_detector`.

## Acceptance gates
- Validate images and YOLO annotations; manually inspect per-class boxes.
- Eliminate duplicated *scenes* across training/test, not just identical hashes.
- Validate each detector's mAP on a genuinely held-out collection of device and screen imagery.
- Validate combined downstream classification on original SIGILLUM false-positive and false-negative cases plus a **never-seen, smartphone-shot external sample**.
- Reject if adding detectors increases false-red decisions for scenes containing TVs/phones or for textiles, documents, walls, etc.
- Do not deploy this research branch or use its weights in SIGILLUM production unless all gates pass.

**Status:** pipeline committed, but training has NOT run from ChatGPT because its container service fails on trivial commands. Files saved in an earlier conversation do not automatically imply an external GPU runner can read them.
