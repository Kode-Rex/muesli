# Auth and Account Model — Design

Date: 2026-05-04
Status: Approved (Google rewrite, 2026-05-06)

## Summary

Sign in with Google on iOS, server-issued session JWT, Express middleware on `/v1/*`. Adds the first persistent backend store (Postgres) since the API is stateless today. Account record is the foundation for the credit ledger and StoreKit specs that follow.

Originally drafted for Sign in with Apple; switched to Google to ease testing on Android-friendly infra and to avoid the per-request signed-client-secret dance Apple's revoke API requires.

## Goals

1. Single sign-in path: Google. No email/password, no Apple, no magic links in v1.
2. Stateless session: short-lived access JWT + refresh token rotation.
3. Drop into existing Express stack as middleware on `/v1/*`. Routes don't change shape.
4. Stand up Postgres so the credit ledger and IAP specs have a place to land.

## Non-goals

- Multi-provider auth (Apple, GitHub, email)
- Multi-device account linking beyond what Google account gives natively
- Team / org accounts
- 2FA (Google provides this upstream)
- Web sign-in (no web app yet — but Google ID tokens make this trivial to add later)

## Architecture

### Sign-in flow

```
iOS                                Backend                          Google
 │                                                                   │
 │── GIDSignIn.sharedInstance.signIn(...) ──────────────────────────▶│
 │◀─── idToken (JWT, signed by Google) + accessToken ──────────────│
 │                                                                   │
 │── POST /v1/auth/google { idToken } ──▶ Backend
 │                                          │
 │                                          ├─ verify idToken against Google's JWKS
 │                                          ├─ check aud == GOOGLE_CLIENT_ID
 │                                          ├─ check iss in {accounts.google.com, https://accounts.google.com}
 │                                          ├─ check exp not expired
 │                                          ├─ extract sub (Google user id), email, email_verified, name
 │                                          ├─ upsert User by google_sub
 │                                          ├─ mint accessJWT (15min) + refreshToken (30d, opaque, stored hashed)
 │◀──────────── { accessToken, refreshToken, user } ────────────────│
 │                                                                   │
 │── subsequent requests: Authorization: Bearer <accessJWT> ──▶ Backend (auth middleware verifies)
 │                                                                   │
 │── POST /v1/auth/refresh { refreshToken } ──▶ Backend (rotates refresh, returns new pair)
```

Google's `idToken` is a JWT signed by Google. We verify it via `google-auth-library`'s `OAuth2Client.verifyIdToken({ idToken, audience: GOOGLE_CLIENT_ID })`, which handles JWKS fetching, caching, and signature/claim verification in one call.

`email`, `email_verified`, and `name` come from the verified payload. We require `email_verified === true` to upsert; reject otherwise with `401 unverified_email`.

### Account model (Postgres)

```sql
CREATE TABLE users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  google_sub      TEXT UNIQUE NOT NULL,
  email           TEXT NOT NULL,
  full_name       TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX users_google_sub_idx ON users(google_sub);

CREATE TABLE refresh_tokens (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash      TEXT NOT NULL,           -- sha256 of the opaque token
  issued_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at      TIMESTAMPTZ NOT NULL,
  rotated_to      UUID REFERENCES refresh_tokens(id),  -- chain on rotation; NULL = active leaf
  revoked_at      TIMESTAMPTZ
);

CREATE INDEX refresh_tokens_user_idx ON refresh_tokens(user_id) WHERE revoked_at IS NULL;
CREATE INDEX refresh_tokens_hash_idx ON refresh_tokens(token_hash);
```

Refresh tokens are opaque (32 random bytes, base64url). Stored hashed (sha256). Rotation: on use, mark old as `rotated_to = newId`, issue new pair. Reuse of a rotated/revoked token is suspicious — revoke the entire chain (all descendants and ancestors of that token) and force re-sign-in.

### Access JWT shape

```json
{
  "sub": "<users.id UUID>",
  "iss": "muesli-api",
  "aud": "muesli-ios",
  "iat": 1714800000,
  "exp": 1714800900,
  "jti": "<random uuid for revocation if needed>"
}
```

Signed with HS256 using `JWT_SECRET` from env. Rotate secret = invalidate all access tokens (acceptable; refresh tokens unaffected, clients will refresh on first 401).

### Routes

| Method | Path | Auth | Body | Response |
|---|---|---|---|---|
| POST | `/v1/auth/google` | none | `{ idToken }` | `{ accessToken, refreshToken, user }` |
| POST | `/v1/auth/refresh` | none | `{ refreshToken }` | `{ accessToken, refreshToken }` |
| POST | `/v1/auth/logout` | required | `{ refreshToken? }` | `204` (revokes refresh) |
| GET | `/v1/auth/me` | required | — | `{ user }` |
| DELETE | `/v1/account` | required | — | `204` (cascade-delete user, sessions, ledger entries) |

Existing `/v1/sessions/*` and `/v1/account/balance` routes (from AI pipeline + ledger specs) get the auth middleware applied once `AUTH_ENABLED=true`.

### Middleware

