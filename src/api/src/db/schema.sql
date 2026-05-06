-- Initial schema: users, refresh_tokens, credit_balances, ledger_entries
-- Lives in src/db/schema.sql so it can be applied identically against pg-mem
-- (in tests) and real Postgres (via applySchema or a migration tool).

CREATE TABLE IF NOT EXISTS users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  google_sub      TEXT UNIQUE NOT NULL,
  email           TEXT NOT NULL,
  full_name       TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS users_google_sub_idx ON users(google_sub);

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash      TEXT NOT NULL,
  issued_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at      TIMESTAMPTZ NOT NULL,
  rotated_to      UUID REFERENCES refresh_tokens(id),
  revoked_at      TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS refresh_tokens_user_idx ON refresh_tokens(user_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS refresh_tokens_hash_idx ON refresh_tokens(token_hash);

CREATE TABLE IF NOT EXISTS credit_balances (
  user_id         UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  micros_balance  BIGINT NOT NULL DEFAULT 0,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ledger_entries (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  micros_delta    BIGINT NOT NULL,
  reason          TEXT NOT NULL,
  session_id      UUID,
  idempotency_key TEXT NOT NULL,
  metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS ledger_entries_user_created_idx ON ledger_entries(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ledger_entries_session_idx ON ledger_entries(session_id) WHERE session_id IS NOT NULL;
