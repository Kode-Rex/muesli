//
//  TranscriptionPort.swift
//  Muesli
//
//  Port (interface) for transcription services. Live adapters wrap
//  the Deepgram / on-device implementations; test fakes return canned
//  responses so tests never touch the real network.
//

import Foundation

protocol TranscriptionPort: AnyObject {
    var isTranscribing: Bool { get }
    var hasValidAPIEndpoint: Bool { get }
    var environmentName: String { get }
    var currentAPIEndpoint: String { get }
    var isUsingLocalhost: Bool { get }

    var onError: ((Error) -> Void)? { get set }
    var onTranscriptionUpdate: ((TranscriptionResult) -> Void)? { get set }

    func startRealtimeTranscription() async -> Bool
    func stopRealtimeTranscription()
    func transcribeAudioFile(url: URL) async -> String?
}
