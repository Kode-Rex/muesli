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

    @Test("Renderer handles overlapping spans (last applied wins)")
    @MainActor
    func overlappingSpans() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "abcdefghij"
        // Two userNoteSpans overlap on chars 3..6.
        let bc = BlendCitations(
            userNoteSpans: [UserNoteSpan(start: 0, end: 6), UserNoteSpan(start: 3, end: 9)],
            quoteSpans: [], imagePlacements: [], citations: []
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)
        container.mainContext.insert(note)

        let segments = BlendRenderer.render(note: note)
        guard case .text(let attr) = segments[0] else {
            Issue.record("expected text")
            return
        }
        // Both ranges set the same attribute value so we can't observe "last wins"
        // through stronglyEmphasized alone; what matters is no crash and the union
        // is bolded. Verify chars 0..9 are all stronglyEmphasized.
        for offset in 0..<9 {
            let idx = attr.index(attr.startIndex, offsetByCharacters: offset)
            let intent = attr.runs[idx].inlinePresentationIntent
            #expect(intent == .stronglyEmphasized, "offset \(offset) should be bolded")
        }
    }

    @Test("Renderer handles a photo at offset 0 (no leading text segment)")
    @MainActor
    func photoAtStart() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "After image."
        container.mainContext.insert(note)
        let photo = Photo(localPath: "/tmp/x.jpg", contentHash: "h", capturedAt: Date(), note: note)
        container.mainContext.insert(photo)
        note.photos.append(photo)
        let bc = BlendCitations(
            userNoteSpans: [], quoteSpans: [],
            imagePlacements: [ImagePlacement(imageId: photo.id.uuidString, charOffset: 0)],
            citations: []
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)

        let segments = BlendRenderer.render(note: note)
        #expect(segments.count == 2)
        if case .photo = segments[0] {} else { Issue.record("expected photo at [0]") }
        if case .text(let a) = segments[1] {
            #expect(String(a.characters) == "After image.")
        } else {
            Issue.record("expected text at [1]")
        }
    }

    @Test("Renderer handles a photo at the end of the text (no trailing text segment)")
    @MainActor
    func photoAtEnd() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "Before image."
        container.mainContext.insert(note)
        let photo = Photo(localPath: "/tmp/x.jpg", contentHash: "h", capturedAt: Date(), note: note)
        container.mainContext.insert(photo)
        note.photos.append(photo)
        let utf16Count = note.blendedMarkdown!.utf16.count
        let bc = BlendCitations(
            userNoteSpans: [], quoteSpans: [],
            imagePlacements: [ImagePlacement(imageId: photo.id.uuidString, charOffset: utf16Count)],
            citations: []
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)

        let segments = BlendRenderer.render(note: note)
        #expect(segments.count == 2)
        if case .text(let a) = segments[0] {
            #expect(String(a.characters) == "Before image.")
        } else {
            Issue.record("expected text at [0]")
        }
        if case .photo = segments[1] {} else { Issue.record("expected photo at [1]") }
    }

    @Test("Renderer handles two photos at the same offset")
    @MainActor
    func twoPhotosAtSameOffset() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "Before. After."
        container.mainContext.insert(note)
        let photoA = Photo(localPath: "/tmp/a.jpg", contentHash: "a", capturedAt: Date(), note: note)
        let photoB = Photo(localPath: "/tmp/b.jpg", contentHash: "b", capturedAt: Date(), note: note)
        container.mainContext.insert(photoA)
        container.mainContext.insert(photoB)
        note.photos.append(contentsOf: [photoA, photoB])
        let bc = BlendCitations(
            userNoteSpans: [], quoteSpans: [],
            imagePlacements: [
                ImagePlacement(imageId: photoA.id.uuidString, charOffset: 7),
                ImagePlacement(imageId: photoB.id.uuidString, charOffset: 7)
            ],
            citations: []
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)

        let segments = BlendRenderer.render(note: note)
        #expect(segments.count == 4)
        if case .text(let a) = segments[0] {
            #expect(String(a.characters) == "Before.")
        } else { Issue.record("[0] text") }
        if case .photo(let p, _) = segments[1] { #expect(p.id == photoA.id) } else { Issue.record("[1] photoA") }
        if case .photo(let p, _) = segments[2] { #expect(p.id == photoB.id) } else { Issue.record("[2] photoB") }
        if case .text(let a) = segments[3] {
            #expect(String(a.characters) == " After.")
        } else { Issue.record("[3] text") }
    }

    @Test("Renderer maps UTF-16 offsets correctly through multi-unit characters (emoji)")
    @MainActor
    func utf16OffsetsThroughEmoji() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        // "Hi 👋 there" — the wave emoji is 2 UTF-16 code units (a surrogate pair).
        // Selecting "there" via UTF-16 offsets: "Hi 👋 " is 6 UTF-16 units → 6..11.
        let markdown = "Hi 👋 there"
        note.blendedMarkdown = markdown
        let bc = BlendCitations(
            userNoteSpans: [UserNoteSpan(start: 6, end: 11)],
            quoteSpans: [], imagePlacements: [], citations: []
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)
        container.mainContext.insert(note)

        let segments = BlendRenderer.render(note: note)
        guard case .text(let attr) = segments[0] else {
            Issue.record("expected text")
            return
        }
        // The bolded substring should be exactly "there".
        let bolded = attr.runs.first { $0.inlinePresentationIntent == .stronglyEmphasized }
        #expect(bolded != nil)
        if let range = bolded?.range {
            #expect(String(attr[range].characters) == "there")
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
