/**
 * /v1/chat REST route — multi-session (conference-scope) chat.
 *
 * The iOS client computes the list of session IDs belonging to a
 * conference and sends them in the body. The server stays stateless
 * about conferences.
 */

import express from 'express';
import { sessionsRepo } from '../services/sessionsRepo.js';
import { chat } from '../services/chatService.js';
import Logger from '../utils/logger.js';

const router = express.Router();

// Cap multi-session chat to a reasonable conference size. Larger groupings
// would not fit the token budget anyway and would just waste lookups.
const MAX_SESSION_IDS = 50;

function userIdFor(req) { return req.userId ?? 'local-dev'; }

router.post('/', express.json(), async (req, res) => {
  const sessionIds = req.body?.sessionIds;
  const messages = req.body?.messages;
  if (!Array.isArray(sessionIds) || sessionIds.length === 0) {
    return res.status(400).json({ error: 'sessionIds_required' });
  }
  if (sessionIds.length > MAX_SESSION_IDS) {
    return res.status(400).json({ error: 'too_many_sessions', max: MAX_SESSION_IDS });
  }
  if (!Array.isArray(messages) || messages.length === 0) {
    return res.status(400).json({ error: 'messages_required' });
  }

  const userId = userIdFor(req);
  const sessions = [];
  for (const id of sessionIds) {
    const s = await sessionsRepo.getSession(id);
    if (!s) return res.status(404).json({ error: 'session_not_found', sessionId: id });
    if (s.userId !== userId) return res.status(403).json({ error: 'forbidden', sessionId: id });
    sessions.push({
      id: s.id, title: null, speaker: null,
      transcript: s.transcript, blendedMarkdown: s.blendedMarkdown,
      aiSummary: null,
      photos: s.photos.filter(p => p.extractStatus === 'complete'),
      createdAt: s.createdAt
    });
  }

  try {
    const result = await chat({
      scope: { kind: 'conference', sessionIds },
      messages,
      sessions
    });
    await sessionsRepo.recordCost({
      userId, sessionId: sessionIds[0], microsDelta: 0, reason: 'chat_conference',
      metadata: {
        sessionCount: sessionIds.length,
        tokensIn: result.tokensIn,
        tokensOut: result.tokensOut,
        citations: result.citations.length
      }
    });
    res.json({
      message: result.message,
      citations: result.citations,
      usage: { tokensIn: result.tokensIn, tokensOut: result.tokensOut }
    });
  } catch (e) {
    Logger.error('chat (multi-session) failed', e);
    res.status(502).json({ error: 'chat_failed', detail: e.message });
  }
});

export default router;
