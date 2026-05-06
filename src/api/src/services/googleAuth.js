import { OAuth2Client } from 'google-auth-library';
import { config } from '../config/index.js';

let _client = null;

export function getClient() {
  if (!_client) _client = new OAuth2Client(config.auth.googleClientId);
  return _client;
}

export function setClient(c) { _client = c; }

/**
 * Verify a Google ID token. Returns { sub, email, emailVerified, name }.
 * Throws on signature/aud/iss/exp failure or unverified email.
 */
export async function verifyIdToken(idToken, deps = {}) {
  const client = deps.client ?? getClient();
  const ticket = await client.verifyIdToken({ idToken, audience: config.auth.googleClientId });
  const payload = ticket.getPayload();
  if (!payload) throw new Error('invalid_id_token');
  if (payload.email_verified !== true) {
    const e = new Error('unverified_email');
    e.code = 'unverified_email';
    throw e;
  }
  return {
    sub: payload.sub,
    email: payload.email,
    emailVerified: payload.email_verified,
    name: payload.name,
  };
}
