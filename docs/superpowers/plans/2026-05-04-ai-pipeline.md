# AI Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Wire up the post-record AI pipeline end-to-end. After Stop, audio + photos + user notes flow through Deepgram → parallel Haiku passes (per-image vision + chapterize) → Sonnet blend → persisted note with augmented body, citations, chapters, and recorded cost.

**Architecture:** Three layers. (1) Backend services: pure cost/hash utilities, model-call services with TDD on parsing/wiring, REST endpoints orchestrating them. (2) iOS data model: new Photo entity with content-addressed storage, expanded Note fields, lightweight migration. (3) iOS service layer: `SessionsService` posts audio + photos to backend, polls for blend completion.

Storage in v1 is **in-memory** on the backend: a Map of `sessionId → SessionState` plus a circular buffer for cost log entries. When the auth + credit-ledger specs ship, this swaps to Postgres mechanically (every read/write goes through a `SessionsRepo` interface that has both impls).

UI rendering is out of scope here — that's the UI translation plan's `AugmentedNoteView`. This plan ends when the iOS app can record-and-blend, populate `Note.blendedMarkdown` etc., and the legacy `SimpleNoteDetailView` continues to render the raw transcript without crashing.

**Tech Stack:** Node 18 / Express / `@anthropic-ai/sdk` / `@deepgram/sdk` / Jest. Swift 5.9 / SwiftUI / SwiftData / URLSession. Anthropic models: `claude-sonnet-4-6` (blend), `claude-haiku-4-5-20251001` (per-image, chapterize).

**Prerequisites — none.** Auth, credit ledger, and IAP specs are NOT live; this plan stubs:
- `userId` is hardcoded `"local-dev"` on every request
- Cost is recorded in-process; no debit gating
- Postgres tables are stubbed by in-memory Maps

When those specs ship later, the swap is a `SessionsRepo` impl change plus middleware mount, not a rewrite.

---

## File Structure

| Path | Responsibility |
|---|---|
| `src/api/src/services/contentHash.js` | sha256 helper for cache keys |
| `src/api/src/services/blendCost.js` | Pure function: micros from {seconds, image count, token counts} |
| `src/api/src/services/imageExtractService.js` | Haiku per-image: returns `{ ocrText, description }` |
| `src/api/src/services/chapterizeService.js` | Haiku chapterize: returns `[{ start, title, summary }]` |
| `src/api/src/services/blendService.js` | Sonnet blend: returns `{ blendedMarkdown, userNoteSpans, quoteSpans, imagePlacements, citations }` |
| `src/api/src/services/sessionsRepo.js` | `InMemorySessionsRepo` with the same shape Postgres would have |
| `src/api/src/services/anthropic.js` | Singleton SDK client wired from config |
| `src/api/src/services/deepgram.js` | Wraps existing Deepgram service for word-level timestamps (already exists in part) |
| `src/api/src/routes/sessions.js` | `POST /v1/sessions`, `/audio`, `/photos`, `/blend`, `GET /v1/sessions/:id` |
| `src/api/src/config/index.js` | Add `ANTHROPIC_API_KEY` (modify) |
| `src/api/tests/unit/contentHash.test.js` | TDD |
| `src/api/tests/unit/blendCost.test.js` | TDD |
| `src/api/tests/unit/imageExtractService.test.js` | TDD with mocked SDK |
| `src/api/tests/unit/chapterizeService.test.js` | TDD |
| `src/api/tests/unit/blendService.test.js` | TDD |
| `src/api/tests/unit/sessionsRepo.test.js` | TDD |
| `src/api/tests/integration/sessionsFlow.test.js` | E2E with all SDKs mocked |
| `src/mobile/Muesli/Models/Photo.swift` | New @Model |
| `src/mobile/Muesli/Models/Note.swift` | New blend fields (modify) |
| `src/mobile/Muesli/Migration/PhotoMigration.swift` | imagePaths → Photo migration |
| `src/mobile/Muesli/Services/SessionsService.swift` | Talks to /v1/sessions |
| `src/mobile/Muesli/Services/BlendOrchestrator.swift` | Coordinates upload → poll → persist |
| `src/mobile/MuesliTests/Services/SessionsClientTests.swift` | TDD on JSON encoding/decoding |
| `src/mobile/MuesliTests/Models/PhotoMigrationTests.swift` | TDD on migration |

---

### Task 1: contentHash + blendCost (TDD, pure functions)

**Files:**
- Create: `src/api/src/services/contentHash.js`, `src/api/src/services/blendCost.js`
- Create: `src/api/tests/unit/contentHash.test.js`, `src/api/tests/unit/blendCost.test.js`

Pure utilities used everywhere downstream. Two short functions, two test files.

- [ ] **Step 1: Write failing tests for contentHash**

```javascript
// src/api/tests/unit/contentHash.test.js
import { describe, it, expect } from '@jest/globals';
import { contentHash } from '../../src/services/contentHash.js';

describe('contentHash', () => {
  it('returns a 64-char hex string for a Buffer input', () => {
    const h = contentHash(Buffer.from('hello'));
    expect(h).toMatch(/^[0-9a-f]{64}$/);
  });

  it('is deterministic — same input produces same hash', () => {
    expect(contentHash(Buffer.from('x'))).toBe(contentHash(Buffer.from('x')));
  });

  it('different inputs produce different hashes', () => {
    expect(contentHash(Buffer.from('a'))).not.toBe(contentHash(Buffer.from('b')));
  });

  it('accepts strings and hashes the utf8 bytes', () => {
    const fromBuffer = contentHash(Buffer.from('hello', 'utf8'));
    const fromString = contentHash('hello');
    expect(fromString).toBe(fromBuffer);
  });
});
```

- [ ] **Step 2: Run, verify failures**

```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/unit/contentHash.test.js
```

- [ ] **Step 3: Implement**

```javascript
// src/api/src/services/contentHash.js
import { createHash } from 'crypto';

export function contentHash(input) {
  const buf = Buffer.isBuffer(input) ? input : Buffer.from(input, 'utf8');
  return createHash('sha256').update(buf).digest('hex');
}
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Write failing tests for blendCost**

```javascript
// src/api/tests/unit/blendCost.test.js
import { describe, it, expect } from '@jest/globals';
import { blendCostMicros } from '../../src/services/blendCost.js';

describe('blendCostMicros', () => {
  it('computes Deepgram + Haiku + Sonnet for a typical session', () => {
    // 30 min audio, 5 images, 8K Sonnet input, 2K Sonnet output
    const cost = blendCostMicros({
      deepgramSeconds: 1800,
      imageCount: 5,
      hasChapterize: true,
      sonnetInputTokens: 8000,
      sonnetOutputTokens: 2000
    });
    // deepgram: 1800 * 71.7 = 129,060
    // image:    5 * 5,000 = 25,000
    // chapterize: 5,000
    // sonnet:   8000 * 3 + 2000 * 15 = 24,000 + 30,000 = 54,000
    // total: 213,060
    expect(cost).toBe(213_060);
  });

  it('handles zero photos and no chapterize', () => {
    expect(blendCostMicros({
      deepgramSeconds: 60,
      imageCount: 0,
      hasChapterize: false,
      sonnetInputTokens: 1000,
      sonnetOutputTokens: 200
    })).toBe(Math.ceil(60 * 71.7) + 1000 * 3 + 200 * 15);
  });

  it('rejects negative or NaN inputs gracefully', () => {
    expect(() => blendCostMicros({
      deepgramSeconds: -5,
      imageCount: 0,
      hasChapterize: false,
      sonnetInputTokens: 0,
      sonnetOutputTokens: 0
    })).toThrow();
  });
});
```

- [ ] **Step 6: Implement**

```javascript
// src/api/src/services/blendCost.js
const DEEPGRAM_MICROS_PER_SEC = 71.7;
const HAIKU_MICROS_PER_IMAGE = 5000;
const HAIKU_MICROS_CHAPTERIZE = 5000;
const SONNET_INPUT_MICROS_PER_TOKEN = 3;
const SONNET_OUTPUT_MICROS_PER_TOKEN = 15;

