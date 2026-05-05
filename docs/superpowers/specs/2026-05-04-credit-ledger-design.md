# Credit Ledger and Metering — Design

Date: 2026-05-04
Status: Draft (pending user review)

## Summary

Server-side credit ledger that records cost for every paid AI operation. Append-only transaction log + materialized balance per user. Atomic debits with idempotency. v1 ships with enforcement disabled (every account effectively has unlimited credits) but the meter runs and persists, so flipping enforcement on later is a config change, not a code change.

## Goals

1. Every API call that costs money records a ledger entry.
2. Balances are correct under concurrent debits and retries.
3. Idempotent: a client retrying the same blend never gets double-charged.
4. v1: no balance check before debit. Negative balances are allowed and recorded — they become useful telemetry for setting future credit pack sizes.
5. Flip to enforced via env flag without touching code paths.

## Non-goals

- Subscription billing (handled later if we add it; current spec is consumable-credit only)
- Refunds UI
- Per-user discount codes / promos (defer)
- Cross-currency support (USD only)
- Multi-tenant org accounts

## Architecture

### Schema (Postgres)

```sql
CREATE TABLE credit_balances (
  user_id         UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  micros_balance  BIGINT NOT NULL DEFAULT 0,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ledger_entries (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  micros_delta    BIGINT NOT NULL,         -- negative = debit, positive = credit
  reason          TEXT NOT NULL,           -- 'blend' | 'iap_topup' | 'grant' | 'refund' | 'adjustment'
  session_id      UUID,                    -- nullable; populated for blend debits
  idempotency_key TEXT NOT NULL,           -- unique per (user_id, reason, ...) to dedupe retries
  metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,  -- audit trail: model, tokens, seconds, etc.
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
);

CREATE INDEX ledger_entries_user_created_idx ON ledger_entries(user_id, created_at DESC);
CREATE INDEX ledger_entries_session_idx ON ledger_entries(session_id) WHERE session_id IS NOT NULL;
```

### Units

The internal unit is **micros of USD** (one millionth of a dollar). All cost computations stay in micros to avoid floating-point math. UI converts micros to "credits" for display only.

