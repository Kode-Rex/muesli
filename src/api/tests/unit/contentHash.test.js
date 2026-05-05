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
