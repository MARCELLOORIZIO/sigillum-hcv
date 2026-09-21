# ML v3 benchmark — 2026-09-21

## Promotion gate

ML v3 may replace the bundled stable V2 only if it:
1. does not lose any known SCREEN case that V2 handles correctly;
2. reduces REALITY false positives;
3. remains stable on the frozen evaluation corpus;
4. passes a fresh physical holdout before release.

The previous ML verdict is not used as ground truth.

## Development data

- final mined training corpus: 1502 unique images before holdout cleanup;
- HCV-581449500C1846FC (BMW seat) full image and derived crop were removed from training because that acquisition belongs to the BUILD126 holdout;
- effective training corpus used by V3 experiments: 1500 images;
- frozen photo evaluation: 13 images, SHA-independent from training;
- BUILD126 photo holdout: 15 images (9 SCREEN family, 6 REALITY family).

## Current BUILD126 / V2 reference

Observed physical photo holdout coherence before V3 work:
- 14/15 correct family-level outcomes;
- 1 known false positive: HCV-581449500C1846FC, perforated BMW seat at ~5.31x;
- known difficult screens include HCV-E9F75F00F6134AF7, HCV-BF1B0754CA594555,
  HCV-AEAFD4855C0B416E, HCV-E7F4F3D3456A4AE1 and HCV-BD06C9FD69284BB6.

## Candidates tested

### V3-A — conservative 96x96 family-aware CNN

- internal validation: SCREEN recall 87.4%, REALITY specificity 93.5% at epoch 3;
- frozen: 12/13;
- BUILD126 photo holdout: 13/15;
- fixes BMW seat and 1x seat texture false positives;
- misses BF1B and AEAF at model level.

Decision: NOT PROMOTED.

### V3-D — hard-example weighted 96x96 CNN

Best internal validation checkpoint:
- SCREEN recall 93.1%;
- REALITY specificity 92.0%.

External:
- frozen: 13/13;
- BUILD126 photo holdout: 11/15.

Decision: REJECTED. It over-corrects and creates new REALITY false positives / SCREEN misses.

### V3 two-branch meta gate

The gate was trained only on the internal validation predictions, using the complete
seven-class probability vectors of V3-A and V3-D.

Internal 5-fold balanced accuracy: ~95.9%.

External:
- frozen: 13/13;
- BUILD126 photo holdout: 13/15;
- SCREEN recall on holdout: 9/9;
- REALITY specificity on holdout: 4/6.

The two errors are:
- HCV-6AE8CBFD1D404588: real BMW cockpit scene that visibly contains a digital dashboard display;
- HCV-DE79FC815C55453F: real eye at 15x, a genuine false positive.

Decision: NOT PROMOTED.

### V3-E — partial-screen fine-tuning

Synthetic SCREEN-in-REALITY augmentation improved internal validation to:
- SCREEN recall 97.7%;
- REALITY specificity 94.2%.

External:
- frozen: 13/13;
- BUILD126 photo holdout: 10/15.

Decision: REJECTED due external degradation.

### V3-A multi-crop inference

Three, five and seven-crop variants were tested.

Best result (max crop):
- frozen: 13/13;
- BUILD126 photo holdout: 13/15.

Errors:
- HCV-6AE8CBFD1D404588, mixed real cockpit / embedded display;
- HCV-AEAFD4855C0B416E, true display.

Decision: NOT PROMOTED.

## Current decision

No V3 candidate currently satisfies the promotion gate.

Therefore:
- the bundled stable V2 remains the production model;
- BUILD126 / release-candidate work must not be blocked by V3;
- the 1500-image cleaned corpus and V3 experiments remain the basis for the post-launch
  ML upgrade;
- no V3 .tflite is installed into the app at this stage.

## Important interpretation

The V3 work confirms that the remaining hard cases are not explained by one simple
threshold. Full-screen display close-ups, embedded displays in real scenes, and real
high-frequency textures overlap in semantic appearance. HFR and other independent
capture evidence therefore remain necessary in the production fusion.
