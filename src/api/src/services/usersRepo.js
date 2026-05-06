import { query, tx } from '../db/index.js';
import { config } from '../config/index.js';

export async function upsertByGoogleSub({ googleSub, email, fullName }) {
  // The credit ledger spec wants new-user grants inserted in the same tx
  // as the user row, so the "did this user just sign up" check has to be
  // tx-local. We use INSERT ... ON CONFLICT and detect insertion via xmax.
  return tx(async (client) => {
    const existing = await client.query(`SELECT id FROM users WHERE google_sub = $1`, [googleSub]);
    const justInserted = existing.rows.length === 0;

    const ins = await client.query(
      `INSERT INTO users (google_sub, email, full_name)
       VALUES ($1, $2, $3)
       ON CONFLICT (google_sub) DO UPDATE
         SET email = EXCLUDED.email,
             full_name = COALESCE(EXCLUDED.full_name, users.full_name),
             updated_at = now()
       RETURNING id, google_sub, email, full_name, created_at`,
      [googleSub, email, fullName ?? null]
    );
    const row = { ...ins.rows[0], just_inserted: justInserted };
    if (row.just_inserted && config.credits.newUserGrantMicros > 0) {
      await client.query(
        `INSERT INTO credit_balances (user_id, micros_balance) VALUES ($1, $2)
         ON CONFLICT (user_id) DO NOTHING`,
        [row.id, config.credits.newUserGrantMicros]
      );
      await client.query(
        `INSERT INTO ledger_entries (user_id, micros_delta, reason, idempotency_key, metadata)
         VALUES ($1, $2, 'grant', $3, $4)`,
        [row.id, config.credits.newUserGrantMicros, `signup:${row.id}`, JSON.stringify({ source: 'signup_grant' })]
      );
    }
    return {
      id: row.id,
      googleSub: row.google_sub,
      email: row.email,
      fullName: row.full_name,
      createdAt: row.created_at,
      justInserted: row.just_inserted,
    };
  });
}

export async function findById(id) {
  const r = await query(`SELECT id, google_sub, email, full_name, created_at FROM users WHERE id = $1`, [id]);
  if (r.rows.length === 0) return null;
  const row = r.rows[0];
  return { id: row.id, googleSub: row.google_sub, email: row.email, fullName: row.full_name, createdAt: row.created_at };
}

export async function deleteUser(id) {
  await query(`DELETE FROM users WHERE id = $1`, [id]);
}
