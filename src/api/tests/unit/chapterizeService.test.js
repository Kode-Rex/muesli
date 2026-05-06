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

  it('returns a fallback chapter on malformed JSON', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue({ content: [{ type: 'text', text: 'not-json' }], usage: { input_tokens: 1, output_tokens: 1 } }) } };
    const r = await chapterize({ transcript: 'x', durationSeconds: 60 }, { anthropic: fakeAnthropic });
    expect(r.chapters).toHaveLength(1);
    expect(r.chapters[0].title).toBe('Recording');
  });

  it('clamps to at least 1 chapter for very short talks', async () => {
    const fakeAnthropic = { messages: { create: jest.fn().mockResolvedValue(ok({ chapters: [] })) } };
    const r = await chapterize({ transcript: 'short', durationSeconds: 30 }, { anthropic: fakeAnthropic });
    expect(r.chapters.length).toBeGreaterThanOrEqual(1);
    expect(r.chapters[0].start).toBe(0);
  });
});
