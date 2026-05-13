/**
 * Chat service — answers questions about one or more sessions using Sonnet.
 *
 * Mirrors the blendService pattern: strict JSON contract, dependency
 * injection for the Anthropic client so unit tests don't reach the network.
 */

import { anthropic, SONNET_MODEL } from './anthropic.js';

const SYSTEM = `You are a helpful assistant answering questions about conference talks.

Rules:
1. Answer only from the supplied context. If you don't know, say so plainly.
2. Inline citation tokens [[c:N]] reference the N-th entry of a parallel "references" array you also return.
3. Return JSON only:
   {
     "answer": "...",
     "references": [
       { "kind": "transcript", "sessionId": "...", "startSec": 0.0, "endSec": 0.0 } |
       { "kind": "note",       "sessionId": "..." }
     ]
   }
4. Transcript references MUST include startSec and endSec.
5. No prose outside the JSON.`;

const REQUIRED_FIELDS = ['answer', 'references'];
const FULL_BLEND_RECENT_N = 3;

function compactSession(s) {
  return `## Session ${s.id} — ${s.title ?? '(untitled)'}
Speaker: ${s.speaker ?? '(unknown)'}
Summary: ${s.aiSummary ?? '(none)'}`;
}

function fullSession(s) {
  const photoBlurb = (s.photos ?? [])
    .map(p => `- photo ${p.photoId}: ocr="${p.ocrText ?? ''}"; desc="${p.description ?? ''}"`)
    .join('\n');
  return `## Session ${s.id} — ${s.title ?? '(untitled)'}
Speaker: ${s.speaker ?? '(unknown)'}
Summary: ${s.aiSummary ?? '(none)'}
Transcript:
${s.transcript ?? '(no transcript)'}
Blended notes:
${s.blendedMarkdown ?? '(none)'}
Photos:
${photoBlurb || '(none)'}`;
}

function buildContext(scope, sessions) {
  if (scope.kind === 'talk') {
    return sessions.map(fullSession).join('\n\n');
  }
  // Conference scope: full blends only for the N most recent sessions.
  const sorted = [...sessions].sort((a, b) =>
    new Date(b.createdAt ?? 0).getTime() - new Date(a.createdAt ?? 0).getTime()
  );
  const recent = new Set(sorted.slice(0, FULL_BLEND_RECENT_N).map(s => s.id));
  return sessions.map(s => (recent.has(s.id) ? fullSession(s) : compactSession(s))).join('\n\n');
}

function stripCitationTokens(answer) {
  return answer.replace(/\s*\[\[c:\d+\]\]\s*/g, ' ').replace(/\s+/g, ' ').trim();
}

function resolveCitations(references, sessions) {
  const byId = new Map(sessions.map(s => [s.id, s]));
  const out = [];
  for (const r of references) {
    const s = byId.get(r.sessionId);
    if (!s) continue;
    if (r.kind === 'transcript' && typeof r.startSec === 'number' && typeof r.endSec === 'number') {
      const mm = Math.floor(r.startSec / 60).toString().padStart(2, '0');
      const ss = Math.floor(r.startSec % 60).toString().padStart(2, '0');
      out.push({
        kind: 'transcript',
        talkId: r.sessionId,
        startSec: r.startSec,
        endSec: r.endSec,
        label: `${mm}:${ss}`
      });
    } else if (r.kind === 'note') {
      out.push({ kind: 'note', noteId: r.sessionId, title: s.title ?? '' });
    }
  }
  return out;
}

export async function chat({ scope, messages, sessions }, deps = {}) {
  const client = deps.anthropic ?? anthropic;
  const context = buildContext(scope, sessions);

  const conversation = messages.map(m => `${m.role}: ${m.content}`).join('\n');
  const userMessage = `Context:\n${context}\n\nConversation so far:\n${conversation}`;

  const response = await client.messages.create({
    model: SONNET_MODEL,
    max_tokens: 2000,
    system: SYSTEM,
    messages: [{ role: 'user', content: userMessage }]
  });

  const raw = response.content?.[0]?.text;
  if (!raw) throw new Error('Empty response from Sonnet');

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(`Sonnet returned invalid JSON: ${raw.slice(0, 200)}`);
  }

  for (const f of REQUIRED_FIELDS) {
    if (!(f in parsed)) throw new Error(`Sonnet output missing required field: ${f}`);
  }

  const message = { role: 'assistant', content: stripCitationTokens(parsed.answer) };
  const citations = resolveCitations(parsed.references, sessions);

  return {
    message,
    citations,
    tokensIn: response.usage?.input_tokens ?? 0,
    tokensOut: response.usage?.output_tokens ?? 0,
  };
}
