/**
 * Returns a deep clone of the input with values whose keys match common
 * secret patterns (key, secret, token, password) replaced with '[REDACTED]'.
 * Used as a defensive logging helper so future code can't accidentally
 * leak credentials through structured logs.
 */

const SECRET_PATTERN = /key|secret|token|password/i;

export function redactConfig(value) {
  if (value === null || value === undefined) return value;
  if (typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.map(redactConfig);

  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (SECRET_PATTERN.test(k)) {
      out[k] = '[REDACTED]';
    } else {
      out[k] = redactConfig(v);
    }
  }
  return out;
}

export default redactConfig;
