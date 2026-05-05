/**
 * /v1/sessions REST routes
 * Orchestration layer: audio → Deepgram, photo → Haiku, blend → Haiku+Sonnet
 */

import express from 'express';
import multer from 'multer';
import { sessionsRepo } from '../services/sessionsRepo.js';
import { extractImage } from '../services/imageExtractService.js';
import { chapterize } from '../services/chapterizeService.js';
import { blend } from '../services/blendService.js';
import { blendCostMicros } from '../services/blendCost.js';
import { contentHash } from '../services/contentHash.js';
import deepgramService from '../services/deepgramService.js';
import Logger from '../utils/logger.js';

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 50 * 1024 * 1024 } });
const router = express.Router();

// HACK for v1: hardcoded user. Auth middleware swaps this in later.
function userIdFor(req) { return req.userId ?? 'local-dev'; }

router.post('/', async (req, res) => {
  const id = await sessionsRepo.createSession({ userId: userIdFor(req) });
  res.json({ sessionId: id });
});

router.get('/:id', async (req, res) => {
  const s = await sessionsRepo.getSession(req.params.id);
  if (!s) return res.status(404).json({ error: 'session_not_found' });
  res.json(s);
});

router.post('/:id/audio', upload.single('audio'), async (req, res) => {
  const id = req.params.id;
  const s = await sessionsRepo.getSession(id);
  if (!s) return res.status(404).json({ error: 'session_not_found' });
  if (!req.file) return res.status(400).json({ error: 'audio_missing' });

  await sessionsRepo.attachAudio(id, { audioPath: 'in-memory', durationSeconds: Number(req.body.durationSeconds || 0) });
  await sessionsRepo.setStatus(id, 'transcribing');

  try {
    const { transcript, words } = await deepgramService.transcribeBuffer(req.file.buffer, req.file.mimetype);
    await sessionsRepo.saveTranscript(id, { text: transcript, words });
    await sessionsRepo.setStatus(id, 'transcribed');
    res.json({ ok: true });
  } catch (e) {
    Logger.error('Transcribe failed', e);
    await sessionsRepo.setStatus(id, 'failed', e.message);
    res.status(500).json({ error: 'transcribe_failed' });
  }
});

router.post('/:id/photos', upload.single('photo'), async (req, res) => {
  const id = req.params.id;
  const s = await sessionsRepo.getSession(id);
  if (!s) return res.status(404).json({ error: 'session_not_found' });
  if (!req.file) return res.status(400).json({ error: 'photo_missing' });

  const photoId = req.body.photoId || contentHash(req.file.buffer);
  const hash = contentHash(req.file.buffer);
  const capturedAt = new Date(Number(req.body.capturedAt || Date.now()));

  await sessionsRepo.addPhoto(id, { photoId, contentHash: hash, capturedAt, localPath: 'in-memory' });

  try {
    const result = await extractImage({ imageBuffer: req.file.buffer, mimeType: req.file.mimetype });
    await sessionsRepo.updatePhotoExtract(id, photoId, {
      ocrText: result.ocrText, description: result.description, extractStatus: 'complete'
    });
    res.json({ photoId, ocrText: result.ocrText, description: result.description });
  } catch (e) {
    Logger.error('Image extract failed', e);
    await sessionsRepo.updatePhotoExtract(id, photoId, { ocrText: '', description: '', extractStatus: 'failed' });
    res.status(500).json({ error: 'extract_failed' });
  }
});

router.post('/:id/blend', express.json(), async (req, res) => {
  const id = req.params.id;
  const s = await sessionsRepo.getSession(id);
  if (!s) return res.status(404).json({ error: 'session_not_found' });
  if (!s.transcript) return res.status(400).json({ error: 'no_transcript' });

  const userNotes = req.body.userNotes ?? '';

  await sessionsRepo.setStatus(id, 'blending');

  try {
    const chap = await chapterize({ transcript: s.transcript, durationSeconds: s.durationSeconds });
    const result = await blend({
      transcript: s.transcript,
      transcriptWords: s.transcriptWords,
      photos: s.photos.filter(p => p.extractStatus === 'complete'),
      userNotes,
      chapters: chap.chapters,
    });

    const cost = blendCostMicros({
      deepgramSeconds: s.durationSeconds,
      imageCount: s.photos.filter(p => p.extractStatus === 'complete').length,
      hasChapterize: true,
      sonnetInputTokens: result.tokensIn,
      sonnetOutputTokens: result.tokensOut,
    });

    await sessionsRepo.saveBlend(id, {
      blendedMarkdown: result.blendedMarkdown,
      userNoteSpans: result.userNoteSpans,
      quoteSpans: result.quoteSpans,
      imagePlacements: result.imagePlacements,
      citations: result.citations,
      chapters: chap.chapters,
      costMicros: cost,
      modelVersion: 'sonnet-4-6+haiku-4-5+nova-3'
    });

    await sessionsRepo.recordCost({
      userId: s.userId, sessionId: id, microsDelta: -cost, reason: 'blend',
      metadata: { sonnetIn: result.tokensIn, sonnetOut: result.tokensOut, photoCount: s.photos.length, chapterCount: chap.chapters.length }
    });

    res.json({
      blendedMarkdown: result.blendedMarkdown,
      userNoteSpans: result.userNoteSpans,
      quoteSpans: result.quoteSpans,
      imagePlacements: result.imagePlacements,
      citations: result.citations,
      chapters: chap.chapters,
      costMicros: cost,
    });
  } catch (e) {
    Logger.error('Blend failed', e);
    await sessionsRepo.setStatus(id, 'failed', e.message);
    res.status(500).json({ error: 'blend_failed', detail: e.message });
  }
});

export default router;
