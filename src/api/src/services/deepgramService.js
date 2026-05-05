/**
 * Deepgram integration service for Muesli Transcription API
 * Handles both batch and real-time transcription with comprehensive error handling
 */

import { createClient } from '@deepgram/sdk';
import { config } from '../config/index.js';
import Logger from '../utils/logger.js';

class DeepgramService {
  constructor() {
    this.client = createClient(config.deepgram.apiKey);
    this.isConnected = false;
    this.activeConnections = new Map();
    
    Logger.info('Deepgram service initialized', {
      model: config.deepgram.model,
      language: config.deepgram.language
    });
  }

  /**
   * Health check for Deepgram service
   */
  async healthCheck() {
    const startTime = Date.now();
    
    try {
      // Test with a minimal audio buffer to verify API connectivity
      const testBuffer = Buffer.alloc(1024, 0);
      const options = {
        model: config.deepgram.model,
        language: config.deepgram.language,
        punctuate: true,
        diarize: false
      };

      await this.client.listen.prerecorded.transcribeFile(testBuffer, options);
      
      const duration = Date.now() - startTime;
      this.isConnected = true;
      
      Logger.health('deepgram', 'healthy', { duration });
      return { healthy: true, latency: duration };
      
    } catch (error) {
      const duration = Date.now() - startTime;
      this.isConnected = false;
      
      Logger.health('deepgram', 'unhealthy', { duration, error: error.message });
      return { 
        healthy: false, 
        latency: duration, 
        error: error.message 
      };
    }
  }

  /**
   * Transcribe audio file (batch processing)
   */
  async transcribeFile(audioBuffer, options = {}) {
    const startTime = Date.now();
    const requestId = options.requestId || 'batch-' + Date.now();
    
    Logger.transcription('File transcription started', {
      requestId,
      bufferSize: audioBuffer.length,
      model: options.model || config.deepgram.model
    });

    try {
      const transcriptionOptions = {
        model: options.model || config.deepgram.model,
        language: options.language || config.deepgram.language,
        punctuate: true,
        diarize: options.diarize || false,
        paragraphs: options.paragraphs || false,
        utterances: options.utterances || false,
        smart_format: true,
        filler_words: false,
        ...options.deepgramOptions
      };

      const response = await this.client.listen.prerecorded.transcribeFile(
        audioBuffer,
        transcriptionOptions
      );

      const duration = Date.now() - startTime;
      const transcript = this.extractTranscript(response);
      const confidence = this.extractConfidence(response);

      Logger.transcription('File transcription completed', {
        requestId,
        duration,
        transcriptLength: transcript.length,
        confidence,
        model: transcriptionOptions.model
      });

      return {
        transcript,
        confidence,
        duration,
        model: transcriptionOptions.model,
        language: transcriptionOptions.language,
        metadata: this.extractMetadata(response)
      };

    } catch (error) {
      const duration = Date.now() - startTime;
      
      Logger.error('File transcription failed', error, {
        requestId,
        duration,
        bufferSize: audioBuffer.length,
        errorType: this.categorizeError(error)
      });

      throw this.handleDeepgramError(error);
    }
  }

  /**
   * Create real-time transcription connection
   */
  async createRealtimeConnection(options = {}) {
    const connectionId = options.connectionId || 'live-' + Date.now();
    const startTime = Date.now();

    Logger.websocket('Creating real-time connection', connectionId, {
      model: options.model || config.deepgram.model
    });

    try {
      const connectionOptions = {
        model: options.model || config.deepgram.model,
        language: options.language || config.deepgram.language,
        punctuate: true,
        interim_results: true,
        endpointing: 300,
        smart_format: true,
        filler_words: false,
        ...options.deepgramOptions
      };

      const connection = this.client.listen.live.transcription(connectionOptions);

      // Connection event handlers
      connection.on('open', () => {
        const duration = Date.now() - startTime;
        this.activeConnections.set(connectionId, {
          connection,
          startTime,
          lastActivity: Date.now()
        });

        Logger.websocket('Real-time connection opened', connectionId, {
          duration,
          totalConnections: this.activeConnections.size
        });
      });

      connection.on('Results', (data) => {
        const connectionInfo = this.activeConnections.get(connectionId);
        if (connectionInfo) {
          connectionInfo.lastActivity = Date.now();
        }

        Logger.websocket('Transcription result received', connectionId, {
          isFinal: data.is_final,
          channel: data.channel_index?.[0],
          duration: data.duration
        });
      });

      connection.on('error', (error) => {
        Logger.error('Real-time connection error', error, {
          connectionId,
          errorType: this.categorizeError(error)
        });
      });

      connection.on('close', () => {
        const connectionInfo = this.activeConnections.get(connectionId);
        const sessionDuration = connectionInfo ? 
          Date.now() - connectionInfo.startTime : 0;

        this.activeConnections.delete(connectionId);

        Logger.websocket('Real-time connection closed', connectionId, {
          sessionDuration,
          totalConnections: this.activeConnections.size
        });
      });

      return {
        connection,
        connectionId,
        send: (audioData) => this.sendAudioData(connectionId, audioData),
        close: () => this.closeConnection(connectionId)
      };

    } catch (error) {
      const duration = Date.now() - startTime;
      
      Logger.error('Failed to create real-time connection', error, {
        connectionId,
        duration,
        errorType: this.categorizeError(error)
      });

      throw this.handleDeepgramError(error);
    }
  }

