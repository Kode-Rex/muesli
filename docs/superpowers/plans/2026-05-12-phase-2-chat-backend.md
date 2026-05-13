# Phase 2: Chat Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans or superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add a stateless chat API to the Node backend. One route for talk-scope (single session) chat; one route for multi-session (conference-scope) chat. Each turn includes citations to transcript timestamps or note titles.

**Architecture:** Mirror the existing `blendService` pattern: a service module (`chatService.js`) wrapping Anthropic with a strict JSON contract, plus thin Express handlers that delegate context assembly to the service and post-process citation references. Stateless — client owns the conversation history. Reuses `requireAuth`, `sessionsRepo`, `ledgerService`, and the JSON multipart/auth middleware already wired in `src/server.js`.

**Tech Stack:** Node 18+, Express, Anthropic SDK (`@anthropic-ai/sdk`), Jest (ES modules).

**Spec reference:** `docs/superpowers/specs/2026-05-12-gap-close-design.md` § Chat Backend Design.

**Route shape (deviation from spec):**
- `POST /v1/sessions/:id/chat` — talk-scope (single session). Per spec.
- `POST /v1/chat` — multi-session. Body carries `sessionIds: []` since the API has no server-side concept of "conference" yet. iOS computes the conference's session list and sends it. This avoids adding a Conference resource on the server until needed.

---

## File Structure

**Creating:**
- `src/api/src/services/chatService.js` — context assembly + Anthropic call + citation post-processing
- `src/api/src/routes/chat.js` — POST /chat (multi-session)
- `src/api/tests/unit/chatService.test.js` — service unit tests
- `src/api/tests/integration/chat.test.js` — route integration tests

**Modifying:**
- `src/api/src/routes/sessions.js` — add POST /:id/chat
- `src/api/src/server.js` — mount `chatRouter` under `/v1/chat`

---

## Task 1: `chatService.js` happy path with talk scope

**Files:**
- Create: `src/api/src/services/chatService.js`
- Test: `src/api/tests/unit/chatService.test.js`

- [ ] **Step 1: Write the failing test**

```js
import { describe, it, expect, jest } from '@jest/globals';
import { chat } from '../../src/services/chatService.js';

const okResponse = (answer = 'The talk covered three pillars.', references = []) => ({
  content: [{ type: 'text', text: JSON.stringify({ answer, references }) }],
  usage: { input_tokens: 1200, output_tokens: 180 }
});

describe('chat (talk scope)', () => {
  it('builds context for one session and returns assistant message with empty citations when no references', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue(okResponse()) } };
    const result = await chat({
      scope: { kind: 'talk', sessionId: 'sess-1' },
      messages: [{ role: 'user', content: 'What did Sarah say?' }],
      sessions: [{ id: 'sess-1', title: 'Three pillars', speaker: 'Sarah Chen', transcript: 'Sarah said hello.', blendedMarkdown: 'Hello.', photos: [], aiSummary: 'A talk.' }],
    }, { anthropic: fakeAnthropic });
    expect(result.message.role).toBe('assistant');
    expect(result.message.content).toBe('The talk covered three pillars.');
    expect(result.citations).toEqual([]);
    expect(result.tokensIn).toBe(1200);
    expect(result.tokensOut).toBe(180);
    expect(fakeAnthropic.messages.create).toHaveBeenCalledTimes(1);
  });
});
```

- [ ] **Step 2: Run test, verify FAIL**

Run: `cd src/api && npm test -- chatService`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `chatService.js` (minimal)**

```js
import { anthropic, SONNET_MODEL } from './anthropic.js';

const SYSTEM = `You are a helpful assistant answering questions about conference talks.

Rules:
1. Answer only from the supplied context. If you don't know, say so plainly.
2. Inline citation tokens [[c:N]] reference the N-th entry of a parallel "references" array you also return.
3. Return JSON only: { "answer": "...", "references": [ { "kind": "transcript" | "note", "sessionId": "...", "startSec": 0.0?, "endSec": 0.0? } ] }
   - "transcript" references include startSec and endSec.
   - "note" references include only sessionId.
