from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F


CLASSES = [
    "SCREEN_MONITOR",
    "SCREEN_PHONE",
    "SCREEN_TABLET",
    "REALITY_PAPER",
    "REALITY_ROOM",
    "REALITY_OBJECT",
    "REALITY_OUTDOOR",
]


class Branch(nn.Module):
    def __init__(self):
        super().__init__()
        self.sem = nn.Sequential(
            nn.Conv2d(3, 24, 3, padding=1),
            nn.BatchNorm2d(24),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(24, 40, 3, padding=1),
            nn.BatchNorm2d(40),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(40, 64, 3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(64, 96, 3, padding=1),
            nn.BatchNorm2d(96),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(96, 128, 3, padding=1),
            nn.BatchNorm2d(128),
            nn.ReLU(),
        )
        self.sem_fc = nn.Linear(128, 96)
        self.tex = nn.Sequential(
            nn.Conv2d(3, 16, 3, padding=1),
            nn.BatchNorm2d(16),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(16, 24, 3, padding=1),
            nn.BatchNorm2d(24),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(24, 40, 3, padding=1),
            nn.BatchNorm2d(40),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(40, 48, 3, padding=1),
            nn.BatchNorm2d(48),
            nn.ReLU(),
        )
        self.fuse = nn.Linear(144, 96)
        self.out = nn.Linear(96, 7)

    def forward(self, rgb_nchw, texture_nchw):
        semantic = self.sem(rgb_nchw).mean((2, 3))
        semantic = F.relu(self.sem_fc(semantic))
        texture = self.tex(texture_nchw).mean((2, 3))
        fused = F.relu(self.fuse(torch.cat([semantic, texture], dim=1)))
        return self.out(fused)


class DualBranchMobile(nn.Module):
    """One LiteRT graph containing the exact clean and hard V3 branches."""

    def __init__(self):
        super().__init__()
        self.clean = Branch()
        self.hard = Branch()

    def forward(self, rgb_nhwc, texture_nhwc):
        rgb = rgb_nhwc.permute(0, 3, 1, 2)
        texture = texture_nhwc.permute(0, 3, 1, 2)
        clean = F.softmax(self.clean(rgb, texture), dim=1)
        hard = F.softmax(self.hard(rgb, texture), dim=1)
        return clean, hard


def load_model(checkpoint: Path) -> DualBranchMobile:
    raw = torch.load(checkpoint, map_location="cpu", weights_only=False)
    model = DualBranchMobile()
    # Transport checkpoint is fp16; loading into fp32 parameters intentionally
    # restores fp32 execution with fp16-rounded weights.
    model.load_state_dict(raw["model"])
    return model.eval()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()

    import litert_torch
    from ai_edge_litert.interpreter import Interpreter

    checkpoint = Path(args.checkpoint)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)

    model = load_model(checkpoint)
    sample_rgb = torch.zeros((1, 96, 96, 3), dtype=torch.float32)
    sample_texture = torch.zeros((1, 96, 96, 3), dtype=torch.float32)

    with torch.no_grad():
        edge_model = litert_torch.convert(
            model,
            (sample_rgb, sample_texture),
        )
    edge_model.export(str(out))

    interpreter = Interpreter(model_path=str(out))
    interpreter.allocate_tensors()
    inputs = interpreter.get_input_details()
    outputs = interpreter.get_output_details()

    if len(inputs) != 2 or len(outputs) != 2:
        raise RuntimeError(
            f"Expected 2 inputs / 2 outputs, got {len(inputs)} / {len(outputs)}"
        )

    rng = np.random.default_rng(127)
    tests = []
    worst = 0.0
    selected_mapping = None

    for test_index in range(8):
        rgb = rng.random((1, 96, 96, 3), dtype=np.float32)
        texture = rng.random((1, 96, 96, 3), dtype=np.float32)
        with torch.no_grad():
            pt_clean, pt_hard = model(
                torch.from_numpy(rgb),
                torch.from_numpy(texture),
            )
        pt = [pt_clean.numpy(), pt_hard.numpy()]

        # LiteRT normally preserves argument order; still evaluate both input
        # and output permutations and record the exact mapping used by this
        # converter/runtime pair.
        candidates = []
        for input_swap in (False, True):
            assigned = [texture, rgb] if input_swap else [rgb, texture]
            for detail, value in zip(inputs, assigned):
                interpreter.set_tensor(detail["index"], value.astype(detail["dtype"]))
            interpreter.invoke()
            raw_out = [interpreter.get_tensor(d["index"]) for d in outputs]
            for output_swap in (False, True):
                got = raw_out[::-1] if output_swap else raw_out
                err = max(
                    float(np.max(np.abs(got[0] - pt[0]))),
                    float(np.max(np.abs(got[1] - pt[1]))),
                )
                candidates.append((err, input_swap, output_swap))
        err, input_swap, output_swap = min(candidates, key=lambda item: item[0])
        if selected_mapping is None:
            selected_mapping = {
                "inputSwap": input_swap,
                "outputSwap": output_swap,
            }
        elif selected_mapping != {
            "inputSwap": input_swap,
            "outputSwap": output_swap,
        }:
            raise RuntimeError("LiteRT tensor mapping changed across parity cases")

        worst = max(worst, err)
        tests.append({"case": test_index, "maxAbsDiff": err})

    if worst > 2e-4:
        raise RuntimeError(f"LiteRT parity failed: worst max abs diff={worst}")

    report = {
        "type": "SIGILLUM_V3_DUAL_BRANCH_LITERT_PARITY_V1",
        "classes": CLASSES,
        "inputs": [
            {
                "index": int(d["index"]),
                "name": str(d.get("name")),
                "shape": [int(v) for v in d["shape"]],
                "dtype": str(d["dtype"]),
            }
            for d in inputs
        ],
        "outputs": [
            {
                "index": int(d["index"]),
                "name": str(d.get("name")),
                "shape": [int(v) for v in d["shape"]],
                "dtype": str(d["dtype"]),
            }
            for d in outputs
        ],
        "mapping": selected_mapping,
        "worstMaxAbsDiff": worst,
        "tests": tests,
    }
    Path(args.report).write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
