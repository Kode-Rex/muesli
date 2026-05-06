import { anthropic, HAIKU_MODEL } from './anthropic.js';

const SYSTEM = `You divide a conference talk transcript into 3-8 chapters that mirror the natural sections (intro, main points, demo, Q&A, etc.). Each chapter should be at least 30 seconds long. Return strict JSON only:
{
  "chapters": [
    { "start": 0.0, "title": "Opening", "summary": "..." },
    { "start": 252.4, "title": "Three pillars", "summary": "..." }
  ]
}
- start: seconds into the talk where the chapter begins
- title: 2-5 words, no trailing punctuation
- summary: one sentence
No commentary, no markdown, just JSON.`;

export async function chapterize({ transcript, durationSeconds }, deps = {}) {
  const client = deps.anthropic ?? anthropic;
  const response = await client.messages.create({
    model: HAIKU_MODEL,
    max_tokens: 1500,
    system: SYSTEM,
    messages: [{ role: 'user', content: `Talk duration: ${Math.round(durationSeconds)}s\n\nTranscript:\n${transcript}` }]
  });

  const raw = response.content?.[0]?.text;
  let parsed;
  try { parsed = JSON.parse(raw); }
  catch {
    return { chapters: [{ start: 0, title: 'Recording', summary: '' }], tokensIn: response.usage?.input_tokens ?? 0, tokensOut: response.usage?.output_tokens ?? 0 };
  }

  let chapters = Array.isArray(parsed.chapters) ? parsed.chapters : [];
  if (chapters.length === 0) {
    chapters = [{ start: 0, title: 'Recording', summary: '' }];
  }

  return {
    chapters,
    tokensIn: response.usage?.input_tokens ?? 0,
    tokensOut: response.usage?.output_tokens ?? 0,
  };
}
