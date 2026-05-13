import { describe, it, expect, jest } from '@jest/globals';
import { chat } from '../../src/services/chatService.js';

const okResponse = (answer = 'The talk covered three pillars.', references = []) => ({
  content: [{ type: 'text', text: JSON.stringify({ answer, references }) }],
  usage: { input_tokens: 1200, output_tokens: 180 }
});

describe('chat (talk scope)', () => {
  it('returns assistant message with empty citations when references are empty', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue(okResponse()) } };
    const result = await chat({
      scope: { kind: 'talk', sessionId: 'sess-1' },
      messages: [{ role: 'user', content: 'What did Sarah say?' }],
      sessions: [{
        id: 'sess-1', title: 'Three pillars', speaker: 'Sarah Chen',
        transcript: 'Sarah said hello.', blendedMarkdown: 'Hello.',
        aiSummary: 'A talk.', photos: []
      }],
    }, { anthropic: fakeAnthropic });
    expect(result.message.role).toBe('assistant');
    expect(result.message.content).toBe('The talk covered three pillars.');
    expect(result.citations).toEqual([]);
    expect(result.tokensIn).toBe(1200);
    expect(result.tokensOut).toBe(180);
    expect(fakeAnthropic.messages.create).toHaveBeenCalledTimes(1);
  });

  it('strips [[c:N]] tokens and resolves transcript + note citations', async () => {
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
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({
      content: [{ type: 'text', text: 'not json' }],
      usage: { input_tokens: 1, output_tokens: 1 }
    }) } };
    await expect(chat({
      scope: { kind: 'talk', sessionId: 's' },
      messages: [{ role: 'user', content: 'q' }],
      sessions: [{ id: 's', transcript: '', photos: [] }]
    }, { anthropic: fakeAnthropic })).rejects.toThrow(/JSON/);
  });

  it('throws on missing required field', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({
      content: [{ type: 'text', text: JSON.stringify({ answer: 'x' }) }],
      usage: { input_tokens: 1, output_tokens: 1 }
    }) } };
    await expect(chat({
      scope: { kind: 'talk', sessionId: 's' },
      messages: [{ role: 'user', content: 'q' }],
      sessions: [{ id: 's', transcript: '', photos: [] }]
    }, { anthropic: fakeAnthropic })).rejects.toThrow(/references/);
  });
});

describe('chat (conference scope)', () => {
  it('keeps full blends only for the N most recent sessions; older ones get summaries', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({
      content: [{ type: 'text', text: JSON.stringify({ answer: 'ok', references: [] }) }],
      usage: { input_tokens: 1, output_tokens: 1 }
    }) } };
    const longBlend = 'X'.repeat(50_000);
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
      messages: [{ role: 'user', content: 'across talks' }],
      sessions
    }, { anthropic: fakeAnthropic });
    const call = fakeAnthropic.messages.create.mock.calls[0][0];
    const userContent = call.messages[0].content;
    // 3 most recent (talks 3, 4, 5 by createdAt) keep their headers.
    expect(userContent).toContain('Talk 5');
    expect(userContent).toContain('Talk 4');
    expect(userContent).toContain('Talk 3');
    // Older talks appear as summaries.
    expect(userContent).toContain('summary 0');
    // Three full blends + three summaries should fit well under 200k chars.
    expect(userContent.length).toBeLessThan(200_000);
  });
});
