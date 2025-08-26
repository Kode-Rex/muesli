//
//  AppConfiguration.swift
//  Muesli
//
//  App configuration for API endpoints and settings
//

import Foundation

struct AppConfiguration {
    
    /// Configure the transcription API endpoint
    /// Call this on app launch with your own API endpoint
    static func configureTranscriptionAPI(baseURL: String) {
        TranscriptionService.shared.setTranscriptionAPIEndpoint(baseURL)
        AppLogger.shared.info("Configured transcription API endpoint")
    }
    
    /// Example API endpoints you might use
    static let exampleEndpoints = [
        "Local Development": "http://localhost:3000/api",
        "Staging": "https://staging-api.yourapp.com/v1",
        "Production": "https://api.yourapp.com/v1"
    ]
    
    /// Quick setup for common configurations
    static func setupForEnvironment(_ environment: Environment) {
        switch environment {
        case .development:
            configureTranscriptionAPI(baseURL: "http://localhost:3000/api")
        case .staging:
            configureTranscriptionAPI(baseURL: "https://staging-api.yourapp.com/v1")
        case .production:
            configureTranscriptionAPI(baseURL: "https://api.yourapp.com/v1")
        }
    }
    
    enum Environment {
        case development
        case staging
        case production
    }
}

// MARK: - Usage Examples

/*
 To configure your transcription API, add this to your app startup:

 // Option 1: Direct configuration
 AppConfiguration.configureTranscriptionAPI(baseURL: "https://your-api.com/v1")

 // Option 2: Environment-based configuration
 #if DEBUG
 AppConfiguration.setupForEnvironment(.development)
 #else
 AppConfiguration.setupForEnvironment(.production)
 #endif

 Your API should implement these endpoints:

 1. Batch Transcription:
    POST /transcribe
    - Accept multipart form data with "audio" file
    - Return JSON: {"transcript": "transcribed text"}

 2. Real-time Transcription (optional):
    WebSocket /transcribe/realtime
    - Accept audio data via WebSocket
    - Return transcription updates

 Example Express.js server routes:
 
 ```javascript
 // Batch transcription
 app.post('/api/transcribe', upload.single('audio'), async (req, res) => {
   try {
     const audioFile = req.file;
     const transcript = await deepgramClient.transcribe(audioFile);
     res.json({ transcript: transcript.results.channels[0].alternatives[0].transcript });
   } catch (error) {
     res.status(500).json({ error: error.message });
   }
 });

 // Real-time transcription (WebSocket)
 wss.on('connection', (ws) => {
   const deepgramLive = deepgramClient.transcription.live({
     model: 'nova-2',
     smart_format: true,
   });
   
   ws.on('message', (audioData) => {
     deepgramLive.send(audioData);
   });
   
   deepgramLive.on('transcriptReceived', (data) => {
     ws.send(JSON.stringify(data));
   });
 });
 ```
 */
