"""Export a locally trained phone/device YOLO detector as a TFLite candidate.

Does not touch SIGILLUM production assets, pubspec.yaml or detector thresholds.
Run on the machine holding best.pt, with ultralytics and export dependencies.
"""
import argparse
import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--weights", type=Path, required=True, help="Path to trained best.pt")
    parser.add_argument("--out", type=Path, required=True, help="Directory for isolated export")
    parser.add_argument("--imgsz", type=int, default=416)
    args = parser.parse_args()
    if not args.weights.is_file():
        parser.error(f"weights not found: {args.weights}")
    if args.imgsz <= 0:
        parser.error("imgsz must be positive")

    from ultralytics import YOLO

    args.out.mkdir(parents=True, exist_ok=True)
    model = YOLO(str(args.weights.resolve()))
    # No INT8 calibration, half precision, NMS fusion or threshold changes.
    exported = Path(model.export(format="tflite", imgsz=args.imgsz, int8=False, nms=False))
    if not exported.is_file():
        raise RuntimeError(f"Export did not produce one TFLite file: {exported}")
    dest = args.out / "phone_device_v1_candidate.tflite"
    if exported.resolve() != dest.resolve():
        shutil.copy2(exported, dest)

    # Inspect the *actual* tensor contract; do not assume YOLO output layout.
    import tensorflow as tf
    interpreter = tf.lite.Interpreter(model_path=str(dest))
    interpreter.allocate_tensors()
    tensor_info = lambda entries: [
        {
            "name": item["name"],
            "shape": [int(v) for v in item["shape"]],
            "shape_signature": [int(v) for v in item["shape_signature"]],
            "dtype": str(item["dtype"]),
            "quantization": list(item["quantization"]),
        }
        for item in entries
    ]
    manifest = {
        "type": "SIGILLUM_PHONE_DEVICE_V4_CANDIDATE",
        "createdAtUtc": datetime.now(timezone.utc).isoformat(),
        "sourceWeightsName": args.weights.name,
        "sourceWeightsSha256": sha256(args.weights),
        "tfliteName": dest.name,
        "tfliteSha256": sha256(dest),
        "imgsz": args.imgsz,
        "ultralyticsClasses": {str(k): str(v) for k, v in model.names.items()},
        "inputTensors": tensor_info(interpreter.get_input_details()),
        "outputTensors": tensor_info(interpreter.get_output_details()),
        "integrated": False,
        "validatedOnIPhone": False,
    }
    (args.out / "candidate_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(json.dumps({"candidate": str(dest), "manifest": str(args.out / "candidate_manifest.json")}, indent=2))


if __name__ == "__main__":
    main()