  /**
   * Send audio data to real-time connection
   */
  sendAudioData(connectionId, audioData) {
    const connectionInfo = this.activeConnections.get(connectionId);
    
    if (!connectionInfo) {
      throw new Error(`Connection ${connectionId} not found`);
    }

    try {
      connectionInfo.connection.send(audioData);
      connectionInfo.lastActivity = Date.now();
      
      Logger.debug('Audio data sent to connection', {
        connectionId,
        dataSize: audioData.length
      });
      
    } catch (error) {
      Logger.error('Failed to send audio data', error, {
        connectionId,
        dataSize: audioData.length
      });
      throw error;
    }
  }

  /**
   * Close real-time connection
   */
  closeConnection(connectionId) {
    const connectionInfo = this.activeConnections.get(connectionId);
    
    if (connectionInfo) {
      try {
        connectionInfo.connection.finish();
        this.activeConnections.delete(connectionId);
        
        Logger.websocket('Connection closed manually', connectionId, {
          sessionDuration: Date.now() - connectionInfo.startTime
        });
        
      } catch (error) {
        Logger.error('Error closing connection', error, { connectionId });
      }
    }
  }

  /**
   * Get service statistics
   */
  getStats() {
    const stats = {
      isConnected: this.isConnected,
      activeConnections: this.activeConnections.size,
      connectionDetails: Array.from(this.activeConnections.entries()).map(([id, info]) => ({
        connectionId: id,
        duration: Date.now() - info.startTime,
        lastActivity: Date.now() - info.lastActivity
      }))
    };

    Logger.debug('Service stats requested', stats);
    return stats;
  }

  /**
   * Extract transcript from Deepgram response
   */
  extractTranscript(response) {
    try {
      return response.results?.channels?.[0]?.alternatives?.[0]?.transcript || '';
    } catch (error) {
      Logger.warn('Failed to extract transcript from response', { error: error.message });
      return '';
    }
  }

  /**
   * Extract confidence score from Deepgram response
   */
  extractConfidence(response) {
    try {
      return response.results?.channels?.[0]?.alternatives?.[0]?.confidence || 0;
    } catch (error) {
      Logger.warn('Failed to extract confidence from response', { error: error.message });
      return 0;
    }
  }

  /**
   * Extract metadata from Deepgram response
   */
  extractMetadata(response) {
    try {
      return {
        requestId: response.metadata?.request_id,
        duration: response.metadata?.duration,
        channels: response.metadata?.channels,
        model: response.metadata?.model_info?.name,
        language: response.metadata?.model_info?.language
      };
    } catch (error) {
      Logger.warn('Failed to extract metadata from response', { error: error.message });
      return {};
    }
  }

  /**
   * Categorize Deepgram errors for better logging
   */
  categorizeError(error) {
    const errorMessage = error.message?.toLowerCase() || '';
    
    if (errorMessage.includes('unauthorized') || errorMessage.includes('api key')) {
      return 'authentication';
    } else if (errorMessage.includes('rate limit') || errorMessage.includes('quota')) {
      return 'rate_limit';
    } else if (errorMessage.includes('timeout') || errorMessage.includes('network')) {
      return 'network';
    } else if (errorMessage.includes('audio') || errorMessage.includes('format')) {
      return 'audio_format';
    } else if (errorMessage.includes('model') || errorMessage.includes('language')) {
      return 'configuration';
    } else {
      return 'unknown';
    }
  }

  /**
   * Handle and transform Deepgram errors
   */
  handleDeepgramError(error) {
    const errorType = this.categorizeError(error);
    
    switch (errorType) {
      case 'authentication':
        return new Error('Deepgram API authentication failed. Please check your API key.');
      case 'rate_limit':
        return new Error('Deepgram API rate limit exceeded. Please try again later.');
      case 'network':
        return new Error('Network error connecting to Deepgram API. Please try again.');
      case 'audio_format':
        return new Error('Audio format not supported or corrupted audio file.');
      case 'configuration':
        return new Error('Invalid model or language configuration for Deepgram API.');
      default:
        return new Error(`Transcription service error: ${error.message}`);
    }
  }

  /**
   * Transcribe a buffer and return { transcript, words } for the pipeline
   */
  async transcribeBuffer(buffer, mimeType = 'audio/mp4') {
    const { result } = await this.client.listen.prerecorded.transcribeFile(buffer, {
      model: config.deepgram.model,
      language: config.deepgram.language,
      punctuate: true,
      diarize: false,
      utterances: false,
    });
    const channel = result?.results?.channels?.[0];
    const transcript = channel?.alternatives?.[0]?.transcript ?? '';
    const words = (channel?.alternatives?.[0]?.words ?? []).map(w => ({
      text: w.word, start: w.start, end: w.end
    }));
    return { transcript, words };
  }

  /**
   * Clean up stale connections
   */
  cleanupStaleConnections(maxIdleTime = 300000) { // 5 minutes
    const now = Date.now();
    const staleConnections = [];

    for (const [connectionId, connectionInfo] of this.activeConnections.entries()) {
      if (now - connectionInfo.lastActivity > maxIdleTime) {
        staleConnections.push(connectionId);
      }
    }

    staleConnections.forEach(connectionId => {
      Logger.warn('Cleaning up stale connection', { connectionId });
      this.closeConnection(connectionId);
    });

    if (staleConnections.length > 0) {
      Logger.info('Cleaned up stale connections', { 
        count: staleConnections.length,
        remaining: this.activeConnections.size
      });
    }
  }
}

// Create singleton instance
const deepgramService = new DeepgramService();

export default deepgramService;