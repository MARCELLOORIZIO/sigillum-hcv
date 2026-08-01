import 'dotenv/config';

import cors from 'cors';
import express from 'express';
import OpenAI from 'openai';

const app = express();
const port = Number(process.env.PORT || 8787);
const model = process.env.SIGILLUM_AI_MODEL || 'gpt-4o-mini';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

app.use(cors());
app.use(express.json({ limit: '35mb' }));

app.get('/health', (_request, response) => {
  response.json({
    ok: true,
    service: 'SIGILLUM_AI_TRAINER',
    model,
  });
});

app.post('/sigillum/ai-trainer/analyze', async (request, response) => {
  try {
    if (!process.env.OPENAI_API_KEY) {
      return response.status(500).json({
        error: 'OPENAI_API_KEY_MISSING',
      });
    }

    const body = request.body ?? {};
    const classes = Array.isArray(body.classes) ? body.classes : [];
    const images = Array.isArray(body.images) ? body.images.slice(0, 5) : [];

    if (classes.length === 0) {
      return response.status(400).json({ error: 'CLASSES_REQUIRED' });
    }

    if (images.length === 0) {
      return response.status(400).json({ error: 'IMAGES_REQUIRED' });
    }

    const content = [
      {
        type: 'text',
        text: buildPrompt({
          classes,
          userSelectedLabel: body.userSelectedLabel,
          localProposal: body.localProposal,
        }),
      },
      ...images.map((image) => ({
        type: 'image_url',
        image_url: {
          url: `data:${image.mimeType || 'image/jpeg'};base64,${image.base64}`,
          detail: 'low',
        },
      })),
    ];

    const completion = await openai.chat.completions.create({
      model,
      temperature: 0.1,
      response_format: { type: 'json_object' },
      messages: [
        {
          role: 'system',
          content:
            'You are SIGILLUM AI Trainer. Return only strict JSON. You classify training images for screen replay detection.',
        },
        {
          role: 'user',
          content,
        },
      ],
    });

    const text = completion.choices?.[0]?.message?.content;
    if (!text) {
      return response.status(502).json({ error: 'EMPTY_OPENAI_RESPONSE' });
    }

    const parsed = JSON.parse(text);
    const normalized = normalizeTrainerResponse(parsed, classes);
    response.json(normalized);
  } catch (error) {
    console.error(error);
    response.status(500).json({
      error: 'AI_TRAINER_ERROR',
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

function buildPrompt({ classes, userSelectedLabel, localProposal }) {
  return [
    'Analyze these SIGILLUM training sample images.',
    '',
    'Choose exactly one label from this list:',
    classes.join(', '),
    '',
    `User selected initial label: ${userSelectedLabel || 'UNKNOWN'}`,
    `Local TFLite proposal: ${JSON.stringify(localProposal || {})}`,
    '',
    'Definitions:',
    '- SCREEN_MONITOR: photo of a desktop/laptop/TV monitor showing content.',
    '- SCREEN_PHONE: photo of a phone screen showing content.',
    '- SCREEN_TABLET: photo of a tablet screen showing content.',
    '- REALITY_PAPER: real paper/document, not displayed on a screen.',
    '- REALITY_ROOM: real room/environment, not a screen.',
    '- REALITY_OBJECT: physical object, not a screen.',
    '- REALITY_OUTDOOR: outdoor real scene, not a screen.',
    '',
    'Return JSON with exactly these keys:',
    '{',
    '  "suggestedLabel": "one class from the list",',
    '  "confidence": 0.0,',
    '  "screenReplayRisk": "LOW|MEDIUM|HIGH|UNKNOWN",',
    '  "quality": "GOOD_FOR_TRAINING|REVIEW|REJECT",',
    '  "reason": "short Italian explanation",',
    '  "nextInstruction": "short Italian instruction for what to collect next"',
    '}',
    '',
    'Prefer REVIEW when uncertain. Use REJECT for blurry, dark, duplicate, or ambiguous samples.',
  ].join('\n');
}

function normalizeTrainerResponse(value, classes) {
  const suggestedLabel = classes.includes(value?.suggestedLabel)
    ? value.suggestedLabel
    : classes[0];

  const confidence = Number.isFinite(Number(value?.confidence))
    ? Math.max(0, Math.min(1, Number(value.confidence)))
    : 0;

  const screenReplayRisk = normalizeEnum(
    value?.screenReplayRisk,
    ['LOW', 'MEDIUM', 'HIGH', 'UNKNOWN'],
    'UNKNOWN',
  );
  const quality = normalizeEnum(
    value?.quality,
    ['GOOD_FOR_TRAINING', 'REVIEW', 'REJECT'],
    'REVIEW',
  );

  return {
    suggestedLabel,
    confidence,
    screenReplayRisk,
    quality,
    reason:
      typeof value?.reason === 'string'
        ? value.reason.slice(0, 600)
        : 'Valutazione AI disponibile.',
    nextInstruction:
      typeof value?.nextInstruction === 'string'
        ? value.nextInstruction.slice(0, 600)
        : 'Raccogli altri campioni bilanciati tra schermo e realta.',
  };
}

function normalizeEnum(value, allowed, fallback) {
  const normalized = String(value || '').toUpperCase();
  return allowed.includes(normalized) ? normalized : fallback;
}

app.listen(port, () => {
  console.log(`SIGILLUM AI Trainer listening on port ${port}`);
});