4. No prose outside the JSON.`;

const REQUIRED_FIELDS = ['answer', 'references'];

function buildContext(sessions) {
  return sessions.map(s => {
    const photoBlurb = (s.photos ?? []).map(p => `- photo ${p.photoId}: ocr="${p.ocrText ?? ''}"; desc="${p.description ?? ''}"`).join('\n');
    return `## Session ${s.id} — ${s.title ?? '(untitled)'}
Speaker: ${s.speaker ?? '(unknown)'}
Summary: ${s.aiSummary ?? '(none)'}
Transcript:
${s.transcript ?? '(no transcript)'}
Blended notes:
${s.blendedMarkdown ?? '(none)'}
Photos:
${photoBlurb || '(none)'}`;
  }).join('\n\n');
}

function stripCitationTokens(answer) {
  return answer.replace(/\[\[c:\d+\]\]/g, '').replace(/\s+/g, ' ').trim();
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
  const context = buildContext(sessions);

  const userMessage = `Context:\n${context}\n\nConversation so far:\n${messages.map(m => `${m.role}: ${m.content}`).join('\n')}`;

  const response = await client.messages.create({
    model: SONNET_MODEL,
    max_tokens: 2000,
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

  const message = { role: 'assistant', content: stripCitationTokens(parsed.answer) };
  const citations = resolveCitations(parsed.references, sessions);

  return {
    message,
    citations,
    tokensIn: response.usage?.input_tokens ?? 0,
    tokensOut: response.usage?.output_tokens ?? 0,
  };
}
```

- [ ] **Step 4: Run test, verify PASS**

Run: `cd src/api && npm test -- chatService`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/api/src/services/chatService.js src/api/tests/unit/chatService.test.js
git commit -m "feat(api): add chatService for talk + conference scopes

Builds Anthropic-backed chat that answers from supplied session
context. Strict JSON contract with parallel references array;
[[c:N]] tokens are stripped from the user-facing answer and the
references are post-processed into citations carrying display labels
(mm:ss for transcript, note title for note).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: chatService — citation resolution and JSON failure modes

**Files:**
- Test: `src/api/tests/unit/chatService.test.js` (extend)

- [ ] **Step 1: Add tests**

