import { describe, it, expect, jest } from '@jest/globals';
import { extractImage } from '../../src/services/imageExtractService.js';

const ok = (json) => ({
  content: [{ type: 'text', text: JSON.stringify(json) }],
  usage: { input_tokens: 100, output_tokens: 50 }
});

describe('extractImage', () => {
  it('returns parsed ocrText + description on Haiku success', async () => {
    const fakeAnthropic = {
      messages: {
        create: jest.fn().mockResolvedValue(ok({
          ocrText: 'Three pillars: coverage, calibration, cost',
          description: 'A slide titled "Three pillars" with three bullet points'
        }))
      }
    };
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
    const fakeAnthropic = {
      messages: {
        create: jest.fn().mockResolvedValue({
          content: [{ type: 'text', text: 'not-json' }],
          usage: { input_tokens: 1, output_tokens: 1 }
        })
      }
    };
    await expect(
      extractImage({ imageBuffer: Buffer.from('x'), mimeType: 'image/jpeg' }, { anthropic: fakeAnthropic })
    ).rejects.toThrow(/JSON/);
  });

  it('passes the image as a base64 image block', async () => {
    const fakeAnthropic = {
      messages: {
        create: jest.fn().mockResolvedValue(ok({ ocrText: '', description: '' }))
      }
    };
    const buf = Buffer.from('abc');
    await extractImage({ imageBuffer: buf, mimeType: 'image/jpeg' }, { anthropic: fakeAnthropic });
    const call = fakeAnthropic.messages.create.mock.calls[0][0];
    const block = call.messages[0].content.find(c => c.type === 'image');
    expect(block.source.type).toBe('base64');
    expect(block.source.media_type).toBe('image/jpeg');
    expect(block.source.data).toBe(buf.toString('base64'));
  });
});
