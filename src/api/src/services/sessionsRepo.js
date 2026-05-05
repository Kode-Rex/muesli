import { randomUUID } from 'crypto';

export class InMemorySessionsRepo {
  constructor() {
    this.sessions = new Map();
    this.costEntries = [];
  }

  async createSession({ userId }) {
    const id = randomUUID();
    this.sessions.set(id, {
      id, userId, status: 'idle',
      audioPath: null, durationSeconds: 0,
      transcript: null, transcriptWords: null,
      photos: [],
      blendedMarkdown: null,
      userNoteSpans: [], quoteSpans: [], imagePlacements: [], citations: [],
      chapters: null,
      costMicros: 0,
      modelVersion: null,
      error: null,
      createdAt: new Date(),
    });
    return id;
  }

  async getSession(id) {
    return this.sessions.get(id) ?? null;
  }

  async attachAudio(id, { audioPath, durationSeconds }) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    s.audioPath = audioPath;
    s.durationSeconds = durationSeconds;
  }

  async addPhoto(id, { photoId, contentHash, capturedAt, localPath }) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    s.photos.push({
      photoId, contentHash, capturedAt, localPath,
      ocrText: null, description: null, extractStatus: 'pending',
    });
  }

  async updatePhotoExtract(id, photoId, { ocrText, description, extractStatus }) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    const p = s.photos.find(p => p.photoId === photoId);
    if (!p) throw new Error(`Unknown photo ${photoId}`);
    p.ocrText = ocrText;
    p.description = description;
    p.extractStatus = extractStatus;
  }

  async saveTranscript(id, { text, words }) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    s.transcript = text;
    s.transcriptWords = words;
  }

  async saveBlend(id, payload) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    Object.assign(s, payload, { status: 'complete' });
  }

  async setStatus(id, status, error = null) {
    const s = this.sessions.get(id);
    if (!s) throw new Error(`Unknown session ${id}`);
    s.status = status;
    if (error) s.error = error;
  }

  async recordCost(entry) {
    this.costEntries.push({ ...entry, createdAt: new Date() });
  }

  async listCostEntries(userId) {
    return this.costEntries.filter(e => e.userId === userId);
  }
}

// Module-scoped singleton; route handlers and tests both reach for this.
export const sessionsRepo = new InMemorySessionsRepo();
