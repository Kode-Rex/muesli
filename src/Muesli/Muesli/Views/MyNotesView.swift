//
//  MyNotesView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct MyNotesView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: String
    
    private var personalNotes: [String] {
        SampleData.extractPersonalNotes(from: content)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if personalNotes.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                
                                Text("No Personal Notes Found")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                
                                Text("Personal notes and action items will appear here")
                                    .font(.body)
                                    .foregroundColor(.gray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 50)
                        } else {
                            Text("Personal Notes & Action Items")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.bottom, 8)
                            
                            ForEach(personalNotes, id: \.self) { note in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle")
                                        .foregroundColor(.teal)
                                        .font(.body)
                                        .frame(width: 20, height: 20)
                                    
                                    Text(note.trimmingCharacters(in: .whitespaces))
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("My Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.teal)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}