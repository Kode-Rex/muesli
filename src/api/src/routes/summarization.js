/**
 * AI Summarization routes for Muesli API
 * Handles text summarization and action item extraction
 */

import express from 'express';
import { config } from '../config/index.js';
import Logger from '../utils/logger.js';
import {
  generalRateLimit,
  validateSummarizationRequest,
  handleValidationErrors
} from '../middleware/security.js';

const router = express.Router();

/**
 * Text summarization endpoint
 * POST /summarize
 */
router.post('/summarize',
  generalRateLimit,
  validateSummarizationRequest,
  handleValidationErrors,
  async (req, res) => {
    const startTime = Date.now();
    
    Logger.info('Summarization request received', {
      requestId: req.id,
      textLength: req.body.text?.length,
      type: req.body.type,
      ip: req.ip
    });

    try {
      const { text, type = 'note', options = {} } = req.body;
      
      // For now, return a mock response since we don't have an AI service configured
      // In production, this would integrate with OpenAI, Claude, or another LLM service
      const summary = await generateMockSummary(text, type, options);
      
      const duration = Date.now() - startTime;

      Logger.info('Summarization completed', {
        requestId: req.id,
        duration,
        originalLength: text.length,
        summaryLength: summary.summary.length,
        keyPointsCount: summary.keyPoints.length,
        actionItemsCount: summary.actionItems.length
      });

      res.status(200).json({
        summary: summary.summary,
        keyPoints: summary.keyPoints,
        actionItems: summary.actionItems,
        confidence: summary.confidence,
        processingTime: duration,
        metadata: {
          model: 'mock-summarizer-v1',
          type,
          requestId: req.id,
          originalLength: text.length
        }
      });

    } catch (error) {
      const duration = Date.now() - startTime;
      
      Logger.error('Summarization failed', error, {
        requestId: req.id,
        duration,
        textLength: req.body.text?.length
      });

      res.status(500).json({
        error: error.message,
        requestId: req.id,
        timestamp: new Date().toISOString(),
        processingTime: duration
      });
    }
  }
);

/**
 * Action items extraction endpoint
 * POST /extract-actions
 */
router.post('/extract-actions',
  generalRateLimit,
  validateSummarizationRequest,
  handleValidationErrors,
  async (req, res) => {
    const startTime = Date.now();
    
    Logger.info('Action items extraction request received', {
      requestId: req.id,
      textLength: req.body.text?.length,
      ip: req.ip
    });

    try {
      const { text } = req.body;
      
      // Extract action items using mock logic
      const actionItems = await extractMockActionItems(text);
      
      const duration = Date.now() - startTime;

      Logger.info('Action items extraction completed', {
        requestId: req.id,
        duration,
        actionItemsCount: actionItems.length
      });

      res.status(200).json({
        actionItems,
        confidence: 0.85,
        processingTime: duration,
        metadata: {
          model: 'mock-action-extractor-v1',
          requestId: req.id,
          originalLength: text.length
        }
      });

    } catch (error) {
      const duration = Date.now() - startTime;
      
      Logger.error('Action items extraction failed', error, {
        requestId: req.id,
        duration
      });

      res.status(500).json({
        error: error.message,
        requestId: req.id,
        timestamp: new Date().toISOString(),
        processingTime: duration
      });
    }
  }
);

/**
 * Mock summarization function
 * In production, replace with actual AI service integration
 */
async function generateMockSummary(text, type, options) {
  // Simulate processing time
  await new Promise(resolve => setTimeout(resolve, 500 + Math.random() * 1000));
  
  const words = text.split(/\s+/);
  const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 0);
  
  // Generate a mock summary (first few sentences, truncated)
  const maxSummaryLength = options.maxSummaryLength || 500;
  let summary = sentences.slice(0, Math.min(3, sentences.length)).join('. ');
  
  if (summary.length > maxSummaryLength) {
    summary = summary.substring(0, maxSummaryLength - 3) + '...';
  }
  
  // Generate mock key points
  const keyPoints = options.includeKeyPoints !== false ? [
    `Main topic discussed with ${words.length} words total`,
    `Session type: ${type}`,
    `Key themes identified in the content`
  ] : [];
  
  // Generate mock action items
  const actionItems = options.includeActionItems !== false ? 
    extractMockActionItems(text) : [];
  
  return {
    summary: summary || 'Summary not available for this content.',
    keyPoints,
    actionItems,
    confidence: 0.8 + Math.random() * 0.15 // Random confidence between 0.8-0.95
  };
}

/**
 * Mock action items extraction
 * In production, replace with actual AI service integration
 */
async function extractMockActionItems(text) {
  const actionWords = ['todo', 'action', 'follow up', 'next steps', 'assign', 'complete', 'finish', 'implement'];
  const sentences = text.toLowerCase().split(/[.!?]+/);
  
  const actionItems = [];
  
  for (const sentence of sentences) {
    if (actionWords.some(word => sentence.includes(word))) {
      // Clean up and format the sentence
      const cleaned = sentence.trim().replace(/^\w/, c => c.toUpperCase());
      if (cleaned.length > 10 && actionItems.length < 5) {
        actionItems.push(cleaned);
      }
    }
  }
  
  // Add some default action items if none found
  if (actionItems.length === 0) {
    actionItems.push('Review meeting notes and key decisions');
    actionItems.push('Follow up on discussed topics');
  }
  
  return actionItems;
}

export default router;