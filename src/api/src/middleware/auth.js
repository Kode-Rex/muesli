import { verifyAccessToken } from '../services/jwtService.js';
import { config } from '../config/index.js';

function extractBearer(req) {
  const h = req.headers.authorization;
  if (!h || !h.startsWith('Bearer ')) return null;
  return h.slice(7);
}

export function requireAuth(req, res, next) {
  if (!config.auth.enabled) {
    req.userId = config.auth.devUserId;
    return next();
  }
  const token = extractBearer(req);
  if (!token) return res.status(401).json({ error: 'missing_token' });
  try {
    const payload = verifyAccessToken(token);
    req.userId = payload.sub;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'invalid_token' });
  }
}