```js
it('strips [[c:N]] tokens and resolves transcript citations to mm:ss labels', async () => {
  const okWithCites = {
    content: [{ type: 'text', text: JSON.stringify({
      answer: 'Sarah opened with evals [[c:0]] and the three pillars [[c:1]].',
      references: [
        { kind: 'transcript', sessionId: 'sess-1', startSec: 12.4, endSec: 24.1 },
        { kind: 'note', sessionId: 'sess-1' }
      ]
    }) }],
    usage: { input_tokens: 1000, output_tokens: 60 }
  };
  const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue(okWithCites) } };
  const r = await chat({
    scope: { kind: 'talk', sessionId: 'sess-1' },
    messages: [{ role: 'user', content: 'summarize' }],
    sessions: [{ id: 'sess-1', title: 'Three pillars', transcript: 't', photos: [] }],
  }, { anthropic: fakeAnthropic });
  expect(r.message.content).not.toMatch(/\[\[c:/);
  expect(r.citations).toHaveLength(2);
  expect(r.citations[0]).toMatchObject({ kind: 'transcript', talkId: 'sess-1', label: '00:12' });
  expect(r.citations[1]).toMatchObject({ kind: 'note', noteId: 'sess-1', title: 'Three pillars' });
});

it('drops references whose sessionId is not in scope', async () => {
  const respWithDangling = {
    content: [{ type: 'text', text: JSON.stringify({
      answer: 'See [[c:0]] and [[c:1]].',
      references: [
        { kind: 'transcript', sessionId: 'sess-1', startSec: 0, endSec: 5 },
        { kind: 'transcript', sessionId: 'sess-MISSING', startSec: 10, endSec: 12 }
      ]
    }) }],
    usage: { input_tokens: 1, output_tokens: 1 }
  };
  const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue(respWithDangling) } };
  const r = await chat({
    scope: { kind: 'talk', sessionId: 'sess-1' },
    messages: [{ role: 'user', content: 'q' }],
    sessions: [{ id: 'sess-1', title: 'T', transcript: 't', photos: [] }],
  }, { anthropic: fakeAnthropic });
  expect(r.citations).toHaveLength(1);
  expect(r.citations[0].talkId).toBe('sess-1');
});

it('throws on invalid JSON', async () => {
  const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({ content: [{ type: 'text', text: 'not json' }], usage: { input_tokens: 1, output_tokens: 1 } }) } };
  await expect(chat({ scope: { kind: 'talk', sessionId: 's' }, messages: [], sessions: [{ id: 's', transcript: '', photos: [] }] }, { anthropic: fakeAnthropic }))
    .rejects.toThrow(/JSON/);
});

it('throws on missing required field', async () => {
  const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({ content: [{ type: 'text', text: JSON.stringify({ answer: 'x' }) }], usage: { input_tokens: 1, output_tokens: 1 } }) } };
  await expect(chat({ scope: { kind: 'talk', sessionId: 's' }, messages: [], sessions: [{ id: 's', transcript: '', photos: [] }] }, { anthropic: fakeAnthropic }))
    .rejects.toThrow(/references/);
});
```

- [ ] **Step 2: Run, expect PASS** (implementation from Task 1 already handles these cases)

Run: `cd src/api && npm test -- chatService`

- [ ] **Step 3: Commit**

```bash
git add src/api/tests/unit/chatService.test.js
git commit -m "test(api): chatService citation handling and JSON guards

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: chatService — conference-scope context fits within budget

**Files:**
- Modify: `src/api/src/services/chatService.js`
- Test: `src/api/tests/unit/chatService.test.js`

- [ ] **Step 1: Add tests for token budget heuristic**

```js
it('for conference scope keeps full blends only for the N most recent sessions and summarizes the rest', async () => {
  const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({ content: [{ type: 'text', text: JSON.stringify({ answer: 'ok', references: [] }) }], usage: { input_tokens: 1, output_tokens: 1 } }) } };
  const longBlend = 'X'.repeat(50000);
  const sessions = Array.from({ length: 6 }, (_, i) => ({
    id: `sess-${i}`,
    title: `Talk ${i}`,
    transcript: 't',
    blendedMarkdown: longBlend,
    aiSummary: `summary ${i}`,
    createdAt: new Date(2026, 0, i + 1).toISOString(),
    photos: []
  }));
  await chat({
    scope: { kind: 'conference', sessionIds: sessions.map(s => s.id) },
    messages: [{ role: 'user', content: 'q' }],
    sessions
  }, { anthropic: fakeAnthropic });
  const call = fakeAnthropic.messages.create.mock.calls[0][0];
  const userContent = call.messages[0].content;
  // The 3 most recent sessions should have full blends; older ones summary-only.
  expect(userContent).toContain('Talk 5');
  expect(userContent).toContain('Talk 4');
  expect(userContent).toContain('Talk 3');
  // Older talks appear by summary, not full blend body.
  expect(userContent).toContain('summary 0');
  // Length cap: should not blow past 150k tokens of input. Rough heuristic: < 200k chars.
  expect(userContent.length).toBeLessThan(200_000);
});
```

- [ ] **Step 2: Run, verify FAIL** (current implementation includes all blends)

Run: `cd src/api && npm test -- chatService`

- [ ] **Step 3: Update buildContext to handle conference scope**

In `chatService.js`, replace `buildContext(sessions)` with a scope-aware version:

```js
const FULL_BLEND_RECENT_N = 3;

