//
//  NoteOptionsPopover.swift
//  Muesli
//
//  Note options popover component
//

import SwiftUI
import UIKit

struct NoteOptionsPopover: View {
    let note: Note
    let onEditTitle: () -> Void
    let onEditContent: () -> Void
    let onViewTranscript: () -> Void
    let onShowMyNotes: () -> Void
    let onEditAISummary: () -> Void
    let onCopyNotes: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            NoteOptionRow(
                icon: "pencil",
                title: "Edit title"
            ) {
                onClose()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onEditTitle()
                }
            }
            
            Divider().background(Color.gray.opacity(0.5))
            
            NoteOptionRow(
                icon: "square.and.pencil",
                title: "Edit content"
            ) {
                onClose()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onEditContent()
                }
            }
            
            Divider().background(Color.gray.opacity(0.5))
            
            NoteOptionRow(
                icon: "brain",
                title: "Edit AI summary"
            ) {
                onClose()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onEditAISummary()
                }
            }
            
            Divider().background(Color.gray.opacity(0.5))
            
            NoteOptionRow(
                icon: "doc.text",
                title: "View transcript"
            ) {
                onClose()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onViewTranscript()
                }
            }
            
            Divider().background(Color.gray.opacity(0.5))
            
            NoteOptionRow(
                icon: "square.on.square",
                title: "Show my notes"
            ) {
                onClose()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onShowMyNotes()
                }
            }
            
            Divider().background(Color.gray.opacity(0.5))
            
            NoteOptionRow(
                icon: "doc.on.doc",
                title: "Copy notes"
            ) {
                UIPasteboard.general.string = note.content
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                AppLogger.shared.userAction("Copy Notes", context: note.title)
                onClose()
            }
        }
        .background(Color(red: 0.2, green: 0.2, blue: 0.2))
        .cornerRadius(12)
        .frame(width: 200)
    }
}

struct NoteOptionRow: View {
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