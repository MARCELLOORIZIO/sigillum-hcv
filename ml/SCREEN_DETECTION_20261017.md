# Screen Detection LiteRT candidate — 2026-10-17

Experimental only; no production or iPhone integration.

Owner-supplied validation: 400 images, 446 annotations; classes desktop, laptop, phone, tablet, tv. Original PyTorch aggregate precision 0.913, recall 0.906, mAP50 0.938, mAP50-95 0.824. Converted LiteRT aggregate precision 0.869, recall 0.924, mAP50 0.919, mAP50-95 0.811.

Class LiteRT mAP50: desktop 0.785 (11 instances), laptop 0.964 (62), phone 0.947 (235), tablet 0.972 (100), tv 0.926 (38).

Input float32 NCHW [1,3,608,608]; output float32 [1,9,7581]; no quantization; NMS not embedded. Export is approximately 42.7 MB. Owner-measured SHA256: eeb5b914fff6f4843e25c562ca78ab3d656bca21d5b9fce062544be4b5f12668.

The binary remains local at /home/marcello71/sigillum-screen-detection/best.tflite. The model has NOT been run or validated on iPhone. These results are not directly comparable with the phone-only V4 metrics (different datasets). No inference from device presence to physical screen recapture is authorized.
