import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';

describe('CORS configuration validation', () => {
  const ORIGINAL_ENV = { ...process.env };

  beforeEach(() => {
    jest.resetModules();
  });

  afterEach(() => {
    process.env = { ...ORIGINAL_ENV };
  });

  async function loadConfig(envOverrides) {
    process.env = { ...ORIGINAL_ENV, ...envOverrides, DEEPGRAM_API_KEY: 'test-key' };
    return import('../../src/config/index.js');
  }

  it('rejects "*" when NODE_ENV is production', async () => {
    const exit = jest.spyOn(process, 'exit').mockImplementation(() => { throw new Error('exit'); });
    await expect(loadConfig({ NODE_ENV: 'production', CORS_ORIGIN: '*' })).rejects.toThrow();
    expect(exit).toHaveBeenCalledWith(1);
    exit.mockRestore();
  });

  it('rejects missing CORS_ORIGIN when NODE_ENV is production', async () => {
    const exit = jest.spyOn(process, 'exit').mockImplementation(() => { throw new Error('exit'); });
    await expect(loadConfig({ NODE_ENV: 'production', CORS_ORIGIN: undefined })).rejects.toThrow();
    expect(exit).toHaveBeenCalledWith(1);
    exit.mockRestore();
  });

  it('accepts a specific origin in production', async () => {
    const { config } = await loadConfig({ NODE_ENV: 'production', CORS_ORIGIN: 'https://muesli.app' });
    expect(config.security.corsOrigin).toEqual(['https://muesli.app']);
  });

  it('defaults to localhost in development', async () => {
    const { config } = await loadConfig({ NODE_ENV: 'development', CORS_ORIGIN: undefined });
    expect(config.security.corsOrigin).toEqual(['http://localhost:3000']);
  });

  it('parses comma-separated origins', async () => {
    const { config } = await loadConfig({ NODE_ENV: 'development', CORS_ORIGIN: 'https://a.example,https://b.example' });
    expect(config.security.corsOrigin).toEqual(['https://a.example', 'https://b.example']);
  });
});
