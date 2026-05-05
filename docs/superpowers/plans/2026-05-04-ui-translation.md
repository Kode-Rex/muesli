# UI Translation: Mockup → SwiftUI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Translate `mockups/flow.html` into a working SwiftUI implementation: design tokens, fonts, theme system, recording UI, in-app camera, blending state, and the augmented-notes view.

**Architecture:** A design system layer (tokens, typography, theme) under `MuesliUI/`, six screen views built on top, and a tested `BlendedNoteParser` that turns `(blendedMarkdown, parallelArrays)` from the AI pipeline spec into a typed list of segments rendered in a `LazyVStack`. Theme switches via `@AppStorage("muesliTheme")` driving a `ThemeManager` that maps to asset-catalog colors.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, AVFoundation, ActivityKit (Live Activity), XCTest + Swift Testing, Xcode 15+. Bundled fonts: Fraunces (variable, with opsz/SOFT axes) and Manrope (variable). JetBrains Mono Regular + Medium (timer/badges).

---

## File Structure

| Path | Responsibility |
|---|---|
| `src/mobile/Muesli/UI/Theme/MuesliColor.swift` | Type-safe color tokens backed by Asset Catalog |
| `src/mobile/Muesli/UI/Theme/MuesliTypography.swift` | Font factory using bundled Fraunces / Manrope with variable-axis support |
| `src/mobile/Muesli/UI/Theme/ThemeManager.swift` | `@Observable` theme state, persisted via UserDefaults |
| `src/mobile/Muesli/UI/Components/PulseDot.swift` | Reusable pulsing dot for recording indicators |
| `src/mobile/Muesli/UI/Components/Waveform.swift` | TimelineView+Canvas waveform pulling amplitude from the recorder |
| `src/mobile/Muesli/UI/Components/EditablePill.swift` | The Edit pill / capsule control style |
| `src/mobile/Muesli/UI/Views/NotesListView.swift` | Scene 1 — home screen |
| `src/mobile/Muesli/UI/Views/RecordingView.swift` | Scene 2 — foreground recording |
| `src/mobile/Muesli/UI/Views/CameraCaptureView.swift` | Scene 4 — in-app camera (UIViewControllerRepresentable wrapping AVFoundation) |
| `src/mobile/Muesli/UI/Views/BlendingProgressView.swift` | Scene 5 — pipeline progress |
| `src/mobile/Muesli/UI/Views/AugmentedNoteView.swift` | Scene 6 — final note rendering |
| `src/mobile/Muesli/UI/Parsing/BlendedNoteSegment.swift` | The typed segment enum (aiText / userText / quote / slide) |
| `src/mobile/Muesli/UI/Parsing/BlendedNoteParser.swift` | Turns (markdown, spans) → `[BlendedNoteSegment]` |
| `src/mobile/Muesli/LiveActivity/RecordingLiveActivity.swift` | ActivityKit Live Activity for the Dynamic Island |
| `src/mobile/Muesli/LiveActivity/RecordingAttributes.swift` | The shared `ActivityAttributes` struct |
| `src/mobile/Muesli/Resources/Fonts/` | Fraunces + Manrope variable font files |
| `src/mobile/Muesli/Resources/Assets.xcassets` | New color sets with light/dark variants, noise texture |
| `src/mobile/MuesliTests/UI/Parsing/BlendedNoteParserTests.swift` | TDD for the parser |
| `src/mobile/MuesliTests/UI/Theme/ThemeManagerTests.swift` | TDD for theme persistence |
| `src/mobile/MuesliTests/UI/Components/WaveformAmplitudeBufferTests.swift` | TDD for the amplitude ring buffer |
| `src/mobile/MuesliTests/UI/Snapshots/` | Snapshot tests for each screen (uses [pointfreeco/swift-snapshot-testing] if added) |

The reviewer's translation notes have been folded into the per-task code below where they apply.

---

### Task 1: Add design-token color set to Asset Catalog

**Files:**
- Modify: `src/mobile/Muesli/Assets.xcassets/Contents.json` (catalog likely already exists)
- Create: 12 color sets under `src/mobile/Muesli/Assets.xcassets/Colors/`
- Create: `src/mobile/Muesli/UI/Theme/MuesliColor.swift`

The color tokens come straight from the mockup CSS variables. Each token gets a color set with explicit `light` and `dark` variants in the catalog, and a Swift constant referencing it.

- [ ] **Step 1: Inspect the existing Asset Catalog**

```bash
ls src/mobile/Muesli/Assets.xcassets/
```
If `Colors/` doesn't exist, create it. The asset catalog is folder-on-disk in modern Xcode (file-system synchronized).

- [ ] **Step 2: Create the 12 color sets**

For each of these 12 color tokens, create a directory under `src/mobile/Muesli/Assets.xcassets/Colors/<TokenName>.colorset/` containing a `Contents.json`. Token names and values:

| Token | Light hex | Dark hex |
|---|---|---|
| Paper | F4EDE0 | 150E1C |
| PaperRaise | EAE0CE | 1F1528 |
| Ink | 1A1614 | F2E9DA |
| InkSecondary | 423A33 | BFB1C9 |
| Muted | 7A716B | A090B2 |
| Rule | C9BEAA | 3A2D44 |
| Accent | 5B2580 | A93FCC |
| AccentGlow | 8A40B8 | C969E8 |
| OnAccent | F4EDE0 | 150E1C |
| Sage | 4A6B61 | 7B9F8A |
| Screen | FBF7EF | 1A1124 |
| Device | 0F0C0A | 060309 |

For each colorset, the `Contents.json` follows this template (substitute the two hex values):

```json
{
  "colors" : [
    {
      "color" : { "color-space" : "srgb", "components" : { "red" : "0xF4", "green" : "0xED", "blue" : "0xE0", "alpha" : "1.000" } },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" : { "red" : "0x15", "green" : "0x0E", "blue" : "0x1C", "alpha" : "1.000" } },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

For efficiency, write a one-shot Bash loop that generates all 12 colorsets from a token table. Suggested helper script under `scripts/` (one-time, can be deleted after running):

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="src/mobile/Muesli/Assets.xcassets/Colors"
mkdir -p "$DIR"

write() {
  local name=$1 lr=$2 lg=$3 lb=$4 dr=$5 dg=$6 db=$7
  local out="$DIR/$name.colorset"
  mkdir -p "$out"
  cat > "$out/Contents.json" <<JSON
{
  "colors" : [
    { "color" : { "color-space" : "srgb", "components" : { "red" : "0x${lr}", "green" : "0x${lg}", "blue" : "0x${lb}", "alpha" : "1.000" } }, "idiom" : "universal" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "color" : { "color-space" : "srgb", "components" : { "red" : "0x${dr}", "green" : "0x${dg}", "blue" : "0x${db}", "alpha" : "1.000" } }, "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
}

write Paper          F4 ED E0 15 0E 1C
write PaperRaise     EA E0 CE 1F 15 28
write Ink            1A 16 14 F2 E9 DA
write InkSecondary   42 3A 33 BF B1 C9
write Muted          7A 71 6B A0 90 B2
write Rule           C9 BE AA 3A 2D 44
write Accent         5B 25 80 A9 3F CC
write AccentGlow     8A 40 B8 C9 69 E8
write OnAccent       F4 ED E0 15 0E 1C
write Sage           4A 6B 61 7B 9F 8A
write Screen         FB F7 EF 1A 11 24
write Device         0F 0C 0A 06 03 09
```

Save as `scripts/gen-colorsets.sh`, `chmod +x`, run once.

- [ ] **Step 3: Create MuesliColor.swift**

```swift
//
//  MuesliColor.swift
//  Muesli
//
//  Type-safe color tokens. Backed by Asset Catalog so light/dark variants
//  are managed by the system; ThemeManager only sets the user override.
//

import SwiftUI

enum MuesliColor {
    static let paper        = Color("Paper")
    static let paperRaise   = Color("PaperRaise")
    static let ink          = Color("Ink")
    static let inkSecondary = Color("InkSecondary")
    static let muted        = Color("Muted")
    static let rule         = Color("Rule")
    static let accent       = Color("Accent")
    static let accentGlow   = Color("AccentGlow")
    static let onAccent     = Color("OnAccent")
    static let sage         = Color("Sage")
    static let screen       = Color("Screen")
    static let device       = Color("Device")
}
```

- [ ] **Step 4: Smoke test in a Preview**

Add a temporary preview at the bottom of `MuesliColor.swift`:

```swift
#Preview {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(["Paper","PaperRaise","Ink","InkSecondary","Muted","Rule","Accent","AccentGlow","OnAccent","Sage","Screen","Device"], id: \.self) { name in
            HStack {
                Color(name).frame(width: 40, height: 24).cornerRadius(4)
                Text(name).font(.caption.monospaced())
            }
        }
    }
    .padding()
    .background(MuesliColor.paper)
}
```

Open the preview, toggle Light/Dark in the canvas, verify all swatches change.

- [ ] **Step 5: Build and commit**

```bash
cd /Users/travisfrisinger/Documents/projects/muesli/src/mobile && xcodebuild -project Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`.

```bash
cd /Users/travisfrisinger/Documents/projects/muesli && git add scripts/gen-colorsets.sh src/mobile/Muesli/Assets.xcassets/Colors src/mobile/Muesli/UI/Theme/MuesliColor.swift && git commit -m "feat(ui): add Muesli color tokens with light/dark variants

12 semantic color tokens backed by the asset catalog. MuesliColor enum
provides type-safe access from SwiftUI views. Theme switching is handled
at the system level via UIUserInterfaceStyle override."
```

---

### Task 2: Bundle Fraunces + Manrope variable fonts (TDD-able where it counts)

