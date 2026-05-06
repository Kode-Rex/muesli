import express from 'express';
import * as ledger from '../services/ledgerService.js';
import * as users from '../services/usersRepo.js';
import { config } from '../config/index.js';
import { requireAuth } from '../middleware/auth.js';

const router = express.Router();

router.get('/balance', requireAuth, async (req, res) => {
  const microsBalance = await ledger.getBalance(req.userId).catch(() => 0);
  // 1 hour ≈ 400_000 micros (credit-ledger spec). With enforcement off, surface
  // the literal balance and let the client treat hoursAvailable as "unlimited".
  const hoursAvailable = config.credits.enforced
    ? Math.max(0, Math.floor(microsBalance / 400_000))
    : Number.MAX_SAFE_INTEGER;
  res.json({ microsBalance, hoursAvailable, enforced: config.credits.enforced });
});

router.get('/ledger', requireAuth, async (req, res) => {
  const limit = Math.min(Number(req.query.limit ?? 50), 200);
  const entries = await ledger.listEntries(req.userId, { limit }).catch(() => []);
  res.json({ entries });
});

router.delete('/', requireAuth, async (req, res) => {
  await users.deleteUser(req.userId);
  res.status(204).end();
});

export default router;