function compactSession(s) {
  return `## Session ${s.id} — ${s.title ?? '(untitled)'}
Speaker: ${s.speaker ?? '(unknown)'}
Summary: ${s.aiSummary ?? '(none)'}`;
}

function fullSession(s) {
  const photoBlurb = (s.photos ?? []).map(p => `- photo ${p.photoId}: ocr="${p.ocrText ?? ''}"; desc="${p.description ?? ''}"`).join('\n');
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
  // conference: full blends only for the N most recent
  const sorted = [...sessions].sort((a, b) =>
    (new Date(b.createdAt ?? 0)).getTime() - (new Date(a.createdAt ?? 0)).getTime()
  );
  const recent = new Set(sorted.slice(0, FULL_BLEND_RECENT_N).map(s => s.id));
  return sessions.map(s => recent.has(s.id) ? fullSession(s) : compactSession(s)).join('\n\n');
}
```

And change the call site `chat()` to pass scope:

```js
const context = buildContext(scope, sessions);
```

- [ ] **Step 4: Run, verify PASS**

Run: `cd src/api && npm test -- chatService`

- [ ] **Step 5: Commit**

```bash
git add src/api/src/services/chatService.js src/api/tests/unit/chatService.test.js
git commit -m "feat(api): conference-scope context heuristic in chatService

Full blends for the 3 most-recent sessions; older sessions degrade
to title + speaker + summary only. Keeps the corpus within the
~150k input-token budget for Sonnet. Embedding-based retrieval is a
future improvement.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `POST /v1/sessions/:id/chat` route (talk scope)

**Files:**
- Modify: `src/api/src/routes/sessions.js`
- Test: `src/api/tests/integration/chat.test.js`

- [ ] **Step 1: Write the failing integration test**

Create `src/api/tests/integration/chat.test.js`:

```js
import { describe, it, expect, beforeEach, jest } from '@jest/globals';
import request from 'supertest';
import { sessionsRepo } from '../../src/services/sessionsRepo.js';

// Mock Anthropic BEFORE importing the app so chatService picks up the mock.
jest.unstable_mockModule('../../src/services/anthropic.js', () => ({
  anthropic: { messages: { create: jest.fn().mockResolvedValue({
    content: [{ type: 'text', text: JSON.stringify({ answer: 'mocked answer', references: [] }) }],
    usage: { input_tokens: 100, output_tokens: 20 }
  }) } },
  SONNET_MODEL: 'claude-sonnet-4-6',
  HAIKU_MODEL: 'claude-haiku-4-5-20251001'
}));

const { default: app } = await import('../../src/server.js');

describe('POST /v1/sessions/:id/chat', () => {
  let sessionId;
  beforeEach(async () => {
    sessionId = await sessionsRepo.createSession({ userId: 'local-dev' });
    await sessionsRepo.saveTranscript(sessionId, { text: 'Sarah said hello.', words: [] });
  });

  it('returns the assistant message and empty citations on a fresh session', async () => {
    const res = await request(app)
      .post(`/v1/sessions/${sessionId}/chat`)
      .send({ messages: [{ role: 'user', content: 'What did Sarah say?' }] });

    expect(res.status).toBe(200);
    expect(res.body.message.role).toBe('assistant');
    expect(res.body.message.content).toBe('mocked answer');
    expect(res.body.citations).toEqual([]);
    expect(res.body.usage.tokensIn).toBe(100);
  });

  it('404s for unknown session', async () => {
    const res = await request(app)
      .post('/v1/sessions/00000000-0000-0000-0000-000000000000/chat')
      .send({ messages: [{ role: 'user', content: 'q' }] });
    expect(res.status).toBe(404);
  });

  it('400s when messages is missing', async () => {
    const res = await request(app)
      .post(`/v1/sessions/${sessionId}/chat`)
      .send({});
    expect(res.status).toBe(400);
  });
});
```