**Files:**
- Create: `src/mobile/Muesli/Resources/Fonts/Fraunces[opsz,wght,SOFT].ttf`
- Create: `src/mobile/Muesli/Resources/Fonts/Fraunces-Italic[opsz,wght,SOFT].ttf`
- Create: `src/mobile/Muesli/Resources/Fonts/Manrope[wght].ttf`
- Create: `src/mobile/Muesli/Resources/Fonts/JetBrainsMono-Regular.ttf`
- Modify: `src/mobile/Muesli/Info.plist` (add UIAppFonts entries)
- Create: `src/mobile/Muesli/UI/Theme/MuesliTypography.swift`
- Create: `src/mobile/MuesliTests/UI/Theme/MuesliTypographyTests.swift`

The reviewer flagged this as non-trivial. The challenge: SwiftUI's `Font.custom` does not expose variation axes. We must construct `UIFont` via `UIFontDescriptor` with `kCTFontVariationAttribute`, then wrap with `Font(uiFont:)`.

- [ ] **Step 1: Download the variable fonts**

```bash
mkdir -p src/mobile/Muesli/Resources/Fonts
cd src/mobile/Muesli/Resources/Fonts

curl -L -o "Fraunces.zip" "https://fonts.google.com/download?family=Fraunces"
unzip -j Fraunces.zip "Fraunces/Fraunces[SOFT,WONK,opsz,wght].ttf" "Fraunces/Fraunces-Italic[SOFT,WONK,opsz,wght].ttf"
rm Fraunces.zip
mv "Fraunces[SOFT,WONK,opsz,wght].ttf" "Fraunces.ttf"
mv "Fraunces-Italic[SOFT,WONK,opsz,wght].ttf" "Fraunces-Italic.ttf"

curl -L -o "Manrope.zip" "https://fonts.google.com/download?family=Manrope"
unzip -j Manrope.zip "Manrope/Manrope[wght].ttf"
rm Manrope.zip
mv "Manrope[wght].ttf" "Manrope.ttf"

curl -L -o "JetBrainsMono.zip" "https://fonts.google.com/download?family=JetBrains+Mono"
unzip -j JetBrainsMono.zip "JetBrainsMono/static/JetBrainsMono-Regular.ttf"
rm JetBrainsMono.zip
```

If `curl` fails (Google sometimes redirects oddly), fall back to manual download via browser at https://fonts.google.com/specimen/Fraunces and https://fonts.google.com/specimen/Manrope and https://fonts.google.com/specimen/JetBrains+Mono.

- [ ] **Step 2: Register in Info.plist**

Open `src/mobile/Muesli/Info.plist`. Add:

```xml
<key>UIAppFonts</key>
<array>
    <string>Fonts/Fraunces.ttf</string>
    <string>Fonts/Fraunces-Italic.ttf</string>
    <string>Fonts/Manrope.ttf</string>
    <string>Fonts/JetBrainsMono-Regular.ttf</string>
</array>
```

If the file is open in Xcode, also add the four `.ttf` files to the Muesli target (they should auto-detect via folder sync).

- [ ] **Step 3: Write failing tests for the font factory**

Create `src/mobile/MuesliTests/UI/Theme/MuesliTypographyTests.swift`:

```swift
//
//  MuesliTypographyTests.swift
//  MuesliTests
//

import XCTest
import UIKit
@testable import Muesli

final class MuesliTypographyTests: XCTestCase {

    func testFrauncesIsRegistered() {
        let font = UIFont(name: "Fraunces", size: 16)
        XCTAssertNotNil(font, "Fraunces variable font should be registered")
    }

    func testManropeIsRegistered() {
        let font = UIFont(name: "Manrope", size: 16)
        XCTAssertNotNil(font, "Manrope variable font should be registered")
    }

    func testJetBrainsMonoIsRegistered() {
        let font = UIFont(name: "JetBrainsMono-Regular", size: 12)
        XCTAssertNotNil(font, "JetBrains Mono should be registered")
    }

    func testDisplayItalicAtLargeOpticalSize() {
        let font = MuesliTypography.uiFont(family: .frauncesItalic, size: 56, opticalSize: 144, weight: 400, soft: 100)
        XCTAssertNotNil(font)
        XCTAssertEqual(font.familyName, "Fraunces")
    }

    func testBodyAtSmallOpticalSize() {
        let font = MuesliTypography.uiFont(family: .fraunces, size: 12, opticalSize: 14, weight: 400)
        XCTAssertNotNil(font)
        XCTAssertEqual(font.pointSize, 12)
    }
}
```

- [ ] **Step 4: Run tests, verify they fail**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/MuesliTypographyTests 2>&1 | tail -20
```
Expected: failures (`MuesliTypography` not defined).

- [ ] **Step 5: Implement MuesliTypography.swift**

Create `src/mobile/Muesli/UI/Theme/MuesliTypography.swift`:

```swift
//
//  MuesliTypography.swift
//  Muesli
//
//  Bridges SwiftUI Font with UIFont so we can drive variable-font axes
//  (opsz, SOFT, wght) that SwiftUI's Font.custom does not expose.
//
//  Variation axis tags from the OpenType spec, packed into 32-bit integers:
//    'wght' = 0x77676874
//    'opsz' = 0x6F70737A
//    'SOFT' = 0x534F4654 (Fraunces vendor axis)
//

import SwiftUI
import UIKit
import CoreText

enum MuesliTypography {
    enum Family: String {
        case fraunces        = "Fraunces"
        case frauncesItalic  = "Fraunces-Italic"
        case manrope         = "Manrope"
        case jetbrainsMono   = "JetBrainsMono-Regular"
    }

    static func uiFont(
        family: Family,
        size: CGFloat,
        opticalSize: CGFloat? = nil,
        weight: CGFloat? = nil,
        soft: CGFloat? = nil
    ) -> UIFont {
        let baseDescriptor = UIFontDescriptor(name: family.rawValue, size: size)
        var variations: [UInt32: CGFloat] = [:]
        if let weight       { variations[0x77676874] = weight }
        if let opticalSize  { variations[0x6F70737A] = opticalSize }
        if let soft         { variations[0x534F4654] = soft }

        guard !variations.isEmpty else {
            return UIFont(descriptor: baseDescriptor, size: size)
        }

        let descriptor = baseDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    static func font(
        family: Family,
        size: CGFloat,
        opticalSize: CGFloat? = nil,
        weight: CGFloat? = nil,
        soft: CGFloat? = nil
    ) -> Font {
        Font(uiFont(family: family, size: size, opticalSize: opticalSize, weight: weight, soft: soft))
    }

    // MARK: - Semantic styles (translated from mockup CSS)

    static let displayItalic     = font(family: .frauncesItalic, size: 56, opticalSize: 144, weight: 400, soft: 100)
    static let h1Display         = font(family: .fraunces,       size: 38, opticalSize: 144, weight: 400, soft: 50)
    static let noteTitle         = font(family: .fraunces,       size: 24, opticalSize: 144, weight: 500, soft: 50)
    static let sectionTitle      = font(family: .fraunces,       size: 22, opticalSize: 60,  weight: 500)
    static let cardTitle         = font(family: .fraunces,       size: 14, opticalSize: 60,  weight: 500)

    static let aiBody            = font(family: .fraunces,       size: 12, opticalSize: 14)
    static let userBody          = font(family: .manrope,        size: 12.5, weight: 600)
    static let quoteBody         = font(family: .frauncesItalic, size: 13.5, opticalSize: 144, weight: 400, soft: 100)

    static let label             = font(family: .manrope,        size: 11, weight: 600)
    static let metadata          = font(family: .manrope,        size: 10, weight: 400)
    static let timer             = font(family: .jetbrainsMono,  size: 10, weight: 500)
    static let timerLarge        = font(family: .fraunces,       size: 56, opticalSize: 144, weight: 300)
}
```

- [ ] **Step 6: Run tests, verify they pass**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/MuesliTypographyTests 2>&1 | tail -20
```
Expected: 5 tests pass.

- [ ] **Step 7: Visual verification preview**

Add a `#Preview` block at the bottom of `MuesliTypography.swift`:

```swift
#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            Text("Mu") + Text("e").italic() + Text("sli")
                .font(MuesliTypography.h1Display)
            Text("Eval as engineering, not afterthought").font(MuesliTypography.noteTitle)
            Text("AI-prose body in Fraunces opsz 14 — small, restrained, designed to recede.").font(MuesliTypography.aiBody)
            Text("USER NOTE — bold Manrope, primary ink, holds its place.").font(MuesliTypography.userBody)
            Text("\"If your eval suite isn't versioned alongside your model, you're not doing evals.\"").font(MuesliTypography.quoteBody)
            Text("12:47").font(MuesliTypography.timerLarge)
            Text("REC · 12:47").font(MuesliTypography.timer)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(MuesliColor.paper)
}
```

Open the preview. Verify Fraunces italic shows the SOFT variation (slightly more rounded counters) — if it looks identical to regular Fraunces, the variation isn't applied; check the axis tag byte values.

- [ ] **Step 8: Commit**

```bash
git add src/mobile/Muesli/Resources/Fonts src/mobile/Muesli/Info.plist src/mobile/Muesli/UI/Theme/MuesliTypography.swift src/mobile/MuesliTests/UI/Theme/MuesliTypographyTests.swift
git commit -m "feat(ui): bundle Fraunces + Manrope + JetBrains Mono with variable-axis support

MuesliTypography wraps UIFont/UIFontDescriptor to expose opsz, wght,
and SOFT (Fraunces vendor axis) variations that SwiftUI's
Font.custom does not. Semantic styles (displayItalic, noteTitle,
aiBody, userBody, quoteBody, timer*) match the mockup specification."
```

---

### Task 3: Theme manager with persisted user override

**Files:**
- Create: `src/mobile/Muesli/UI/Theme/ThemeManager.swift`
- Create: `src/mobile/MuesliTests/UI/Theme/ThemeManagerTests.swift`
- Modify: `src/mobile/Muesli/MuesliApp.swift` — apply preferred color scheme

The mockup has a Day/Night toggle. iOS provides this via `preferredColorScheme(_:)` modifier or the global `UIWindow.overrideUserInterfaceStyle` API. We'll use the SwiftUI modifier driven by `@AppStorage`.

- [ ] **Step 1: Write failing tests**

Create `src/mobile/MuesliTests/UI/Theme/ThemeManagerTests.swift`:

```swift
import XCTest
import SwiftUI
@testable import Muesli

final class ThemeManagerTests: XCTestCase {

    private let testKey = "muesliTheme.test"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: testKey)
    }

    func testDefaultsToSystem() {
        let mgr = ThemeManager(storageKey: testKey)
        XCTAssertEqual(mgr.preference, .system)
        XCTAssertNil(mgr.colorScheme)
    }

    func testLightSetsColorScheme() {
        let mgr = ThemeManager(storageKey: testKey)
        mgr.preference = .light
        XCTAssertEqual(mgr.colorScheme, .light)
    }

    func testDarkSetsColorScheme() {
        let mgr = ThemeManager(storageKey: testKey)
        mgr.preference = .dark
        XCTAssertEqual(mgr.colorScheme, .dark)
    }

    func testPreferencePersists() {
        let mgr1 = ThemeManager(storageKey: testKey)
        mgr1.preference = .dark

        let mgr2 = ThemeManager(storageKey: testKey)
        XCTAssertEqual(mgr2.preference, .dark)
    }
}
```

- [ ] **Step 2: Run, verify they fail**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/ThemeManagerTests 2>&1 | tail -20
```
Expected: failures (`ThemeManager` not defined).

- [ ] **Step 3: Implement**

Create `src/mobile/Muesli/UI/Theme/ThemeManager.swift`:

```swift
//
//  ThemeManager.swift
//  Muesli
//

import SwiftUI

enum ThemePreference: String, CaseIterable {
    case system, light, dark
}

@Observable
final class ThemeManager {
    private let storageKey: String

