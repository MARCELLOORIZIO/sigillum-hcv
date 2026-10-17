"""Experimental, read-only comparison of two SIGILLUM LiteRT detectors.

Run against one directory of *independent, owner-selected* test images.
Each model runs on exactly the same files. CSV contains counts/confidences
and never infers physical display recapture or image authenticity.

Dependencies: ultralytics, installed in ~/sigillum-v4-py312.
"""
from __future__ import annotations

import argparse
import csv
from pathlib import Path

SUFFIXES = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--images", type=Path, required=True)
    parser.add_argument("--screen-model", type=Path, required=True)
    parser.add_argument("--phone-model", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path.home() / "sigillum_dual_detector_audit.csv")
    parser.add_argument("--conf", type=float, default=0.25)
    args = parser.parse_args()
    if not args.images.is_dir():
        parser.error("Image directory does not exist")
    for path in (args.screen_model, args.phone_model):
        if not path.is_file():
            parser.error(f"Model not found: {path}")
    if not 0.0 < args.conf < 1.0:
        parser.error("--conf must be between 0 and 1")
    images = sorted(p for p in args.images.rglob("*") if p.is_file() and p.suffix.lower() in SUFFIXES)
    if not images:
        parser.error("No supported images found")

    from ultralytics import YOLO

    screen = YOLO(str(args.screen_model))
    phone = YOLO(str(args.phone_model))
    rows = []
    for n, image in enumerate(images, 1):
        row = {"image": image.relative_to(args.images).as_posix()}
        for tag, model, imgsz in (("screen", screen, 608), ("phone", phone, 416)):
            result = model.predict(source=str(image), imgsz=imgsz, device="cpu",
                                   conf=args.conf, iou=0.7, verbose=False)[0]
            detections = []
            for box in result.boxes:
                class_id = int(box.cls[0])
                score = float(box.conf[0])
                coords = [round(float(v), 1) for v in box.xyxy[0].tolist()]
                detections.append((str(model.names[class_id]), round(score, 4), coords))
            row[tag + "_count"] = len(detections)
            row[tag + "_detections"] = repr(detections)
        rows.append(row)
        if n % 25 == 0 or n == len(images):
            print(f"Processed {n}/{len(images)}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["image", "screen_count",
                                                    "screen_detections", "phone_count",
                                                    "phone_detections"])
        writer.writeheader()
        writer.writerows(rows)
    mismatches = sum(bool(r["screen_count"]) != bool(r["phone_count"]) for r in rows)
    print(f"Saved: {args.output}; images={len(rows)}; differing detection presence={mismatches}")
    print("Not an accuracy measurement unless images have independent annotations.")
    print("Neither positive nor negative device detection proves display recapture.")


if __name__ == "__main__":
    main()
