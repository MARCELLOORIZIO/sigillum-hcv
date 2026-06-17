# SIGILLUM AI Trainer server contract

The iPhone app does not call OpenAI directly. It calls your private server:

```text
POST /sigillum/ai-trainer/analyze
Content-Type: application/json
```

Request shape:

```json
{
  "type": "SIGILLUM_AI_TRAINER_SAMPLE_REQUEST_V1",
  "userSelectedLabel": "SCREEN_MONITOR",
  "classes": [
    "SCREEN_MONITOR",
    "SCREEN_PHONE",
    "SCREEN_TABLET",
    "REALITY_PAPER",
    "REALITY_ROOM",
    "REALITY_OBJECT",
    "REALITY_OUTDOOR"
  ],
  "localProposal": {
    "label": "SCREEN_MONITOR",
    "confidence": 0.81,
    "source": "SIGILLUM_SCREEN_REPLAY_TFLITE"
  },
  "images": [
    {
      "fileName": "sample.jpg",
      "mimeType": "image/jpeg",
      "base64": "..."
    }
  ]
}
```

Response shape expected by the app:

```json
{
  "suggestedLabel": "SCREEN_MONITOR",
  "confidence": 0.94,
  "screenReplayRisk": "HIGH",
  "quality": "GOOD_FOR_TRAINING",
  "reason": "Visible display pixel grid and uniform emitted light.",
  "nextInstruction": "Collect 5 REALITY_ROOM samples in natural light."
}
```

Allowed `quality` values:

```text
GOOD_FOR_TRAINING
REVIEW
REJECT
```

Model update ZIP expected by the app:

```text
model.tflite
labels.json
manifest.json
```

`ml/train_tflite.py` now creates this ZIP automatically as:

```text
assets/ml/sigillum_screen_replay_model_update.zip
```
