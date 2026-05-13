//
//  BlendRenderer.swift
//  Muesli
//
//  Pure value-type renderer that converts a Note's blend pipeline output
//  (blendedMarkdown + parallel char-range arrays + photos) into a list of
//  display segments. The view layer iterates the segments and draws each.
//

import Foundation
import SwiftUI

/// A single segment of the augmented-note display.
enum BlendSegment {
    case text(AttributedString)
    /// A full-width photo card with an optional caption from blend output.
    case photo(Photo, caption: String?)
}

enum BlendRenderer {

    /// Returns the list of display segments for a Note. Empty if the note has
    /// no `blendedMarkdown`. Defensive against bad span offsets (clamped + skipped).
    static func render(note: Note) -> [BlendSegment] {
        guard let markdown = note.blendedMarkdown, !markdown.isEmpty else { return [] }

        let citations: BlendCitations = (note.blendCitationsJSON.flatMap {
            try? JSONDecoder().decode(BlendCitations.self, from: $0)
        }) ?? BlendCitations(userNoteSpans: [], quoteSpans: [], imagePlacements: [], citations: [])

        // We render the raw markdown text as AttributedString without parsing.
        // The blend service emits char offsets into the raw source; any markdown
        // parser would shift indices and break the overlays.
        var base = AttributedString(markdown)

        applyUserNoteSpans(citations.userNoteSpans, on: &base)
        applyQuoteSpans(citations.quoteSpans, on: &base)
        applyCitations(citations.citations, on: &base)

        return splitAtImagePlacements(
            base: base,
            placements: citations.imagePlacements,
            photos: note.photos
        )
    }

    // MARK: - Overlays

    private static func applyUserNoteSpans(_ spans: [UserNoteSpan], on attr: inout AttributedString) {
        for span in spans {
            guard let range = range(in: attr, start: span.start, end: span.end) else { continue }
            attr[range].inlinePresentationIntent = .stronglyEmphasized
            attr[range].foregroundColor = .accentColor
        }
    }

    private static func applyQuoteSpans(_ spans: [QuoteSpan], on attr: inout AttributedString) {
        for span in spans {
            guard let range = range(in: attr, start: span.start, end: span.end) else { continue }
            attr[range].inlinePresentationIntent = .emphasized
            attr[range].quoteStartSec = span.transcriptStart
            attr[range].quoteEndSec = span.transcriptEnd
        }
    }

    private static func applyCitations(_ cites: [Citation], on attr: inout AttributedString) {
        for c in cites {
            guard let range = range(in: attr, start: c.blendStart, end: c.blendEnd) else { continue }
            attr[range].underlineStyle = .single
            attr[range].citationTranscriptStart = c.transcriptStart
            attr[range].citationTranscriptEnd = c.transcriptEnd
        }
    }

    // MARK: - Image placement splitting

    private static func splitAtImagePlacements(
        base: AttributedString,
        placements: [ImagePlacement],
        photos: [Photo]
    ) -> [BlendSegment] {
        let count = base.characters.count
        let photoById = Dictionary(uniqueKeysWithValues: photos.map { ($0.id.uuidString, $0) })

        let validPlacements = placements
            .filter { $0.charOffset >= 0 && $0.charOffset <= count }
            .filter { photoById[$0.imageId] != nil }
            .sorted { $0.charOffset < $1.charOffset }

        if validPlacements.isEmpty {
            return [.text(base)]
        }

        var segments: [BlendSegment] = []
        var cursor = 0
        for p in validPlacements {
            if p.charOffset > cursor {
                let lo = base.index(base.startIndex, offsetByCharacters: cursor)
                let hi = base.index(base.startIndex, offsetByCharacters: p.charOffset)
                segments.append(.text(AttributedString(base[lo..<hi])))
            }
            if let photo = photoById[p.imageId] {
                segments.append(.photo(photo, caption: nil))
            }
            cursor = p.charOffset
        }
        if cursor < count {
            let lo = base.index(base.startIndex, offsetByCharacters: cursor)
            segments.append(.text(AttributedString(base[lo..<base.endIndex])))
        }
        return segments
    }

    // MARK: - Range helper

    private static func range(in attr: AttributedString, start: Int, end: Int) -> Range<AttributedString.Index>? {
        let count = attr.characters.count
        let lo = max(0, min(start, count))
        let hi = max(lo, min(end, count))
        guard lo < hi else { return nil }
        let from = attr.index(attr.startIndex, offsetByCharacters: lo)
        let to = attr.index(attr.startIndex, offsetByCharacters: hi)
        return from..<to
    }
}

// MARK: - Custom AttributedString attribute keys

enum QuoteStartSecKey: AttributedStringKey {
    typealias Value = Double
    static let name = "quoteStartSec"
}

enum QuoteEndSecKey: AttributedStringKey {
    typealias Value = Double
    static let name = "quoteEndSec"
}

enum CitationStartSecKey: AttributedStringKey {
    typealias Value = Double
    static let name = "citationTranscriptStart"
}

enum CitationEndSecKey: AttributedStringKey {
    typealias Value = Double
    static let name = "citationTranscriptEnd"
}

extension AttributeScopes {
    struct MuesliBlendScope: AttributeScope {
        let quoteStartSec: QuoteStartSecKey
        let quoteEndSec: QuoteEndSecKey
        let citationTranscriptStart: CitationStartSecKey
        let citationTranscriptEnd: CitationEndSecKey
    }

    var muesli: MuesliBlendScope.Type { MuesliBlendScope.self }
}

extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.MuesliBlendScope, T>) -> T {
        self[T.self]
    }
}
