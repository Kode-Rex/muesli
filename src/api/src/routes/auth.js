import express from 'express';
import * as users from '../services/usersRepo.js';
import * as refresh from '../services/refreshTokensRepo.js';
import { signAccessToken } from '../services/jwtService.js';
import { verifyIdToken } from '../services/googleAuth.js';
import { requireAuth } from '../middleware/auth.js';
import { config } from '../config/index.js';
import Logger from '../utils/logger.js';

const router = express.Router();
router.use(express.json());

router.post('/google', async (req, res) => {
  const { idToken } = req.body ?? {};
  if (!idToken) return res.status(400).json({ error: 'id_token_missing' });
  let claims;
  try {
    claims = await verifyIdToken(idToken);
  } catch (e) {
    if (e.code === 'unverified_email') return res.status(401).json({ error: 'unverified_email' });
    Logger.warn('Google ID token verification failed', { msg: e.message });
    return res.status(401).json({ error: 'invalid_id_token' });
  }
  const user = await users.upsertByGoogleSub({ googleSub: claims.sub, email: claims.email, fullName: claims.name });
  const accessToken = signAccessToken(user.id);
  const r = await refresh.create(user.id);
  res.json({
    accessToken,
    refreshToken: r.token,
    user: { id: user.id, email: user.email, fullName: user.fullName }
  });
});

router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body ?? {};
  if (!refreshToken) return res.status(400).json({ error: 'refresh_token_missing' });
  const rotated = await refresh.rotate(refreshToken);
  if (!rotated) return res.status(401).json({ error: 'token_reuse' });
  const accessToken = signAccessToken(rotated.userId);
  res.json({ accessToken, refreshToken: rotated.token });
});

router.post('/logout', requireAuth, async (req, res) => {
  const { refreshToken } = req.body ?? {};
  if (refreshToken) await refresh.revoke(refreshToken);
  res.status(204).end();
});

/**
 * Dev sign-in. Non-production only: mints access + refresh tokens for an
 * arbitrary email without going through Google's OAuth flow. The user row
 * is upserted with a synthetic `dev:<email>` googleSub so the existing
 * unique constraint and signup-grant logic still works.
 *
 * Disabled when NODE_ENV === 'production'; returns 404 to avoid leaking
 * the route's existence.
 */
router.post('/dev', async (req, res) => {
  if (config.server.environment === 'production') {
    return res.status(404).json({ error: 'not_found' });
  }
  const { email, fullName } = req.body ?? {};
  if (typeof email !== 'string' || !email.includes('@')) {
    return res.status(400).json({ error: 'email_invalid' });
  }
  const user = await users.upsertByGoogleSub({
    googleSub: `dev:${email.toLowerCase()}`,
    email,
    fullName: fullName ?? null
  });
  const accessToken = signAccessToken(user.id);
  const r = await refresh.create(user.id);
  Logger.info('Dev sign-in', { userId: user.id, email });
  res.json({
    accessToken,
    refreshToken: r.token,
    user: { id: user.id, email: user.email, fullName: user.fullName }
  });
});

router.get('/me', requireAuth, async (req, res) => {
  const u = await users.findById(req.userId);
  if (!u) return res.status(404).json({ error: 'user_not_found' });
  res.json({ user: { id: u.id, email: u.email, fullName: u.fullName } });
});

export default router;
