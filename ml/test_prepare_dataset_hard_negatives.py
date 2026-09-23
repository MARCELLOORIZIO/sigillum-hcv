from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
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


class PrepareDatasetHardNegativeTest(unittest.TestCase):
    def test_hard_negatives_are_train_only(self) -> None:
        with tempfile.TemporaryDirectory() as raw_root:
            root = Path(raw_root)
            source = root / "base"
            hard = root / "hard"
            out = root / "out"

            for class_name in CLASSES:
                class_dir = source / class_name
                class_dir.mkdir(parents=True)
                for index in range(4):
                    Image.new(
                        "RGB",
                        (24, 24),
                        (index * 20 + 10, 30, 40),
                    ).save(class_dir / f"base_{index}.jpg")

            hard_class = hard / "REALITY_OBJECT"
            hard_class.mkdir(parents=True)
            for index in range(2):
                Image.new("RGB", (24, 24), (200, index * 20, 20)).save(
                    hard_class / f"hard_{index}.jpg"
                )

            subprocess.run(
                [
                    sys.executable,
                    "ml/prepare_dataset.py",
                    "--source",
                    str(source),
                    "--hard-negatives",
                    str(hard),
                    "--out",
                    str(out),
                ],
                check=True,
            )

            manifest = json.loads((out / "manifest.json").read_text())
            self.assertEqual(manifest["hardNegativeSets"][0]["splitRole"], "TRAIN_ONLY")
            self.assertEqual(manifest["hardNegativeSets"][0]["total"], 2)

            train_hard = list(
                (out / "train" / "REALITY_OBJECT").glob("hardneg_*.jpg")
            )
            val_hard = list((out / "val" / "REALITY_OBJECT").glob("hardneg_*.jpg"))
            test_hard = list(
                (out / "test" / "REALITY_OBJECT").glob("hardneg_*.jpg")
            )
            self.assertEqual(len(train_hard), 2)
            self.assertEqual(val_hard, [])
            self.assertEqual(test_hard, [])


if __name__ == "__main__":
    unittest.main()
