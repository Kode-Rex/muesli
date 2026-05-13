//
//  TappableAttributedText.swift
//  Muesli
//
//  SwiftUI Text renders AttributedString but exposes no per-run gesture
//  hook. This wraps UITextView so individual ranges in the augmented
//  note body can be tapped to seek the chaptered playback view.
//

import SwiftUI
import UIKit

/// A region of the attributed text that the host wants to make tappable.
struct TappableTextTarget: Equatable {
    /// NSRange in the rendered NSAttributedString.
    let range: NSRange
    /// Audio target in seconds.
    let startSec: Double
}

struct TappableAttributedText: UIViewRepresentable {
    let attributed: AttributedString
    let targets: [TappableTextTarget]
    let onTap: (Double) -> Void

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isScrollEnabled = false
        view.isSelectable = true
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.dataDetectorTypes = []
        view.adjustsFontForContentSizeCategory = true
        view.font = .preferredFont(forTextStyle: .body)

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)
        context.coordinator.textView = view
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        let nsBase = NSAttributedString(attributed)
        let ns = NSMutableAttributedString(attributedString: nsBase)
        // Apply a baseline font so the system font + size match SwiftUI Text.
        let full = NSRange(location: 0, length: ns.length)
        ns.addAttribute(NSAttributedString.Key.font, value: UIFont.preferredFont(forTextStyle: .body), range: full)
        uiView.attributedText = ns
        context.coordinator.targets = targets
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var textView: UITextView?
        var targets: [TappableTextTarget] = []
        var onTap: (Double) -> Void = { _ in }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let textView, recognizer.state == .ended else { return }
            let layout = textView.layoutManager
            let container = textView.textContainer
            var location = recognizer.location(in: textView)
            location.x -= textView.textContainerInset.left
            location.y -= textView.textContainerInset.top
            let charIndex = layout.characterIndex(
                for: location,
                in: container,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
            guard charIndex >= 0 else { return }
            // Pick the first target whose range contains the index. Targets
            // are not expected to overlap (BlendRenderer produces flat
            // ranges from char-offset arrays).
            if let hit = targets.first(where: { NSLocationInRange(charIndex, $0.range) }) {
                onTap(hit.startSec)
            }
        }
    }
}
