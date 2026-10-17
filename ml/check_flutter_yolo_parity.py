"""Compare actual Flutter diagnostic outputs against Ultralytics reference JSON.

Fail-closed diagnostic gate. Requires REAL Flutter outputs produced by
HCVYoloDiagnosticRunner on precisely the same image bytes as the reference.
Does not create predictions, modify models, or infer capture authenticity.
"""
import argparse
import json
from pathlib import Path


def evaluate(reference, dart, coordinate_tolerance=2.0, score_tolerance=0.03):
    issues = []
    if reference.get("type") != "SIGILLUM_YOLO_REFERENCE_ONLY":
        return ["Invalid Ultralytics reference type"]
    if dart.get("type") != "SIGILLUM_YOLO_FLUTTER_PARITY":
        return ["Invalid Flutter diagnostic output type"]
    flutter_by_image = {row.get("imageSha256"): row for row in dart.get("images", [])}
    if len(flutter_by_image) != len(dart.get("images", [])):
        issues.append("Duplicate Flutter image hash")
    for item in reference.get("images", []):
        key = item["imageSha256"]
        other = flutter_by_image.get(key)
        if other is None:
            issues.append(f"{item['image']}: missing matching Flutter image SHA256")
            continue
        for model, expected in item["models"].items():
            actual = other.get("models", {}).get(model)
            if not actual or actual.get("analysisStatus") != "ANALYZED":
                issues.append(f"{item['image']} {model}: no real Flutter inference")
                continue
            if actual.get("modelSha256") != expected["modelSha256"]:
                issues.append(f"{item['image']} {model}: model SHA256 mismatch")
                continue
            boxes = actual.get("detections", [])
            reference_boxes = expected["detections"]
            if len(boxes) != len(reference_boxes):
                issues.append(f"{item['image']} {model}: different number of detections ({len(boxes)} vs {len(reference_boxes)})")
                continue
            unmatched = list(boxes)
            for want in reference_boxes:
                candidates = [
                    (index, box) for index, box in enumerate(unmatched)
                    if box.get("class") == want["class"]
                    and abs(box.get("confidence", -999) - want["score"]) <= score_tolerance
                    and isinstance(box.get("boxXYXY"), list)
                    and len(box["boxXYXY"]) == 4
                    and all(abs(a - b) <= coordinate_tolerance
                            for a, b in zip(box["boxXYXY"], want["xyxy"]))
                ]
                if not candidates:
                    issues.append(f"{item['image']} {model}: no matching Flutter box for {want}")
                else:
                    unmatched.pop(candidates[0][0])
    return issues


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--reference", type=Path, required=True)
    p.add_argument("--flutter", type=Path, required=True)
    args = p.parse_args()
    issues = evaluate(json.loads(args.reference.read_text()),
                      json.loads(args.flutter.read_text()))
    if issues:
        print("\n".join(issues))
        raise SystemExit(1)
    print("Flutter/Ultralytics box parity: PASSED for provided real outputs.")


if __name__ == "__main__":
    main()
