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
