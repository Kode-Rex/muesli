import { anthropic, SONNET_MODEL } from './anthropic.js';

const SYSTEM = `You are blending a conference talk transcript, photos with extracted slide content, and the user's typed notes into a single coherent set of session notes.

Rules:
1. Preserve the user's notes verbatim somewhere in the output.
2. Around the user's notes, write AI prose that fills in context from the transcript.
3. Output plain markdown — NO custom tags, NO sentinels. Just real markdown.
4. Track structure with parallel arrays in the JSON output:
   - userNoteSpans: char ranges in blendedMarkdown where user-verbatim text appears
   - quoteSpans: char ranges of speaker quotes (must be exact transcript text), with their transcript timestamps
   - imagePlacements: char offsets where each photo should be inserted
   - citations: char ranges of AI claims with the transcript range they're grounded in
5. Place each photo near the moment its content was being discussed.
6. Output JSON exactly matching: { blendedMarkdown, userNoteSpans, quoteSpans, imagePlacements, citations }
7. Do not invent. Do not fabricate speaker quotes.`;

const REQUIRED_FIELDS = ['blendedMarkdown', 'userNoteSpans', 'quoteSpans', 'imagePlacements', 'citations'];

export async function blend({ transcript, transcriptWords, photos, userNotes, chapters }, deps = {}) {
  const client = deps.anthropic ?? anthropic;

  const photoSummary = photos.map(p =>
    `- id: ${p.photoId}; capturedAt: ${new Date(p.capturedAt).toISOString()}; ocr: ${p.ocrText}; desc: ${p.description}`
  ).join('\n');

  const chapterSummary = chapters.map(c => `- ${c.start.toFixed(1)}s — ${c.title}`).join('\n');

  const userMessage = `USER NOTES:\n${userNotes || '(none)'}\n\nTRANSCRIPT:\n${transcript}\n\nPHOTOS:\n${photoSummary || '(none)'}\n\nCHAPTERS:\n${chapterSummary || '(none)'}`;

  const response = await client.messages.create({
    model: SONNET_MODEL,
    max_tokens: 4000,
    system: SYSTEM,
    messages: [{ role: 'user', content: userMessage }]
  });

  const raw = response.content?.[0]?.text;
  if (!raw) throw new Error('Empty response from Sonnet');

  let parsed;
  try { parsed = JSON.parse(raw); }
  catch { throw new Error(`Sonnet returned invalid JSON: ${raw.slice(0, 200)}`); }

  for (const f of REQUIRED_FIELDS) {
    if (!(f in parsed)) throw new Error(`Sonnet output missing required field: ${f}`);
  }

  return {
    ...parsed,
    tokensIn: response.usage?.input_tokens ?? 0,
    tokensOut: response.usage?.output_tokens ?? 0,
  };
}
