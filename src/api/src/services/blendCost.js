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
