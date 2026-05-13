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
    var network: any NetworkPort
    var blend: any BlendPort
    var chat: any ChatPort
}

extension World {
    /// Mutable accessor. Production is initialized to `.live` at launch.
    /// Tests overwrite this in setUp and restore the prior value in tearDown.
    @MainActor
    static var current: World = .live

    /// Real adapters wired against production services.
    @MainActor
    static var live: World {
        World(
            transcription: TranscriptionService.shared,
            network: NetworkMonitor.shared,
            blend: SessionsService.shared,
            chat: UnimplementedChatAdapter()
        )
    }
}
