# Auth and Account Model — Design

Date: 2026-05-04
Status: Draft (pending user review)

## Summary

Sign in with Apple on iOS, server-issued session JWT, Express middleware on `/v1/*`. Adds the first persistent backend store (Postgres) since the API is stateless today. Account record is the foundation for the credit ledger and StoreKit specs that follow.

## Goals

1. Single sign-in path: Apple. No email/password, no Google, no magic links.
2. Stateless session: short-lived access JWT + refresh token rotation.
3. Drop into existing Express stack as middleware on `/v1/*`. Routes don't change shape.
4. Stand up Postgres so the credit ledger and IAP specs have a place to land.

## Non-goals

- Multi-provider auth (Google, GitHub, email)
- Multi-device account linking beyond what Apple ID gives natively
- Team / org accounts
- 2FA (Apple ID provides this upstream)
- Web sign-in (no web app)

## Architecture

### Sign-in flow

```
iOS                                Backend                          Apple
 │                                                                   │
 │── ASAuthorizationAppleIDRequest ─────────────────────────────────▶│
 │◀─── identityToken (JWT, signed by Apple) + authorizationCode ────│
 │                                                                   │
 │── POST /v1/auth/apple { identityToken, fullName?, email? } ──▶ Backend
 │                                          │
 │                                          ├─ verify token signature against Apple JWKS
 │                                          ├─ extract sub (Apple user id), email
 │                                          ├─ upsert User by appleSub
 │                                          ├─ mint accessJWT (15min) + refreshToken (30d, opaque, stored)
 │◀──────────── { accessToken, refreshToken, user } ────────────────│
 │                                                                   │
 │── subsequent requests: Authorization: Bearer <accessJWT> ──▶ Backend (auth middleware verifies)
 │                                                                   │
 │── POST /v1/auth/refresh { refreshToken } ──▶ Backend (rotates refresh, returns new pair)
```

Apple's `identityToken` is a JWT signed by Apple. We verify the signature against `https://appleid.apple.com/auth/keys` (cached, refreshed daily), check `aud` matches our app bundle id, check `iss == https://appleid.apple.com`, check `exp` not expired, then trust the `sub` claim as the Apple user id.

`fullName` and `email` are only sent by Apple on the first sign-in. Persist them on initial upsert; ignore them on subsequent sign-ins (they'll be empty).

### Account model (Postgres)

```sql
CREATE TABLE users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  apple_sub       TEXT UNIQUE NOT NULL,
  email           TEXT,
  full_name       TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX users_apple_sub_idx ON users(apple_sub);

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

Refresh tokens are opaque (32 random bytes, base64url). Stored hashed. Rotation: on use, mark old as `rotated_to` the new one's id, issue new pair. Reuse of a rotated token is suspicious — revoke the entire chain (all descendants and ancestors of that user).

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
| POST | `/v1/auth/apple` | none | `{ identityToken, fullName?, email? }` | `{ accessToken, refreshToken, user }` |
| POST | `/v1/auth/refresh` | none | `{ refreshToken }` | `{ accessToken, refreshToken }` |
| POST | `/v1/auth/logout` | required | `{ refreshToken? }` | `204` (revokes refresh) |
| GET | `/v1/auth/me` | required | — | `{ user }` |
| DELETE | `/v1/account` | required | — | `204` (cascade-delete user, sessions, ledger entries) |

Existing `/v1/sessions/*` and `/v1/account/balance` routes (from AI pipeline + ledger specs) get the auth middleware applied.

### Middleware

```js
// src/api/src/middleware/auth.js
export function requireAuth(req, res, next) {
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
app.use('/v1', requireAuth, protectedRouter);    // requires bearer
```

### iOS integration

- `SignInWithAppleButton` (SwiftUI) on first launch → on success, `POST /v1/auth/apple` with the identity token.
- Tokens stored in **Keychain** (`kSecClassGenericPassword`, accessible after first unlock).
- An `APIClient` wraps URLSession, injects `Authorization` header, and auto-refreshes on 401: pause request → call `/v1/auth/refresh` → retry once. On refresh failure (e.g. revoked), bubble to a sign-in-required state.
- Sign out: revoke refresh token via `/v1/auth/logout`, clear Keychain, return to sign-in screen.

### Tech choices

- **Postgres** over SQLite: this is the production backend; SQLite buys nothing for a server process and complicates deployment if we go multi-instance.
- **`pg`** node driver (no Prisma/ORM in v1 — schema is small, raw SQL in a thin repository layer is fine).
- **`jsonwebtoken`** for JWT signing/verification, **`jose`** for Apple JWKS verification (better fit for remote JWKS).
- Migrations: **`node-pg-migrate`**. Up/down per migration, checked into the repo under `src/api/migrations/`.

### Environment variables

```
DATABASE_URL=postgres://...
JWT_SECRET=...                  # 32+ random bytes
APPLE_BUNDLE_ID=com.hydraflow.muesli
APPLE_TEAM_ID=...               # for future use (Sign In with Apple revoke API)
APPLE_KEY_ID=...
APPLE_PRIVATE_KEY_PATH=...
ACCESS_TOKEN_TTL_MIN=15
REFRESH_TOKEN_TTL_DAYS=30
```

Apple revoke API requires a signed client secret per request — defer that integration; on `DELETE /v1/account` we mark the user deleted in our DB but don't notify Apple in v1 (acceptable; user revokes via Apple ID settings if they want).

## Failure modes

| Failure | Behavior |
|---|---|
| Apple JWKS unreachable | Cache last-known keys for 24h; if cache stale, return 503 with retry-after |
| Invalid `identityToken` (signature, aud, iss, exp) | 401 `invalid_apple_token` |
| Postgres unreachable on sign-in | 503 retry; client backs off |
| Refresh token reuse detected | Revoke entire chain for that user, return 401 `token_reuse`, force re-sign-in |
| JWT secret rotation | All access tokens become invalid → clients refresh transparently |
| Clock skew on Apple JWT | Allow 60s leeway in `exp` check |

## Migration / sequencing

1. Stand up Postgres in dev (`docker-compose.yml`) and prod (managed instance).
2. Run initial migration: `users`, `refresh_tokens`.
3. Add auth routes + middleware behind a feature flag (`AUTH_ENABLED=false` initially).
4. Update iOS client with sign-in flow, gated by a build flag so existing local-dev paths continue to work.
5. Flip `AUTH_ENABLED=true`. The `userId="local-dev"` placeholder from the AI pipeline spec gets replaced by `req.userId` from middleware.
6. Credit ledger spec lands on top of this.

## Acceptance criteria

- Cold install → sign in with Apple → land in app with a valid session.
- Force-quit → relaunch → still signed in (Keychain restore).
- Let access token expire (15 min) → next API call transparently refreshes and succeeds.
- Sign out → relaunch → sign-in screen again.
- Delete account → user row gone, refresh tokens revoked, all related rows cascaded.
- Backend rejects expired/forged JWTs with 401 and a clear error code.
- `npm test` covers: token verification (valid, expired, wrong audience, wrong issuer, bad signature), refresh rotation, refresh reuse detection, account deletion cascade.

## Open questions

- (resolved) Postgres vs SQLite → Postgres
- (resolved) ORM vs raw SQL → raw SQL with a small repository layer
- Apple revoke API — defer to v2; document the gap
- Token storage format on iOS — Keychain (decided)