export function blendCostMicros({ deepgramSeconds, imageCount, hasChapterize, sonnetInputTokens, sonnetOutputTokens }) {
  for (const [k, v] of Object.entries({ deepgramSeconds, imageCount, sonnetInputTokens, sonnetOutputTokens })) {
    if (typeof v !== 'number' || !Number.isFinite(v) || v < 0) {
      throw new Error(`Invalid ${k}: ${v}`);
    }
  }
  const dg = Math.ceil(deepgramSeconds * DEEPGRAM_MICROS_PER_SEC);
  const img = imageCount * HAIKU_MICROS_PER_IMAGE;
  const chap = hasChapterize ? HAIKU_MICROS_CHAPTERIZE : 0;
  const son = sonnetInputTokens * SONNET_INPUT_MICROS_PER_TOKEN + sonnetOutputTokens * SONNET_OUTPUT_MICROS_PER_TOKEN;
  return dg + img + chap + son;
}
```

- [ ] **Step 7: Run, verify pass**

- [ ] **Step 8: Commit**

```bash
git add src/api/src/services/contentHash.js src/api/src/services/blendCost.js src/api/tests/unit/contentHash.test.js src/api/tests/unit/blendCost.test.js
git commit -m "feat(api): contentHash + blendCost pure functions

contentHash(buffer|string) → sha256 hex. Used as cache keys for
photos and transcripts. blendCostMicros computes per-session cost
from Deepgram seconds + image count + Sonnet token usage; throws
on invalid inputs. Both TDD'd."
```

---

### Task 2: SessionsRepo (in-memory v1, TDD)

**Files:**
- Create: `src/api/src/services/sessionsRepo.js`
- Create: `src/api/tests/unit/sessionsRepo.test.js`

Single state holder for v1. Postgres swap later is one file change.

- [ ] **Step 1: Write tests**

```javascript
// src/api/tests/unit/sessionsRepo.test.js
import { describe, it, expect, beforeEach } from '@jest/globals';
import { InMemorySessionsRepo } from '../../src/services/sessionsRepo.js';

describe('InMemorySessionsRepo', () => {
  let repo;
  beforeEach(() => { repo = new InMemorySessionsRepo(); });

  it('createSession returns a fresh sessionId and stores the row', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    const s = await repo.getSession(id);
    expect(s.userId).toBe('u1');
    expect(s.status).toBe('idle');
    expect(s.photos).toEqual([]);
    expect(s.transcript).toBeNull();
  });

  it('attachAudio sets transcript fields', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.attachAudio(id, { audioPath: '/tmp/x.m4a', durationSeconds: 47.2 });
    const s = await repo.getSession(id);
    expect(s.audioPath).toBe('/tmp/x.m4a');
    expect(s.durationSeconds).toBe(47.2);
  });

  it('addPhoto appends a photo with extract status pending', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.addPhoto(id, { photoId: 'p1', contentHash: 'abc', capturedAt: new Date(), localPath: '/tmp/p1.jpg' });
    const s = await repo.getSession(id);
    expect(s.photos).toHaveLength(1);
    expect(s.photos[0].extractStatus).toBe('pending');
  });

  it('updatePhotoExtract sets extracted fields', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.addPhoto(id, { photoId: 'p1', contentHash: 'abc', capturedAt: new Date(), localPath: '/tmp/p1.jpg' });
    await repo.updatePhotoExtract(id, 'p1', { ocrText: 'slide text', description: 'a slide', extractStatus: 'complete' });
    const s = await repo.getSession(id);
    expect(s.photos[0].ocrText).toBe('slide text');
    expect(s.photos[0].extractStatus).toBe('complete');
  });

  it('saveTranscript stores text + words', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.saveTranscript(id, { text: 'hi', words: [{ text: 'hi', start: 0, end: 0.5 }] });
    const s = await repo.getSession(id);
    expect(s.transcript).toBe('hi');
    expect(s.transcriptWords).toEqual([{ text: 'hi', start: 0, end: 0.5 }]);
  });

  it('saveBlend stores all blend output and chapters', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.saveBlend(id, {
      blendedMarkdown: '# x',
      userNoteSpans: [], quoteSpans: [], imagePlacements: [], citations: [],
      chapters: [{ start: 0, title: 'a', summary: '' }],
      costMicros: 12345,
      modelVersion: 'sonnet-4-6+haiku-4-5+nova-3'
    });
    const s = await repo.getSession(id);
    expect(s.blendedMarkdown).toBe('# x');
    expect(s.chapters).toHaveLength(1);
    expect(s.costMicros).toBe(12345);
    expect(s.status).toBe('complete');
  });

  it('setStatus updates status', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.setStatus(id, 'transcribing');
    expect((await repo.getSession(id)).status).toBe('transcribing');
  });

  it('getSession returns null for unknown id', async () => {
    expect(await repo.getSession('nope')).toBeNull();
  });

  it('listCostEntries returns entries appended via recordCost', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.recordCost({ userId: 'u1', sessionId: id, microsDelta: -10000, reason: 'blend' });
    const entries = await repo.listCostEntries('u1');
    expect(entries).toHaveLength(1);
    expect(entries[0].microsDelta).toBe(-10000);
  });
});
```

- [ ] **Step 2: Run, verify failures**

- [ ] **Step 3: Implement**

```javascript
// src/api/src/services/sessionsRepo.js
import { randomUUID } from 'crypto';

export class InMemorySessionsRepo {
  constructor() {
    this.sessions = new Map();
    this.costEntries = [];
  }

  async createSession({ userId }) {
    const id = randomUUID();
    this.sessions.set(id, {
      id, userId, status: 'idle',
      audioPath: null, durationSeconds: 0,
      transcript: null, transcriptWords: null,
      photos: [],
      blendedMarkdown: null,
      userNoteSpans: [], quoteSpans: [], imagePlacements: [], citations: [],
      chapters: null,
      costMicros: 0,
      modelVersion: null,
      error: null,
      createdAt: new Date(),
    });
    return id;
  }

  async getSession(id) {
    return this.sessions.get(id) ?? null;
  }