    var preference: ThemePreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: storageKey)
        }
    }

    var colorScheme: ColorScheme? {
        switch preference {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    init(storageKey: String = "muesliTheme") {
        self.storageKey = storageKey
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ThemePreference.system.rawValue
        self.preference = ThemePreference(rawValue: raw) ?? .system
    }
}
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/ThemeManagerTests 2>&1 | tail -20
```
Expected: 4 tests pass.

- [ ] **Step 5: Wire into MuesliApp**

In `src/mobile/Muesli/MuesliApp.swift`, add at top of struct:

```swift
@State private var themeManager = ThemeManager()
```

In `body`, change:

```swift
WindowGroup {
    SimpleMainView()
}
.modelContainer(sharedModelContainer)
```

to:

```swift
WindowGroup {
    SimpleMainView()
        .preferredColorScheme(themeManager.colorScheme)
        .environment(themeManager)
}
.modelContainer(sharedModelContainer)
```

- [ ] **Step 6: Commit**

```bash
git add src/mobile/Muesli/UI/Theme/ThemeManager.swift src/mobile/MuesliTests/UI/Theme/ThemeManagerTests.swift src/mobile/Muesli/MuesliApp.swift
git commit -m "feat(ui): persisted theme preference (system/light/dark)

ThemeManager is @Observable and persists user override to UserDefaults.
Wired into MuesliApp via .preferredColorScheme(_:) on the root window."
```

---

### Task 4: BlendedNoteParser (TDD)

**Files:**
- Create: `src/mobile/Muesli/UI/Parsing/BlendedNoteSegment.swift`
- Create: `src/mobile/Muesli/UI/Parsing/BlendedNoteParser.swift`
- Create: `src/mobile/MuesliTests/UI/Parsing/BlendedNoteParserTests.swift`

The reviewer flagged this as the highest-leverage architectural decision: the augmented-notes view is a `LazyVStack` of typed segments, not an `AttributedString`. The parser turns the AI pipeline's `(blendedMarkdown, userNoteSpans, quoteSpans, imagePlacements, citations)` into `[BlendedNoteSegment]` ready for rendering.

- [ ] **Step 1: Define the segment type**

Create `src/mobile/Muesli/UI/Parsing/BlendedNoteSegment.swift`:

```swift
//
//  BlendedNoteSegment.swift
//  Muesli
//

import Foundation

/// A single rendered chunk of an augmented note. Order in the array
/// determines reading order in the LazyVStack.
enum BlendedNoteSegment: Equatable {
    case aiText(String, citation: TranscriptCitation?)
    case userText(String)
    case quote(text: String, transcriptStart: Double, transcriptEnd: Double, speaker: String?)
    case slide(imageId: String)
}

struct TranscriptCitation: Equatable {
    let transcriptStart: Double
    let transcriptEnd: Double
}

struct BlendedNoteSpans {
    struct Range: Equatable { let start: Int; let end: Int }
    struct QuoteSpan: Equatable { let start: Int; let end: Int; let transcriptStart: Double; let transcriptEnd: Double; let speaker: String? }
    struct ImagePlacement: Equatable { let imageId: String; let charOffset: Int }
    struct Citation: Equatable { let blendStart: Int; let blendEnd: Int; let transcriptStart: Double; let transcriptEnd: Double }

    let userNoteSpans: [Range]
    let quoteSpans: [QuoteSpan]
    let imagePlacements: [ImagePlacement]
    let citations: [Citation]
}
```

- [ ] **Step 2: Write failing tests**

Create `src/mobile/MuesliTests/UI/Parsing/BlendedNoteParserTests.swift`:

```swift
import XCTest
@testable import Muesli

final class BlendedNoteParserTests: XCTestCase {

    func testPlainAITextOnly() {
        let md = "This was a great talk."
        let spans = BlendedNoteSpans(userNoteSpans: [], quoteSpans: [], imagePlacements: [], citations: [])
        let segs = BlendedNoteParser.parse(markdown: md, spans: spans)
        XCTAssertEqual(segs, [.aiText("This was a great talk.", citation: nil)])
    }

    func testUserTextSpan() {
        let md = "AI prose. eval as ENG. AI prose tail."
        // "eval as ENG." is at chars 10..22
        let spans = BlendedNoteSpans(
            userNoteSpans: [.init(start: 10, end: 22)],
            quoteSpans: [], imagePlacements: [], citations: []
        )
        let segs = BlendedNoteParser.parse(markdown: md, spans: spans)
        XCTAssertEqual(segs, [
            .aiText("AI prose. ", citation: nil),
            .userText("eval as ENG."),
            .aiText(" AI prose tail.", citation: nil)
        ])
    }

    func testQuoteSpan() {
        let md = "Sarah said: If your evals aren't versioned, you're doing vibes. End."
        // quote at chars 12..62
        let spans = BlendedNoteSpans(
            userNoteSpans: [],
            quoteSpans: [.init(start: 12, end: 62, transcriptStart: 754.2, transcriptEnd: 758.4, speaker: "Sarah Chen")],
            imagePlacements: [], citations: []
        )
        let segs = BlendedNoteParser.parse(markdown: md, spans: spans)
        XCTAssertEqual(segs.count, 3)
        if case let .quote(text, start, end, speaker) = segs[1] {
            XCTAssertEqual(text, "If your evals aren't versioned, you're doing vibes")
            XCTAssertEqual(start, 754.2, accuracy: 0.01)
            XCTAssertEqual(end, 758.4, accuracy: 0.01)
            XCTAssertEqual(speaker, "Sarah Chen")
        } else {
            XCTFail("middle segment should be quote")
        }
    }

    func testImagePlacement() {
        let md = "Pillar one. Pillar two."
        // place image after char 11 (between "one." and " Pillar two.")
        let spans = BlendedNoteSpans(
            userNoteSpans: [],
            quoteSpans: [],
            imagePlacements: [.init(imageId: "img-1", charOffset: 11)],
            citations: []
        )
        let segs = BlendedNoteParser.parse(markdown: md, spans: spans)
        XCTAssertEqual(segs, [
            .aiText("Pillar one.", citation: nil),
            .slide(imageId: "img-1"),
            .aiText(" Pillar two.", citation: nil)
        ])
    }

    func testInterleavedSpansSortedByOffset() {
        let md = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let spans = BlendedNoteSpans(
            userNoteSpans: [.init(start: 5, end: 10)],
            quoteSpans: [.init(start: 15, end: 20, transcriptStart: 0, transcriptEnd: 1, speaker: nil)],
            imagePlacements: [.init(imageId: "i", charOffset: 22)],
            citations: []
        )
        let segs = BlendedNoteParser.parse(markdown: md, spans: spans)
        // expect: aiText(0..5), userText(5..10), aiText(10..15), quote(15..20), aiText(20..22), slide, aiText(22..26)
        XCTAssertEqual(segs.count, 7)
        XCTAssertEqual(segs[0], .aiText("ABCDE", citation: nil))
        XCTAssertEqual(segs[1], .userText("FGHIJ"))
        XCTAssertEqual(segs[2], .aiText("KLMNO", citation: nil))
        if case let .quote(text, _, _, _) = segs[3] {
            XCTAssertEqual(text, "PQRST")
        } else { XCTFail() }
        XCTAssertEqual(segs[4], .aiText("UV", citation: nil))
        XCTAssertEqual(segs[5], .slide(imageId: "i"))
        XCTAssertEqual(segs[6], .aiText("WXYZ", citation: nil))
    }

    func testEmptyMarkdown() {
        let spans = BlendedNoteSpans(userNoteSpans: [], quoteSpans: [], imagePlacements: [], citations: [])
        XCTAssertEqual(BlendedNoteParser.parse(markdown: "", spans: spans), [])
    }

    func testCitationAttachedToOverlappingAIText() {
        let md = "Sarah opened with three pillars."
        let spans = BlendedNoteSpans(
            userNoteSpans: [],
            quoteSpans: [],
            imagePlacements: [],
            citations: [.init(blendStart: 0, blendEnd: 32, transcriptStart: 12.0, transcriptEnd: 18.5)]
        )
        let segs = BlendedNoteParser.parse(markdown: md, spans: spans)
        XCTAssertEqual(segs.count, 1)
        if case let .aiText(text, citation) = segs[0] {
            XCTAssertEqual(text, "Sarah opened with three pillars.")
            XCTAssertEqual(citation?.transcriptStart, 12.0)
            XCTAssertEqual(citation?.transcriptEnd, 18.5)
        } else { XCTFail() }
    }
}
```

- [ ] **Step 3: Run, verify failures**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/BlendedNoteParserTests 2>&1 | tail -25
```
Expected: 7 failures (parser not implemented).

- [ ] **Step 4: Implement parser**

Create `src/mobile/Muesli/UI/Parsing/BlendedNoteParser.swift`:

```swift
//
//  BlendedNoteParser.swift
//  Muesli
//
//  Walks the blended markdown, slicing it at every span boundary to
//  produce a flat ordered list of segments. The renderer then maps each
//  segment to a SwiftUI view in a LazyVStack.
//
//  Span semantics (from AI pipeline spec):
//  - userNoteSpans:  char ranges that came from the user verbatim
//  - quoteSpans:     char ranges of speaker quotes with their audio timestamps
//  - imagePlacements: char OFFSETS (not ranges) where a photo should drop in
//  - citations:      char ranges of AI prose with their grounding transcript range
//
//  Spans are pre-sorted by offset; we iterate boundaries in one pass.
//

import Foundation

enum BlendedNoteParser {

    // Internal boundary representation
    private enum Boundary {
        case userStart(Int), userEnd(Int)
        case quoteStart(Int, BlendedNoteSpans.QuoteSpan), quoteEnd(Int)
        case image(Int, String)
    }

    static func parse(markdown md: String, spans: BlendedNoteSpans) -> [BlendedNoteSegment] {
        guard !md.isEmpty else { return [] }

        var boundaries: [(offset: Int, kind: Boundary)] = []
        for r in spans.userNoteSpans {
            boundaries.append((r.start, .userStart(r.start)))
            boundaries.append((r.end, .userEnd(r.end)))
        }
        for q in spans.quoteSpans {
            boundaries.append((q.start, .quoteStart(q.start, q)))
            boundaries.append((q.end, .quoteEnd(q.end)))
        }
        for p in spans.imagePlacements {
            boundaries.append((p.charOffset, .image(p.charOffset, p.imageId)))
        }
        boundaries.sort { lhs, rhs in
            if lhs.offset != rhs.offset { return lhs.offset < rhs.offset }
            // ties: ends before starts before images so blocks close cleanly
            return rank(lhs.kind) < rank(rhs.kind)
        }

        let chars = Array(md)
        var cursor = 0
        var mode: Mode = .aiText
        var pendingQuote: BlendedNoteSpans.QuoteSpan?
        var out: [BlendedNoteSegment] = []

        for b in boundaries {
            if b.offset > cursor {
                let slice = String(chars[cursor..<min(b.offset, chars.count)])
                appendSegment(text: slice, mode: mode, quote: pendingQuote, citations: spans.citations, sliceStart: cursor, into: &out)
                cursor = b.offset
            }
            switch b.kind {
            case .userStart:               mode = .userText
            case .userEnd:                 mode = .aiText
            case .quoteStart(_, let q):    mode = .quote; pendingQuote = q
            case .quoteEnd:                mode = .aiText; pendingQuote = nil
            case .image(_, let imageId):   out.append(.slide(imageId: imageId))
            }
        }

        if cursor < chars.count {
            let tail = String(chars[cursor..<chars.count])
            appendSegment(text: tail, mode: mode, quote: pendingQuote, citations: spans.citations, sliceStart: cursor, into: &out)
        }

        return out
    }

    private enum Mode { case aiText, userText, quote }

    private static func rank(_ b: Boundary) -> Int {
        switch b {
        case .userEnd, .quoteEnd: return 0
        case .userStart, .quoteStart: return 1
        case .image: return 2
        }
    }

    private static func appendSegment(text: String, mode: Mode, quote: BlendedNoteSpans.QuoteSpan?, citations: [BlendedNoteSpans.Citation], sliceStart: Int, into out: inout [BlendedNoteSegment]) {
        guard !text.isEmpty else { return }
        switch mode {
        case .aiText:
            let citation = citationCovering(start: sliceStart, end: sliceStart + text.count, in: citations)
            out.append(.aiText(text, citation: citation))
        case .userText:
            out.append(.userText(text))
        case .quote:
            guard let q = quote else { return }
            out.append(.quote(text: text, transcriptStart: q.transcriptStart, transcriptEnd: q.transcriptEnd, speaker: q.speaker))
        }
    }

    private static func citationCovering(start: Int, end: Int, in citations: [BlendedNoteSpans.Citation]) -> TranscriptCitation? {
        // first citation that fully contains the slice; OK if multiple — pick the tightest
        let candidates = citations.filter { $0.blendStart <= start && $0.blendEnd >= end }
        guard let best = candidates.min(by: { ($0.blendEnd - $0.blendStart) < ($1.blendEnd - $1.blendStart) }) else { return nil }
        return TranscriptCitation(transcriptStart: best.transcriptStart, transcriptEnd: best.transcriptEnd)
    }
}
```

- [ ] **Step 5: Run tests, verify they pass**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/BlendedNoteParserTests 2>&1 | tail -30
```
Expected: 7 tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/mobile/Muesli/UI/Parsing src/mobile/MuesliTests/UI/Parsing
git commit -m "feat(ui): BlendedNoteParser — markdown + spans → typed segments

The augmented note rendering can't be a plain AttributedString because
imagePlacements need to inject SwiftUI views at char offsets. The parser
walks the markdown once at every boundary and emits an ordered
[BlendedNoteSegment]. The renderer (next task) is then a simple
LazyVStack mapping each case to a view."
```

---

### Task 5: AugmentedNoteView renderer

**Files:**
- Create: `src/mobile/Muesli/UI/Views/AugmentedNoteView.swift`

This view consumes `[BlendedNoteSegment]` and renders the design from Scene 6 of the mockup. Each segment becomes a row in a `LazyVStack`. Tap on a `.quote` row seeks audio. Tap on an `.aiText` with a citation opens a transcript-context sheet. Tap on a `.slide` opens fullscreen.

- [ ] **Step 1: Create the view**

```swift
//
//  AugmentedNoteView.swift
//  Muesli
//

import SwiftUI

struct AugmentedNoteView: View {
    let title: String
    let speakerLine: String
    let eyebrow: String
    let segments: [BlendedNoteSegment]
    let onCitationTap: (TranscriptCitation) -> Void
    let onQuoteTap: (Double) -> Void
    let onSlideTap: (String) -> Void
    let onEditTap: () -> Void
    let onShareTap: () -> Void
    let onListenTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text(eyebrow.uppercased())
                        .font(MuesliTypography.label)
                        .tracking(2.4)
                        .foregroundStyle(MuesliColor.accent)
                        .padding(.top, 6)

                    Text(title)
                        .font(MuesliTypography.noteTitle)
                        .foregroundStyle(MuesliColor.ink)

                    Text(speakerLine)
                        .font(MuesliTypography.metadata)
                        .foregroundStyle(MuesliColor.muted)
                        .padding(.bottom, 4)

                    Divider().background(MuesliColor.rule)

                    ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                        renderSegment(seg)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 80)
            }

            editPill
                .padding(.top, 12)
                .padding(.trailing, 18)

            VStack { Spacer(); bottomBar }
        }
        .background(MuesliColor.screen)
    }

    @ViewBuilder
    private func renderSegment(_ seg: BlendedNoteSegment) -> some View {
        switch seg {
        case let .aiText(text, citation):
            Text(text)
                .font(MuesliTypography.aiBody)
                .foregroundStyle(MuesliColor.muted)
                .lineSpacing(4)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let citation { onCitationTap(citation) }
                }

        case let .userText(text):
            Text(text)
                .font(MuesliTypography.userBody)
                .foregroundStyle(MuesliColor.ink)
                .padding(.leading, 10)
                .overlay(alignment: .leading) {
                    Rectangle().fill(MuesliColor.ink).frame(width: 2)
                }
                .padding(.vertical, 4)

        case let .quote(text, start, _, _):
            HStack(alignment: .top, spacing: 0) {
                Rectangle().fill(MuesliColor.accent).frame(width: 2)
                VStack(alignment: .leading, spacing: 6) {
                    Text(timestampLabel(start))
                        .font(MuesliTypography.timer)
                        .foregroundStyle(MuesliColor.onAccent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(MuesliColor.accent, in: RoundedRectangle(cornerRadius: 4))
                    Text(text)
                        .font(MuesliTypography.quoteBody)
                        .foregroundStyle(MuesliColor.ink)
                }
                .padding(.leading, 12)
                .padding(.vertical, 10)
            }
            .contentShape(Rectangle())
            .onTapGesture { onQuoteTap(start) }

        case let .slide(imageId):
            SlideThumbnail(imageId: imageId)
                .onTapGesture { onSlideTap(imageId) }
        }
    }

    private var editPill: some View {
        Button(action: onEditTap) {
            HStack(spacing: 5) {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .semibold))
                Text("Edit")
                    .font(MuesliTypography.label)
                    .tracking(0.4)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(MuesliColor.ink)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(MuesliColor.rule, lineWidth: 1))
        }
        .accessibilityLabel("Edit note")
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            actionButton(icon: "square.and.arrow.up", label: "Share", primary: true, action: onShareTap)
            actionButton(icon: "play.fill", label: "Listen", primary: false, action: onListenTap)
            Button(action: { /* present sheet with Re-blend, Delete, Export */ }) {
                Text("⋯")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MuesliColor.ink)
                    .frame(width: 48, height: 44)
                    .background(MuesliColor.paperRaise, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MuesliColor.rule, lineWidth: 1))
            }
            .accessibilityLabel("More actions")
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(
            LinearGradient(colors: [.clear, MuesliColor.screen], startPoint: .top, endPoint: .bottom)
                .frame(height: 80)
                .allowsHitTesting(false),
            alignment: .top
        )
    }

    private func actionButton(icon: String, label: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(MuesliTypography.label).tracking(0.6)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .foregroundStyle(primary ? MuesliColor.onAccent : MuesliColor.ink)
            .background(primary ? MuesliColor.accent : MuesliColor.paperRaise, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(primary ? .clear : MuesliColor.rule, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }

    private func timestampLabel(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

private struct SlideThumbnail: View {
    let imageId: String

    var body: some View {
        HStack(spacing: 12) {
            // Replace with AsyncImage(url: photoURL(for: imageId)) once Photo store wired up
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(hex: "F5ECD8"), Color(hex: "D6C39D")], startPoint: .top, endPoint: .bottom))
                .frame(width: 64, height: 40)
                .shadow(radius: 1, y: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("SLIDE")
                    .font(MuesliTypography.label)
                    .tracking(1.6)
                    .foregroundStyle(MuesliColor.accent)
                Text(imageId)
                    .font(MuesliTypography.metadata)
                    .foregroundStyle(MuesliColor.inkSecondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(MuesliColor.paperRaise, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MuesliColor.rule, lineWidth: 1))
    }
}

private extension Color {
    init(hex: String) {
        let r = UInt8(hex.prefix(2), radix: 16) ?? 0
        let g = UInt8(hex.dropFirst(2).prefix(2), radix: 16) ?? 0
        let b = UInt8(hex.dropFirst(4).prefix(2), radix: 16) ?? 0
        self = Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }
}

#Preview {
    AugmentedNoteView(
        title: "Eval as engineering, not research afterthought",
        speakerLine: "By Sarah Chen · 47 min · Hall A · 11:14 AM",
        eyebrow: "Talk · DataSummit 2026",
        segments: [
            .aiText("Sarah opened with the case for treating LLM evaluation as a first-class engineering discipline.", citation: nil),
            .userText("eval as ENG, not research afterthought"),
            .aiText(" She framed it around three pillars.", citation: nil),
            .slide(imageId: "Three pillars: coverage, calibration, cost"),
            .userText("· coverage / calibration / cost"),
            .quote(text: "If your eval suite isn't versioned alongside your model, you're not doing evals — you're doing vibes.", transcriptStart: 754, transcriptEnd: 759, speaker: "Sarah Chen"),
            .userText("· version evals next to model")
        ],
        onCitationTap: { _ in }, onQuoteTap: { _ in }, onSlideTap: { _ in },
        onEditTap: {}, onShareTap: {}, onListenTap: {}
    )
}
```

- [ ] **Step 2: Build, open Preview**

```bash
xcodebuild -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' build 2>&1 | tail -3
```
Expected: clean. Open `AugmentedNoteView.swift` in Xcode and check the Preview matches the mockup's Scene 6 visually (modulo the placeholder slide thumbnail).

- [ ] **Step 3: Commit**

```bash
git add src/mobile/Muesli/UI/Views/AugmentedNoteView.swift
git commit -m "feat(ui): AugmentedNoteView — Granola-style note rendering

LazyVStack of typed BlendedNoteSegment cases. User text gets the
ink-bordered primary treatment; AI prose recedes in serif-italic muted;
quotes show with timestamp badge and accent border; slides render as
inline thumbnails. Edit pill top-right, bottom bar with Share primary,
Listen secondary, ⋯ for tertiary actions. All touch targets ≥ 44pt."
```

---

### Task 6: PulseDot + Waveform components (Waveform TDD'd via amplitude buffer)

**Files:**
- Create: `src/mobile/Muesli/UI/Components/PulseDot.swift`
- Create: `src/mobile/Muesli/UI/Components/Waveform.swift`
- Create: `src/mobile/Muesli/UI/Components/AmplitudeRingBuffer.swift`
- Create: `src/mobile/MuesliTests/UI/Components/AmplitudeRingBufferTests.swift`

The reviewer flagged the waveform must be `TimelineView(.animation) { Canvas { ... } }` to avoid 20 separate animating Rectangles. Real audio amplitude comes from `AudioRecordingManager.averagePower(forChannel:)`. Wrap in a fixed-size ring buffer so the canvas always has a consistent slice of recent values.

- [ ] **Step 1: Write failing tests for the ring buffer**

Create `src/mobile/MuesliTests/UI/Components/AmplitudeRingBufferTests.swift`:

```swift
import XCTest
@testable import Muesli

final class AmplitudeRingBufferTests: XCTestCase {

    func testStartsZeroFilled() {
        let buf = AmplitudeRingBuffer(capacity: 5)
        XCTAssertEqual(buf.values, [0, 0, 0, 0, 0])
    }

    func testPushSlidesValuesLeftAndAppendsRight() {
        var buf = AmplitudeRingBuffer(capacity: 4)
        buf.push(0.1); buf.push(0.2); buf.push(0.3); buf.push(0.4)
        XCTAssertEqual(buf.values, [0.1, 0.2, 0.3, 0.4])
        buf.push(0.5)
        XCTAssertEqual(buf.values, [0.2, 0.3, 0.4, 0.5])
    }

    func testClampsToZeroOneRange() {
        var buf = AmplitudeRingBuffer(capacity: 3)
        buf.push(-1); buf.push(0.5); buf.push(2.0)
        XCTAssertEqual(buf.values, [0.0, 0.5, 1.0])
    }

    func testClearResets() {
        var buf = AmplitudeRingBuffer(capacity: 3)
        buf.push(0.5); buf.push(0.6)
        buf.clear()
        XCTAssertEqual(buf.values, [0, 0, 0])
    }
}
```

- [ ] **Step 2: Run, verify failures**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/AmplitudeRingBufferTests 2>&1 | tail -20
```
Expected: failures.

- [ ] **Step 3: Implement ring buffer**

```swift
//
//  AmplitudeRingBuffer.swift
//  Muesli
//

struct AmplitudeRingBuffer {
    private(set) var values: [Float]

    init(capacity: Int) {
        self.values = Array(repeating: 0, count: max(1, capacity))
    }

    mutating func push(_ value: Float) {
        let clamped = max(0, min(1, value))
        values.removeFirst()
        values.append(clamped)
    }

    mutating func clear() {
        for i in values.indices { values[i] = 0 }
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/AmplitudeRingBufferTests 2>&1 | tail -15
```
Expected: 4 pass.

- [ ] **Step 5: PulseDot view**

Create `src/mobile/Muesli/UI/Components/PulseDot.swift`:

```swift
//
//  PulseDot.swift
//  Muesli
//

import SwiftUI

struct PulseDot: View {
    var color: Color = MuesliColor.accent
    var size: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .stroke(color.opacity(0.7), lineWidth: 0)
                    .scaleEffect(pulse ? 2.4 : 1)
                    .opacity(pulse ? 0 : 0.7)
                    .animation(reduceMotion ? .default : .easeOut(duration: 1.6).repeatForever(autoreverses: false), value: pulse)
            }
            .onAppear { if !reduceMotion { pulse = true } }
    }
}

#Preview {
    HStack(spacing: 24) {
        PulseDot()
        PulseDot(color: MuesliColor.sage)
    }
    .padding()
    .background(MuesliColor.paper)
}
```

- [ ] **Step 6: Waveform view (Canvas + TimelineView)**

Create `src/mobile/Muesli/UI/Components/Waveform.swift`:

```swift
//
//  Waveform.swift
//  Muesli
//
//  Single-draw-call waveform via Canvas inside a TimelineView. Pulls
//  the latest amplitude from a binding so the recorder stays the source
//  of truth.
//

