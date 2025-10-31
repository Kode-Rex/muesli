/**
 * Integration tests for summarization endpoints
 */

import request from 'supertest';
import express from 'express';
import summarizationRoutes from '../../src/routes/summarization.js';
import { 
  requestIdMiddleware,
  validateSummarizationRequest,
  handleValidationErrors 
} from '../../src/middleware/security.js';

// Create test app
const app = express();
app.use(express.json());
app.use(requestIdMiddleware);
app.use('/api/v1', summarizationRoutes);

describe('Summarization API', () => {
  const sampleText = 'This is a test meeting transcript. We discussed the quarterly goals and decided to implement new features. John will follow up on the budget analysis. Sarah needs to complete the user research by Friday. The team agreed to meet again next week to review progress.';

  describe('POST /api/v1/summarize', () => {
    it('should successfully summarize text', async () => {
      const response = await request(app)
        .post('/api/v1/summarize')
        .send({
          text: sampleText,
          type: 'meeting',
          options: {
            includeKeyPoints: true,
            includeActionItems: true,
            maxSummaryLength: 500
          }
        });

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('summary');
      expect(response.body).toHaveProperty('keyPoints');
      expect(response.body).toHaveProperty('actionItems');
      expect(response.body).toHaveProperty('confidence');
      expect(response.body.confidence).toBeGreaterThan(0);
      expect(Array.isArray(response.body.keyPoints)).toBe(true);
      expect(Array.isArray(response.body.actionItems)).toBe(true);
    });

    it('should reject text that is too short', async () => {
      const response = await request(app)
        .post('/api/v1/summarize')
        .send({
          text: 'Too short',
          type: 'meeting'
        });

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('errors');
    });

    it('should reject invalid session type', async () => {
      const response = await request(app)
        .post('/api/v1/summarize')
        .send({
          text: sampleText,
          type: 'invalid-type'
        });

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('errors');
    });

    it('should handle missing text field', async () => {
      const response = await request(app)
        .post('/api/v1/summarize')
        .send({
          type: 'meeting'
        });

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('errors');
    });
  });

  describe('POST /api/v1/extract-actions', () => {
    it('should successfully extract action items', async () => {
      const response = await request(app)
        .post('/api/v1/extract-actions')
        .send({
          text: sampleText
        });

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('actionItems');
      expect(response.body).toHaveProperty('confidence');
      expect(Array.isArray(response.body.actionItems)).toBe(true);
      expect(response.body.actionItems.length).toBeGreaterThan(0);
    });

    it('should reject text that is too short', async () => {
      const response = await request(app)
        .post('/api/v1/extract-actions')
        .send({
          text: 'Short'
        });

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('errors');
    });
  });
});