  async attachAudio(id, { audioPath, durationSeconds }) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    s.audioPath = audioPath;
    s.durationSeconds = durationSeconds;
  }

  async addPhoto(id, { photoId, contentHash, capturedAt, localPath }) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    s.photos.push({
      photoId, contentHash, capturedAt, localPath,
      ocrText: null, description: null, extractStatus: 'pending',
    });
  }

  async updatePhotoExtract(id, photoId, { ocrText, description, extractStatus }) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    const p = s.photos.find(p => p.photoId === photoId);
    if (!p) throw new Error(`Unknown photo ${photoId}`);
    p.ocrText = ocrText;
    p.description = description;
    p.extractStatus = extractStatus;
  }

  async saveTranscript(id, { text, words }) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    s.transcript = text;
    s.transcriptWords = words;
  }

  async saveBlend(id, payload) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    Object.assign(s, payload, { status: 'complete' });
  }

  async setStatus(id, status, error = null) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    s.status = status;
    if (error) s.error = error;
  }

  async recordCost(entry) {
    this.costEntries.push({ ...entry, createdAt: new Date() });
  }

  async listCostEntries(userId) {
    return this.costEntries.filter(e => e.userId === userId);
  }
}

// Module-scoped singleton; route handlers and tests both reach for this.
export const sessionsRepo = new InMemorySessionsRepo();
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add src/api/src/services/sessionsRepo.js src/api/tests/unit/sessionsRepo.test.js
git commit -m "feat(api): InMemorySessionsRepo for v1

Single state holder for sessions, photos, transcripts, blends, and
cost entries. Postgres swap later is a single-file change — every
read/write goes through this repo's surface."
```

---

### Task 3: imageExtractService (Haiku, TDD with mocked SDK)

**Files:**
- Create: `src/api/src/services/anthropic.js`
- Create: `src/api/src/services/imageExtractService.js`
- Create: `src/api/tests/unit/imageExtractService.test.js`
- Modify: `src/api/src/config/index.js` to add `ANTHROPIC_API_KEY`

- [ ] **Step 1: Add Anthropic config + dependency**

```bash
cd src/api && npm install @anthropic-ai/sdk
```

In `src/api/src/config/index.js`, add to the schema (alphabetized near DEEPGRAM):

```javascript
ANTHROPIC_API_KEY: Joi.string().required().messages({
  'any.required': 'ANTHROPIC_API_KEY is required',
  'string.empty': 'ANTHROPIC_API_KEY cannot be empty'
}),
```

And in the exported `config` object:

```javascript
anthropic: {
  apiKey: envVars.ANTHROPIC_API_KEY,
},
```

Update `.env.example` with `ANTHROPIC_API_KEY=` placeholder.

- [ ] **Step 2: Anthropic singleton**

```javascript
// src/api/src/services/anthropic.js
import Anthropic from '@anthropic-ai/sdk';
import { config } from '../config/index.js';

export const anthropic = new Anthropic({ apiKey: config.anthropic.apiKey });

export const HAIKU_MODEL = 'claude-haiku-4-5-20251001';
export const SONNET_MODEL = 'claude-sonnet-4-6';
```

- [ ] **Step 3: Write failing tests**

```javascript
// src/api/tests/unit/imageExtractService.test.js
import { describe, it, expect, jest } from '@jest/globals';
import { extractImage } from '../../src/services/imageExtractService.js';

const ok = (json) => ({ content: [{ type: 'text', text: JSON.stringify(json) }], usage: { input_tokens: 100, output_tokens: 50 } });

describe('extractImage', () => {
  it('returns parsed ocrText + description on Haiku success', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue(ok({
      ocrText: 'Three pillars: coverage, calibration, cost',
      description: 'A slide titled "Three pillars" with three bullet points'
    })) } };
    const result = await extractImage({
      imageBuffer: Buffer.from('fakejpeg'),
      mimeType: 'image/jpeg'
    }, { anthropic: fakeAnthropic });
    expect(result.ocrText).toContain('Three pillars');
    expect(result.description).toContain('slide');
    expect(result.tokensIn).toBe(100);
    expect(result.tokensOut).toBe(50);
  });

  it('throws on invalid JSON from Haiku', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({ content: [{ type: 'text', text: 'not-json' }], usage: { input_tokens: 1, output_tokens: 1 } }) } };
    await expect(extractImage({ imageBuffer: Buffer.from('x'), mimeType: 'image/jpeg' }, { anthropic: fakeAnthropic })).rejects.toThrow(/JSON/);
  });

  it('passes the image as a base64 image block', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue(ok({ ocrText: '', description: '' })) } };
    const buf = Buffer.from('abc');
    await extractImage({ imageBuffer: buf, mimeType: 'image/jpeg' }, { anthropic: fakeAnthropic });
    const call = fakeAnthropic.messages.create.mock.calls[0][0];
    const block = call.messages[0].content.find(c => c.type === 'image');
    expect(block.source.type).toBe('base64');
    expect(block.source.media_type).toBe('image/jpeg');
    expect(block.source.data).toBe(buf.toString('base64'));
  });
});
```

- [ ] **Step 4: Run, verify failures**

- [ ] **Step 5: Implement**

```javascript
// src/api/src/services/imageExtractService.js
import { anthropic, HAIKU_MODEL } from './anthropic.js';

const SYSTEM = `You extract structured information from a single image (typically a conference slide).
Return strict JSON only with two fields:
- ocrText: every readable word on the slide concatenated naturally; "" if non-text content
- description: one or two sentences describing what the image shows; "" if it's purely text
No commentary, no markdown, just JSON.`;

const USER = `Extract the slide content. Output JSON: { "ocrText": "...", "description": "..." }`;

export async function extractImage({ imageBuffer, mimeType }, deps = {}) {
  const client = deps.anthropic ?? anthropic;
  const response = await client.messages.create({
    model: HAIKU_MODEL,
    max_tokens: 800,
    system: SYSTEM,
    messages: [{
      role: 'user',
      content: [
        { type: 'image', source: { type: 'base64', media_type: mimeType, data: imageBuffer.toString('base64') } },
        { type: 'text', text: USER }
      ]
    }]
  });

  const raw = response.content?.[0]?.text;
  if (!raw) throw new Error('Empty response from Haiku');

  let parsed;
  try { parsed = JSON.parse(raw); }
  catch { throw new Error(`Haiku returned invalid JSON: ${raw.slice(0, 200)}`); }

  return {
    ocrText: parsed.ocrText ?? '',
    description: parsed.description ?? '',
    tokensIn: response.usage?.input_tokens ?? 0,
    tokensOut: response.usage?.output_tokens ?? 0,
  };
}
```

- [ ] **Step 6: Run, verify pass**

- [ ] **Step 7: Commit**

```bash
git add src/api/src/services/anthropic.js src/api/src/services/imageExtractService.js src/api/tests/unit/imageExtractService.test.js src/api/src/config/index.js src/api/.env.example
git commit -m "feat(api): Haiku image extraction service

Single Haiku call per image returning { ocrText, description }.
Image sent as base64 in a content block. TDD covers happy path,
invalid JSON, and image encoding shape."
```

---

### Task 4: chapterizeService (TDD)

**Files:**
- Create: `src/api/src/services/chapterizeService.js`
- Create: `src/api/tests/unit/chapterizeService.test.js`

Same Haiku-call-with-strict-JSON shape as image extraction. Input: transcript text + word timings. Output: ordered array of `{ start, title, summary }`.

- [ ] **Step 1: Write tests**

```javascript
// src/api/tests/unit/chapterizeService.test.js
import { describe, it, expect, jest } from '@jest/globals';
import { chapterize } from '../../src/services/chapterizeService.js';