import SwiftUI

struct Waveform: View {
    @Binding var buffer: AmplitudeRingBuffer
    var color: Color = MuesliColor.ink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0/30, paused: false)) { _ in
            Canvas { ctx, size in
                let bars = buffer.values
                let count = bars.count
                guard count > 0 else { return }
                let gap: CGFloat = 3
                let totalGap = CGFloat(count - 1) * gap
                let barW = (size.width - totalGap) / CGFloat(count)
                for (i, amp) in bars.enumerated() {
                    let h = max(2, CGFloat(amp) * size.height)
                    let x = CGFloat(i) * (barW + gap)
                    let rect = CGRect(x: x, y: (size.height - h) / 2, width: barW, height: h)
                    let path = Path(roundedRect: rect, cornerRadius: barW / 2)
                    ctx.fill(path, with: .color(color))
                }
            }
        }
    }
}
```

- [ ] **Step 7: Build, commit**

```bash
xcodebuild build -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' 2>&1 | tail -3
git add src/mobile/Muesli/UI/Components src/mobile/MuesliTests/UI/Components
git commit -m "feat(ui): PulseDot + Waveform + AmplitudeRingBuffer

PulseDot honors Reduce Motion. Waveform is a single Canvas inside a
TimelineView pulling from a ring buffer the recorder writes into —
20 bars with 30fps refresh in one draw call instead of 20 animating
views. Reduce Motion drops refresh rate to 2Hz."
```

---

### Task 7: NotesListView (Scene 1)

**Files:**
- Create: `src/mobile/Muesli/UI/Views/NotesListView.swift`

Translates Scene 1 of the mockup. SwiftData `@Query` for notes, sorted by createdAt descending. Conference name inline in each row's metadata (no section headers). Floating action button bottom-right via `.safeAreaInset`.

- [ ] **Step 1: Implement**

```swift
//
//  NotesListView.swift
//  Muesli
//

