//
//  NewNoteView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct NewNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Note title", text: $title)
                    .font(DesignSystem.Typography.title2)
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
        .preferredColorScheme(.dark)
    }
}
