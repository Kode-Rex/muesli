/**
 * Haiku image extraction service
 * Sends a single image to Claude Haiku and returns structured OCR + description.
 */

import { anthropic, HAIKU_MODEL } from './anthropic.js';

const SYSTEM = `You extract structured information from a single image (typically a conference slide).
Return strict JSON only with two fields:
- ocrText: every readable word on the slide concatenated naturally; "" if non-text content
- description: one or two sentences describing what the image shows; "" if it's purely text
No commentary, no markdown, just JSON.`;

const USER = `Extract the slide content. Output JSON: { "ocrText": "...", "description": "..." }`;

/**
 * Extract OCR text and description from an image buffer.
 *
 * @param {{ imageBuffer: Buffer, mimeType: string }} input
 * @param {{ anthropic?: object }} deps - optional dependency overrides for testing
 * @returns {Promise<{ ocrText: string, description: string, tokensIn: number, tokensOut: number }>}
 */
export async function extractImage({ imageBuffer, mimeType }, deps = {}) {
  const client = deps.anthropic ?? anthropic;

  const response = await client.messages.create({
    model: HAIKU_MODEL,
    max_tokens: 800,
    system: SYSTEM,
    messages: [{
      role: 'user',
      content: [
        {
          type: 'image',
          source: {
            type: 'base64',
            media_type: mimeType,
            data: imageBuffer.toString('base64')
          }
        },
        { type: 'text', text: USER }
      ]
    }]
  });

  const raw = response.content?.[0]?.text;
  if (!raw) throw new Error('Empty response from Haiku');

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(`Haiku returned invalid JSON: ${raw.slice(0, 200)}`);
  }

  return {
    ocrText: parsed.ocrText ?? '',
    description: parsed.description ?? '',
    tokensIn: response.usage?.input_tokens ?? 0,
    tokensOut: response.usage?.output_tokens ?? 0,
  };
}