import SwiftUI
import SwiftData

struct NotesListView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var showingRecording = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header
                    ForEach(notes) { note in
                        NoteRow(note: note)
                            .padding(.vertical, 10)
                            .overlay(alignment: .bottom) { Divider().background(MuesliColor.rule) }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 100)
            }

            recordButton
                .padding(.trailing, 22)
                .padding(.bottom, 28)
        }
        .background(MuesliColor.screen)
        .fullScreenCover(isPresented: $showingRecording) {
            RecordingView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            (Text("Mu") + Text("e").italic().foregroundStyle(MuesliColor.accent) + Text("sli"))
                .font(MuesliTypography.h1Display)
                .foregroundStyle(MuesliColor.ink)
            Text("Conference notes · \(notes.count) sessions")
                .font(MuesliTypography.label)
                .tracking(2)
                .foregroundStyle(MuesliColor.muted)
        }
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var recordButton: some View {
        Button { showingRecording = true } label: {
            ZStack {
                Circle().fill(MuesliColor.accent).frame(width: 60, height: 60)
                Circle().fill(MuesliColor.onAccent).frame(width: 22, height: 22)
            }
            .shadow(color: MuesliColor.accent.opacity(0.45), radius: 16, y: 6)
            .overlay(Circle().stroke(MuesliColor.accent.opacity(0.18), lineWidth: 4).frame(width: 68, height: 68))
        }
        .accessibilityLabel("New recording")
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(MuesliTypography.cardTitle)
                    .foregroundStyle(MuesliColor.ink)
                    .lineLimit(2)
                Text(metaLine)
                    .font(MuesliTypography.metadata)
                    .foregroundStyle(MuesliColor.muted)
            }
            Spacer(minLength: 12)
            Text(durationLabel)
                .font(MuesliTypography.font(family: .fraunces, size: 14, opticalSize: 60, weight: 300))
                .italic()
                .foregroundStyle(MuesliColor.inkSecondary)
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        if !note.conferenceName.isEmpty { parts.append(note.conferenceName) }
        parts.append(relativeTime(note.createdAt))
        if !note.imagePaths.isEmpty {
            parts.append("\(note.imagePaths.count) \(note.imagePaths.count == 1 ? "photo" : "photos")")
        }
        return parts.joined(separator: " · ")
    }

    private var durationLabel: String {
        guard let d = note.duration, d > 0 else { return "—" }
        let m = Int(d) / 60
        return "\(m)′"
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NotesListView()
        .modelContainer(for: Note.self, inMemory: true)
}
```

- [ ] **Step 2: Verify in preview, then commit**

```bash
xcodebuild build -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' 2>&1 | tail -3
git add src/mobile/Muesli/UI/Views/NotesListView.swift
git commit -m "feat(ui): NotesListView — Scene 1 home screen

