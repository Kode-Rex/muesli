import { describe, it, expect, beforeEach } from '@jest/globals';
import { InMemorySessionsRepo } from '../../src/services/sessionsRepo.js';

describe('InMemorySessionsRepo', () => {
  let repo;
  beforeEach(() => { repo = new InMemorySessionsRepo(); });

  it('createSession returns a fresh sessionId and stores the row', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    const s = await repo.getSession(id);
    expect(s.userId).toBe('u1');
    expect(s.status).toBe('idle');
    expect(s.photos).toEqual([]);
    expect(s.transcript).toBeNull();
  });

  it('attachAudio sets transcript fields', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.attachAudio(id, { audioPath: '/tmp/x.m4a', durationSeconds: 47.2 });
    const s = await repo.getSession(id);
    expect(s.audioPath).toBe('/tmp/x.m4a');
    expect(s.durationSeconds).toBe(47.2);
  });

  it('addPhoto appends a photo with extract status pending', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.addPhoto(id, { photoId: 'p1', contentHash: 'abc', capturedAt: new Date(), localPath: '/tmp/p1.jpg' });
    const s = await repo.getSession(id);
    expect(s.photos).toHaveLength(1);
    expect(s.photos[0].extractStatus).toBe('pending');
  });

  it('updatePhotoExtract sets extracted fields', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.addPhoto(id, { photoId: 'p1', contentHash: 'abc', capturedAt: new Date(), localPath: '/tmp/p1.jpg' });
    await repo.updatePhotoExtract(id, 'p1', { ocrText: 'slide text', description: 'a slide', extractStatus: 'complete' });
    const s = await repo.getSession(id);
    expect(s.photos[0].ocrText).toBe('slide text');
    expect(s.photos[0].extractStatus).toBe('complete');
  });

  it('saveTranscript stores text + words', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.saveTranscript(id, { text: 'hi', words: [{ text: 'hi', start: 0, end: 0.5 }] });
    const s = await repo.getSession(id);
    expect(s.transcript).toBe('hi');
    expect(s.transcriptWords).toEqual([{ text: 'hi', start: 0, end: 0.5 }]);
  });

  it('saveBlend stores all blend output and chapters', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.saveBlend(id, {
      blendedMarkdown: '# x',
      userNoteSpans: [], quoteSpans: [], imagePlacements: [], citations: [],
      chapters: [{ start: 0, title: 'a', summary: '' }],
      costMicros: 12345,
      modelVersion: 'sonnet-4-6+haiku-4-5+nova-3'
    });
    const s = await repo.getSession(id);
    expect(s.blendedMarkdown).toBe('# x');
    expect(s.chapters).toHaveLength(1);
    expect(s.costMicros).toBe(12345);
    expect(s.status).toBe('complete');
  });

  it('setStatus updates status', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.setStatus(id, 'transcribing');
    expect((await repo.getSession(id)).status).toBe('transcribing');
  });

  it('getSession returns null for unknown id', async () => {
    expect(await repo.getSession('nope')).toBeNull();
  });

  it('listCostEntries returns entries appended via recordCost', async () => {
    const id = await repo.createSession({ userId: 'u1' });
    await repo.recordCost({ userId: 'u1', sessionId: id, microsDelta: -10000, reason: 'blend' });
    const entries = await repo.listCostEntries('u1');
    expect(entries).toHaveLength(1);
    expect(entries[0].microsDelta).toBe(-10000);
  });
});
