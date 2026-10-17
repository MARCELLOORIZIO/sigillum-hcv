r"""Read-only comparison of two local YOLO datasets for SIGILLUM V4.

Usage (Windows PowerShell, from any directory):
  python compare_v4_datasets.py --a "C:\\Users\\Admin\\Documents\\SIGILLUM IPHONE\\V4_PHONE_DEVICE_DATASET" --b "C:\\Users\\Admin\\Documents\\SIGILLUM IPHONE\\Mobile Detection v4.v1i.yolov8"

Stdlib only. Never edits data; prints counts, exact SHA-256 overlaps,
cross-split leakage and class IDs. No filenames or private images uploaded.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from hashlib import sha256
from pathlib import Path

SPLIT_NAMES = {"train": "train", "valid": "val", "val": "val", "test": "test"}
EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def inventory(root: Path):
    entries = []
    missing_labels = []
    classes = Counter()
    invalid = []
    for subfolder, split in SPLIT_NAMES.items():
        images = root / subfolder / "images"
        labels = root / subfolder / "labels"
        if not images.is_dir():
            continue
        for image in sorted(images.rglob("*")):
            if not image.is_file() or image.suffix.lower() not in EXTENSIONS:
                continue
            digest = sha256(image.read_bytes()).hexdigest()
            relative_stem = image.relative_to(images).with_suffix("")
            label = labels / relative_stem.with_suffix(".txt")
            entries.append((split, digest, image.relative_to(root).as_posix()))
            if not label.is_file():
                missing_labels.append(image.relative_to(root).as_posix())
                continue
            for line in label.read_text(encoding="utf-8-sig", errors="replace").splitlines():
                if not line.strip():
                    continue
                parts = line.split()
                if len(parts) != 5:
                    invalid.append((label.relative_to(root).as_posix(), "fields"))
                    continue
                try:
                    cls = int(parts[0])
                    values = [float(x) for x in parts[1:]]
                    if cls < 0 or not all(0 <= v <= 1 for v in values):
                        raise ValueError()
                    classes[cls] += 1
                except ValueError:
                    invalid.append((label.relative_to(root).as_posix(), "values"))
    return entries, missing_labels, classes, invalid


def summarize(name: str, root: Path, records):
    by_split = Counter(split for split, _, _ in records)
    by_digest = defaultdict(set)
    for split, digest, _ in records:
        by_digest[digest].add(split)
    leaks = {key: splits for key, splits in by_digest.items() if len(splits) > 1}
    print(f"\n{name}: {root}")
    print(f"  images by split: {dict(sorted(by_split.items()))}")
    print(f"  distinct image hashes: {len(by_digest)}; duplicates within dataset: {len(records)-len(by_digest)}")
    print(f"  hashes present in multiple splits: {len(leaks)}")
    return by_digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--a", type=Path, required=True)
    parser.add_argument("--b", type=Path, required=True)
    args = parser.parse_args()
    if not args.a.is_dir() or not args.b.is_dir():
        parser.error("Both dataset directories must exist.")
    ea, ma, ca, ia = inventory(args.a)
    eb, mb, cb, ib = inventory(args.b)
    ha = summarize("A (trained V4)", args.a, ea)
    hb = summarize("B (Mobile Detection)", args.b, eb)
    print(f"\nAnnotations A: class-object counts {dict(sorted(ca.items()))}; missing label files {len(ma)}; invalid annotation lines {len(ia)}")
    print(f"Annotations B: class-object counts {dict(sorted(cb.items()))}; missing label files {len(mb)}; invalid annotation lines {len(ib)}")
    both = set(ha) & set(hb)
    print(f"\nExact image SHA-256 overlap A/B: {len(both)}")
    print(f"Unique to A: {len(set(ha)-both)}; unique to B: {len(set(hb)-both)}")
    transitions = Counter((left, right) for digest in both for left in ha[digest] for right in hb[digest])
    print("Split combinations for overlapping image hashes:", dict(sorted(transitions.items())))
    print("Cross-dataset train/val-or-test overlaps:",
          len([digest for digest in both if
               (('train' in ha[digest]) and bool(hb[digest] & {'val', 'test'})) or
               (('train' in hb[digest]) and bool(ha[digest] & {'val', 'test'}))]))
    for name, root in (("A", args.a), ("B", args.b)):
        yaml = root / "data.yaml"
        print(f"\n{name} data.yaml:")
        print(yaml.read_text(encoding="utf-8-sig", errors="replace")[:2000] if yaml.exists() else "(not present)")
    print("\nNote: identical-image detection is exact-byte SHA-256, not perceptual near-duplicate detection.")
    print("A missing YOLO label may denote a valid negative image. No dataset files were changed.")


if __name__ == "__main__":
    main()
