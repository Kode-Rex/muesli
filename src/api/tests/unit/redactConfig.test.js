import { describe, it, expect } from '@jest/globals';
import { redactConfig } from '../../src/utils/redactConfig.js';

describe('redactConfig', () => {
  it('redacts top-level keys matching apiKey', () => {
    const out = redactConfig({ apiKey: 'sk-secret', model: 'nova-3' });
    expect(out).toEqual({ apiKey: '[REDACTED]', model: 'nova-3' });
  });

  it('redacts case-insensitive matches for key/secret/token/password', () => {
    const out = redactConfig({
      DEEPGRAM_KEY: 'a',
      jwtSecret: 'b',
      refresh_token: 'c',
      Password: 'd',
      bundleId: 'com.example'
    });
    expect(out).toEqual({
      DEEPGRAM_KEY: '[REDACTED]',
      jwtSecret: '[REDACTED]',
      refresh_token: '[REDACTED]',
      Password: '[REDACTED]',
      bundleId: 'com.example'
    });
  });

  it('redacts nested objects', () => {
    const out = redactConfig({ deepgram: { apiKey: 'x', model: 'nova-3' } });
    expect(out).toEqual({ deepgram: { apiKey: '[REDACTED]', model: 'nova-3' } });
  });

  it('handles arrays without crashing', () => {
    const out = redactConfig({ origins: ['a', 'b'], apiKey: 'x' });
    expect(out).toEqual({ origins: ['a', 'b'], apiKey: '[REDACTED]' });
  });

  it('returns non-objects unchanged', () => {
    expect(redactConfig('hello')).toEqual('hello');
    expect(redactConfig(42)).toEqual(42);
    expect(redactConfig(null)).toEqual(null);
    expect(redactConfig(undefined)).toEqual(undefined);
  });

  it('does not mutate the input', () => {
    const input = { apiKey: 'x', model: 'y' };
    const out = redactConfig(input);
    expect(input).toEqual({ apiKey: 'x', model: 'y' });
    expect(out).not.toBe(input);
  });
});