const ok = (json) => ({ content: [{ type: 'text', text: JSON.stringify(json) }], usage: { input_tokens: 1500, output_tokens: 200 } });

describe('chapterize', () => {
  it('returns parsed chapters in order', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue(ok({
      chapters: [
        { start: 0, title: 'Opening', summary: 'Sarah introduces herself' },
        { start: 252.4, title: 'Three pillars', summary: 'The framework' }
      ]
    })) } };
    const r = await chapterize({ transcript: 'long talk text', durationSeconds: 2820 }, { anthropic: fakeAnthropic });
    expect(r.chapters).toHaveLength(2);
    expect(r.chapters[0].title).toBe('Opening');
  });

  it('returns empty array if Haiku returns malformed JSON (graceful degrade)', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({ content: [{ type: 'text', text: 'not-json' }], usage: { input_tokens: 1, output_tokens: 1 } }) } };
    const r = await chapterize({ transcript: 'x', durationSeconds: 60 }, { anthropic: fakeAnthropic });
    expect(r.chapters).toEqual([]);
  });

  it('clamps to at least 1 chapter for very short talks', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue(ok({ chapters: [] })) } };
    const r = await chapterize({ transcript: 'short', durationSeconds: 30 }, { anthropic: fakeAnthropic });
    expect(r.chapters.length).toBeGreaterThanOrEqual(1);
    expect(r.chapters[0].start).toBe(0);
  });
});
```

- [ ] **Step 2: Run, verify failures**

- [ ] **Step 3: Implement**

```javascript
// src/api/src/services/chapterizeService.js
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
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add src/api/src/services/chapterizeService.js src/api/tests/unit/chapterizeService.test.js
git commit -m "feat(api): chapterize service — Haiku → ordered chapters

Splits a transcript into 3-8 chapters with start times, titles,
and one-sentence summaries. Degrades to a single 'Recording'
chapter on parse failure."
```

---

### Task 5: blendService (Sonnet, TDD)

**Files:**
- Create: `src/api/src/services/blendService.js`
- Create: `src/api/tests/unit/blendService.test.js`

Bundles transcript + image extracts + user notes + chapters into the Sonnet prompt. Returns the full structured output the iOS renderer needs.

- [ ] **Step 1: Write tests**

```javascript
// src/api/tests/unit/blendService.test.js
import { describe, it, expect, jest } from '@jest/globals';
import { blend } from '../../src/services/blendService.js';

const okFull = () => ({ content: [{ type: 'text', text: JSON.stringify({
  blendedMarkdown: 'Sarah opened with the case for evals.\n\neval as ENG\n\nShe framed three pillars.',
  userNoteSpans: [{ start: 41, end: 53 }],
  quoteSpans: [],
  imagePlacements: [{ imageId: 'p1', charOffset: 80 }],
  citations: [{ blendStart: 0, blendEnd: 41, transcriptStart: 0, transcriptEnd: 12 }]
}) }], usage: { input_tokens: 8000, output_tokens: 1900 } });

describe('blend', () => {
  it('returns the full structured output on Sonnet success', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue(okFull()) } };
    const r = await blend({
      transcript: 'long...',
      transcriptWords: [],
      photos: [{ photoId: 'p1', ocrText: 'Three pillars', description: 'a slide', capturedAt: new Date() }],
      userNotes: 'eval as ENG',
      chapters: [{ start: 0, title: 'Opening', summary: '' }]
    }, { anthropic: fakeAnthropic });
    expect(r.blendedMarkdown).toContain('Sarah');
    expect(r.userNoteSpans).toHaveLength(1);
    expect(r.imagePlacements[0].imageId).toBe('p1');
    expect(r.tokensIn).toBe(8000);
    expect(r.tokensOut).toBe(1900);
  });

  it('throws on invalid JSON', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({ content: [{ type: 'text', text: 'not-json' }], usage: { input_tokens: 1, output_tokens: 1 } }) } };
    await expect(blend({
      transcript: 'x', transcriptWords: [], photos: [], userNotes: '', chapters: []
    }, { anthropic: fakeAnthropic })).rejects.toThrow(/JSON/);
  });

  it('throws on schema mismatch (missing required field)', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({ content: [{ type: 'text', text: JSON.stringify({ foo: 'bar' }) }], usage: { input_tokens: 1, output_tokens: 1 } }) } };
    await expect(blend({
      transcript: 'x', transcriptWords: [], photos: [], userNotes: '', chapters: []
    }, { anthropic: fakeAnthropic })).rejects.toThrow(/blendedMarkdown/);
  });
});
```

- [ ] **Step 2: Run, verify failures**

- [ ] **Step 3: Implement**

```javascript
// src/api/src/services/blendService.js
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
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add src/api/src/services/blendService.js src/api/tests/unit/blendService.test.js
git commit -m "feat(api): Sonnet blend service

Single Sonnet call combining transcript + per-image extracts + user
notes + chapters into the structured blend output the iOS renderer
consumes. Validates JSON shape and required fields; throws on
malformed responses for the route handler to surface as retry."
```

---

### Task 6: Sessions REST routes

**Files:**
- Create: `src/api/src/routes/sessions.js`
- Modify: `src/api/src/server.js` to mount the router

The orchestration layer. POST audio kicks off Deepgram in the background; POST photo runs Haiku; POST blend runs chapterize + Sonnet and writes the result.

- [ ] **Step 1: Implement (no separate TDD — covered by integration test next task)**

```javascript
// src/api/src/routes/sessions.js
import express from 'express';
import multer from 'multer';
import { sessionsRepo } from '../services/sessionsRepo.js';
import { extractImage } from '../services/imageExtractService.js';
import { chapterize } from '../services/chapterizeService.js';
import { blend } from '../services/blendService.js';
import { blendCostMicros } from '../services/blendCost.js';
import { contentHash } from '../services/contentHash.js';
import deepgramService from '../services/deepgramService.js';
import Logger from '../utils/logger.js';

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 50 * 1024 * 1024 } });
const router = express.Router();

// HACK for v1: hardcoded user. Auth middleware swaps this in later.
function userIdFor(req) { return req.userId ?? 'local-dev'; }

router.post('/', async (req, res) => {
  const id = await sessionsRepo.createSession({ userId: userIdFor(req) });
  res.json({ sessionId: id });
});

router.get('/:id', async (req, res) => {
  const s = await sessionsRepo.getSession(req.params.id);
  if (!s) return res.status(404).json({ error: 'session_not_found' });
  res.json(s);
});

router.post('/:id/audio', upload.single('audio'), async (req, res) => {
  const id = req.params.id;
  const s = await sessionsRepo.getSession(id);
  if (!s) return res.status(404).json({ error: 'session_not_found' });
  if (!req.file) return res.status(400).json({ error: 'audio_missing' });

  await sessionsRepo.attachAudio(id, { audioPath: 'in-memory', durationSeconds: Number(req.body.durationSeconds || 0) });
  await sessionsRepo.setStatus(id, 'transcribing');

  try {
    const { transcript, words } = await deepgramService.transcribeBuffer(req.file.buffer, req.file.mimetype);
    await sessionsRepo.saveTranscript(id, { text: transcript, words });
    await sessionsRepo.setStatus(id, 'transcribed');
    res.json({ ok: true });
  } catch (e) {
    Logger.error('Transcribe failed', e);
    await sessionsRepo.setStatus(id, 'failed', e.message);
    res.status(500).json({ error: 'transcribe_failed' });
  }
});

