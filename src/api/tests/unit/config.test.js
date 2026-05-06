import { describe, it, expect, jest } from '@jest/globals';
import { loadConfig } from '../../src/config/index.js';

describe('CORS configuration validation', () => {
  it('rejects "*" when NODE_ENV is production', () => {
    const exit = jest.spyOn(process, 'exit').mockImplementation(() => { throw new Error('exit'); });
    expect(() => loadConfig({ NODE_ENV: 'production', CORS_ORIGIN: '*', DEEPGRAM_API_KEY: 'k', ANTHROPIC_API_KEY: 'test-anthropic-key' })).toThrow();
    expect(exit).toHaveBeenCalledWith(1);
    exit.mockRestore();
  });

  it('rejects missing CORS_ORIGIN when NODE_ENV is production', () => {
    const exit = jest.spyOn(process, 'exit').mockImplementation(() => { throw new Error('exit'); });
    expect(() => loadConfig({ NODE_ENV: 'production', DEEPGRAM_API_KEY: 'k', ANTHROPIC_API_KEY: 'test-anthropic-key' })).toThrow();
    expect(exit).toHaveBeenCalledWith(1);
    exit.mockRestore();
  });

  it('accepts a specific origin in production', () => {
    const cfg = loadConfig({ NODE_ENV: 'production', CORS_ORIGIN: 'https://muesli.app', DEEPGRAM_API_KEY: 'k', ANTHROPIC_API_KEY: 'test-anthropic-key' });
    expect(cfg.security.corsOrigin).toEqual(['https://muesli.app']);
  });

  it('defaults to localhost in development', () => {
    const cfg = loadConfig({ NODE_ENV: 'development', DEEPGRAM_API_KEY: 'k', ANTHROPIC_API_KEY: 'test-anthropic-key' });
    expect(cfg.security.corsOrigin).toEqual(['http://localhost:3000']);
  });

  it('parses comma-separated origins', () => {
    const cfg = loadConfig({ NODE_ENV: 'development', CORS_ORIGIN: 'https://a.example,https://b.example', DEEPGRAM_API_KEY: 'k', ANTHROPIC_API_KEY: 'test-anthropic-key' });
    expect(cfg.security.corsOrigin).toEqual(['https://a.example', 'https://b.example']);
  });
});
