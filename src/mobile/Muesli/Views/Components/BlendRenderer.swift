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
    ///
    /// Char offsets in BlendCitations are UTF-16 code-unit offsets into the raw
    /// `blendedMarkdown` source — that's what the Node blend service produces
    /// (Sonnet sees the same string-length semantics, `String.length` in JS).
    /// Swift's grapheme-cluster indices would drift on non-ASCII content, so
    /// translation goes through `String.UTF16View` → `String.Index` →
    /// `AttributedString.Index`.
    static func render(note: Note) -> [BlendSegment] {
        guard let markdown = note.blendedMarkdown, !markdown.isEmpty else { return [] }

        let citations: BlendCitations = (note.blendCitationsJSON.flatMap {
            try? JSONDecoder().decode(BlendCitations.self, from: $0)
        }) ?? BlendCitations(userNoteSpans: [], quoteSpans: [], imagePlacements: [], citations: [])

        // We render the raw markdown text as AttributedString without parsing.
        // The blend service emits char offsets into the raw source; any markdown
        // parser would shift indices and break the overlays.
        var base = AttributedString(markdown)

        applyUserNoteSpans(citations.userNoteSpans, source: markdown, on: &base)
        applyQuoteSpans(citations.quoteSpans, source: markdown, on: &base)
        applyCitations(citations.citations, source: markdown, on: &base)

        return splitAtImagePlacements(
            base: base,
            source: markdown,
            placements: citations.imagePlacements,
            photos: note.photos
        )
    }

    // MARK: - Overlays

    private static func applyUserNoteSpans(_ spans: [UserNoteSpan], source: String, on attr: inout AttributedString) {
        for span in spans {
            guard let range = range(in: attr, source: source, start: span.start, end: span.end) else {
                AppLogger.shared.warning("BlendRenderer: dropping userNoteSpan with bad range \(span.start)..<\(span.end)")
                continue
            }
            attr[range].inlinePresentationIntent = .stronglyEmphasized
            attr[range].foregroundColor = .accentColor
        }
    }

    private static func applyQuoteSpans(_ spans: [QuoteSpan], source: String, on attr: inout AttributedString) {
        for span in spans {
            guard let range = range(in: attr, source: source, start: span.start, end: span.end) else {
                AppLogger.shared.warning("BlendRenderer: dropping quoteSpan with bad range \(span.start)..<\(span.end)")
                continue
            }
            attr[range].inlinePresentationIntent = .emphasized
            attr[range].quoteStartSec = span.transcriptStart
            attr[range].quoteEndSec = span.transcriptEnd
        }
    }

    private static func applyCitations(_ cites: [Citation], source: String, on attr: inout AttributedString) {
        for c in cites {
            guard let range = range(in: attr, source: source, start: c.blendStart, end: c.blendEnd) else {
                AppLogger.shared.warning("BlendRenderer: dropping citation with bad range \(c.blendStart)..<\(c.blendEnd)")
                continue
            }
            attr[range].underlineStyle = .single
            attr[range].citationTranscriptStart = c.transcriptStart
            attr[range].citationTranscriptEnd = c.transcriptEnd
        }
    }

    // MARK: - Image placement splitting

    private static func splitAtImagePlacements(
        base: AttributedString,
        source: String,
        placements: [ImagePlacement],
        photos: [Photo]
    ) -> [BlendSegment] {
        let utf16Count = source.utf16.count
        let photoById = Dictionary(uniqueKeysWithValues: photos.map { ($0.id.uuidString, $0) })

        var validPlacements: [ImagePlacement] = []
        for p in placements {
            if p.charOffset < 0 || p.charOffset > utf16Count {
                AppLogger.shared.warning("BlendRenderer: dropping placement at offset \(p.charOffset) (markdown is \(utf16Count) UTF-16 units)")
                continue
            }
            if photoById[p.imageId] == nil {
                AppLogger.shared.warning("BlendRenderer: dropping placement for unknown photoId \(p.imageId)")
                continue
            }
            validPlacements.append(p)
        }
        validPlacements.sort { $0.charOffset < $1.charOffset }

        if validPlacements.isEmpty {
            return [.text(base)]
        }

        var segments: [BlendSegment] = []
        var cursor = 0
        for p in validPlacements {
            if p.charOffset > cursor,
               let lo = attributedIndex(in: base, source: source, utf16Offset: cursor),
               let hi = attributedIndex(in: base, source: source, utf16Offset: p.charOffset) {
                segments.append(.text(AttributedString(base[lo..<hi])))
            }
            if let photo = photoById[p.imageId] {
                segments.append(.photo(photo, caption: nil))
            }
            cursor = p.charOffset
        }
        if cursor < utf16Count,
           let lo = attributedIndex(in: base, source: source, utf16Offset: cursor) {
            segments.append(.text(AttributedString(base[lo..<base.endIndex])))
        }
        return segments
    }

    /// Returns the NSRanges of all tappable spans (quote spans + citations)
    /// inside an AttributedString produced by `render(note:)`. Each target
    /// carries the audio second to seek to. Offsets are UTF-16 code units to
    /// match `NSAttributedString` / `NSLayoutManager` semantics used by the
    /// hosting `UITextView`.
    static func tapTargets(in attr: AttributedString) -> [TappableTextTarget] {
        var targets: [TappableTextTarget] = []
        var nsLocation = 0
        for run in attr.runs {
            let runText = String(attr[run.range].characters)
            let utf16Length = runText.utf16.count
            let startSec: Double?
            if let q = run.quoteStartSec {
                startSec = q
            } else if let c = run.citationTranscriptStart {
                startSec = c
            } else {
                startSec = nil
            }
            if let target = startSec, utf16Length > 0 {
                targets.append(TappableTextTarget(
                    range: NSRange(location: nsLocation, length: utf16Length),
                    startSec: target
                ))
            }
            nsLocation += utf16Length
        }
        return targets
    }

    // MARK: - Index helpers

    /// Translates a UTF-16 code-unit offset into the source string into an
    /// `AttributedString.Index` on the parallel attributed string. Returns
    /// nil if the offset lands inside a surrogate pair or beyond the end.
    private static func attributedIndex(in attr: AttributedString, source: String, utf16Offset: Int) -> AttributedString.Index? {
        let utf16Count = source.utf16.count
        let clamped = max(0, min(utf16Offset, utf16Count))
        let stringIdx = String.Index(utf16Offset: clamped, in: source)
        return AttributedString.Index(stringIdx, within: attr)
    }

    private static func range(in attr: AttributedString, source: String, start: Int, end: Int) -> Range<AttributedString.Index>? {
        let utf16Count = source.utf16.count
        let lo = max(0, min(start, utf16Count))
        let hi = max(lo, min(end, utf16Count))
        guard lo < hi,
              let from = attributedIndex(in: attr, source: source, utf16Offset: lo),
              let to = attributedIndex(in: attr, source: source, utf16Offset: hi)
        else { return nil }
        return from..<to
    }
}

// MARK: - Custom AttributedString attribute keys

enum QuoteStartSecKey: CodableAttributedStringKey {
    typealias Value = Double
    static let name = "quoteStartSec"
}

enum QuoteEndSecKey: CodableAttributedStringKey {
    typealias Value = Double
    static let name = "quoteEndSec"
}

enum CitationStartSecKey: CodableAttributedStringKey {
    typealias Value = Double
    static let name = "citationTranscriptStart"
}

enum CitationEndSecKey: CodableAttributedStringKey {
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