router.post('/:id/photos', upload.single('photo'), async (req, res) => {
  const id = req.params.id;
  const s = await sessionsRepo.getSession(id);
  if (!s) return res.status(404).json({ error: 'session_not_found' });
  if (!req.file) return res.status(400).json({ error: 'photo_missing' });

  const photoId = req.body.photoId || contentHash(req.file.buffer);
  const hash = contentHash(req.file.buffer);
  const capturedAt = new Date(Number(req.body.capturedAt || Date.now()));

  await sessionsRepo.addPhoto(id, { photoId, contentHash: hash, capturedAt, localPath: 'in-memory' });

  try {
    const result = await extractImage({ imageBuffer: req.file.buffer, mimeType: req.file.mimetype });
    await sessionsRepo.updatePhotoExtract(id, photoId, {
      ocrText: result.ocrText, description: result.description, extractStatus: 'complete'
    });
    res.json({ photoId, ocrText: result.ocrText, description: result.description });
  } catch (e) {
    Logger.error('Image extract failed', e);
    await sessionsRepo.updatePhotoExtract(id, photoId, { ocrText: '', description: '', extractStatus: 'failed' });
    res.status(500).json({ error: 'extract_failed' });
  }
});

router.post('/:id/blend', express.json(), async (req, res) => {
  const id = req.params.id;
  const s = await sessionsRepo.getSession(id);
  if (!s) return res.status(404).json({ error: 'session_not_found' });
  if (!s.transcript) return res.status(400).json({ error: 'no_transcript' });

  const userNotes = req.body.userNotes ?? '';

  await sessionsRepo.setStatus(id, 'blending');

  try {
    const chap = await chapterize({ transcript: s.transcript, durationSeconds: s.durationSeconds });
    const result = await blend({
      transcript: s.transcript,
      transcriptWords: s.transcriptWords,
      photos: s.photos.filter(p => p.extractStatus === 'complete'),
      userNotes,
      chapters: chap.chapters,
    });

    const cost = blendCostMicros({
      deepgramSeconds: s.durationSeconds,
      imageCount: s.photos.filter(p => p.extractStatus === 'complete').length,
      hasChapterize: true,
      sonnetInputTokens: result.tokensIn,
      sonnetOutputTokens: result.tokensOut,
    });

    await sessionsRepo.saveBlend(id, {
      blendedMarkdown: result.blendedMarkdown,
      userNoteSpans: result.userNoteSpans,
      quoteSpans: result.quoteSpans,
      imagePlacements: result.imagePlacements,
      citations: result.citations,
      chapters: chap.chapters,
      costMicros: cost,
      modelVersion: 'sonnet-4-6+haiku-4-5+nova-3'
    });

    await sessionsRepo.recordCost({
      userId: s.userId, sessionId: id, microsDelta: -cost, reason: 'blend',
      metadata: { sonnetIn: result.tokensIn, sonnetOut: result.tokensOut, photoCount: s.photos.length, chapterCount: chap.chapters.length }
    });

    res.json({
      blendedMarkdown: result.blendedMarkdown,
      userNoteSpans: result.userNoteSpans,
      quoteSpans: result.quoteSpans,
      imagePlacements: result.imagePlacements,
      citations: result.citations,
      chapters: chap.chapters,
      costMicros: cost,
    });
  } catch (e) {
    Logger.error('Blend failed', e);
    await sessionsRepo.setStatus(id, 'failed', e.message);
    res.status(500).json({ error: 'blend_failed', detail: e.message });
  }
});

export default router;
```

- [ ] **Step 2: Mount in server.js**

In `src/api/src/server.js`, add:

```javascript
import sessionsRouter from './routes/sessions.js';
// ... existing middleware ...
app.use('/v1/sessions', sessionsRouter);
```

- [ ] **Step 3: Add a `transcribeBuffer` helper to the existing deepgramService.js**

If the service doesn't already expose a buffer-based transcription that returns `{ transcript, words }`, add:

```javascript
async transcribeBuffer(buffer, mimeType = 'audio/mp4') {
  const { result } = await this.client.listen.prerecorded.transcribeFile(buffer, {
    model: config.deepgram.model,
    language: config.deepgram.language,
    punctuate: true,
    diarize: false,
    utterances: false,
  });
  const channel = result?.results?.channels?.[0];
  const transcript = channel?.alternatives?.[0]?.transcript ?? '';
  const words = (channel?.alternatives?.[0]?.words ?? []).map(w => ({
    text: w.word, start: w.start, end: w.end
  }));
  return { transcript, words };
}
```

- [ ] **Step 4: Build, smoke**

```bash
cd src/api && npm run lint && npm run test:ci
```

Expected: existing tests pass, new tests pass. (`npm test` runs the full suite including pre-existing flaky / broken integration suites; `test:ci` is the gate CI uses.)

- [ ] **Step 5: Commit**

```bash
git add src/api/src/routes/sessions.js src/api/src/server.js src/api/src/services/deepgramService.js
git commit -m "feat(api): /v1/sessions REST routes

POST /         create session
GET /:id       fetch state
POST /:id/audio    upload audio, run Deepgram, save transcript
POST /:id/photos   upload photo, run Haiku image extract
POST /:id/blend    run Haiku chapterize + Sonnet blend, record cost

Failure on any LLM call sets session status to 'failed' with error
message; client can retry. Cost recorded on the in-memory ledger
on successful blend; debit gating arrives with the auth + ledger
specs."
```

---

### Task 7: Integration test — end-to-end with all SDKs mocked

**Files:**
- Create: `src/api/tests/integration/sessionsFlow.test.js`

Exercises the full POST /sessions → /audio → /photos → /blend flow with mocked Deepgram + Anthropic SDKs.

- [ ] **Step 1: Implement**

```javascript
// src/api/tests/integration/sessionsFlow.test.js
import { describe, it, expect, jest, beforeEach } from '@jest/globals';
import request from 'supertest';

// Mock the SDKs via module mocking before importing the app.
jest.unstable_mockModule('@deepgram/sdk', () => ({
  createClient: () => ({
    listen: { prerecorded: { transcribeFile: async () => ({
      result: { results: { channels: [{ alternatives: [{
        transcript: 'Hello this is a test talk',
        words: [{ word: 'Hello', start: 0, end: 0.5 }, { word: 'this', start: 0.6, end: 0.8 }]
      }] }] } }
    }) } }
  })
}));

jest.unstable_mockModule('@anthropic-ai/sdk', () => ({
  default: jest.fn().mockImplementation(() => ({
    messages: { create: jest.fn().mockImplementation(async ({ model, messages }) => {
      // Image extract
      if (model.includes('haiku') && messages?.[0]?.content?.some?.(c => c.type === 'image')) {
        return { content: [{ type: 'text', text: JSON.stringify({ ocrText: 'Slide text', description: 'A slide' }) }], usage: { input_tokens: 100, output_tokens: 30 } };
      }
      // Chapterize
      if (model.includes('haiku')) {
        return { content: [{ type: 'text', text: JSON.stringify({ chapters: [{ start: 0, title: 'Opening', summary: 'intro' }] }) }], usage: { input_tokens: 200, output_tokens: 50 } };
      }
      // Sonnet blend
      return { content: [{ type: 'text', text: JSON.stringify({
        blendedMarkdown: 'Hello this is a test talk.\n\ncool',
        userNoteSpans: [{ start: 28, end: 32 }],
        quoteSpans: [],
        imagePlacements: [],
        citations: []
      }) }], usage: { input_tokens: 500, output_tokens: 100 } };
    }) }
  }))
}));

