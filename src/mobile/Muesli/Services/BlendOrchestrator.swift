//
//  BlendOrchestrator.swift
//  Muesli
//
//  @MainActor singleton that coordinates the iOS side of the AI blend pipeline.
//  On note save, it creates a backend Session, uploads audio + photos, runs
//  the blend, and persists results (blendedMarkdown, citations, chapters, cost)
//  back onto the Note, updating blendStatus through each stage.
//

import Foundation
import SwiftData
import AVFoundation

// MARK: - Codable wrappers for blend pipeline outputs

struct BlendCitations: Codable {
    let userNoteSpans: [UserNoteSpan]
    let quoteSpans: [QuoteSpan]
    let imagePlacements: [ImagePlacement]
    let citations: [Citation]
}

struct ChaptersWrapper: Codable {
    let chapters: [ChapterDTO]
}

// MARK: - BlendOrchestrator

@MainActor
final class BlendOrchestrator {
    static let shared = BlendOrchestrator()
    private var container: ModelContainer?
    private init() {}

    func setContainer(_ container: ModelContainer) {
        self.container = container
    }

    /// Enqueues a detached Task that drives the full blend pipeline for a note.
    /// Safe to call immediately after ModelContext.save() in a view — the task
    /// uses its own ModelContext so the view's context lifetime is irrelevant.
    func enqueueBlend(noteId: PersistentIdentifier, audioPath: String) {
        guard let container else {
            AppLogger.shared.error("BlendOrchestrator has no ModelContainer; call setContainer() at app launch")
            return
        }
        Task.detached { [weak self] in
            await self?.runBlend(noteId: noteId, audioPath: audioPath, container: container)
        }
    }

    // MARK: - Private pipeline

    private func runBlend(noteId: PersistentIdentifier, audioPath: String, container: ModelContainer) async {
        let context = ModelContext(container)
        guard let note = context.model(for: noteId) as? Note else {
            AppLogger.shared.warning("BlendOrchestrator: Note not found for id \(noteId)")
            return
        }

        let svc = SessionsService.shared

        do {
            // 1. Status → transcribing
            await MainActor.run {
                note.blendStatus = .transcribing
                try? context.save()
            }

            // 2. Create backend session
            let sessionId = try await svc.createSession()
            AppLogger.shared.info("BlendOrchestrator: session created \(sessionId)")

            // 3. Upload audio
            guard let audioURL = AudioRecordingManager.shared.getRecordingURL(fileName: audioPath) else {
                throw NSError(
                    domain: "Muesli.BlendOrchestrator",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Audio file not found: \(audioPath)"]
                )
            }
            let duration: Double
            do {
                duration = try await AVAsset(url: audioURL).load(.duration).seconds
            } catch {
                // Fallback to the stored duration if AVAsset fails
                duration = note.duration ?? 0
                AppLogger.shared.warning("BlendOrchestrator: AVAsset duration read failed, using fallback \(duration)s — \(error.localizedDescription)")
            }
            try await svc.uploadAudio(sessionId: sessionId, audioURL: audioURL, durationSeconds: duration)
            AppLogger.shared.info("BlendOrchestrator: audio uploaded (\(duration)s)")

            // 4. Status → extracting
            await MainActor.run {
                note.blendStatus = .extracting
                try? context.save()
            }

            // 5. Upload each photo
            let photos = await MainActor.run { note.photos }
            for photo in photos {
                guard let jpeg = try? Data(contentsOf: URL(fileURLWithPath: photo.localPath)) else {
                    AppLogger.shared.warning("BlendOrchestrator: skipping photo with missing file \(photo.localPath)")
                    continue
                }
                do {
                    let resp = try await svc.uploadPhoto(sessionId: sessionId, photo: photo, jpegData: jpeg)
                    AppLogger.shared.info("BlendOrchestrator: photo uploaded \(resp.photoId)")
                } catch {
                    AppLogger.shared.warning("BlendOrchestrator: photo upload failed, continuing — \(error.localizedDescription)")
                }
            }

            // 6. Status → blending
            await MainActor.run {
                note.blendStatus = .blending
                try? context.save()
            }

            // 7. Run blend
            let userNotes = await MainActor.run { note.userNotes }
            let blend = try await svc.runBlend(sessionId: sessionId, userNotes: userNotes)
            AppLogger.shared.info("BlendOrchestrator: blend complete — \(blend.blendedMarkdown.count) chars, cost \(blend.costMicros)µ")

            // 8. Persist results → status .complete
            await MainActor.run {
                note.blendedMarkdown = blend.blendedMarkdown
                note.blendCitationsJSON = try? JSONEncoder().encode(BlendCitations(
                    userNoteSpans: blend.userNoteSpans,
                    quoteSpans: blend.quoteSpans,
                    imagePlacements: blend.imagePlacements,
                    citations: blend.citations
                ))
                note.chaptersJSON = try? JSONEncoder().encode(ChaptersWrapper(chapters: blend.chapters))
                note.blendCostMicros = blend.costMicros
                note.blendStatus = .complete
                note.blendError = nil
                try? context.save()
            }

        } catch {
            // 9. On any error → status .failed
            await MainActor.run {
                note.blendStatus = .failed
                note.blendError = error.localizedDescription
                try? context.save()
            }
            AppLogger.shared.error("BlendOrchestrator: blend failed for note \(noteId)", error: error)
        }
    }
}
