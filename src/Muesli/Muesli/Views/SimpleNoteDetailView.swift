//
//  SimpleNoteDetailView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import UIKit

struct SimpleNoteDetailView: View {
    let title: String
    let content: String
    let date: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingOptions = false
    @State private var showingEditTitle = false
    @State private var showingTranscript = false
    @State private var showingMyNotes = false
    @State private var editedTitle = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(date)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Content using simple text parsing
                    ForEach(parseSimpleContent(content), id: \.text) { item in
                        SimpleContentItemView(item: item)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .background(Color.black)
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
        .confirmationDialog("Note Options", isPresented: $showingOptions) {
            Button("Edit Title") {
                editedTitle = title
                showingEditTitle = true
            }
            Button("View Transcript") { showingTranscript = true }
            Button("Show My Notes") { showingMyNotes = true }
            Button("Copy Notes") { 
                UIPasteboard.general.string = content
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingTranscript) {
            TranscriptView(title: title)
        }
        .sheet(isPresented: $showingMyNotes) {
            MyNotesView(title: title, content: content)
        }
        .alert("Edit Title", isPresented: $showingEditTitle) {
            TextField("Note title", text: $editedTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") { /* Save logic */ }
        }
        .preferredColorScheme(.dark)
    }
    
    private func parseSimpleContent(_ content: String) -> [SimpleContentData] {
        content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("# ") {
                    return SimpleContentData(text: String(trimmed.dropFirst(2)), type: .header)
                } else if trimmed.hasPrefix("• ") {
                    return SimpleContentData(text: String(trimmed.dropFirst(2)), type: .bullet)
                } else if trimmed.hasPrefix("○ ") {
                    return SimpleContentData(text: String(trimmed.dropFirst(2)), type: .subBullet)
                } else {
                    return SimpleContentData(text: trimmed, type: .text)
                }
            }
    }
}

struct SimpleContentItemView: View {
    let item: SimpleContentData
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            switch item.type {
            case .header:
                Text(item.text)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .bullet:
                Text("•")
                    .foregroundColor(.white)
                    .frame(width: 12)
                Text(item.text)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .subBullet:
                Text("○")
                    .foregroundColor(.gray)
                    .frame(width: 12)
                    .padding(.leading, 20)
                Text(item.text)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .text:
                Text(item.text)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct SimpleContentData {
    let text: String
    let type: SimpleContentType
}

enum SimpleContentType {
    case header, bullet, subBullet, text
}

#Preview {
    SimpleNoteDetailView(
        title: "August 2025 HOA Board Meeting",
        content: SampleData.generateContent(for: "August 2025 HOA Board Meeting"),
        date: "Wed 20 Aug"
    )
}
