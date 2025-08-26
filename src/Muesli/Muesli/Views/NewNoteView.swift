//
//  NewNoteView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import SwiftData
import AVFoundation

struct NewNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Recording state
    @State private var recordingManager = AudioRecordingManager.shared
    @State private var transcriptionService = TranscriptionService.shared
    @State private var networkMonitor = NetworkMonitor.shared
    
    // Note properties
    @State private var title = ""
    @State private var content = ""
    @State private var conferenceName = ""
    @State private var sessionType = "note"
    
    // UI state
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var recordingTime: TimeInterval = 0
    @State private var isOnlineMode = false
    @State private var showingPermissionAlert = false
    
    // Timer for updating UI
    @State private var recordingTimer: Timer?
    
    private let sessionTypes = ["note", "meeting", "session"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Coming up section (matching your screenshot)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Coming up")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                            
                            Text("No upcoming meetings found")
                                .foregroundColor(.gray)
                                .font(.body)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Earlier today section header
                    HStack {
                        Text("Earlier today")
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
                                
                                Text(formatTime(recordingTime))
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        // Live transcription content
                        if !content.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                    .padding(.horizontal, 20)
                                
                                ScrollView {
                                    Text(content)
                                        .foregroundColor(.white.opacity(0.9))
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 20)
                                }
                                .frame(maxHeight: 200)
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
            setupRecording()
        }
        .onDisappear {
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
    }
    
    // MARK: - Recording Controls View
    
    @ViewBuilder
    private var recordingControlsView: some View {
        HStack(spacing: 30) {
            // Resume/Pause Button
            Button(action: {
                handleResumeOrPause()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: recordingManager.state == .recording ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(recordingManager.state == .recording ? "Pause" : "Resume")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            }
            .disabled(recordingManager.state == .idle)
            
            // Recording indicator and timer
            VStack(spacing: 4) {
                if recordingManager.state == .recording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .scaleEffect(1.0)
                            .opacity(1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: recordingManager.state == .recording)
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(formatTime(recordingTime))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            
            // End Button
            Button(action: {
                endRecording()
            }) {
                Text("End")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.teal)
                    .cornerRadius(25)
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
        transcriptionService.onTranscriptionUpdate = { result in
            DispatchQueue.main.async {
                self.content += result.text + " "
            }
        }
        
        transcriptionService.onError = { error in
            DispatchQueue.main.async {
                self.showError("Transcription error: \(error.localizedDescription)")
            }
        }
        
        // Note: API endpoint should be configured programmatically or via settings
        // No need to prompt user for API keys on device
    }
    
    private func startRecording() async {
        do {
            // Determine if we can use real-time transcription
            isOnlineMode = networkMonitor.isConnected && transcriptionService.hasValidAPIEndpoint
            
            // Start recording
            let fileName = try await recordingManager.startRecording()
            
            // Start real-time transcription if online
            if isOnlineMode {
                try await transcriptionService.startRealtimeTranscription()
            }
            
            // Start UI timer
            startRecordingTimer()
            
            AppLogger.shared.info("Recording started - Mode: \(isOnlineMode ? "Online" : "Offline")")
            
        } catch {
            showError("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    private func handleResumeOrPause() {
        switch recordingManager.state {
        case .recording:
            pauseRecording()
        case .paused:
            resumeRecording()
        default:
            break
        }
    }
    
    private func pauseRecording() {
        recordingManager.pauseRecording()
        stopRecordingTimer()
        
        if isOnlineMode {
            transcriptionService.stopRealtimeTranscription()
        }
    }
    
    private func resumeRecording() {
        recordingManager.resumeRecording()
        startRecordingTimer()
        
        if isOnlineMode {
            Task {
                try? await transcriptionService.startRealtimeTranscription()
            }
        }
    }
    
    private func endRecording() {
        recordingManager.stopRecording()
        stopRecordingTimer()
        
        if isOnlineMode {
            transcriptionService.stopRealtimeTranscription()
        }
        
        // Save the note
        saveNote()
    }
    
    private func saveNote() {
        do {
            let conferenceValue = conferenceName.isEmpty ? nil : conferenceName
            let finalTitle = title.isEmpty ? "New Note" : title
            
            let transcriptionStatus: String
            if isOnlineMode {
                transcriptionStatus = content.isEmpty ? "failed" : "completed"
            } else {
                transcriptionStatus = "pending"
            }
            
            let note = Note(
                title: finalTitle,
                content: content,
                timestamp: Date(),
                conferenceName: conferenceValue,
                sessionType: sessionType,
                isArchived: false,
                audioFilePath: recordingManager.currentRecordingPath,
                transcriptionStatus: transcriptionStatus,
                duration: recordingTime
            )
            
            modelContext.insert(note)
            try modelContext.save()
            
            AppLogger.shared.info("Note saved - Duration: \(recordingTime)s, Transcription: \(transcriptionStatus)")
            dismiss()
            
        } catch {
            showError("Failed to save note: \(error.localizedDescription)")
        }
    }
    
    private func cleanup() {
        stopRecordingTimer()
        
        if recordingManager.state == .recording || recordingManager.state == .paused {
            recordingManager.cancelRecording()
        }
        
        if transcriptionService.isTranscribing {
            transcriptionService.stopRealtimeTranscription()
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime = recordingManager.recordingDuration
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let centiseconds = Int((time - Double(Int(time))) * 100)
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}