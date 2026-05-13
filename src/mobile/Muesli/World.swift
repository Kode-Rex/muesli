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

    /// Real adapters wired against production services.
    static var live: World {
        World(
            transcription: TranscriptionService.shared,
            hybridTranscription: HybridTranscriptionService.shared,
            network: NetworkMonitor.shared,
            blend: SessionsService.shared,
            chat: UnimplementedChatAdapter()
        )
    }
}
