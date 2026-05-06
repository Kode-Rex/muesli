import express from 'express';
import * as users from '../services/usersRepo.js';
import * as refresh from '../services/refreshTokensRepo.js';
import { signAccessToken } from '../services/jwtService.js';
import { verifyIdToken } from '../services/googleAuth.js';
import { requireAuth } from '../middleware/auth.js';
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

router.get('/me', requireAuth, async (req, res) => {
  const u = await users.findById(req.userId);
  if (!u) return res.status(404).json({ error: 'user_not_found' });
  res.json({ user: { id: u.id, email: u.email, fullName: u.fullName } });
});

export default router;
