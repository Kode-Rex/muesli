//
//  NewNoteView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import SwiftData
import AVFoundation
import UIKit

struct CapturedImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let timestamp: Date
}

struct NewNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Recording state
    @State private var recordingManager = AudioRecordingManager.shared
    @State private var transcriptionService = HybridTranscriptionService.shared
    @State private var networkMonitor = NetworkMonitor.shared

    // Note properties
    @State private var title = ""
    @State private var userNotes = "" // User's typed notes during recording
    @State private var conferenceName = ""
    @State private var sessionType = "note"

    // UI state
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isOnlineMode = false
    @State private var showingPermissionAlert = false
    @State private var showingImagePicker = false
    @State private var capturedImages: [CapturedImage] = []
    @State private var userEndedRecording = false
    @State private var recordingStartTime: Date?

    private let sessionTypes = ["note", "meeting", "session"]

    // Computed property to show appropriate icon based on availability
    private var cameraIconName: String {
        #if targetEnvironment(simulator)
        return "photo.on.rectangle"
        #else
        return UIImagePickerController.isSourceTypeAvailable(.camera) ? "camera.fill" : "photo.on.rectangle"
        #endif
    }

    // Prevent accidental pause button presses right after recording starts
    private var shouldDisablePauseButton: Bool {
        guard let startTime = recordingStartTime else { return false }
        return Date().timeIntervalSince(startTime) < 2.0 // Disable for first 2 seconds
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Recording status header
                    HStack {
                        Text("New Recording")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // Note card (current recording)
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.teal)
                                .font(.system(size: 20))
                                .frame(width: 40, height: 40)
                                .background(Color.teal.opacity(0.2))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                TextField("New Note", text: $title)
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .medium))
                                    .textFieldStyle(PlainTextFieldStyle())

                                HStack(spacing: 8) {
                                    Text(formatTime(recordingManager.recordingDuration))
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))

                                    // Recording mode indicator
                                    if recordingManager.state == .recording || recordingManager.state == .paused {
                                        HStack(spacing: 4) {
                                            Image(systemName: isOnlineMode ? "wifi" : "wifi.slash")
                                                .foregroundColor(isOnlineMode ? .green : .orange)
                                                .font(.system(size: 12))

                                            Text(isOnlineMode ? "Live transcription" : "Local recording")
                                                .foregroundColor(isOnlineMode ? .green : .orange)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                    }
                                }
                            }

                            Spacer()

                            // Camera Button
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                Image(systemName: cameraIconName)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.gray.opacity(0.3))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // Text input area
                        VStack(alignment: .leading, spacing: 8) {
                            Divider()
                                .background(Color.gray.opacity(0.3))
                                .padding(.horizontal, 20)

                            TextField("Feel free to write notes here...", text: $userNotes, axis: .vertical)
                                .foregroundColor(.white.opacity(0.9))
                                .font(.body)
                                .textFieldStyle(PlainTextFieldStyle())
                                .lineLimit(3...10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .frame(minHeight: 80)
                        }

                        // Captured images section
                        if !capturedImages.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                    .padding(.horizontal, 20)

                                Text("Attached images")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(capturedImages) { capturedImage in
                                            VStack(spacing: 4) {
                                                Image(uiImage: capturedImage.image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 80, height: 100)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                                Text(formatImageTimestamp(capturedImage.timestamp))
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        Spacer()
                    }
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    Spacer()

                    // Recording controls
                    recordingControlsView
                }
            }
            .navigationTitle("My Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // User profile placeholder
                    } label: {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            AppLogger.shared.info("NewNoteView appeared - setting up recording")
            setupRecording()
        }
        .onDisappear {
            AppLogger.shared.info("NewNoteView disappeared - running cleanup")
            cleanup()
        }
        .alert("Microphone Permission", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel") { }
        } message: {
            Text("Please allow microphone access to record notes.")
        }

        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(isPresented: $showingImagePicker) { image in
                addCapturedImage(image)
            }
        }
    }

    // MARK: - Recording Controls View

    @ViewBuilder
    private var recordingControlsView: some View {
        HStack(spacing: 30) {
            // Pause/Resume Button
            Button(action: {
                handleResumeOrPause()
            }) {
                Image(systemName: recordingManager.state == .recording ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.clear)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
            }
            .disabled(recordingManager.state == .idle || shouldDisablePauseButton)

            // Waveform and timer
            VStack(spacing: 8) {
                WaveformView()
                    .onChange(of: recordingManager.state) { oldValue, newValue in
                        AppLogger.shared.info("UI: Recording state changed from \(oldValue) to \(newValue)")
                    }
                    .onChange(of: recordingManager.audioLevel) { oldValue, newValue in
                        if abs(newValue - oldValue) > 0.1 {
                            AppLogger.shared.info("UI: Audio level changed from \(oldValue) to \(newValue)")
                        }
                    }

                Text(formatTime(recordingManager.recordingDuration))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.green)
                    .monospacedDigit()
                    .onChange(of: recordingManager.recordingDuration) { oldValue, newValue in
                        if Int(newValue) != Int(oldValue) {
                            AppLogger.shared.info("UI: Recording duration changed from \(oldValue) to \(newValue)")
                        }
                    }
            }

            // Stop Button — square stop icon matching the mockup.
            Button(action: {
                endRecording()
            }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityLabel("Stop recording")
            }
            .disabled(recordingManager.state == .idle)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    // MARK: - Helper Methods

    private func setupRecording() {
        // Check permissions
        recordingManager.checkPermission()
        if !recordingManager.hasPermission {
            Task {
                let granted = await recordingManager.requestPermission()
                if !granted {
                    showingPermissionAlert = true
                    return
                }
                await startRecording()
            }
        } else {
            Task {
                await startRecording()
            }
        }

        // Setup transcription callbacks
        transcriptionService.onTranscriptionUpdate = { _, _ in
            // Live transcription not used - we do batch transcription after recording
        }

        transcriptionService.onError = { error in
            DispatchQueue.main.async {
                // Gracefully handle transcription errors without disrupting the user
                AppLogger.shared.warning("Transcription service error - continuing with local recording: \(error.localizedDescription)")

                // Switch to offline mode instead of showing error
                self.isOnlineMode = false
            }
        }

        // Note: API endpoint should be configured programmatically or via settings
        // No need to prompt user for API keys on device
    }

    private func startRecording() async {
        do {
            // Start recording (always works locally)
            _ = try await recordingManager.startRecording()

            // Set recording start time for UI protection
            recordingStartTime = Date()

            // Try to start real-time transcription if possible
            isOnlineMode = await tryStartTranscription()

            // UI timer is handled by AudioRecordingManager

            let mode = isOnlineMode ? "Online with transcription" : "Offline (local recording only)"
            AppLogger.shared.info("Recording started - Mode: \(mode)")
        } catch {
            recordingStartTime = nil
            showError("Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func tryStartTranscription() async -> Bool {
        // Check if any transcription service is available
        guard transcriptionService.isLocalAvailable || transcriptionService.isCloudAvailable else {
            AppLogger.shared.info("No transcription service available - continuing with local recording only")
            return false
        }

        // Attempt to start hybrid transcription service
        do {
            try await transcriptionService.startRealtimeTranscription()
            AppLogger.shared.info("Hybrid transcription started - Active: \(transcriptionService.activeService)")
            return true
        } catch {
            AppLogger.shared.info("Transcription service unavailable - continuing with local recording only: \(error.localizedDescription)")
            return false
        }
    }

    private func handleResumeOrPause() {
        AppLogger.shared.info("handleResumeOrPause called - current state: \(recordingManager.state)")
        AppLogger.shared.info("Call Stack: \(Thread.callStackSymbols.prefix(3).joined(separator: "\n"))")

        switch recordingManager.state {
        case .recording:
            AppLogger.shared.info("Pausing recording from handleResumeOrPause")
            pauseRecording()
        case .paused:
            AppLogger.shared.info("Resuming recording from handleResumeOrPause")
            resumeRecording()
            default:
            AppLogger.shared.warning("handleResumeOrPause called with unexpected state: \(recordingManager.state)")
        }
    }

    private func pauseRecording() {
        recordingManager.pauseRecording()

        if isOnlineMode {
            transcriptionService.stopRealtimeTranscription()
        }
    }

    private func resumeRecording() {
        recordingManager.resumeRecording()

        if isOnlineMode {
            Task {
                do {
                    try await transcriptionService.startRealtimeTranscription()
                    AppLogger.shared.info("Transcription reconnected - Active: \(transcriptionService.activeService)")
                } catch {
                    // If transcription fails, switch to offline mode
                    isOnlineMode = false
                    AppLogger.shared.info("Transcription reconnection failed - continuing in offline mode: \(error.localizedDescription)")
                }
            }
        }
    }

    private func endRecording() {
        AppLogger.shared.info("endRecording called from NewNoteView - user initiated: \(userEndedRecording)")
        AppLogger.shared.info("Call Stack: \(Thread.callStackSymbols.prefix(5).joined(separator: "\n"))")

        // Only proceed if we're actually recording
        guard recordingManager.state == .recording || recordingManager.state == .paused else {
            AppLogger.shared.warning("endRecording called but recording state is: \(recordingManager.state)")
            return
        }

        userEndedRecording = true
        recordingManager.stopRecording()

        if isOnlineMode {
            transcriptionService.stopRealtimeTranscription()
        }

        // Save the note
        saveNote()
    }

    private func saveNote() {
        do {
            let conferenceValue = conferenceName.isEmpty ? nil : conferenceName
            // Generate AI title from user notes or use timestamp
            let finalTitle: String
            if !userNotes.isEmpty {
                finalTitle = SimpleSummaryGenerator.generateTitle(from: userNotes)
            } else {
                finalTitle = SimpleSummaryGenerator.timestampTitle()
            }

            // Determine transcription status based on audio availability
            let transcriptionStatus: String
            if recordingManager.currentRecordingPath != nil {
                // No transcription yet, but we have audio - try batch later
                transcriptionStatus = "pending"
            } else {
                // No transcription and no audio
                transcriptionStatus = "none"
            }

            // Save captured images to disk
            let savedImagePaths = saveImagesToDisk()

            // Generate initial summary from user notes if present
            let initialSummary = !userNotes.isEmpty
                ? SimpleSummaryGenerator.generateSummary(from: "", userNotes: userNotes)
                : nil

            let note = Note(
                title: finalTitle,
                content: "", // Transcript will be added later via transcription
                timestamp: Date(),
                conferenceName: conferenceValue,
                sessionType: sessionType,
                isArchived: false,
                audioFilePath: recordingManager.currentRecordingPath,
                transcriptionStatus: transcriptionStatus,
                duration: recordingManager.recordingDuration > 0 ? recordingManager.recordingDuration : nil,
                imagePaths: savedImagePaths,
                aiSummary: initialSummary,
                userNotes: userNotes // Save user's notes separately
            )

            modelContext.insert(note)
            try modelContext.save()

            // Hand the blend pipeline off to the long-lived orchestrator;
            // the view is about to dismiss and its modelContext should not
            // be used from an async task that outlives it.
            // TranscriptionOrchestrator is kept as a fallback for offline / legacy paths.
            if let audioPath = recordingManager.currentRecordingPath {
                BlendOrchestrator.shared.enqueueBlend(
                    noteId: note.persistentModelID,
                    audioPath: audioPath
                )
            }

            AppLogger.shared.info("Note saved - Duration: \(recordingManager.recordingDuration)s, Transcription: \(transcriptionStatus)")
            dismiss()
        } catch {
            showError("Failed to save note: \(error.localizedDescription)")
        }
    }

    private func cleanup() {
        AppLogger.shared.info("cleanup called - recording state: \(recordingManager.state), userEndedRecording: \(userEndedRecording)")

        // Only cancel if user didn't properly end the recording
        if (recordingManager.state == .recording || recordingManager.state == .paused) && !userEndedRecording {
            AppLogger.shared.info("cancelling active recording in cleanup because user didn't end it properly")
            recordingManager.cancelRecording()
        } else if recordingManager.state == .recording || recordingManager.state == .paused {
            AppLogger.shared.info("recording is still active but user ended it - stopping normally")
            recordingManager.stopRecording()
        }

        if transcriptionService.isTranscribing {
            AppLogger.shared.info("stopping transcription in cleanup")
            transcriptionService.stopRealtimeTranscription()
        }

        // Reset flags
        userEndedRecording = false
        recordingStartTime = nil
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatImageTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    private func addCapturedImage(_ image: UIImage) {
        let capturedImage = CapturedImage(image: image, timestamp: Date())
        capturedImages.append(capturedImage)
        AppLogger.shared.info("Image captured at \(formatImageTimestamp(capturedImage.timestamp))")
    }

    private func saveImagesToDisk() -> [String] {
        guard !capturedImages.isEmpty else { return [] }

        var savedPaths: [String] = []

        // Create images directory if it doesn't exist
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDirectory = documentsPath.appendingPathComponent("Images", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

            // Save each image
            for (index, capturedImage) in capturedImages.enumerated() {
                let timestamp = Int(capturedImage.timestamp.timeIntervalSince1970)
                let filename = "img_\(timestamp)_\(index).jpg"
                let fileURL = imagesDirectory.appendingPathComponent(filename)

                // Convert to JPEG data (compress to 0.8 quality)
                if let imageData = capturedImage.image.jpegData(compressionQuality: 0.8) {
                    try imageData.write(to: fileURL)
                    // Store relative path (just "Images/filename.jpg")
                    savedPaths.append("Images/\(filename)")
                    AppLogger.shared.info("Saved image to: \(filename)")
                }
            }
        } catch {
            AppLogger.shared.error("Failed to save images", error: error)
        }

        return savedPaths
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
