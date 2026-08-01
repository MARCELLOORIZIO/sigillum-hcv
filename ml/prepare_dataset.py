from __future__ import annotations

import argparse
import json
import random
import shutil
from pathlib import Path

from PIL import Image


CLASSES = [
    "SCREEN_MONITOR",
    "SCREEN_PHONE",
    "SCREEN_TABLET",
    "REALITY_PAPER",
    "REALITY_ROOM",
    "REALITY_OBJECT",
    "REALITY_OUTDOOR",
]


def iter_images(class_dir: Path):
    for pattern in ("*.jpg", "*.jpeg", "*.png"):
        yield from class_dir.glob(pattern)


def resize_and_copy(source: Path, target: Path, size: int) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        image = image.convert("RGB")
        image.thumbnail((size, size), Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", (size, size), (0, 0, 0))
        left = (size - image.width) // 2
        top = (size - image.height) // 2
        canvas.paste(image, (left, top))
        canvas.save(target, format="JPEG", quality=92)


def split_items(items: list[Path], seed: int):
    shuffled = items[:]
    random.Random(seed).shuffle(shuffled)
    total = len(shuffled)
    train_end = max(1, int(total * 0.72))
    val_end = max(train_end + 1, int(total * 0.86)) if total >= 3 else train_end
    return {
        "train": shuffled[:train_end],
        "val": shuffled[train_end:val_end],
        "test": shuffled[val_end:],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default="sigillum_ml_dataset")
    parser.add_argument("--out", default="ml_work/dataset")
    parser.add_argument("--image-size", type=int, default=224)
    parser.add_argument("--seed", type=int, default=1337)
    args = parser.parse_args()

    source = Path(args.source)
    output = Path(args.out)
    if output.exists():
        shutil.rmtree(output)

    manifest = {
        "type": "SIGILLUM_SCREEN_REPLAY_TRAINING_DATASET_V1",
        "imageSize": args.image_size,
        "classes": CLASSES,
        "splits": {},
    }

    for class_name in CLASSES:
        class_dir = source / class_name
        images = sorted(path for path in iter_images(class_dir) if path.is_file())
        splits = split_items(images, args.seed)
        manifest["splits"][class_name] = {
            split: len(paths) for split, paths in splits.items()
        }

        for split, paths in splits.items():
            for index, path in enumerate(paths):
                target = output / split / class_name / f"{path.stem}_{index:04d}.jpg"
                resize_and_copy(path, target, args.image_size)

    (output / "labels.json").write_text(
        json.dumps({"classes": CLASSES}, indent=2),
        encoding="utf-8",
    )
    (output / "manifest.json").write_text(
        json.dumps(manifest, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
