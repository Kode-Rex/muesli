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
