//
//  SimpleNoteDetailView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import SwiftData
import UIKit
import AVFoundation

struct SimpleNoteDetailView: View {
    let note: Note

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingOptions = false
    @State private var showingEditTitle = false
    @State private var showingTranscript = false
    @State private var showingMyNotes = false
    @State private var showingEnhancedEditor = false
    @State private var editedTitle = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedImagePath: String?
    @State private var selectedImageWrapper: ImageWrapper?
    @State private var showingImagePicker = false
    @State private var imagesExpanded = true
    @State private var editedSummary = ""

    // Audio playback state
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var playbackPosition: TimeInterval = 0
    @State private var audioDuration: TimeInterval = 0
    @State private var playbackTimer: Timer?

    var body: some View {
        content
    }

    private var content: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.dateString)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(note.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))

                    // Audio player section
                    if note.hasAudio {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recording")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack(spacing: 16) {
                                // Play/Pause button
                                Button(action: togglePlayback) {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.teal)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    // Progress bar
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(height: 4)

                                            if audioDuration > 0 {
                                                Rectangle()
                                                    .fill(Color.teal)
                                                    .frame(width: geometry.size.width * CGFloat(playbackPosition / audioDuration), height: 4)
                                            }
                                        }
                                        .cornerRadius(2)
                                    }
                                    .frame(height: 4)

                                    // Time labels
                                    HStack {
                                        Text(formatTime(playbackPosition))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text(formatTime(audioDuration))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.bottom, 12)

                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }

                    // Captured images section (collapsable)
                    VStack(alignment: .leading, spacing: 12) {
                            // Header with collapse button
                            Button(action: {
                                withAnimation {
                                    imagesExpanded.toggle()
                                }
                            }) {
                                HStack {
                                    Text("Captured Images")
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Spacer()

                                    Image(systemName: imagesExpanded ? "chevron.down" : "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            if imagesExpanded {
                                // Image gallery
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        // Add new image button
                                        Button(action: {
                                            showingImagePicker = true
                                        }) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(width: 100, height: 100)

                                                Image(systemName: "plus")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(.white.opacity(0.6))
                                            }
                                        }

                                        // Existing images
                                        ForEach(note.imagePaths, id: \.self) { imagePath in
                                            if let image = loadImage(from: imagePath) {
                                                ZStack(alignment: .topTrailing) {
                                                    // Image thumbnail
                                                    Image(uiImage: image)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 100, height: 100)
                                                        .cornerRadius(8)
                                                        .clipped()
                                                        .onTapGesture {
                                                            if let img = loadImage(from: imagePath) {
                                                                selectedImageWrapper = ImageWrapper(image: img)
                                                            }
                                                        }

                                                    // Delete button
                                                    Button(action: {
                                                        deleteImage(imagePath)
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.system(size: 20))
                                                            .foregroundColor(.white)
                                                            .background(Circle().fill(Color.black.opacity(0.5)))
                                                    }
                                                    .padding(4)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 12)

                    Divider()
                        .background(Color.gray.opacity(0.3))

                    // AI Summary display
                    Group {
                        if note.content.isEmpty && note.transcriptionStatus == "processing" {
                            // Show loading indicator while transcribing
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .teal))
                                    .scaleEffect(1.5)

                                Text("Transcribing audio...")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else if let summary = note.aiSummary, !summary.isEmpty {
                            // Show editable AI-generated summary
                            VStack(alignment: .leading, spacing: 8) {
                                TextEditor(text: $editedSummary)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .frame(minHeight: 200)
                                    .onChange(of: editedSummary) { _, newValue in
                                        saveSummaryChanges(newValue)
                                    }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else if note.content.isEmpty {
                            // Show empty state
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)

                                Text("No transcription available")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)

                                if note.hasAudio {
                                    Text("Tap the play button above to listen to the recording")
                                        .font(.caption)
                                        .foregroundColor(.gray.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            // Fallback: show raw content if no summary
                            VStack(alignment: .leading, spacing: 8) {
                                NoteContentView(content: note.content)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.teal)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingOptions = true }) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .popover(isPresented: $showingOptions, attachmentAnchor: .point(.topTrailing), arrowEdge: .top) {
            NoteOptionsPopover(
                note: note,
                onEditTitle: {
                    editedTitle = note.title
                    showingEditTitle = true
                },
                onEditContent: {
                    showingEnhancedEditor = true
                },
                onViewTranscript: {
                    showingTranscript = true
                },
                onShowMyNotes: {
                    showingMyNotes = true
                },
                onArchive: {
                    archiveNote()
                },
                onDelete: {
                    deleteNote()
                },
                onClose: {
                    showingOptions = false
                }
            )
            .presentationCompactAdaptation(.popover)
        }
        .sheet(isPresented: $showingTranscript) {
            TranscriptView(title: note.title)
        }
        .sheet(isPresented: $showingMyNotes) {
            MyNotesView(title: note.title, content: note.content)
        }
        .sheet(isPresented: $showingEnhancedEditor) {
            EnhancedNoteEditorView(note: note)
        }
        .fullScreenCover(item: $selectedImageWrapper) { wrapper in
            FullscreenImageViewer(image: wrapper.image, onDismiss: {
                selectedImageWrapper = nil
            })
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(isPresented: $showingImagePicker, onImagePicked: { image in
                addNewImage(image)
            })
        }
        .alert("Edit Title", isPresented: $showingEditTitle) {
            TextField("Note title", text: $editedTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") { 
                saveEditedTitle()
            }
            .disabled(editedTitle.isEmpty)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupAudioPlayer()
            checkAndTriggerPendingTranscription()
            editedSummary = note.aiSummary ?? ""
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private func checkAndTriggerPendingTranscription() {
        // If note content is empty but has audio and is pending, trigger transcription
        guard note.content.isEmpty else {
            AppLogger.shared.debug("Note has content (\(note.content.count) chars), skipping transcription")
            return
        }
        guard note.transcriptionStatus == "pending" else {
            AppLogger.shared.debug("Note status is '\(note.transcriptionStatus)', not pending - skipping")
            return
        }
        guard let audioPath = note.audioFilePath else {
            AppLogger.shared.warning("No audio file path in note - cannot transcribe")
            return
        }

        AppLogger.shared.info("🎯 Note opened with pending transcription - triggering now for '\(note.title)'")

        // Update status to processing
        note.transcriptionStatus = "processing"
        do {
            try modelContext.save()
            AppLogger.shared.info("✅ Updated note status to 'processing'")
        } catch {
            AppLogger.shared.error("❌ Failed to update transcription status", error: error)
        }

        // Add a small delay to ensure UI updates
        Task {
            // Wait a moment to ensure permissions are ready
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            guard let audioURL = AudioRecordingManager.shared.getRecordingURL(fileName: audioPath) else {
                AppLogger.shared.warning("❌ Audio file not found for transcription: \(audioPath)")
                await MainActor.run {
                    note.transcriptionStatus = "failed"
                    try? modelContext.save()
                }
                return
            }

            AppLogger.shared.info("🎤 Starting transcription for audio file: \(audioURL.lastPathComponent)")

            do {
                let transcript = try await HybridTranscriptionService.shared.transcribeAudioFile(url: audioURL)

                AppLogger.shared.info("✅ Transcription completed: \(transcript.count) characters")

                await MainActor.run {
                    note.content = transcript
                    note.transcriptionStatus = "completed"

                    // Generate AI title and summary from transcript
                    note.title = SimpleSummaryGenerator.generateTitle(from: transcript)
                    note.aiSummary = SimpleSummaryGenerator.generateSummary(from: transcript)

                    do {
                        try modelContext.save()
                        AppLogger.shared.info("✅ Successfully saved transcribed note: '\(note.title)' (\(transcript.count) chars)")
                    } catch {
                        AppLogger.shared.error("❌ Failed to save transcribed content", error: error)
                        note.transcriptionStatus = "failed"
                    }
                }
            } catch {
                AppLogger.shared.error("❌ Transcription failed on view for '\(note.title)'", error: error)
                await MainActor.run {
                    note.transcriptionStatus = "failed"
                    do {
                        try modelContext.save()
                    } catch {
                        AppLogger.shared.error("❌ Failed to update failed status", error: error)
                    }
                }
            }
        }
    }

    // MARK: - Audio Playback Methods

    private func setupAudioPlayer() {
        guard let audioPath = note.audioFilePath else {
            AppLogger.shared.warning("No audio file path in note")
            return
        }

        guard let audioURL = AudioRecordingManager.shared.getRecordingURL(fileName: audioPath) else {
            AppLogger.shared.warning("Audio file not found at path: \(audioPath)")
            // Try to list what files ARE in the documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            if let files = try? FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil) {
                AppLogger.shared.info("Files in documents directory: \(files.map { $0.lastPathComponent }.joined(separator: ", "))")
            }
            return
        }

        AppLogger.shared.info("Loading audio from: \(audioURL.path)")

        do {
            // Configure audio session for playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.prepareToPlay()
            audioDuration = audioPlayer?.duration ?? 0
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int) ?? 0
            AppLogger.shared.info("Audio player loaded successfully - duration: \(audioDuration)s, file size: \(fileSize) bytes")
        } catch {
            AppLogger.shared.error("Failed to load audio file at \(audioURL.path)", error: error)
        }
    }

    private func togglePlayback() {
        guard let player = audioPlayer else { return }

        if isPlaying {
            player.pause()
            playbackTimer?.invalidate()
            playbackTimer = nil
        } else {
            player.play()
            startPlaybackTimer()
        }

        isPlaying.toggle()
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        playbackPosition = 0
    }

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = audioPlayer else { return }

            playbackPosition = player.currentTime

            if !player.isPlaying {
                // Playback finished
                isPlaying = false
                playbackPosition = 0
                playbackTimer?.invalidate()
                playbackTimer = nil
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Helper Methods

    private func loadImage(from path: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(path)

        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            AppLogger.shared.warning("Image not found at path: \(path)")
            return nil
        }

        guard let imageData = try? Data(contentsOf: imageURL),
              let image = UIImage(data: imageData) else {
            AppLogger.shared.warning("Failed to load image from path: \(path)")
            return nil
        }

        return image
    }

    private func saveEditedTitle() {
        do {
            note.title = editedTitle
            try modelContext.save()
        } catch {
            showError("Failed to update note title: \(error.localizedDescription)")
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    private func archiveNote() {
        do {
            note.isArchived = true
            try modelContext.save()
            AppLogger.shared.noteOperation(.archive, title: note.title)
            AppLogger.shared.userAction("Archive Note", context: note.title)
            dismiss() // Close the detail view after archiving
        } catch {
            showError("Failed to archive note: \(error.localizedDescription)")
        }
    }

    private func deleteImage(_ imagePath: String) {
        // Delete file from disk
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(imagePath)
        try? FileManager.default.removeItem(at: imageURL)

        // Remove from note's imagePaths array
        if let index = note.imagePaths.firstIndex(of: imagePath) {
            note.imagePaths.remove(at: index)

            do {
                try modelContext.save()
                AppLogger.shared.info("Deleted image: \(imagePath)")
            } catch {
                AppLogger.shared.error("Failed to save after deleting image", error: error)
            }
        }
    }

    private func addNewImage(_ image: UIImage) {
        // Save image to disk
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDirectory = documentsPath.appendingPathComponent("Images", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

            let timestamp = Int(Date().timeIntervalSince1970)
            let filename = "img_\(timestamp)_\(note.imagePaths.count).jpg"
            let fileURL = imagesDirectory.appendingPathComponent(filename)

            if let imageData = image.jpegData(compressionQuality: 0.8) {
                try imageData.write(to: fileURL)
                // Add to note's imagePaths array
                note.imagePaths.append("Images/\(filename)")

                try modelContext.save()
                AppLogger.shared.info("Added new image: \(filename)")
            }
        } catch {
            AppLogger.shared.error("Failed to add new image", error: error)
            showError("Failed to add image: \(error.localizedDescription)")
        }
    }

    private func deleteNote() {
        // Delete associated files if they exist
        if let audioPath = note.audioFilePath,
           let audioURL = AudioRecordingManager.shared.getRecordingURL(fileName: audioPath) {
            try? FileManager.default.removeItem(at: audioURL)
            AppLogger.shared.info("Deleted audio file: \(audioPath)")
        }

        // Delete associated images
        if !note.imagePaths.isEmpty {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            for imagePath in note.imagePaths {
                let imageURL = documentsPath.appendingPathComponent(imagePath)
                try? FileManager.default.removeItem(at: imageURL)
            }
            AppLogger.shared.info("Deleted \(note.imagePaths.count) image(s)")
        }

        // Delete the note from the database
        do {
            modelContext.delete(note)
            try modelContext.save()
            AppLogger.shared.noteOperation(.delete, title: note.title)
            AppLogger.shared.userAction("Delete Note", context: note.title)
            dismiss() // Close the detail view after deletion
        } catch {
            showError("Failed to delete note: \(error.localizedDescription)")
        }
    }

    private func saveSummaryChanges(_ newSummary: String) {
        // Debounce to avoid saving on every keystroke
        note.aiSummary = newSummary
        do {
            try modelContext.save()
        } catch {
            AppLogger.shared.error("Failed to save summary changes", error: error)
        }
    }

}

// Helper struct to make UIImage identifiable for sheet(item:)
private struct ImageWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

#Preview {
    let note = Note(
        title: "Sample Meeting Notes",
        content: """
        # Meeting Overview
        
        • Key discussion points covered
        • Action items identified
        • Follow-up meetings scheduled
        
        # Next Steps
        
        ○ Finalize project timeline
        ○ Schedule stakeholder review
        ○ Prepare documentation
        """,
        sessionType: "meeting"
    )
    
    SimpleNoteDetailView(note: note)
        .modelContainer(for: Note.self, inMemory: true)
        .environment(\.dataService, DataService(modelContext: ModelContext(try! ModelContainer(for: Note.self))))
}
