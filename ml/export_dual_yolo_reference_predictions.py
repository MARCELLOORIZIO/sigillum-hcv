"""Generate deterministic reference detections for the two experimental models.

Read-only inference on owner-supplied images. Does not upload or alter images,
does not assert image authenticity, and does not modify SIGILLUM's PHOTO policy.
Requires ultralytics and both previously exported LiteRT files.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
SCREEN_SHA = "eeb5b914fff6f4843e25c562ca78ab3d656bca21d5b9fce062544be4b5f12668"
PHONE_SHA = "69a68829f3328f3580dcd3fca7326f4b363c3579a58d558d9ffe0bfa1957ae85"


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--images", type=Path, required=True)
    p.add_argument("--screen-model", type=Path, required=True)
    p.add_argument("--phone-model", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True)
    p.add_argument("--conf", type=float, default=0.25)
    p.add_argument("--iou", type=float, default=0.7)
    args = p.parse_args()
    if not args.images.is_dir():
        p.error("Image directory not found")
    for file, expected in ((args.screen_model, SCREEN_SHA), (args.phone_model, PHONE_SHA)):
        if not file.is_file() or digest(file) != expected:
            p.error(f"Expected model binary not found or SHA-256 mismatch: {file}")
    if not 0 < args.conf < 1 or not 0 < args.iou < 1:
        p.error("Invalid conf/iou")
    photos = sorted(f for f in args.images.rglob("*") if f.is_file() and f.suffix.lower() in EXTENSIONS)
    if not photos:
        p.error("No test photos")
    from ultralytics import YOLO

    models = [("screen_detection", YOLO(str(args.screen_model)), 608),
              ("phone_device_v4", YOLO(str(args.phone_model)), 416)]
    results = []
    for index, photo in enumerate(photos, 1):
        record = {"image": photo.relative_to(args.images).as_posix(),
                  "imageSha256": digest(photo), "models": {}}
        for name, model, size in models:
            pred = model.predict(str(photo), imgsz=size, conf=args.conf,
                                 iou=args.iou, device="cpu", verbose=False)[0]
            detections = []
            for box in pred.boxes:
                detections.append({
                    "class": str(model.names[int(box.cls[0])]),
                    "score": round(float(box.conf[0]), 6),
                    "xyxy": [round(float(v), 3) for v in box.xyxy[0].tolist()],
                })
            detections.sort(key=lambda d: (-d["score"], d["class"], d["xyxy"]))
            record["models"][name] = {"inputSize": size,
                                      "modelSha256": SCREEN_SHA if name == "screen_detection" else PHONE_SHA,
                                      "detections": detections}
        results.append(record)
        if index % 25 == 0 or index == len(photos):
            print(f"{index}/{len(photos)}")
    payload = {"type": "SIGILLUM_YOLO_REFERENCE_ONLY", "status": "DIAGNOSTIC_ONLY",
               "confidenceThreshold": args.conf, "iouThreshold": args.iou,
               "images": results}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    print(f"Saved {args.out}; images={len(results)}")
    print("No inference about display recapture or authenticity is permitted.")


if __name__ == "__main__":
    main()
