import { createHash } from 'crypto';

export function contentHash(input) {
  const buf = Buffer.isBuffer(input) ? input : Buffer.from(input, 'utf8');
  return createHash('sha256').update(buf).digest('hex');
}
