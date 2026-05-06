import { createHash, randomBytes } from 'crypto';
import { query, tx } from '../db/index.js';
import { config } from '../config/index.js';

function hash(token) {
  return createHash('sha256').update(token).digest('hex');
}

export function generateOpaqueToken() {
  return randomBytes(32).toString('base64url');
}

export async function create(userId) {
  const token = generateOpaqueToken();
  const expiresAt = new Date(Date.now() + config.auth.refreshTokenTtlDays * 86400 * 1000);
  const r = await query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3) RETURNING id`,
    [userId, hash(token), expiresAt]
  );
  return { token, id: r.rows[0].id, expiresAt };
}

export async function findByToken(token) {
  const r = await query(
    `SELECT id, user_id, expires_at, rotated_to, revoked_at FROM refresh_tokens WHERE token_hash = $1`,
    [hash(token)]
  );
  return r.rows[0] ?? null;
}

/**
 * Rotate a refresh token. If the supplied token has already been rotated or
 * revoked, treat as reuse: revoke the entire chain and return null.
 */
export async function rotate(token) {
  const existing = await findByToken(token);
  if (!existing) return null;
  if (existing.revoked_at || existing.rotated_to) {
    await revokeChain(existing.user_id);
    return null;
  }
  if (new Date(existing.expires_at) < new Date()) return null;

  return tx(async (client) => {
    const fresh = generateOpaqueToken();
    const expiresAt = new Date(Date.now() + config.auth.refreshTokenTtlDays * 86400 * 1000);
    const ins = await client.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3) RETURNING id`,
      [existing.user_id, hash(fresh), expiresAt]
    );
    await client.query(
      `UPDATE refresh_tokens SET rotated_to = $1 WHERE id = $2`,
      [ins.rows[0].id, existing.id]
    );
    return { token: fresh, userId: existing.user_id, expiresAt };
  });
}

export async function revokeChain(userId) {
  await query(`UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL`, [userId]);
}

export async function revoke(token) {
  const existing = await findByToken(token);
  if (!existing) return;
  await query(`UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1`, [existing.id]);
}