const { app } = await import('../../src/server.js');

describe('Sessions flow E2E', () => {
  it('runs the full pipeline and returns a blended note', async () => {
    const create = await request(app).post('/v1/sessions').send();
    expect(create.status).toBe(200);
    const sessionId = create.body.sessionId;

    const audio = await request(app)
      .post(`/v1/sessions/${sessionId}/audio`)
      .field('durationSeconds', '60')
      .attach('audio', Buffer.from('fakeaudio'), { filename: 't.m4a', contentType: 'audio/mp4' });
    expect(audio.status).toBe(200);

    const photo = await request(app)
      .post(`/v1/sessions/${sessionId}/photos`)
      .field('photoId', 'p1')
      .field('capturedAt', String(Date.now()))
      .attach('photo', Buffer.from('fakejpg'), { filename: 's.jpg', contentType: 'image/jpeg' });
    expect(photo.status).toBe(200);
    expect(photo.body.ocrText).toBe('Slide text');

    const blend = await request(app)
      .post(`/v1/sessions/${sessionId}/blend`)
      .send({ userNotes: 'cool' });
    expect(blend.status).toBe(200);
    expect(blend.body.blendedMarkdown).toContain('Hello');
    expect(blend.body.chapters).toHaveLength(1);
    expect(blend.body.costMicros).toBeGreaterThan(0);

    const get = await request(app).get(`/v1/sessions/${sessionId}`);
    expect(get.body.status).toBe('complete');
  });

  it('returns 400 when blending without transcript', async () => {
    const create = await request(app).post('/v1/sessions').send();
    const id = create.body.sessionId;
    const blend = await request(app).post(`/v1/sessions/${id}/blend`).send({ userNotes: '' });
    expect(blend.status).toBe(400);
    expect(blend.body.error).toBe('no_transcript');
  });
});
```

- [ ] **Step 2: Run, verify pass**

```bash
cd src/api && NODE_OPTIONS='--experimental-vm-modules' npx jest tests/integration/sessionsFlow.test.js
```

- [ ] **Step 3: Commit**

```bash
git add src/api/tests/integration/sessionsFlow.test.js
git commit -m "test(api): E2E pipeline test with mocked Deepgram + Anthropic

Exercises POST /sessions → /audio → /photos → /blend → GET /:id with
SDK mocks routing per-call to image-extract / chapterize / blend
based on model name and content shape."
```

---

### Task 8: iOS — Photo SwiftData model + content-hash migration (TDD)

**Files:**
- Create: `src/mobile/Muesli/Models/Photo.swift`
- Create: `src/mobile/Muesli/Migration/PhotoMigration.swift`
- Create: `src/mobile/MuesliTests/Models/PhotoMigrationTests.swift`
- Modify: `src/mobile/Muesli/MuesliApp.swift` (add Photo to schema, run migration)
- Modify: `src/mobile/Muesli/Models/Note.swift` (add `photos: [Photo]` relationship + new blend fields)

- [ ] **Step 1: Write failing tests**

```swift
// src/mobile/MuesliTests/Models/PhotoMigrationTests.swift
import XCTest
import SwiftData
@testable import Muesli

@MainActor
final class PhotoMigrationTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testMigratesImagePathsToPhotos() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let note = Note(title: "Talk", imagePaths: ["a.jpg", "b.jpg", "c.jpg"])
        context.insert(note)
        try context.save()

        // Simulate that the files exist and have content
        PhotoMigration.run(in: context, fileBytesProvider: { path in
            Data(path.utf8)  // hash will be predictable per filename
        })

        XCTAssertEqual(note.photos.count, 3)
        XCTAssertNotEqual(note.photos[0].contentHash, note.photos[1].contentHash)
        // capturedAt defaults to note.timestamp
        XCTAssertEqual(note.photos[0].capturedAt, note.timestamp)
    }

    func testIsIdempotent() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let note = Note(title: "Talk", imagePaths: ["x.jpg"])
        context.insert(note)
        try context.save()

        PhotoMigration.run(in: context, fileBytesProvider: { _ in Data([1,2,3]) })
        PhotoMigration.run(in: context, fileBytesProvider: { _ in Data([1,2,3]) })

        XCTAssertEqual(note.photos.count, 1)
    }
}
```

- [ ] **Step 2: Run, verify failures**

- [ ] **Step 3: Define Photo model**

```swift
// src/mobile/Muesli/Models/Photo.swift
import Foundation
import SwiftData

@Model
final class Photo {
    var id: UUID
    var localPath: String
    var contentHash: String
    var capturedAt: Date
    var ocrText: String?
    var photoDescription: String?    // 'description' is reserved-ish on @Model
    var extractStatusRaw: String     // pending / complete / failed
    var note: Note?

    var extractStatus: ExtractStatus {
        get { ExtractStatus(rawValue: extractStatusRaw) ?? .pending }
        set { extractStatusRaw = newValue.rawValue }
    }

    init(localPath: String, contentHash: String, capturedAt: Date, note: Note? = nil) {
        self.id = UUID()
        self.localPath = localPath
        self.contentHash = contentHash
        self.capturedAt = capturedAt
        self.extractStatusRaw = ExtractStatus.pending.rawValue
        self.note = note
    }
}

enum ExtractStatus: String, Codable { case pending, complete, failed }
```

- [ ] **Step 4: Add new fields to Note**

In `src/mobile/Muesli/Models/Note.swift`, append:

```swift
// Blend pipeline outputs (populated post-stop)
var transcript: String?
var transcriptWordsJSON: Data?
var blendedMarkdown: String?
var blendCitationsJSON: Data?
var chaptersJSON: Data?
var blendStatusRaw: String = "idle"
var blendError: String?
var blendCostMicros: Int?
var blendModelVersion: String?

@Relationship(deleteRule: .cascade, inverse: \Photo.note) var photos: [Photo] = []

var blendStatus: BlendStatus {
    get { BlendStatus(rawValue: blendStatusRaw) ?? .idle }
    set { blendStatusRaw = newValue.rawValue }
}
```

And alongside Note, add:

```swift
enum BlendStatus: String, Codable {
    case idle, transcribing, transcribed, extracting, blending, complete, failed
}
```

Keep the existing `imagePaths: [String]` field for now — migration leaves it alone, but reads should prefer `photos`.

- [ ] **Step 5: Implement PhotoMigration**

```swift
// src/mobile/Muesli/Migration/PhotoMigration.swift
import Foundation
import SwiftData
import CryptoKit

enum PhotoMigration {
    private static let runFlagKey = "muesli.photoMigration.v1.complete"

