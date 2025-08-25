//
//  ContentView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]
    @State private var searchText = ""
    @State private var showingNewNote = false
    
    // Sample data for mock UI
    private let sampleNotes = [
        ("August 2025 HOA Board Meeting", "6:20 PM", "Wed 20 Aug"),
        ("AI integration strategy for higher...", "12:52 PM", "Wed 13 Aug"),
        ("AI learning and personal reflectio...", "12:29 PM", "Wed 13 Aug"),
        ("AI opportunities for marketplace...", "12:15 PM", "Wed 13 Aug")
    ]

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with profile
                HStack {
                    Text("My Notes")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Profile image placeholder
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search", text: $searchText)
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        // Coming up section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Coming up")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                            
                            VStack {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                    
                                    Text("No upcoming meetings found")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 16))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Sample notes grouped by date
                        ForEach(groupedNotes, id: \.0) { dateGroup in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(dateGroup.0)
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 20)
                                
                                ForEach(dateGroup.1, id: \.0) { note in
                                    NoteCardView(
                                        title: note.0,
                                        time: note.1,
                                        icon: "doc.text"
                                    )
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Bottom padding for floating button
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 100)
                    }
                    .padding(.top, 20)
                }
                
                // Bottom chat input
                HStack {
                    Text("Chat with all your meetings")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "arrow.up")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black)
            }
            
            // Floating New button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingNewNote = true }) {
                        HStack {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("New")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(25)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            NewNoteView()
        }
    }
    
    private var groupedNotes: [(String, [(String, String)])] {
        let groups = Dictionary(grouping: sampleNotes) { $0.2 }
        return groups.sorted { $0.key > $1.key }.map { (key, value) in
            (key, value.map { ($0.0, $0.1) })
        }
    }
}

struct NoteCardView: View {
    let title: String
    let time: String
    let icon: String
    
    var body: some View {
        HStack {
            // Teal icon
            Image(systemName: icon)
                .foregroundColor(.teal)
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
                .background(Color.teal.opacity(0.2))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                Text(time)
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

struct NewNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Note title", text: $title)
                    .font(.title2)
                    .padding()
                
                TextEditor(text: $content)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save logic here
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}