- [ ] **Step 2: Run, verify FAIL**

Run: `cd src/api && npm test -- chat.test`
Expected: FAIL — route doesn't exist.

- [ ] **Step 3: Add the route to `sessions.js`**

Append below the existing `/:id/blend` handler:

```js
import { chat } from '../services/chatService.js';

router.post('/:id/chat', express.json(), async (req, res) => {
  const id = req.params.id;
  const s = await sessionsRepo.getSession(id);
  if (!s) return res.status(404).json({ error: 'session_not_found' });
  const messages = req.body?.messages;
  if (!Array.isArray(messages) || messages.length === 0) {
    return res.status(400).json({ error: 'messages_required' });
  }
  try {
    const result = await chat({
      scope: { kind: 'talk', sessionId: id },
      messages,
      sessions: [{
        id: s.id, title: null, speaker: null, transcript: s.transcript,
        blendedMarkdown: s.blendedMarkdown, aiSummary: null,
        photos: s.photos.filter(p => p.extractStatus === 'complete'),
        createdAt: s.createdAt
      }]
    });
    res.json({
      message: result.message,
      citations: result.citations,
      usage: { tokensIn: result.tokensIn, tokensOut: result.tokensOut }
    });
  } catch (e) {
    Logger.error('chat (talk) failed', e);
    res.status(502).json({ error: 'chat_failed', detail: e.message });
  }
});
```

(The existing `import` block at the top of `sessions.js` already brings in `Logger` etc; add the `chat` import near the others.)

- [ ] **Step 4: Run, verify PASS**

Run: `cd src/api && npm test -- chat.test`

- [ ] **Step 5: Commit**

```bash
git add src/api/src/routes/sessions.js src/api/tests/integration/chat.test.js
git commit -m "feat(api): POST /v1/sessions/:id/chat (talk-scope chat)

Adds a stateless chat endpoint scoped to a single session. Client
provides the full conversation each turn. Server fetches the
session, assembles context, calls chatService, and returns
{ message, citations, usage }. 404 for unknown session, 400 for
missing messages, 502 if Sonnet fails.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: `POST /v1/chat` route (multi-session / conference scope)

**Files:**
- Create: `src/api/src/routes/chat.js`
- Modify: `src/api/src/server.js` (mount router)
- Test: `src/api/tests/integration/chat.test.js` (extend)

- [ ] **Step 1: Add the failing integration test**

Append to `tests/integration/chat.test.js`:

```js
describe('POST /v1/chat (multi-session scope)', () => {
  let sess1, sess2;
  beforeEach(async () => {
    sess1 = await sessionsRepo.createSession({ userId: 'local-dev' });
    sess2 = await sessionsRepo.createSession({ userId: 'local-dev' });
    await sessionsRepo.saveTranscript(sess1, { text: 'talk one', words: [] });
    await sessionsRepo.saveTranscript(sess2, { text: 'talk two', words: [] });
  });

  it('aggregates two sessions and returns assistant message', async () => {
    const res = await request(app)
      .post('/v1/chat')
      .send({ sessionIds: [sess1, sess2], messages: [{ role: 'user', content: 'across talks' }] });
    expect(res.status).toBe(200);
    expect(res.body.message.role).toBe('assistant');
  });

  it('400s when sessionIds is missing or empty', async () => {
    const res = await request(app)
      .post('/v1/chat')
      .send({ messages: [{ role: 'user', content: 'q' }] });
    expect(res.status).toBe(400);
  });

  it('404s when any session is unknown', async () => {
    const res = await request(app)
      .post('/v1/chat')
      .send({ sessionIds: [sess1, '00000000-0000-0000-0000-000000000000'], messages: [{ role: 'user', content: 'q' }] });
    expect(res.status).toBe(404);
  });
});
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd src/api && npm test -- chat.test`

- [ ] **Step 3: Create `src/api/src/routes/chat.js`**

```js
import express from 'express';
import { sessionsRepo } from '../services/sessionsRepo.js';
import { chat } from '../services/chatService.js';
import Logger from '../utils/logger.js';

