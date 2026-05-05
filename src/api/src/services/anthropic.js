/**
 * Anthropic SDK singleton and model constants
 */

import Anthropic from '@anthropic-ai/sdk';
import { config } from '../config/index.js';

export const anthropic = new Anthropic({ apiKey: config.anthropic.apiKey });

export const HAIKU_MODEL = 'claude-haiku-4-5-20251001';
export const SONNET_MODEL = 'claude-sonnet-4-6';
