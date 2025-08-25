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
        .popover(isPresented: $showingOptions, attachmentAnchor: .point(.topTrailing), arrowEdge: .top) {
            VStack(spacing: 0) {
                NoteOptionRow(
                    icon: "pencil",
                    title: "Edit title"
                ) {
                    showingOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        editedTitle = title
                        showingEditTitle = true
                    }
                }
                
                Divider().background(Color.gray.opacity(0.5))
                
                NoteOptionRow(
                    icon: "pencil",
                    title: "Edit AI summary"
                ) {
                    showingOptions = false
                }
                
                Divider().background(Color.gray.opacity(0.5))
                
                NoteOptionRow(
                    icon: "doc.text",
                    title: "View transcript"
                ) {
                    showingOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingTranscript = true
                    }
                }
                
                Divider().background(Color.gray.opacity(0.5))
                
                NoteOptionRow(
                    icon: "square.on.square",
                    title: "Show my notes"
                ) {
                    showingOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingMyNotes = true
                    }
                }
                
                Divider().background(Color.gray.opacity(0.5))
                
                NoteOptionRow(
                    icon: "doc.on.doc",
                    title: "Copy notes"
                ) {
                    UIPasteboard.general.string = content
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showingOptions = false
                }
            }
            .background(Color(red: 0.2, green: 0.2, blue: 0.2))
            .cornerRadius(12)
            .frame(width: 200)
            .presentationCompactAdaptation(.popover)
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


// MARK: - Note Option Row
private struct NoteOptionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 16))
                    .frame(width: 20, height: 20)
                
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SimpleNoteDetailView(
        title: "August 2025 HOA Board Meeting",
        content: SampleData.generateContent(for: "August 2025 HOA Board Meeting"),
        date: "Wed 20 Aug"
    )
}
