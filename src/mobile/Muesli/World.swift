//
//  World.swift
//  Muesli
//
//  Composition root for the hex-arch ports. Production sets `World.current`
//  to `.live` at app launch; tests install a World composed of fake adapters
//  in setUp so no test ever reaches the real network.
//

import Foundation

struct World {
    var transcription: any TranscriptionPort
    var hybridTranscription: any HybridTranscriptionPort
    var network: any NetworkPort
    var blend: any BlendPort
    var chat: any ChatPort
}

extension World {
    /// Mutable accessor. Production is initialized to `.live` at launch and
    /// never mutated thereafter. Tests overwrite this in setUp and restore
    /// the prior value in tearDown. The `nonisolated(unsafe)` annotation
    /// reflects this contract: writes are confined to test setUp on the main
    /// actor; reads happen from any context (including detached Tasks in
    /// orchestrators). Production code must NOT mutate `World.current`.
    nonisolated(unsafe) static var current: World = .live

    /// Real adapters wired against production services. The chat adapter
    /// uses a default-empty sessionIdsResolver; ChatViewModel pre-resolves
    /// the conference's member sessions from SwiftData and passes them via
    /// LiveChatAdapter's explicit-resolver send variant.
    static var live: World {
        let chatBase = URL(string: APIConfiguration.transcriptionAPIBaseURL) ?? URL(string: "https://api.muesli-app.com/api/v1")!
        return World(
            transcription: TranscriptionService.shared,
            hybridTranscription: HybridTranscriptionService.shared,
            network: NetworkMonitor.shared,
            blend: SessionsService.shared,
            chat: LiveChatAdapter(baseURL: chatBase)
        )
    }
}
