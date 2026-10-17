"""Audit known SIGILLUM detector observations without changing model policy.

Input is output of ml/export_dual_yolo_reference_predictions.py generated with
conf=0.25, iou=0.7 and the two pinned LiteRT binaries.
This is a regression *observation*, not a quality or authenticity assertion.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

EXPECTED = {
    "B3461FFB": (0, 0),
    "C8FFE434": (0, 3),
    "D2BEECE9": (0, 1),
    "D320B452": (0, 1),
    "D4E1E525": (0, 0),
    "E68BE510": (0, 0),
}


def check(data: dict) -> list[str]:
    errors = []
    if data.get("type") != "SIGILLUM_YOLO_REFERENCE_ONLY":
        return ["Wrong reference JSON type"]
    if data.get("confidenceThreshold") != 0.25 or data.get("iouThreshold") != 0.7:
        errors.append("Reference threshold mismatch (must be conf=0.25 iou=0.7)")
    seen = set()
    for row in data.get("images", []):
        filename = row.get("image", "")
        matched = [key for key in EXPECTED if key in filename]
        if len(matched) != 1:
            continue
        key = matched[0]
        if key in seen:
            errors.append(f"Duplicate HCV case {key}")
            continue
        seen.add(key)
        models = row.get("models", {})
        try:
            screen = models["screen_detection"]
            phone = models["phone_device_v4"]
            actual = (len(screen["detections"]), len(phone["detections"]))
        except (KeyError, TypeError):
            errors.append(f"{key}: model detections missing")
            continue
        if actual != EXPECTED[key]:
            errors.append(f"{key}: observed counts {actual} != baseline {EXPECTED[key]}")
    for key in EXPECTED.keys() - seen:
        errors.append(f"Missing case {key}")
    return errors


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("reference_json", type=Path)
    args = p.parse_args()
    data = json.loads(args.reference_json.read_text(encoding="utf-8"))
    errors = check(data)
    if errors:
        for message in errors:
            print("CHECK:", message)
        raise SystemExit(1)
    print("Six-case observation baseline MATCHED.")
    print("WARNING: This verifies reproducibility of previously observed outputs,")
    print("NOT correct object detection, screen recapture, or authenticity.")


if __name__ == "__main__":
    main()