```js
// src/api/src/middleware/auth.js
export function requireAuth(req, res, next) {
  if (!config.auth.enabled) {
    // Dev convenience: when auth is off, fix userId to a stable dev sub so the
    // pipeline + ledger keep working end-to-end without sign-in.
    req.userId = config.auth.devUserId; // 'local-dev'
    return next();
  }
  const token = extractBearer(req);
  if (!token) return res.status(401).json({ error: 'missing_token' });
  try {
    const payload = jwt.verify(token, config.auth.jwtSecret, { audience: 'muesli-ios', issuer: 'muesli-api' });
    req.userId = payload.sub;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'invalid_token' });
  }
}
```

Mount on the `/v1` router after public auth routes:

```js
app.use('/v1/auth', authRouter);                 // public
app.use('/v1', requireAuth, protectedRouter);    // requires bearer when AUTH_ENABLED
```

### iOS integration

- **Google Sign-In SDK** (`GoogleSignIn` Swift Package). On first launch, present `GIDSignIn.sharedInstance.signIn(withPresenting:)`; on success, take the `idToken` from `result.user.idToken.tokenString` and `POST /v1/auth/google`.
- Tokens stored in **Keychain** (`kSecClassGenericPassword`, accessible after first unlock).
- An `APIClient` wraps URLSession, injects `Authorization` header, and auto-refreshes on 401: pause request → call `/v1/auth/refresh` → retry once. On refresh failure (e.g. revoked), bubble to a sign-in-required state.
- Sign out: revoke refresh token via `/v1/auth/logout`, clear Keychain, return to sign-in screen.

### Tech choices

- **Postgres** over SQLite: production backend; SQLite buys nothing for a server process and complicates deployment if we go multi-instance.
- **`pg`** node driver (no Prisma/ORM in v1 — schema is small, raw SQL in a thin repository layer is fine).
- **`google-auth-library`** for ID token verification (handles JWKS fetching/caching).
- **`jsonwebtoken`** for our own access-JWT signing/verification.
- Migrations: **`node-pg-migrate`**. Up/down per migration, checked into the repo under `src/api/migrations/`.
- Tests: **`pg-mem`** for unit/integration tests so CI doesn't need a real Postgres.

### Environment variables

```
DATABASE_URL=postgres://...
JWT_SECRET=...                       # 32+ random bytes
GOOGLE_CLIENT_ID=...apps.googleusercontent.com   # iOS client id from Google Cloud Console
ACCESS_TOKEN_TTL_MIN=15
REFRESH_TOKEN_TTL_DAYS=30
AUTH_ENABLED=false                   # v1 default; flip true after iOS sign-in lands
DEV_USER_ID=local-dev                # used when AUTH_ENABLED=false
```

Google account deletion: when the user calls `DELETE /v1/account`, we cascade-delete their rows. We don't notify Google; the user can revoke our app's Google access from their Google Account → Security → Third-party apps page.

## Failure modes

| Failure | Behavior |
|---|---|
| Google JWKS unreachable | `google-auth-library` caches keys; if cache stale we return 503 with retry-after |
| Invalid `idToken` (signature, aud, iss, exp) | 401 `invalid_id_token` |
| `email_verified === false` | 401 `unverified_email` |
| Postgres unreachable on sign-in | 503 retry; client backs off |
| Refresh token reuse detected | Revoke entire chain for that user, return 401 `token_reuse`, force re-sign-in |
| JWT secret rotation | All access tokens become invalid → clients refresh transparently |
| Clock skew on Google JWT | Allow 60s leeway in `exp` check |

## Migration / sequencing

1. Stand up Postgres in dev (`docker-compose.yml`) and prod (managed instance, e.g. Cloud SQL).
2. Run initial migration: `users`, `refresh_tokens` (alongside ledger tables in the same migration — see credit-ledger spec).
3. Add auth routes + middleware behind `AUTH_ENABLED=false`.
4. Update iOS client with Google sign-in flow, gated by a build flag so existing local-dev paths continue to work.
5. Flip `AUTH_ENABLED=true`. The `userId="local-dev"` placeholder from the AI pipeline spec gets replaced by `req.userId` from middleware (which now reads `payload.sub`).
6. Credit ledger spec lands on top of this.

## Acceptance criteria

- Cold install → sign in with Google → land in app with a valid session.
- Force-quit → relaunch → still signed in (Keychain restore).
- Let access token expire (15 min) → next API call transparently refreshes and succeeds.
- Sign out → relaunch → sign-in screen again.
- Delete account → user row gone, refresh tokens revoked, all related rows cascaded.
- Backend rejects expired/forged JWTs with 401 and a clear error code.
- `npm test` covers: Google ID token verification (valid, expired, wrong audience, wrong issuer, bad signature, unverified email), refresh rotation, refresh reuse detection, account deletion cascade.

## Open questions

- (resolved) Postgres vs SQLite → Postgres
- (resolved) ORM vs raw SQL → raw SQL with a small repository layer
- (resolved) Provider: Google
- (resolved) Token storage format on iOS — Keychain
- Web sign-in — adding it later is one route handler away (Google ID tokens are issued by the same flow on web). Defer.
