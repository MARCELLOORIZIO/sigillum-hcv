# BUILD127 ML hard negatives

This candidate addresses a systematic ML false-positive class: real high-zoom
textures, paper and repetitive physical patterns classified as
`SCREEN_MONITOR`.

## Dataset

Persistent source artifact:

`SIGILLUM_build127_hard_negatives_v1.zip`

SHA-256:

`597d5ccfbf9a3aa42d0551e364380bcd3579b7292c8576922df97f4bf42ce6ef`

The set contains 14 source photos and frames from 2 sufficiently long REALITY
videos, producing 34 training images. It includes the BMW seat false positive
and the texture/paper controls from archive 80.

The full image manifest is stored beside the ZIP as
`SIGILLUM_build127_hard_negatives_v1_manifest.json`.

## Training contract

Hard negatives must be merged into TRAIN ONLY. The existing validation/test
split from the original seven-class dataset must remain untouched.

Example:

```bash
python ml/prepare_dataset.py \
  --source sigillum_ml_dataset \
  --hard-negatives build127_hard_negatives_v1 \
  --out ml_work/dataset

python ml/train_tflite.py \
  --dataset ml_work/dataset \
  --out assets/ml/sigillum_screen_replay_v2.tflite
```

## Safety gate

Do not replace the bundled V2 model by training only these hard negatives.
The original balanced training dataset is not committed in this repository.
A safe replacement model requires the original SCREEN/REALITY corpus plus
this set, followed by regression checks against known monitor recall and an
independent physical holdout.

No display-policy threshold is changed by this branch.
