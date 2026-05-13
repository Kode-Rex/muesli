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
  it('keeps full blends only for the 3 most recent sessions; older ones get compact summaries', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({
      content: [{ type: 'text', text: JSON.stringify({ answer: 'ok', references: [] }) }],
      usage: { input_tokens: 1, output_tokens: 1 }
    }) } };
    const distinctiveBlend = 'BLENDED_BODY_MARKER';
    const sessions = Array.from({ length: 6 }, (_, i) => ({
      id: `sess-${i}`,
      title: `Talk ${i}`,
      transcript: `TRANSCRIPT_OF_${i}`,
      blendedMarkdown: `${distinctiveBlend}_${i}`,
      aiSummary: `summary ${i}`,
      createdAt: new Date(2026, 0, i + 1).toISOString(),
      photos: []
    }));
    await chat({
      scope: { kind: 'conference', sessionIds: sessions.map(s => s.id) },
      messages: [{ role: 'user', content: 'across talks' }],
      sessions
    }, { anthropic: fakeAnthropic });
    const userContent = fakeAnthropic.messages.create.mock.calls[0][0].messages[0].content;

    // The 3 most recent (Talk 3, 4, 5) should include full blend body + transcript.
    for (const i of [3, 4, 5]) {
      expect(userContent).toContain(`${distinctiveBlend}_${i}`);
      expect(userContent).toContain(`TRANSCRIPT_OF_${i}`);
    }
    // The 3 oldest (Talk 0, 1, 2) should appear only in compact form — no
    // Transcript / Blended notes body for them.
    for (const i of [0, 1, 2]) {
      expect(userContent).not.toContain(`${distinctiveBlend}_${i}`);
      expect(userContent).not.toContain(`TRANSCRIPT_OF_${i}`);
      // Compact section header still appears for them.
      expect(userContent).toContain(`Talk ${i}`);
      expect(userContent).toContain(`summary ${i}`);
    }
  });

  it('demotes additional sessions when the 3-recent full blends exceed the budget', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({
      content: [{ type: 'text', text: JSON.stringify({ answer: 'ok', references: [] }) }],
      usage: { input_tokens: 1, output_tokens: 1 }
    }) } };
    // Three big blends — each well past 200k chars. Default rule would render
    // all three; budget rule should demote until under 600k input chars.
    const bigBlend = 'X'.repeat(250_000);
    const sessions = [3, 4, 5].map(i => ({
      id: `sess-${i}`,
      title: `Talk ${i}`,
      transcript: `T_${i}`,
      blendedMarkdown: bigBlend,
      aiSummary: `summary ${i}`,
      createdAt: new Date(2026, 0, i + 1).toISOString(),
      photos: []
    }));
    await chat({
      scope: { kind: 'conference', sessionIds: sessions.map(s => s.id) },
      messages: [{ role: 'user', content: 'q' }],
      sessions
    }, { anthropic: fakeAnthropic });
    const userContent = fakeAnthropic.messages.create.mock.calls[0][0].messages[0].content;
    // Total context length must fit under 600k chars.
    expect(userContent.length).toBeLessThan(600_000);
    // The most recent talk (Talk 5) must still have its full blend.
    expect(userContent).toContain('Talk 5');
    expect(userContent).toContain('Transcript:');
  });
});

describe('citation post-processing preserves paragraphs', () => {
  it('does not collapse newlines or paragraph breaks in the answer', async () => {
    const multiline = {
      content: [{ type: 'text', text: JSON.stringify({
        answer: 'First paragraph [[c:0]].\n\nSecond paragraph with a bullet:\n- item one\n- item two',
        references: [{ kind: 'note', sessionId: 'sess-1' }]
      }) }],
      usage: { input_tokens: 1, output_tokens: 1 }
    };
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue(multiline) } };
    const r = await chat({
      scope: { kind: 'talk', sessionId: 'sess-1' },
      messages: [{ role: 'user', content: 'q' }],
      sessions: [{ id: 'sess-1', title: 'T', transcript: 't', photos: [] }]
    }, { anthropic: fakeAnthropic });
    expect(r.message.content).toContain('\n\n');
    expect(r.message.content).toContain('- item one');
    expect(r.message.content).not.toMatch(/\[\[c:/);
  });
});