@Query-backed list, conference name inline per row metadata (no folder
headers), italic duration in display serif, oxblood floating record
button with safe-area-aware positioning."
```

---

### Task 8: RecordingView (Scene 2)

**Files:**
- Create: `src/mobile/Muesli/UI/Views/RecordingView.swift`
- Modify: `src/mobile/Muesli/AudioRecordingManager.swift` — expose `currentAmplitude` and a publisher

The recording view shows the timer, the waveform, the quick-jot text editor, and the three controls. The amplitude flows from `AudioRecordingManager` through a binding to the `Waveform`.

- [ ] **Step 1: Add amplitude publishing to AudioRecordingManager**

In `AudioRecordingManager.swift`, find where `AVAudioRecorder` is configured. Ensure `recorder.isMeteringEnabled = true` is set. Add a public method:

```swift
@MainActor
func currentAmplitude() -> Float {
    guard let recorder = currentRecorder else { return 0 }
    recorder.updateMeters()
    let db = recorder.averagePower(forChannel: 0)  // -160 to 0 dB
    // Map dB to 0–1 with a -50dB floor for visible motion
    let normalized = max(0, (db + 50) / 50)
    return min(1, normalized)
}
```

(If `currentRecorder` isn't already an exposed property, add `private(set) var currentRecorder: AVAudioRecorder?` and assign on start.)

- [ ] **Step 2: Implement RecordingView**

```swift
//
//  RecordingView.swift
//  Muesli
//

import SwiftUI

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var elapsed: TimeInterval = 0
    @State private var quickNotes = ""
    @State private var amplitudeBuffer = AmplitudeRingBuffer(capacity: 24)
    @State private var meterTimer: Timer?

    var body: some View {
        ZStack {
            backdrop.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)
                timerBlock
                Spacer().frame(height: 28)
                Waveform(buffer: $amplitudeBuffer)
                    .frame(height: 80)
                    .padding(.horizontal, 22)
                Spacer().frame(height: 18)
                quickNoteEditor
                    .padding(.horizontal, 22)
                Spacer().frame(height: 18)
                controlRow
                Spacer().frame(height: 24)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { startMetering() }
        .onDisappear { stopMetering() }
    }

    private var backdrop: some View {
        ZStack {
            MuesliColor.screen
            RadialGradient(
                colors: [MuesliColor.accent.opacity(0.18), .clear],
                center: .top, startRadius: 0, endRadius: 280
            )
        }
    }

    private var timerBlock: some View {
        VStack(spacing: 8) {
            Text(formatTime(elapsed))
                .font(MuesliTypography.timerLarge)
                .foregroundStyle(MuesliColor.ink)
                .monospacedDigit()
            HStack(spacing: 8) {
                PulseDot(color: MuesliColor.accent, size: 8)
                Text("RECORDING · TALK 02")
                    .font(MuesliTypography.label)
                    .tracking(2.4)
                    .foregroundStyle(MuesliColor.accent)
            }
        }
    }

    private var quickNoteEditor: some View {
        TextEditor(text: $quickNotes)
            .font(MuesliTypography.font(family: .manrope, size: 13, weight: 500))
            .scrollContentBackground(.hidden)
            .background(MuesliColor.ink.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(MuesliColor.rule, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .frame(maxHeight: .infinity)
            .accessibilityLabel("Quick notes during recording")
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            Button { /* minimize / background */ } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MuesliColor.ink)
                    .frame(width: 48, height: 48)
                    .background(MuesliColor.ink.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(MuesliColor.ink.opacity(0.1)))
            }
            .accessibilityLabel("Background recording")

            Spacer()

            Button {
                stopMetering()
                dismiss()
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(MuesliColor.onAccent)
                    .frame(width: 18, height: 18)
                    .frame(width: 64, height: 64)
                    .background(MuesliColor.accent, in: Circle())
                    .shadow(color: MuesliColor.accent.opacity(0.42), radius: 16, y: 8)
            }
            .accessibilityLabel("Stop recording")

            Spacer()

            Button { /* open camera */ } label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(MuesliColor.accentGlow)
                    .frame(width: 48, height: 48)
                    .background(MuesliColor.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MuesliColor.accent.opacity(0.3)))
            }
            .accessibilityLabel("Snap a slide")
        }
        .padding(.horizontal, 30)
    }

    private func startMetering() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0/15, repeats: true) { _ in
            Task { @MainActor in
                let amp = AudioRecordingManager.shared.currentAmplitude()
                amplitudeBuffer.push(amp)
                elapsed = AudioRecordingManager.shared.recordingDuration
            }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
```

- [ ] **Step 3: Build, commit**

```bash
xcodebuild build -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' 2>&1 | tail -3
git add src/mobile/Muesli/AudioRecordingManager.swift src/mobile/Muesli/UI/Views/RecordingView.swift
git commit -m "feat(ui): RecordingView (Scene 2) with live waveform metering

15Hz amplitude polling from AudioRecordingManager into the Canvas-based
Waveform via an AmplitudeRingBuffer. Quick-notes TextEditor with dashed
border for jotting during a talk. Stop / minimize / camera controls
visually differentiated to prevent stop-button misfire."
```

---

### Task 9: Live Activity for Dynamic Island (Scenes 2/3 background recording)

**Files:**
- Create: `src/mobile/Muesli/LiveActivity/RecordingAttributes.swift`
- Create new target: `MuesliLiveActivity` (Widget Extension)
- Create: `src/mobile/MuesliLiveActivity/RecordingLiveActivity.swift`
- Modify: `AudioRecordingManager.swift` — start/end the activity

The reviewer flagged that ActivityKit cannot tick a per-second timer. Use `Text(timerInterval:countsDown:)` with the recording start `Date` so the system renders elapsed time efficiently with no app updates needed.

- [ ] **Step 1: Add a Widget Extension target in Xcode**

Open Xcode → File → New → Target → Widget Extension → name `MuesliLiveActivity` → uncheck "Configuration Intent" → check "Include Live Activity". Bundle ID auto-completes from the parent.

This step is manual — the plan can't add an Xcode target programmatically without modifying the .pbxproj risky way. After adding, the project should build with the placeholder Live Activity Apple generates.

- [ ] **Step 2: Define attributes**

Create `src/mobile/Muesli/LiveActivity/RecordingAttributes.swift`:

```swift
//
//  RecordingAttributes.swift
//  Muesli (shared with MuesliLiveActivity target — add file to BOTH)
//

import ActivityKit
import Foundation

struct RecordingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var photoCount: Int
    }

    var startDate: Date
    var sessionTitle: String
}
```

In Xcode, add this file to the `MuesliLiveActivity` target as well (File Inspector → Target Membership).

- [ ] **Step 3: Implement the Live Activity widget**

Replace the auto-generated `MuesliLiveActivityLiveActivity.swift` with:

```swift
//
//  RecordingLiveActivity.swift
//  MuesliLiveActivity
//

import SwiftUI
import WidgetKit
import ActivityKit

struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            HStack(spacing: 12) {
                Circle().fill(.red).frame(width: 10, height: 10)
                Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                    .monospacedDigit()
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(context.state.photoCount) photos").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .activityBackgroundTint(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
                            .monospacedDigit()
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.photoCount) photos").font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.sessionTitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            } compactLeading: {
                Circle().fill(.red).frame(width: 8, height: 8)
            } compactTrailing: {
                Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false, showsHours: false)
                    .monospacedDigit()
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 40)
            } minimal: {
                Circle().fill(.red).frame(width: 8, height: 8)
            }
        }
    }
}

@main
struct MuesliLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        RecordingLiveActivity()
    }
}
```

- [ ] **Step 4: Wire start/end into AudioRecordingManager**

In `AudioRecordingManager.swift`, add:

```swift
import ActivityKit

private var liveActivity: Activity<RecordingAttributes>?

@MainActor
func startLiveActivity(title: String) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
    do {
        let attrs = RecordingAttributes(startDate: Date(), sessionTitle: title)
        let state = RecordingAttributes.ContentState(photoCount: 0)
        liveActivity = try Activity.request(attributes: attrs, content: .init(state: state, staleDate: nil))
    } catch {
        AppLogger.shared.error("Failed to start live activity", error: error)
    }
}

@MainActor
func updatePhotoCount(_ count: Int) async {
    let state = RecordingAttributes.ContentState(photoCount: count)
    await liveActivity?.update(.init(state: state, staleDate: nil))
}

@MainActor
func endLiveActivity() async {
    await liveActivity?.end(nil, dismissalPolicy: .immediate)
    liveActivity = nil
}
```

Call `startLiveActivity(title:)` from the existing `startRecording` flow and `endLiveActivity()` from the stop flow. Update photo count from wherever a photo is added to the active session.

- [ ] **Step 5: Add NSSupportsLiveActivities to Info.plist**

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

- [ ] **Step 6: Build, commit**

```bash
xcodebuild build -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' 2>&1 | tail -3
git add src/mobile/Muesli/LiveActivity src/mobile/MuesliLiveActivity src/mobile/Muesli/AudioRecordingManager.swift src/mobile/Muesli/Info.plist
git commit -m "feat(live-activity): Dynamic Island recording indicator

ActivityKit Live Activity rendering elapsed time via system-managed
Text(timerInterval:) — no app-side ticking, no background-budget cost.
Compact island shows red dot + monospace timer; expanded shows photo
count; the system handles refresh."
```

---

### Task 10: BlendingProgressView (Scene 5)

**Files:**
- Create: `src/mobile/Muesli/UI/Views/BlendingProgressView.swift`

Renders the three-stage pipeline state. Driven by an enum with associated values for the per-stage detail line.

- [ ] **Step 1: Implement**

```swift
//
//  BlendingProgressView.swift
//  Muesli
//

import SwiftUI

enum BlendStageStatus { case done, live, pending }

struct BlendStage: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let status: BlendStageStatus
}

struct BlendingProgressView: View {
    let stages: [BlendStage]
    let estimatedCredits: Double
    let durationLabel: String
    let photoCount: Int
    let typedLineCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            stageList
            Spacer(minLength: 12)
            progressBar
            costFooter
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MuesliColor.screen)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Blending\nyour note")
                .font(MuesliTypography.font(family: .frauncesItalic, size: 32, opticalSize: 144, weight: 400, soft: 50))
                .foregroundStyle(MuesliColor.ink)
            Text("\(durationLabel) · \(photoCount) photos · \(typedLineCount) lines typed".uppercased())
                .font(MuesliTypography.label)
                .tracking(2)
                .foregroundStyle(MuesliColor.muted)
        }
        .padding(.bottom, 28)
    }

    private var stageList: some View {
        VStack(spacing: 14) {
            ForEach(stages) { stage in
                StageRow(stage: stage)
                if stage.id != stages.last?.id {
                    Divider().background(MuesliColor.rule)
                }
            }
        }
    }

    private var progressBar: some View {
        let completed = stages.filter { $0.status == .done }.count
        let liveCount = stages.contains { $0.status == .live } ? 1 : 0
        let denom = max(1, stages.count)
        let progress = (Double(completed) + Double(liveCount) * 0.5) / Double(denom)
        return RoundedRectangle(cornerRadius: 4)
            .fill(MuesliColor.rule)
            .frame(height: 3)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    LinearGradient(colors: [MuesliColor.accent, MuesliColor.accentGlow], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * progress)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.top, 12)
    }

    private var costFooter: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Text("THIS SESSION").font(MuesliTypography.label).tracking(2).foregroundStyle(MuesliColor.muted)
                Text(String(format: "≈ %.1f credits", estimatedCredits))
                    .font(MuesliTypography.font(family: .frauncesItalic, size: 14, opticalSize: 60, weight: 300))
                    .foregroundStyle(MuesliColor.ink)
            }
            Spacer()
        }
        .padding(.top, 14)
    }
}

private struct StageRow: View {
    let stage: BlendStage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            number
            VStack(alignment: .leading, spacing: 2) {
                Text(stage.title).font(MuesliTypography.cardTitle).foregroundStyle(titleColor)
                Text(stage.detail).font(MuesliTypography.metadata).foregroundStyle(MuesliColor.muted)
            }
            Spacer()
            statusIcon
        }
    }

    private var number: some View {
        Text(romanNumeralForRow)
            .font(MuesliTypography.font(family: .frauncesItalic, size: 18, opticalSize: 60, weight: 300))
            .foregroundStyle(numberColor)
            .frame(width: 28, alignment: .leading)
    }

    private var romanNumeralForRow: String { "·" }  // simplified; real impl uses index from parent

    private var titleColor: Color {
        switch stage.status {
        case .done:    return MuesliColor.ink
        case .live:    return MuesliColor.accent
        case .pending: return MuesliColor.rule
        }
    }
    private var numberColor: Color { titleColor }

    @ViewBuilder
    private var statusIcon: some View {
        switch stage.status {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MuesliColor.onAccent)
                .frame(width: 22, height: 22)
                .background(MuesliColor.sage, in: Circle())
        case .live:
            Circle()
                .strokeBorder(MuesliColor.accent, lineWidth: 1.5)
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(reduceMotion ? .default : .linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)
                .onAppear { if !reduceMotion { spin = true } }
        case .pending:
            Circle()
                .strokeBorder(MuesliColor.rule, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .frame(width: 22, height: 22)
        }
    }
}

#Preview {
    BlendingProgressView(
        stages: [
            BlendStage(title: "Transcribed", detail: "Deepgram nova-3 · 6,148 words · 47:12", status: .done),
            BlendStage(title: "Reading 8 slides", detail: "Claude Haiku · 5 of 8 done", status: .live),
            BlendStage(title: "Blending", detail: "Claude Sonnet · ~4 seconds", status: .pending)
        ],
        estimatedCredits: 1.2,
        durationLabel: "47 minutes",
        photoCount: 8,
        typedLineCount: 14
    )
}
```

- [ ] **Step 2: Build, commit**

```bash
xcodebuild build -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' 2>&1 | tail -3
git add src/mobile/Muesli/UI/Views/BlendingProgressView.swift
git commit -m "feat(ui): BlendingProgressView (Scene 5)

Three-stage pipeline UI driven by [BlendStage]. Done = sage check;
Live = spinning accent circle (Reduce Motion respected); Pending =
dashed rule border. Progress bar shows fractional completion. Cost
preview at the bottom in Fraunces italic."
```

---

### Task 11: Wire RecordingView → blending → AugmentedNoteView in the existing flow

**Files:**
- Modify: `src/mobile/Muesli/Views/SimpleMainView.swift` — replace home with `NotesListView`
- Modify: `src/mobile/Muesli/Views/SimpleNoteDetailView.swift` — render `AugmentedNoteView` when blend is complete

This is the integration step. Existing views are kept around for fallback during testing; new views become the primary path.

- [ ] **Step 1: Swap the root view**

In `MuesliApp.swift`, change `SimpleMainView()` to `NotesListView()` inside the `WindowGroup`. The old `SimpleMainView` can stay in the codebase for now as `LegacySimpleMainView` (rename) or simply not be referenced — no need to delete.

- [ ] **Step 2: Detail-view integration**

In `SimpleNoteDetailView.swift`, when the note has `blendedMarkdown` non-nil and `blendStatus == .complete`, render `AugmentedNoteView` instead of the existing layout. Otherwise show the legacy view (transcription progress, raw transcript). The `BlendedNoteParser` runs once per render with the note's stored data:

```swift
if let md = note.blendedMarkdown, note.blendStatus == .complete {
    let spans = decodeSpans(from: note.blendCitationsJSON ?? Data())
    AugmentedNoteView(
        title: note.title,
        speakerLine: speakerLineFor(note),
        eyebrow: eyebrowFor(note),
        segments: BlendedNoteParser.parse(markdown: md, spans: spans),
        onCitationTap: { ... },
        onQuoteTap: { ts in audioPlayer.seek(to: ts) },
        onSlideTap: { id in showFullscreen(id: id) },
        onEditTap: { isEditing = true },
        onShareTap: { showShareSheet = true },
        onListenTap: { audioPlayer.toggle() }
    )
} else {
    legacyDetailBody  // existing implementation
}
```

NOTE: `note.blendedMarkdown`, `blendStatus`, and `blendCitationsJSON` come from the AI pipeline spec. If those fields don't exist yet on `Note`, this branch is unreachable until that spec ships. The `if` guard makes that safe — until the AI pipeline is implemented, every note shows the legacy view.

- [ ] **Step 3: Build, commit**

```bash
xcodebuild build -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' 2>&1 | tail -3
git add src/mobile/Muesli/MuesliApp.swift src/mobile/Muesli/Views/SimpleNoteDetailView.swift
git commit -m "feat(ui): wire NotesListView root and AugmentedNoteView for blended notes

