//
//  TestWorld.swift
//  MuesliTests
//
//  Installs a fully-faked World.current so no test reaches real network.
//  Tests can either call TestWorld.install() in setUp, or build their own
//  World composed of specific fakes via TestWorld.make().
//

import Foundation
@testable import Muesli

enum TestWorld {

    /// Replace World.current with a fully-faked World. Returns the fakes
    /// so the test can configure stubs and inspect recorded calls.
    @MainActor
    @discardableResult
    static func install(
        transcription: FakeTranscriptionAdapter = FakeTranscriptionAdapter(),
        network: FakeNetworkAdapter = FakeNetworkAdapter(),
        blend: FakeBlendAdapter = FakeBlendAdapter(),
        chat: any ChatPort = UnimplementedChatAdapter()
    ) -> (transcription: FakeTranscriptionAdapter, network: FakeNetworkAdapter, blend: FakeBlendAdapter) {
        World.current = World(
            transcription: transcription,
            network: network,
            blend: blend,
            chat: chat
        )
        return (transcription, network, blend)
    }

    /// Restore the live World (used in tearDown).
    @MainActor
    static func restore() {
        World.current = .live
    }
}
