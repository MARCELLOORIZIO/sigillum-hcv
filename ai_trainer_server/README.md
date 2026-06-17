# SIGILLUM AI Trainer Server

Backend for the iPhone app `AI SERVER` button.

The app sends sample images here. This server calls OpenAI Vision and returns a
strict JSON label proposal.

## Local run

```powershell
cd G:\SIGILLUM_PARALLELO\hcv_app\ai_trainer_server
npm install
copy .env.example .env
```

Edit `.env` and set:

```text
OPENAI_API_KEY=...
```

Then run:

```powershell
npm start
```

Health check:

```text
http://localhost:8787/health
```

For iPhone use, this server must be reachable from the phone. In production,
publish it to Render, Railway, Fly.io, a VPS, or another HTTPS host.

Then in the app:

```text
AUTO TRAINING ML -> AI SERVER -> https://your-server.example
```

## Endpoint

```text
POST /sigillum/ai-trainer/analyze
```

Expected response:

```json
{
  "suggestedLabel": "SCREEN_MONITOR",
  "confidence": 0.94,
  "screenReplayRisk": "HIGH",
  "quality": "GOOD_FOR_TRAINING",
  "reason": "Il campione mostra una griglia pixel compatibile con monitor.",
  "nextInstruction": "Raccogli altri campioni REALITY_ROOM con luce naturale."
}
```