    static func run(in context: ModelContext, fileBytesProvider: (String) -> Data?) {
        let allNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        for note in allNotes {
            // Skip if photos already migrated for this note
            let existingPaths = Set(note.photos.map(\.localPath))
            for path in note.imagePaths where !existingPaths.contains(path) {
                let bytes = fileBytesProvider(path) ?? Data(path.utf8)
                let hash = SHA256.hash(data: bytes).compactMap { String(format: "%02x", $0) }.joined()
                let photo = Photo(localPath: path, contentHash: hash, capturedAt: note.timestamp, note: note)
                context.insert(photo)
                note.photos.append(photo)
            }
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: runFlagKey)
    }

    static var hasRun: Bool {
        UserDefaults.standard.bool(forKey: runFlagKey)
    }
}
```

- [ ] **Step 6: Run, verify tests pass**

- [ ] **Step 7: Wire into MuesliApp**

In `MuesliApp.swift`, add `Photo.self` to the Schema. In `init()`, after `ConferenceMigration.run`, add:

```swift
if !PhotoMigration.hasRun {
    PhotoMigration.run(in: context, fileBytesProvider: { path in
        // Best-effort read: returns nil if file is missing.
        guard let url = AudioRecordingManager.shared.fileURL(for: path) else { return nil }
        return try? Data(contentsOf: url)
    })
}
```

(`AudioRecordingManager.fileURL(for:)` may need a small helper added — same logic as `getRecordingURL` but for any file in the recordings directory.)

- [ ] **Step 8: Build, commit**

```bash
git add src/mobile/Muesli/Models/Photo.swift src/mobile/Muesli/Models/Note.swift src/mobile/Muesli/Migration/PhotoMigration.swift src/mobile/MuesliTests/Models/PhotoMigrationTests.swift src/mobile/Muesli/MuesliApp.swift
git commit -m "feat(ios): Photo SwiftData model + imagePaths migration

Photo entity with content-hash storage. One-shot migration converts
existing Note.imagePaths into Photo rows, hashing the file bytes for
cache keys downstream. New blend fields added to Note (transcript,
blendedMarkdown, chaptersJSON, blendStatus, etc.) for the pipeline
to populate."
```

---

### Task 9: iOS — SessionsService client (TDD on JSON shapes)

**Files:**
- Create: `src/mobile/Muesli/Services/SessionsService.swift`
- Create: `src/mobile/MuesliTests/Services/SessionsClientTests.swift`

URLSession-based client for the new backend endpoints. TDD covers the JSON encoding/decoding; the actual network calls are covered by manual smoke + an iOS UI test layer if one exists.

- [ ] **Step 1: Write failing tests**

```swift
// src/mobile/MuesliTests/Services/SessionsClientTests.swift
import XCTest
@testable import Muesli

