//
//  TranscriptionOrchestrator.swift
//  Muesli
//
//  Long-lived service that runs post-save transcription work with a
//  ModelContext it owns, decoupled from any view's lifecycle.
//

import Foundation
import SwiftData

@MainActor
final class TranscriptionOrchestrator {
    static let shared = TranscriptionOrchestrator()

    private var container: ModelContainer?

    private init() {}

    func setContainer(_ container: ModelContainer) {
        self.container = container
    }

    /// Run batch transcription for a note. Looks up the note in a fresh context
    /// to avoid using a context from the calling view that may be deallocated.
    func enqueueTranscription(noteId: PersistentIdentifier, audioPath: String) {
        guard let container else {
            AppLogger.shared.error("TranscriptionOrchestrator has no ModelContainer; call setContainer() at app launch")
            return
        }

        Task {
            let context = ModelContext(container)
            guard let note = context.model(for: noteId) as? Note else {
                AppLogger.shared.warning("Note not found for transcription: \(noteId)")
                return
            }
            guard let audioURL = AudioRecordingManager.shared.getRecordingURL(fileName: audioPath) else {
                AppLogger.shared.warning("Audio file not found for transcription: \(audioPath)")
                return
            }

            // Mark processing before the async network call so any other
            // ModelContext (e.g. the detail view's) sees the status change
            // and won't kick off a duplicate transcription.
            note.transcriptionStatus = "processing"
            do {
                try context.save()
            } catch {
                AppLogger.shared.error("Orchestrator failed to mark note processing", error: error)
                return
            }

            AppLogger.shared.info("Orchestrator starting batch transcription for '\(note.title)'")

            do {
                let transcript = try await World.current.hybridTranscription.transcribeAudioFile(url: audioURL)

                note.content = transcript
                note.transcriptionStatus = "completed"
                note.title = SimpleSummaryGenerator.generateTitle(from: transcript)
                note.aiSummary = SimpleSummaryGenerator.generateSummary(from: transcript, userNotes: note.userNotes)

                try context.save()
                AppLogger.shared.info("Orchestrator finished transcription for '\(note.title)' (\(transcript.count) chars)")
            } catch {
                note.transcriptionStatus = "failed"
                try? context.save()
                AppLogger.shared.error("Orchestrator transcription failed for '\(note.title)'", error: error)
            }
        }
    }
}