const router = express.Router();

router.post('/', express.json(), async (req, res) => {
  const sessionIds = req.body?.sessionIds;
  const messages = req.body?.messages;
  if (!Array.isArray(sessionIds) || sessionIds.length === 0) {
    return res.status(400).json({ error: 'sessionIds_required' });
  }
  if (!Array.isArray(messages) || messages.length === 0) {
    return res.status(400).json({ error: 'messages_required' });
  }

  const sessions = [];
  for (const id of sessionIds) {
    const s = await sessionsRepo.getSession(id);
    if (!s) return res.status(404).json({ error: 'session_not_found', sessionId: id });
    sessions.push({
      id: s.id, title: null, speaker: null,
      transcript: s.transcript, blendedMarkdown: s.blendedMarkdown,
      aiSummary: null,
      photos: s.photos.filter(p => p.extractStatus === 'complete'),
      createdAt: s.createdAt
    });
  }

  try {
    const result = await chat({
      scope: { kind: 'conference', sessionIds },
      messages,
      sessions
    });
    res.json({
      message: result.message,
      citations: result.citations,
      usage: { tokensIn: result.tokensIn, tokensOut: result.tokensOut }
    });
  } catch (e) {
    Logger.error('chat (multi-session) failed', e);
    res.status(502).json({ error: 'chat_failed', detail: e.message });
  }
});

export default router;
```

- [ ] **Step 4: Mount the router in `src/server.js`**

Find the routes-mounting block (look for `app.use('/v1/sessions', ...)`) and add:

```js
import chatRouter from './routes/chat.js';
// ... later ...
app.use('/v1/chat', requireAuth, chatRouter);
```

- [ ] **Step 5: Run tests, verify PASS**

Run: `cd src/api && npm test -- chat.test`

- [ ] **Step 6: Commit**

```bash
git add src/api/src/routes/chat.js src/api/src/server.js src/api/tests/integration/chat.test.js
git commit -m "feat(api): POST /v1/chat for multi-session (conference) chat

Body carries sessionIds (the iOS client computes the membership
from its Conference relationship). Server fetches each session,
builds aggregated context via chatService, and returns the same
shape as the talk-scope route. 400 on missing sessionIds or
messages, 404 when any sessionId is unknown.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Coverage gate stays green

- [ ] **Step 1: Run full API suite with coverage**

Run: `cd src/api && npm test`
Expected: all tests pass; coverage at or above 70% lines/statements (per CI gate from commit 3a5a0b9).

- [ ] **Step 2: If coverage dipped, add a coverage-fortifying test**

The most likely uncovered branches are the citation post-processing edge cases (already covered) and the error paths in the routes. If coverage drops, add an integration test for the 502 path:

```js
it('502s when chatService throws', async () => {
  // jest module mock applied at top of file already; override once for this test:
  const { anthropic } = await import('../../src/services/anthropic.js');
  anthropic.messages.create.mockRejectedValueOnce(new Error('Sonnet down'));
  const res = await request(app)
    .post(`/v1/sessions/${sessionId}/chat`)
    .send({ messages: [{ role: 'user', content: 'q' }] });
  expect(res.status).toBe(502);
});
```

- [ ] **Step 3: Commit any added coverage tests**

```bash
git add src/api/tests/integration/chat.test.js
git commit -m "test(api): cover chat 502 path

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 2 done when

- All six tasks committed.
- `cd src/api && npm test` green.
- Coverage at or above 70% lines/statements.
- Both chat routes return `{ message, citations, usage }` for happy paths and the documented error codes for failures.
- No real network call to Anthropic during tests (everything mocked).

## Next plan

Phase 3 covers the augmented-note renderer + AugmentedNoteView on iOS (the flagship view).
