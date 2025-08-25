//
//  SimpleSettingsView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//

import SwiftUI

struct SimpleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sampleNotes: [SampleNote]
    @Binding var showingArchive: Bool
    
    private var archivedCount: Int {
        sampleNotes.filter { $0.isArchived }.count
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Profile Section
                Button(action: {}) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                            .frame(width: 24)
                        
                        Text("Profile")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Archive Section
                Button(action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingArchive = true
                    }
                }) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Archive")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if archivedCount > 0 {
                                Text("\(archivedCount) archived notes")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .background(Color.black)
            .navigationTitle("Settings")
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

#Preview {
    SimpleSettingsView(
        sampleNotes: .constant(SampleData.notes),
        showingArchive: .constant(false)
    )
}