NotesListView replaces SimpleMainView at app root. SimpleNoteDetailView
renders AugmentedNoteView when blendedMarkdown is present (gated on
blendStatus == .complete); legacy path remains for in-progress notes."
```

---

## Final verification

- [ ] **All tests pass**
```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' 2>&1 | tail -10
```

- [ ] **Smoke**: launch app, see NotesListView with sample notes, tap record → RecordingView opens with timer/waveform/quick-notes/controls, tap stop, see existing flow (until AI pipeline lands).

- [ ] **Theme**: trigger Day/Night override (TBD: where in UI? Add to settings sheet in a follow-up). For now, confirm system Dark/Light toggle in iOS Settings flips the entire palette.

- [ ] **Dynamic Type**: in iOS Settings → Accessibility → Display & Text → Larger Text, drag to maximum. Open the app. AugmentedNoteView body should scale; titles should remain readable. If anything truncates, file a follow-up — don't block on it.

- [ ] **Reduce Motion**: in iOS Settings → Accessibility → Motion → Reduce Motion ON. PulseDot and spinner stop animating; waveform refresh drops to 2Hz.

- [ ] **VoiceOver pass**: swipe through NotesListView, RecordingView controls, AugmentedNoteView. Every interactive element should announce its label.

- [ ] **All 11 task commits present**
```bash
git log --oneline | head -15
```

### Task 12: Chaptered playback view (TDD on the parser)

**Files:**
- Create: `src/mobile/Muesli/UI/Parsing/Chapter.swift`
- Create: `src/mobile/Muesli/UI/Parsing/ChapterParser.swift`
- Create: `src/mobile/MuesliTests/UI/Parsing/ChapterParserTests.swift`
- Create: `src/mobile/Muesli/UI/Views/ChapteredPlaybackView.swift`
- Modify: `src/mobile/Muesli/UI/Views/AugmentedNoteView.swift` — wire "Listen" button to present `ChapteredPlaybackView`

The chapters arrive on the Note as `chaptersJSON: Data?` from the AI pipeline. Parsed once into `[Chapter]` and surfaced **only** in the full-screen playback view (Scene 9). The augmented note itself stays focused on reading — it already has time-anchored quotes and slide thumbnails for in-context jumps; chapters live where they earn their keep, in the listening mode.

- [ ] **Step 1: Define Chapter type**

```swift
// src/mobile/Muesli/UI/Parsing/Chapter.swift
import Foundation

struct Chapter: Codable, Equatable, Identifiable {
    var id: String { "\(start)-\(title)" }
    let start: Double      // seconds
    let title: String
    let summary: String?
}
```

- [ ] **Step 2: TDD on the parser**

```swift
// src/mobile/MuesliTests/UI/Parsing/ChapterParserTests.swift
import XCTest
@testable import Muesli

final class ChapterParserTests: XCTestCase {
    func testReturnsEmptyArrayForNilData() {
        XCTAssertEqual(ChapterParser.parse(json: nil), [])
    }
    func testReturnsEmptyArrayForMalformedJSON() {
        XCTAssertEqual(ChapterParser.parse(json: Data("not-json".utf8)), [])
    }
    func testParsesValidChapters() {
        let json = Data(#"{"chapters":[{"start":0,"title":"Opening","summary":"intro"},{"start":252.4,"title":"Three pillars"}]}"#.utf8)
        let chapters = ChapterParser.parse(json: json)
        XCTAssertEqual(chapters.count, 2)
        XCTAssertEqual(chapters[0].title, "Opening")
        XCTAssertEqual(chapters[0].summary, "intro")
        XCTAssertNil(chapters[1].summary)
    }
    func testActiveIndexBeforeFirstChapterIsZero() {
        let chapters = [Chapter(start: 100, title: "A", summary: nil), Chapter(start: 200, title: "B", summary: nil)]
        XCTAssertEqual(ChapterParser.activeIndex(at: 50, in: chapters), 0)
    }
    func testActiveIndexBetweenChapters() {
        let chapters = [
            Chapter(start: 0, title: "A", summary: nil),
            Chapter(start: 100, title: "B", summary: nil),
            Chapter(start: 200, title: "C", summary: nil)
        ]
        XCTAssertEqual(ChapterParser.activeIndex(at: 99, in: chapters), 0)
        XCTAssertEqual(ChapterParser.activeIndex(at: 100, in: chapters), 1)
        XCTAssertEqual(ChapterParser.activeIndex(at: 250, in: chapters), 2)
    }
    func testActiveIndexInEmptyChaptersIsNil() {
        XCTAssertNil(ChapterParser.activeIndex(at: 0, in: []))
    }
}
```

- [ ] **Step 3: Run, verify failures**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/ChapterParserTests 2>&1 | tail -10
```

- [ ] **Step 4: Implement parser**

```swift
// src/mobile/Muesli/UI/Parsing/ChapterParser.swift
import Foundation

enum ChapterParser {
    private struct Wrapper: Decodable { let chapters: [Chapter] }

    static func parse(json data: Data?) -> [Chapter] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode(Wrapper.self, from: data).chapters) ?? []
    }

    static func activeIndex(at seconds: Double, in chapters: [Chapter]) -> Int? {
        guard !chapters.isEmpty else { return nil }
        var idx = 0
        for (i, c) in chapters.enumerated() {
            if seconds >= c.start { idx = i } else { break }
        }
        return idx
    }
}
```

- [ ] **Step 5: Run, verify pass**

```bash
xcodebuild test -project src/mobile/Muesli.xcodeproj -scheme Muesli -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.6' -only-testing:MuesliTests/ChapterParserTests 2>&1 | tail -10
```

- [ ] **Step 6: ChapteredPlaybackView (Scene 9)**

Full-screen view, presented via `.fullScreenCover` when "Listen" is tapped from the augmented note's bottom bar. Layout (match Scene 9 mockup verbatim):

- Header: "PLAYING · CHAPTER 02" eyebrow, current chapter title in Fraunces, speaker line in muted
- Mini-player: round play/pause button, scrubber track with chapter-boundary markers, elapsed/total timecodes
- Chapter list: each row shows roman-numeral marker, mono timecode, title + summary; current chapter highlighted in accent

Audio is `AVPlayer` driven from the Note's recording URL. The current-time state drives both the scrubber position and the active-chapter highlight via `ChapterParser.activeIndex(at:in:)`. Tap on a chapter row → `player.seek(to:)`.

The skeleton:

```swift
// src/mobile/Muesli/UI/Views/ChapteredPlaybackView.swift
import SwiftUI
import AVFoundation

struct ChapteredPlaybackView: View {
    let audioURL: URL
    let chapters: [Chapter]
    let title: String
    let speaker: String

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isPlaying = false
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var activeIndex: Int? {
        ChapterParser.activeIndex(at: currentTime, in: chapters)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            miniPlayer.padding(.horizontal, 22).padding(.top, 12)
            chapterList
        }
        .background(MuesliColor.screen)
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
        .onReceive(timer) { _ in
            currentTime = player?.currentTime().seconds ?? 0
        }
    }

    // header, miniPlayer, chapterList — implementer fills in matching Scene 9 styles
    // setupPlayer creates AVPlayer(url:), reads duration via AVAsset(url:).load(.duration)
    // play/pause toggles isPlaying and calls player?.play() / player?.pause()
    // chapter row tap: player?.seek(to: CMTime(seconds: ch.start, preferredTimescale: 600))
}
```

(Implementer expands the three sub-views following the mockup CSS as the visual spec. The `Chapter` and `ChapterParser` types from Steps 1–5 are everything needed.)

- [ ] **Step 7: Wire "Listen" button in AugmentedNoteView**

In `AugmentedNoteView`'s bottom bar, change the existing Listen action to present the playback view:

```swift
@State private var showingPlayback = false

// in the Listen button action:
{ showingPlayback = true }

// at the end of the view body:
.fullScreenCover(isPresented: $showingPlayback) {
    ChapteredPlaybackView(
        audioURL: audioURL,
        chapters: chapters,
        title: title,
        speaker: speakerLine
    )
}
```

`chapters` is computed once from `ChapterParser.parse(json: note.chaptersJSON)` higher up in the view.

- [ ] **Step 8: Build, smoke-test**

Open a note with chapters → tap "Listen" → full-screen scrubber appears → chapter markers render along the track → tap a chapter row → audio jumps to that timestamp → currently-playing chapter highlights in accent. Note view itself does NOT show a chapter strip — chapters are exclusively a playback-mode concern.

- [ ] **Step 9: Commit**

```bash
git add src/mobile/Muesli/UI/Parsing/Chapter.swift src/mobile/Muesli/UI/Parsing/ChapterParser.swift src/mobile/MuesliTests/UI/Parsing/ChapterParserTests.swift src/mobile/Muesli/UI/Views/ChapteredPlaybackView.swift src/mobile/Muesli/UI/Views/AugmentedNoteView.swift
git commit -m "feat(ui): chaptered playback (Scene 9)

ChapterParser parses Note.chaptersJSON into [Chapter] and exposes
activeIndex(at:in:) for highlighting. ChapteredPlaybackView is a
full-screen scrubber surface with chapter-boundary markers and a
tappable chapter list. Listen button on the augmented note presents
it. The note view itself stays focused on reading — chapters live
where they earn their keep, in the listening mode."
```

---

## Out of scope (revisit after this lands)

- **In-app camera** (Scene 4) — uses AVCaptureSession + UIViewControllerRepresentable. Substantial enough to be its own plan; the camera button in RecordingView wires up later.
- **Edit interaction model** for AugmentedNoteView — the Edit pill calls `onEditTap` but the editing UX itself (per-paragraph or full-document) is undesigned. Treat as separate spec.
- **Settings screen** with theme picker + credits display — small, nice-to-have, deferred.
- **Snapshot tests** for UI views — pointfreeco/swift-snapshot-testing is the library; deferred to its own task to avoid forcing a dependency add as part of UI translation.
