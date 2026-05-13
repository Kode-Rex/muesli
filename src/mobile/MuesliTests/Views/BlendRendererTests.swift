//
//  BlendRendererTests.swift
//  MuesliTests
//
//  Unit tests for BlendRenderer: empty / single text / overlays /
//  image splitting / defensive against bad offsets.
//

import Testing
import Foundation
import SwiftData
@testable import Muesli

@Suite("Blend Renderer Tests", .tags(.unit))
struct BlendRendererTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Note.self, Photo.self, Conference.self, ChatThread.self, ChatMessage.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Renderer returns empty segments when blendedMarkdown is nil")
    @MainActor
    func emptyWhenNoMarkdown() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        container.mainContext.insert(note)
        let segments = BlendRenderer.render(note: note)
        #expect(segments.isEmpty)
    }

    @Test("Renderer returns a single text segment when no overlays or photos")
    @MainActor
    func singleTextSegment() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "Just plain prose."
        container.mainContext.insert(note)
        let segments = BlendRenderer.render(note: note)
        #expect(segments.count == 1)
        guard case .text(let attr) = segments[0] else {
            Issue.record("Expected .text segment")
            return
        }
        #expect(String(attr.characters) == "Just plain prose.")
    }

    @Test("Renderer bolds userNoteSpans ranges")
    @MainActor
    func userNoteSpansApplied() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "AI prose then USER NOTES and more AI."
        let bc = BlendCitations(
            userNoteSpans: [UserNoteSpan(start: 14, end: 24)],
            quoteSpans: [], imagePlacements: [], citations: []
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)
        container.mainContext.insert(note)

        let segments = BlendRenderer.render(note: note)
        #expect(segments.count == 1)
        guard case .text(let attr) = segments[0] else {
            Issue.record("Expected .text segment")
            return
        }
        let lo = attr.index(attr.startIndex, offsetByCharacters: 14)
        let hi = attr.index(attr.startIndex, offsetByCharacters: 24)
        let intent = attr[lo..<hi].runs.first?.inlinePresentationIntent
        #expect(intent == .stronglyEmphasized)
    }

    @Test("Renderer attaches quote start/end seconds to quoteSpans ranges")
    @MainActor
    func quoteSpanAttributesAttached() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "He said hello clearly."
        let bc = BlendCitations(
            userNoteSpans: [],
            quoteSpans: [QuoteSpan(start: 8, end: 13, transcriptStart: 12.5, transcriptEnd: 14.0, speaker: "S")],
            imagePlacements: [], citations: []
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)
        container.mainContext.insert(note)

        let segments = BlendRenderer.render(note: note)
        guard case .text(let attr) = segments[0] else {
            Issue.record("Expected .text segment")
            return
        }
        let lo = attr.index(attr.startIndex, offsetByCharacters: 8)
        let hi = attr.index(attr.startIndex, offsetByCharacters: 13)
        let run = attr[lo..<hi].runs.first
        #expect(run?.quoteStartSec == 12.5)
        #expect(run?.quoteEndSec == 14.0)
    }

    @Test("Renderer underlines citations and carries transcript range")
    @MainActor
    func citationAttributesAttached() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "He explained the demo well."
        let bc = BlendCitations(
            userNoteSpans: [], quoteSpans: [], imagePlacements: [],
            citations: [Citation(blendStart: 15, blendEnd: 19, transcriptStart: 30.0, transcriptEnd: 45.0)]
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)
        container.mainContext.insert(note)

        let segments = BlendRenderer.render(note: note)
        guard case .text(let attr) = segments[0] else {
            Issue.record("Expected .text segment")
            return
        }
        let lo = attr.index(attr.startIndex, offsetByCharacters: 15)
        let hi = attr.index(attr.startIndex, offsetByCharacters: 19)
        let run = attr[lo..<hi].runs.first
        #expect(run?.underlineStyle == .single)
        #expect(run?.citationTranscriptStart == 30.0)
        #expect(run?.citationTranscriptEnd == 45.0)
    }

    @Test("Renderer splits at imagePlacements and inserts photo cards")
    @MainActor
    func imagePlacementSplitting() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "Before image. After image."
        container.mainContext.insert(note)
        let photo = Photo(localPath: "/tmp/x.jpg", contentHash: "h", capturedAt: Date(), note: note)
        container.mainContext.insert(photo)
        note.photos.append(photo)

        let bc = BlendCitations(
            userNoteSpans: [], quoteSpans: [],
            imagePlacements: [ImagePlacement(imageId: photo.id.uuidString, charOffset: 13)],
            citations: []
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)

        let segments = BlendRenderer.render(note: note)
        #expect(segments.count == 3)
        if case .text(let a) = segments[0] {
            #expect(String(a.characters) == "Before image.")
        } else {
            Issue.record("expected text at [0]")
        }
        if case .photo(let p, _) = segments[1] {
            #expect(p.id == photo.id)
        } else {
            Issue.record("expected photo at [1]")
        }
        if case .text(let a) = segments[2] {
            #expect(String(a.characters) == " After image.")
        } else {
            Issue.record("expected text at [2]")
        }
    }

    @Test("Renderer clamps out-of-range spans and skips unresolved photos")
    @MainActor
    func defensiveAgainstBadOffsets() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "short"
        let bc = BlendCitations(
            userNoteSpans: [UserNoteSpan(start: 0, end: 9999)],
            quoteSpans: [],
            imagePlacements: [ImagePlacement(imageId: "missing-photo", charOffset: 3)],
            citations: []
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)
        container.mainContext.insert(note)

        let segments = BlendRenderer.render(note: note)
        #expect(segments.count == 1)
        guard case .text(let attr) = segments[0] else {
            Issue.record("expected text")
            return
        }
        #expect(String(attr.characters) == "short")
        let intent = attr.runs.first?.inlinePresentationIntent
        #expect(intent == .stronglyEmphasized)
    }
}
