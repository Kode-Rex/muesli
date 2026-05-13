//
//  HybridTranscriptionPort.swift
//  Muesli
//
//  Port for batch / file transcription that may use local or cloud
//  implementations. Separate from TranscriptionPort because the file
//  transcription contract throws and returns a non-optional String,
//  while the realtime port returns a Bool / optional.
//

import Foundation

protocol HybridTranscriptionPort: AnyObject {
    func transcribeAudioFile(url: URL) async throws -> String
}
