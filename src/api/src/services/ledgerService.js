import { query, tx } from '../db/index.js';
import { config } from '../config/index.js';
import { contentHash } from './contentHash.js';

/**
 * Compute the idempotency key for a blend.
 * blend:{sessionId}:{contentHash(audio + photoHashes + userNotes + pricingVersion)}
 */
export function blendIdempotencyKey({ sessionId, audioHash, photoHashes, userNotes }) {
  const photos = [...(photoHashes ?? [])].sort().join(',');
  const fingerprint = `${audioHash}|${photos}|${userNotes ?? ''}|v${config.credits.pricingVersion}`;
  return `blend:${sessionId}:${contentHash(fingerprint)}`;
}

/**
 * Record a blend cost as a single atomic transaction: insert ledger entry
 * (idempotent on retry), update balance.
 *
 * Returns { entryId, microsDelta, microsBalance, alreadyRecorded }.
 */
export async function recordBlend({ userId, sessionId, microsCost, idempotencyKey, metadata }) {
  if (microsCost <= 0) throw new Error('microsCost must be positive');
  return tx(async (client) => {
    // Replay-safety: explicit existence check inside the tx (works on pg-mem
    // and real Postgres). Real Postgres alternative is ON CONFLICT DO NOTHING
    // RETURNING id and inspecting rows.length, but pg-mem doesn't model that
    // edge identically.
    const replay = await client.query(
      `SELECT id FROM ledger_entries WHERE user_id = $1 AND idempotency_key = $2`,
      [userId, idempotencyKey]
    );
    if (replay.rows.length > 0) {
      const bal = await client.query(`SELECT micros_balance FROM credit_balances WHERE user_id = $1`, [userId]);
      return { entryId: replay.rows[0].id, microsDelta: -microsCost, microsBalance: Number(bal.rows[0]?.micros_balance ?? 0), alreadyRecorded: true };
    }

    const ins = await client.query(
      `INSERT INTO ledger_entries (user_id, micros_delta, reason, session_id, idempotency_key, metadata)
       VALUES ($1, $2, 'blend', $3, $4, $5)
       RETURNING id`,
      [userId, -microsCost, sessionId, idempotencyKey, JSON.stringify(metadata ?? {})]
    );

    const upd = await client.query(
      `INSERT INTO credit_balances (user_id, micros_balance) VALUES ($1, $2)
       ON CONFLICT (user_id) DO UPDATE
         SET micros_balance = credit_balances.micros_balance + EXCLUDED.micros_balance,
             updated_at = now()
       RETURNING micros_balance`,
      [userId, -microsCost]
    );
    return { entryId: ins.rows[0].id, microsDelta: -microsCost, microsBalance: Number(upd.rows[0].micros_balance), alreadyRecorded: false };
  });
}

export async function getBalance(userId) {
  const r = await query(`SELECT micros_balance FROM credit_balances WHERE user_id = $1`, [userId]);
  return Number(r.rows[0]?.micros_balance ?? 0);
}

export async function listEntries(userId, { limit = 50 } = {}) {
  const r = await query(
    `SELECT id, micros_delta, reason, session_id, idempotency_key, metadata, created_at
     FROM ledger_entries WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`,
    [userId, limit]
  );
  return r.rows;
}

/**
 * Pre-debit guard. With CREDITS_ENFORCED=false (v1) always returns ok.
 */
export async function checkBalance(userId, requiredMicros) {
  if (!config.credits.enforced) return { ok: true };
  const bal = await getBalance(userId);
  return bal >= requiredMicros ? { ok: true } : { ok: false, available: bal, required: requiredMicros };
}
