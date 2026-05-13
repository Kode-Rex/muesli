# Phase 3: BlendRenderer + AugmentedNoteView Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans or superpowers:subagent-driven-development.

**Goal:** Render `Note.blendedMarkdown` + the parallel `BlendCitations` (`userNoteSpans`, `quoteSpans`, `imagePlacements`, `citations`) + photos as a styled SwiftUI segment list. Add `AugmentedNoteView` that consumes the renderer for the augmented-note screen.

**Architecture:** A pure `BlendRenderer` value type that returns `[BlendSegment]`. Segments alternate between styled `AttributedString` text and `Photo` cards. The view iterates the segment list with `ForEach`. No SwiftUI markdown parsing in v1 — we render the raw text as `AttributedString` and apply char-range overlays directly, because the blend service emits char offsets into the raw markdown source and any markdown parser would shift those indices. Bold/italic gain is forfeited; user-note highlighting and quote/citation styling are preserved.

**Tech Stack:** SwiftUI, Swift Testing (`import Testing`), `AttributedString`.

**Spec reference:** `docs/superpowers/specs/2026-05-12-gap-close-design.md` § Component design: Augmented note renderer.

**Deferred to later phases:**
- Tap on `quoteSpans` / `citations` opening `ChapteredPlaybackView` (Phase 5 wires the scrubber)
- Edit affordances (AI-summary sheet, inline userNotes editor) — Phase 9 salvage
- Replacing `SimpleNoteDetailView` navigation everywhere — Phase 9
- Markdown formatting (bold/italic from the blend service's `**...**` etc.) — future polish

---

## File Structure

**Creating:**
- `src/mobile/Muesli/Views/AugmentedNoteView.swift` — flagship screen
- `src/mobile/Muesli/Views/Components/BlendRenderer.swift` — pure renderer + segment type
- `src/mobile/Muesli/Views/Components/SlideCard.swift` — photo card used inside segments
- `src/mobile/MuesliTests/Views/BlendRendererTests.swift` — renderer unit tests

---

## Task 1: `BlendSegment` + `BlendRenderer` skeleton

**Files:**
- Create: `src/mobile/Muesli/Views/Components/BlendRenderer.swift`
- Create: `src/mobile/MuesliTests/Views/BlendRendererTests.swift`

- [ ] **Step 1: Write the first failing test**

```swift
//
//  BlendRendererTests.swift
//  MuesliTests
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
}
```

- [ ] **Step 2: Run, expect FAIL (no BlendRenderer yet)**

Focused run:
```
cd src/mobile && xcodebuild test -scheme Muesli -destination "platform=iOS Simulator,name=iPhone 17,OS=26.1" -only-testing:MuesliTests/BlendRendererTests -parallel-testing-enabled NO
```

- [ ] **Step 3: Implement the minimal renderer**

Create `src/mobile/Muesli/Views/Components/BlendRenderer.swift`:

```swift
//
//  BlendRenderer.swift
//  Muesli
//
//  Pure value-type renderer that converts a Note's blend pipeline output
//  (blendedMarkdown + parallel char-range arrays + photos) into a list of
//  display segments. The view layer iterates the segments and draws each.
//

import Foundation

/// A single segment of the augmented-note display.
enum BlendSegment: Equatable {
    case text(AttributedString)
    /// A full-width photo card with optional caption (taken from blend output).
    case photo(Photo, caption: String?)
}

enum BlendRenderer {

    /// Returns the list of display segments for a Note. Empty if the note has
    /// no `blendedMarkdown`. Defensive against bad span offsets (clamped + skipped).
    static func render(note: Note) -> [BlendSegment] {
        guard let markdown = note.blendedMarkdown, !markdown.isEmpty else { return [] }

        // Decode citations (optional — empty fallback is fine).
        let citations: BlendCitations = (note.blendCitationsJSON.flatMap {
            try? JSONDecoder().decode(BlendCitations.self, from: $0)
        }) ?? BlendCitations(userNoteSpans: [], quoteSpans: [], imagePlacements: [], citations: [])

        // Build the base AttributedString from the raw markdown text. We do
        // NOT use SwiftUI's markdown init because the blend service's char
        // offsets are into the raw source, and parsing would shift indices.
        var base = AttributedString(markdown)

        // Apply overlays.
        applyUserNoteSpans(citations.userNoteSpans, on: &base)
        applyQuoteSpans(citations.quoteSpans, on: &base)
        applyCitations(citations.citations, on: &base)

        // Split at image placements into a sequence of text segments and photo cards.
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
            // Custom attributes documenting the audio target. The view layer
            // reads these to render a quote bar and (later) wire the tap.
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

        // Sort by offset ascending; drop offsets that point outside the string
        // or reference a photo not in note.photos.
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

// MARK: - Custom AttributedString attributes

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
```

- [ ] **Step 4: Run, expect PASS**

- [ ] **Step 5: Commit**

```bash
git add src/mobile/Muesli/Views/Components/BlendRenderer.swift \
        src/mobile/MuesliTests/Views/BlendRendererTests.swift

git commit -m "$(cat <<'EOF'
feat(ios): BlendRenderer — pure value renderer for blended notes

Converts a Note's blendedMarkdown + parallel char-range arrays
(userNoteSpans, quoteSpans, imagePlacements, citations) plus its
photos into a [BlendSegment] list. Each segment is either
.text(AttributedString) with attribute overlays applied or a
.photo(Photo, caption) card.

The renderer treats blendedMarkdown as raw source text rather than
parsing it through SwiftUI's markdown init, because the blend
service's char offsets are into the raw source and any markdown
parser would shift indices. Custom AttributedString attribute keys
carry transcript timestamps for later tap-to-seek wiring (Phase 5).

Defensive against bad span offsets (clamps + drops invalid ranges)
and photo placements pointing at photos no longer in note.photos.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Renderer overlay tests

**Files:**
- Test: `src/mobile/MuesliTests/Views/BlendRendererTests.swift` (extend)

- [ ] **Step 1: Add tests for userNoteSpans, quoteSpans, citations, image splitting, and edge cases**

```swift
    @Test("Renderer bolds userNoteSpans ranges")
    @MainActor
    func userNoteSpansApplied() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "AI prose then USER NOTES and more AI."
        let bc = BlendCitations(
            userNoteSpans: [UserNoteSpan(start: 14, end: 24)], // "USER NOTES"
            quoteSpans: [], imagePlacements: [], citations: []
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)
        container.mainContext.insert(note)

        let segments = BlendRenderer.render(note: note)
        #expect(segments.count == 1)
        guard case .text(let attr) = segments[0] else { Issue.record("expected text"); return }

        let lo = attr.index(attr.startIndex, offsetByCharacters: 14)
        let hi = attr.index(attr.startIndex, offsetByCharacters: 24)
        let attrs = attr[lo..<hi].runs.first?.inlinePresentationIntent
        #expect(attrs == .stronglyEmphasized)
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
        guard case .text(let attr) = segments[0] else { Issue.record("expected text"); return }
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
        guard case .text(let attr) = segments[0] else { Issue.record("expected text"); return }
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
        let photo = Photo(localPath: "/tmp/x.jpg", contentHash: "h", capturedAt: Date(), note: note)
        container.mainContext.insert(note)
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
        if case .text(let a) = segments[0] { #expect(String(a.characters) == "Before image.") } else { Issue.record("[0] text") }
        if case .photo(let p, _) = segments[1] { #expect(p.id == photo.id) } else { Issue.record("[1] photo") }
        if case .text(let a) = segments[2] { #expect(String(a.characters) == " After image.") } else { Issue.record("[2] text") }
    }

    @Test("Renderer clamps out-of-range spans and skips unresolved photos")
    @MainActor
    func defensiveAgainstBadOffsets() async throws {
        let container = try makeContainer()
        let note = Note(title: "x")
        note.blendedMarkdown = "short"
        let bc = BlendCitations(
            userNoteSpans: [UserNoteSpan(start: 0, end: 9999)],   // clamps to 5
            quoteSpans: [],
            imagePlacements: [ImagePlacement(imageId: "missing-photo", charOffset: 3)],
            citations: []
        )
        note.blendCitationsJSON = try JSONEncoder().encode(bc)
        container.mainContext.insert(note)

        let segments = BlendRenderer.render(note: note)
        // Unresolved photo dropped → single text segment.
        #expect(segments.count == 1)
        guard case .text(let attr) = segments[0] else { Issue.record("text"); return }
        #expect(String(attr.characters) == "short")
        // Bold applied across the whole string after clamping.
        let attrs = attr.runs.first?.inlinePresentationIntent
        #expect(attrs == .stronglyEmphasized)
    }
```

- [ ] **Step 2: Run, expect all PASS**

```
xcodebuild test ... -only-testing:MuesliTests/BlendRendererTests
```

- [ ] **Step 3: Commit**

```bash
git add src/mobile/MuesliTests/Views/BlendRendererTests.swift
git commit -m "test(ios): BlendRenderer overlays + image splitting + defensive cases

Covers userNoteSpans bolding, quoteSpans timestamp attributes,
citations underline + transcript range attributes, photo card
insertion at imagePlacements offsets, and the defensive clamp /
drop path for out-of-range spans and unresolved photo ids.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `SlideCard` component

**Files:**
- Create: `src/mobile/Muesli/Views/Components/SlideCard.swift`

- [ ] **Step 1: Create the component**

```swift
//
//  SlideCard.swift
//  Muesli
//
//  Full-width photo card used between text segments in AugmentedNoteView.
//  Loads the image from Photo.localPath; shows a placeholder if missing.
//

import SwiftUI

struct SlideCard: View {
    let photo: Photo
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let uiImage = loadImage() {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 180)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.secondary)
                    )
            }

            if let ocr = photo.ocrText, !ocr.isEmpty {
                Text(ocr)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.footnote)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 8)
    }

    private func loadImage() -> UIImage? {
        let url: URL? = photo.localPath.hasPrefix("/")
            ? URL(fileURLWithPath: photo.localPath)
            : AudioRecordingManager.shared.getRecordingURL(fileName: photo.localPath)
        guard let url else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/mobile/Muesli/Views/Components/SlideCard.swift
git commit -m "feat(ios): SlideCard component for AugmentedNoteView photo segments

Loads the image from Photo.localPath; shows a placeholder card if
the file is missing. Renders OCR text as a caption and the optional
blend-provided caption as a footnote.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `AugmentedNoteView`

**Files:**
- Create: `src/mobile/Muesli/Views/AugmentedNoteView.swift`

- [ ] **Step 1: Create the view**

```swift
//
//  AugmentedNoteView.swift
//  Muesli
//
//  Flagship note detail view: renders blendedMarkdown + parallel char-range
//  overlays + photo cards as a vertically-scrolling document.
//

import SwiftUI

struct AugmentedNoteView: View {
    let note: Note

    private var segments: [BlendSegment] {
        BlendRenderer.render(note: note)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header

                if segments.isEmpty {
                    blendStatusFallback
                } else {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                        switch seg {
                        case .text(let attr):
                            Text(attr)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        case .photo(let photo, let caption):
                            SlideCard(photo: photo, caption: caption)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let conf = note.resolvedConferenceName {
                    Text(conf)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accentColor)
                }
                if let speaker = note.speaker {
                    Text("· \(speaker)").font(.caption).foregroundColor(.secondary)
                }
                Text("· \(note.dateString)").font(.caption).foregroundColor(.secondary)
            }
            Text(note.title)
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var blendStatusFallback: some View {
        switch note.blendStatus {
        case .idle, .transcribing, .transcribed, .extracting, .blending:
            VStack(spacing: 8) {
                ProgressView()
                Text("Preparing note…").font(.footnote).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        case .failed:
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundColor(.orange)
                Text(note.blendError ?? "Blend failed.").font(.footnote)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
        case .complete:
            // blendedMarkdown nil despite .complete — unexpected. Show transcript or content.
            Text(note.transcript ?? note.content).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

```
xcodebuild build -scheme Muesli -destination "platform=iOS Simulator,name=iPhone 17,OS=26.1"
```

- [ ] **Step 3: Commit**

```bash
git add src/mobile/Muesli/Views/AugmentedNoteView.swift
git commit -m "feat(ios): AugmentedNoteView — flagship blended note display

Renders the BlendRenderer segment list. Header shows conference +
speaker + date eyebrow with the note title. Empty-segment state
shows a blend-status appropriate placeholder: a progress spinner
during the transcribe / blend pipeline, a failure card with the
blend error, and the raw transcript or content as a last-resort
fallback when status is .complete but blendedMarkdown is nil.

Tap-to-seek wiring on quoteSpans and citations comes in Phase 5
with ChapteredPlaybackView; the AttributedString attributes are
already in place to drive it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Phase 3 done when

- All four tasks committed.
- `BlendRendererTests` green: empty, single text, userNoteSpans, quoteSpans, citations, image splitting, defensive offsets — 7 tests.
- Build green; no warnings introduced.
- `AugmentedNoteView` renders a sample note in Xcode preview / simulator (manual smoke).

## Next plan

Phase 4 wires `MainView` + `ConferenceDetailView` (notes-list grouping and the conference hero), which in turn pushes `AugmentedNoteView` into the navigation stack.