Display rule: `1 credit = 200,000 micros = $0.20` (matches the AI pipeline spec's per-session estimate). Pure UI mapping; can change without ledger migration.

### Cost computation (server-side, after each AI op)

```js
function blendCostMicros({ deepgramSeconds, imageCount, sonnetInputTokens, sonnetOutputTokens }) {
  const deepgram = Math.ceil(deepgramSeconds * 71.7);
  const haiku    = imageCount * 5_000;
  const sonnet   = Math.ceil((sonnetInputTokens * 3 + sonnetOutputTokens * 15) / 1_000);
  return deepgram + haiku + sonnet;
}
```

Rates live in `src/api/src/config/pricing.js` and are versioned (`PRICING_VERSION`). Changing rates requires bumping the version, which gets recorded in `metadata.pricingVersion` on every entry. Old entries remain valid history.

### Debit flow

The blend endpoint orchestrates:

```
POST /v1/sessions/:id/blend
  ├─ run pipeline (Deepgram → Haiku × N → Sonnet)
  ├─ collect actuals: seconds, image count, token counts
  ├─ compute cost = blendCostMicros(actuals)
  ├─ within a single Postgres transaction:
  │     INSERT INTO ledger_entries (..., -cost, ..., idempotency_key)
  │       ON CONFLICT (user_id, idempotency_key) DO NOTHING
  │     UPDATE credit_balances SET micros_balance = micros_balance - cost
  │       WHERE user_id = $1
  │     (if balance row missing, INSERT it with -cost)
  ├─ return blend result + cost
```

Transaction isolation: `READ COMMITTED` is sufficient. The `UPDATE ... SET balance = balance - cost` is atomic per row, and the unique `(user_id, idempotency_key)` constraint dedupes concurrent retries.

If the conflict path triggers (entry already existed), we do **not** decrement the balance again — the original transaction already did. We return the earlier result if cached, or a 200 with the existing ledger entry id.

### Idempotency

`idempotency_key` is supplied by the client and must be deterministic per logical operation:

- For a fresh blend: `blend:{sessionId}:{contentHash}` where `contentHash` covers (audio file hash, photo hashes, user notes hash, prompt version)
- For a regenerate: same scheme; if any input changed, the hash changes, so it's a new key (and gets charged)
- For an IAP top-up: `iap:{appleTransactionId}` (handled in the StoreKit spec)

If the client retries and the inputs haven't changed, the idempotency key matches and the debit is skipped. If inputs changed, it's a new operation and gets charged.

### Pre-debit check (when enforcement is on)

```js
async function checkBalance(userId, requiredMicros) {
  if (!config.credits.enforced) return { ok: true };
  const { micros_balance } = await db.one('SELECT micros_balance FROM credit_balances WHERE user_id = $1', [userId]);
  return micros_balance >= requiredMicros
    ? { ok: true }
    : { ok: false, available: micros_balance, required: requiredMicros };
}
```

The blend endpoint **estimates** cost before running the pipeline (using session length cap + image count) and rejects with `402 insufficient_credits` if the estimate exceeds available balance. After the pipeline runs, the actual cost is recorded — which may differ slightly from the estimate. The estimate is a guard, not the source of truth.

v1: `config.credits.enforced = false`. Always returns `{ ok: true }` regardless of balance.

### Routes

| Method | Path | Auth | Purpose |
|---|---|---|---|
| GET | `/v1/account/balance` | required | Returns `{ creditsAvailable: Int, microsBalance: Int, enforced: Bool }`. With enforcement off, `creditsAvailable = Int.MAX_SAFE_INTEGER`. |
| GET | `/v1/account/ledger?limit=50&before=...` | required | Paginated history of ledger entries for the user. |
| POST | `/v1/account/grant` | admin only | Grant credits (positive delta). For dev, support, manual top-ups. |

The blend endpoint (`POST /v1/sessions/:id/blend` from the AI pipeline spec) gains the cost-recording step; no new dedicated debit endpoint.

### Concurrency

Two threats:

1. **Same client retries** — handled by idempotency key.
2. **Two parallel blends from the same user** — each is a separate logical operation with a different idempotency key. Both debit. Postgres row-level lock on the balance row serializes the updates; no double-spend. With enforcement on, both could succeed even if total cost exceeds balance — the user goes negative for that brief window. Acceptable for v1.

### Audit and observability

Every ledger entry stores in `metadata`:

```json
{
  "pricingVersion": 1,
  "blendDetails": {
    "deepgramSeconds": 2700,
    "imageCount": 5,
    "sonnetModel": "claude-sonnet-4-6",
    "haikuModel": "claude-haiku-4-5-20251001",
    "sonnetInputTokens": 8123,
    "sonnetOutputTokens": 1942
  },
  "estimatedMicros": 198000,
  "actualMicros": 203740
}
```

This makes pricing tuning, customer support, and revenue forecasting tractable later.

Logs: every debit emits a structured Winston log (no secrets). Sample 100% in dev, 10% in prod (cost-controlled).

### iOS integration

- `APIClient` exposes a `balance: BalanceState` observable, refreshed on app foreground and after every blend.
- A debug-only "Credits" screen shows: balance, last 20 entries, the last blend's cost breakdown.
- v1 user-facing UI: small badge in the corner of the recording screen showing "estimated cost: ~1 credit" before recording starts. No hard cap, but the meter is visible.

### Environment variables

```
CREDITS_ENFORCED=false              # v1 default; flip to true to gate operations
PRICING_VERSION=1
DEEPGRAM_MICROS_PER_SEC=71.7
HAIKU_MICROS_PER_IMAGE=5000
SONNET_INPUT_MICROS_PER_KTOKEN=3000
SONNET_OUTPUT_MICROS_PER_KTOKEN=15000
NEW_USER_GRANT_MICROS=1000000       # 5 free credits ($1.00) on signup; 0 to disable
```

On user signup, if `NEW_USER_GRANT_MICROS > 0`, insert a `grant` ledger entry within the same transaction that creates the user.

## Failure modes

| Failure | Behavior |
|---|---|
| Pipeline succeeds, ledger insert fails | Log loud error, return 500. Operation succeeded but billing didn't — accept the loss in v1 (very rare; instrument an alert). v2 may add an outbox/retry queue. |
| Pipeline fails midway (e.g. Sonnet errors) | Record only the costs of stages that completed. Deepgram + Haiku get charged; Sonnet does not. |
| Idempotency key collision with different inputs | Treat as a programming error; log warn, fail closed (return 409). Never silently merge. |
| Balance row missing | First-debit-wins inserts it; subsequent debits update. Use `INSERT ... ON CONFLICT (user_id) DO UPDATE SET micros_balance = credit_balances.micros_balance - EXCLUDED.micros_balance` |
| Negative balance with enforcement on | Should never happen due to pre-check, but if it does (race), log and continue; user can't start new ops until topped up |

## Migration / sequencing

1. Add migration for `credit_balances` and `ledger_entries`.
2. Implement `LedgerService` with `recordBlend`, `recordIAP`, `getBalance`, `listEntries`.
3. Wire `LedgerService.recordBlend` into the AI pipeline blend endpoint.
4. Add `/v1/account/balance` and `/v1/account/ledger` routes.
5. Ship with `CREDITS_ENFORCED=false`.
6. Build the StoreKit IAP spec on top.
7. After IAP lands and is tested, flip `CREDITS_ENFORCED=true` in production.

## Acceptance criteria

- Run a blend → ledger entry inserted with correct `micros_delta` matching the cost formula → balance decreases.
- Retry the same blend (same idempotency key) → no second debit; original entry returned.
- Run two parallel blends → two distinct entries, balance decremented by both, no race-induced overcharge.
- With `CREDITS_ENFORCED=true` and balance below estimate → blend rejected with 402 before any AI calls fire.
- New user signup with `NEW_USER_GRANT_MICROS=1000000` → balance starts at 1,000,000 micros + a `grant` ledger entry exists.
- `npm test` covers: cost computation, idempotency dedup, atomic debit, balance enforcement on/off, parallel debit isolation.

## Open questions

- (resolved) Display unit: 1 credit = $0.20 = 200,000 micros
- (resolved) Enforcement default: off in v1
- (resolved) New-user grant: 5 credits
- Whether to expose ledger history in user-facing UI v1 → recommend debug-only for v1, polish for v2
- Whether parallel-blend overdraft is acceptable → yes for v1; revisit if we see abuse