final class SessionsClientTests: XCTestCase {
    func testDecodesBlendResponse() throws {
        let json = #"""
        {
          "blendedMarkdown": "Hello.",
          "userNoteSpans": [{ "start": 0, "end": 6 }],
          "quoteSpans": [{ "start": 0, "end": 5, "transcriptStart": 1.0, "transcriptEnd": 2.0, "speaker": "Sarah" }],
          "imagePlacements": [{ "imageId": "p1", "charOffset": 6 }],
          "citations": [{ "blendStart": 0, "blendEnd": 6, "transcriptStart": 0.0, "transcriptEnd": 1.5 }],
          "chapters": [{ "start": 0, "title": "Opening", "summary": "intro" }],
          "costMicros": 12345
        }
        """#.data(using: .utf8)!

        let resp = try JSONDecoder().decode(BlendResponse.self, from: json)
        XCTAssertEqual(resp.blendedMarkdown, "Hello.")
        XCTAssertEqual(resp.userNoteSpans.count, 1)
        XCTAssertEqual(resp.quoteSpans.first?.speaker, "Sarah")
        XCTAssertEqual(resp.chapters.count, 1)
        XCTAssertEqual(resp.costMicros, 12345)
    }

    func testEncodesBlendRequest() throws {
        let req = BlendRequest(userNotes: "eval as ENG")
        let data = try JSONEncoder().encode(req)
        let s = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(s.contains("\"userNotes\""))
        XCTAssertTrue(s.contains("eval as ENG"))
    }
}
```

- [ ] **Step 2: Run, verify failures**

- [ ] **Step 3: Implement**

```swift
// src/mobile/Muesli/Services/SessionsService.swift
import Foundation

struct CreateSessionResponse: Decodable { let sessionId: UUID }

struct PhotoResponse: Decodable {
    let photoId: String
    let ocrText: String
    let description: String
}

struct BlendRequest: Encodable {
    let userNotes: String
}

struct UserNoteSpan: Codable { let start: Int; let end: Int }
struct QuoteSpan: Codable {
    let start: Int; let end: Int
    let transcriptStart: Double; let transcriptEnd: Double
    let speaker: String?
}
struct ImagePlacement: Codable { let imageId: String; let charOffset: Int }
struct Citation: Codable {
    let blendStart: Int; let blendEnd: Int
    let transcriptStart: Double; let transcriptEnd: Double
}
struct ChapterDTO: Codable { let start: Double; let title: String; let summary: String? }

struct BlendResponse: Decodable {
    let blendedMarkdown: String
    let userNoteSpans: [UserNoteSpan]
    let quoteSpans: [QuoteSpan]
    let imagePlacements: [ImagePlacement]
    let citations: [Citation]
    let chapters: [ChapterDTO]
    let costMicros: Int
}

actor SessionsService {
    static let shared = SessionsService()
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Anthropic / our backend uses ISO/numeric — no special config needed
        return d
    }()
    private let encoder = JSONEncoder()

    private var baseURL: URL { APIConfig.baseURL }

    func createSession() async throws -> UUID {
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/sessions"))
        req.httpMethod = "POST"
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(CreateSessionResponse.self, from: data).sessionId
    }

    func uploadAudio(sessionId: UUID, audioURL: URL, durationSeconds: Double) async throws {
        let url = baseURL.appendingPathComponent("/v1/sessions/\(sessionId)/audio")
        let (data, name, mime) = (try Data(contentsOf: audioURL), audioURL.lastPathComponent, "audio/mp4")
        try await uploadMultipart(url: url, fields: ["durationSeconds": String(durationSeconds)], file: (name: "audio", filename: name, mime: mime, data: data))
    }

    func uploadPhoto(sessionId: UUID, photo: Photo, jpegData: Data) async throws -> PhotoResponse {
        let url = baseURL.appendingPathComponent("/v1/sessions/\(sessionId)/photos")
        let body = try await uploadMultipart(
            url: url,
            fields: [
                "photoId": photo.id.uuidString,
                "capturedAt": String(Int(photo.capturedAt.timeIntervalSince1970 * 1000))
            ],
            file: (name: "photo", filename: "\(photo.contentHash).jpg", mime: "image/jpeg", data: jpegData)
        )
        return try decoder.decode(PhotoResponse.self, from: body)
    }

    func runBlend(sessionId: UUID, userNotes: String) async throws -> BlendResponse {
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/sessions/\(sessionId)/blend"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(BlendRequest(userNotes: userNotes))
        let (data, _) = try await session.data(for: req)
        return try decoder.decode(BlendResponse.self, from: data)
    }

    @discardableResult
    private func uploadMultipart(url: URL, fields: [String: String], file: (name: String, filename: String, mime: String, data: Data)) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        for (k, v) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(v)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(file.mime)\r\n\r\n".data(using: .utf8)!)
        body.append(file.data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, _) = try await session.data(for: req)
        return data
    }
}
```

(Assumes `APIConfig.baseURL` exists — if not, implementer adds a small struct that reads from `Info.plist` or a constant.)

- [ ] **Step 4: Run, verify tests pass**

- [ ] **Step 5: Commit**

```bash
git add src/mobile/Muesli/Services/SessionsService.swift src/mobile/MuesliTests/Services/SessionsClientTests.swift
git commit -m "feat(ios): SessionsService client for /v1/sessions

Actor-based URLSession wrapper with multipart upload helper. JSON
shapes (BlendRequest, BlendResponse, ImagePlacement, etc.) match
the backend API spec exactly; TDD covers encode/decode round trip."
```

---

### Task 10: BlendOrchestrator — coordinates the iOS side of the pipeline

**Files:**
- Create: `src/mobile/Muesli/Services/BlendOrchestrator.swift`
- Modify: `src/mobile/Muesli/Views/NewNoteView.swift` — replace the `TranscriptionOrchestrator.shared.enqueueTranscription(...)` call site with `BlendOrchestrator.shared.enqueueBlend(noteId:audioPath:)`. `TranscriptionOrchestrator` stays wired in `MuesliApp.init` as a fallback for the legacy local-only path; no feature flag in v1.

The note's lifecycle goes idle → recording (existing) → on-stop the orchestrator: creates a Session, uploads audio, uploads each photo, runs blend, persists results back to the Note.

- [ ] **Step 1: Implement orchestrator**

```swift
// src/mobile/Muesli/Services/BlendOrchestrator.swift
import Foundation
import SwiftData

@MainActor
final class BlendOrchestrator {
    static let shared = BlendOrchestrator()
    private var container: ModelContainer?
    private init() {}

    func setContainer(_ c: ModelContainer) { container = c }

    func enqueueBlend(noteId: PersistentIdentifier, audioPath: String) {
        guard let container else {
            AppLogger.shared.error("BlendOrchestrator has no ModelContainer")
            return
        }
        Task.detached { [weak self] in
            await self?.runBlend(noteId: noteId, audioPath: audioPath, container: container)
        }
    }

    private func runBlend(noteId: PersistentIdentifier, audioPath: String, container: ModelContainer) async {
        let context = ModelContext(container)
        guard let note = context.model(for: noteId) as? Note else { return }

        await MainActor.run { note.blendStatus = .transcribing; try? context.save() }

        let svc = SessionsService.shared
        do {
            let sessionId = try await svc.createSession()

            guard let audioURL = AudioRecordingManager.shared.getRecordingURL(fileName: audioPath) else {
                throw NSError(domain: "Muesli", code: 1, userInfo: [NSLocalizedDescriptionKey: "audio missing"])
            }
            let duration = (try? AVAsset(url: audioURL).load(.duration).seconds) ?? note.duration ?? 0
            try await svc.uploadAudio(sessionId: sessionId, audioURL: audioURL, durationSeconds: duration)

            await MainActor.run { note.blendStatus = .extracting; try? context.save() }

            for photo in note.photos {
                guard let jpeg = try? Data(contentsOf: URL(fileURLWithPath: photo.localPath)) else { continue }
                _ = try? await svc.uploadPhoto(sessionId: sessionId, photo: photo, jpegData: jpeg)
            }

            await MainActor.run { note.blendStatus = .blending; try? context.save() }

            let blend = try await svc.runBlend(sessionId: sessionId, userNotes: note.userNotes)

            await MainActor.run {
                note.blendedMarkdown = blend.blendedMarkdown
                note.blendCitationsJSON = try? JSONEncoder().encode([
                    "userNoteSpans": blend.userNoteSpans,
                    "quoteSpans": blend.quoteSpans,
                    "imagePlacements": blend.imagePlacements,
                    "citations": blend.citations
                ] as [String: Any])
                note.chaptersJSON = try? JSONEncoder().encode(["chapters": blend.chapters])
                note.blendCostMicros = blend.costMicros
                note.blendStatus = .complete
                note.blendError = nil
                try? context.save()
            }
        } catch {
            await MainActor.run {
                note.blendStatus = .failed
                note.blendError = error.localizedDescription
                try? context.save()
            }
            AppLogger.shared.error("Blend failed for note", error: error)
        }
    }
}
```

(The `[String: Any]` JSON encoding shortcut works for v1; cleaner is a `BlendCitations` Codable struct that wraps the four arrays. Implementer can refactor if they prefer.)

- [ ] **Step 2: Wire container in MuesliApp.init**

```swift
BlendOrchestrator.shared.setContainer(sharedModelContainer)
```

- [ ] **Step 3: Replace TranscriptionOrchestrator call site**

In `NewNoteView.saveNote()`, where it currently calls `TranscriptionOrchestrator.shared.enqueueTranscription(...)`, switch to `BlendOrchestrator.shared.enqueueBlend(noteId:audioPath:)`. The legacy path stays for fallback (e.g., if the backend is unreachable, BlendOrchestrator could fall back to local transcription) — but for v1 the backend is the only path.

- [ ] **Step 4: Build, smoke**

Manually with the API running on localhost:3000:
- Record a short audio, take 1 photo, save → see status progress through transcribing → extracting → blending → complete in console logs
- Open the note → `note.blendedMarkdown` is populated
- (UI rendering is the UI translation plan; for now SimpleNoteDetailView shows the raw transcript field)

- [ ] **Step 5: Commit**

```bash
git add src/mobile/Muesli/Services/BlendOrchestrator.swift src/mobile/Muesli/MuesliApp.swift src/mobile/Muesli/Views/NewNoteView.swift
git commit -m "feat(ios): BlendOrchestrator — drives the iOS side of the pipeline

On stop, creates a backend Session, uploads audio + photos, runs the
blend, and persists blendedMarkdown / citations / chapters / cost
back onto the Note. Updates blendStatus through transcribing →
extracting → blending → complete. Failure path captures error and
sets status .failed for the UI to surface a retry."
```

---

### Final verification

- [ ] **All tests pass**
```bash
cd src/api && npm run test:ci
cd src/mobile && xcodebuild test -project Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6'
```

- [ ] **Manual smoke (requires real API keys)**
- Set `DEEPGRAM_API_KEY` and `ANTHROPIC_API_KEY` in `src/api/.env`
- `cd src/api && npm run dev`
- iOS sim: record 30s of audio while reading a slide aloud, take 1 photo of the slide, save
- Watch API logs: should see Deepgram transcribe, Haiku extract photo, Haiku chapterize, Sonnet blend
- Open the note in the iOS app: `note.blendedMarkdown` populated, `note.chaptersJSON` populated, `note.blendCostMicros > 0`

- [ ] **Commit log shows all 10 tasks**
```bash
git log --oneline | head -15
```

## Out of scope (revisit later)

- **AugmentedNoteView rendering** — UI translation plan owns this
- **Auth middleware** — userId hardcoded; auth spec swap later
- **Postgres backend** — SessionsRepo abstraction makes the swap mechanical
- **Credit ledger enforcement** — cost is recorded but no balance check
- **Background uploads** — for v1, audio + photos upload synchronously when `enqueueBlend` runs; long-running uploads block the orchestrator until done. v2 should chunk and resume.
- **Streaming blend output** — Sonnet returns the full blend after the call; streaming UI is v2 polish
