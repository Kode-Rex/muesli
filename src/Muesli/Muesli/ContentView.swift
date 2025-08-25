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
    @State private var showingEditAlert = false
    @State private var showingSettings = false
    @State private var showingArchive = false
    @State private var showingNoteDetail = false
    @State private var selectedNote: (String, String, String)? = nil
    @State private var editingNoteIndex: Int?
    @State private var editingTitle = ""
    
    // Sample data for mock UI - now mutable with archive status
    @State private var sampleNotes = [
        ("August 2025 HOA Board Meeting", "6:20 PM", "Wed 20 Aug", false),
        ("AI integration strategy for higher...", "12:52 PM", "Wed 13 Aug", false),
        ("AI learning and personal reflectio...", "12:29 PM", "Wed 13 Aug", false),
        ("AI opportunities for marketplace...", "12:15 PM", "Wed 13 Aug", false)
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
                    
                    // Profile image placeholder - tappable to open settings
                    Button(action: {
                        showingSettings = true
                    }) {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20))
                            )
                    }
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
                        // Sample notes grouped by date
                        ForEach(groupedNotes, id: \.0) { dateGroup in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(dateGroup.0)
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 20)
                                
                                ForEach(Array(dateGroup.1.enumerated()), id: \.element.0) { index, note in
                                    NoteCardView(
                                        title: note.0,
                                        time: note.1,
                                        icon: "doc.text"
                                    )
                                    .padding(.horizontal, 20)
                                    .onTapGesture {
                                        selectedNote = (note.0, note.1, dateGroup.0)
                                        showingNoteDetail = true
                                    }
                                    .contextMenu {
                                        Button(action: {
                                            // Find the original index in sampleNotes
                                            if let originalIndex = sampleNotes.firstIndex(where: { $0.0 == note.0 && $0.1 == note.1 }) {
                                                editingNoteIndex = originalIndex
                                                editingTitle = note.0
                                                showingEditAlert = true
                                            }
                                        }) {
                                            Label("Edit Title", systemImage: "pencil")
                                        }
                                        
                                        Button(action: {
                                            // Find the original index in sampleNotes and archive it
                                            if let originalIndex = sampleNotes.firstIndex(where: { $0.0 == note.0 && $0.1 == note.1 }) {
                                                sampleNotes[originalIndex] = (note.0, note.1, sampleNotes[originalIndex].2, true)
                                            }
                                        }) {
                                            Label("Archive", systemImage: "archivebox")
                                        }
                                    }
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
        .sheet(isPresented: $showingSettings) {
            SettingsView(sampleNotes: $sampleNotes, showingArchive: $showingArchive)
        }
        .sheet(isPresented: $showingArchive) {
            ArchiveView(sampleNotes: $sampleNotes)
        }
        .sheet(isPresented: $showingNoteDetail) {
            if let note = selectedNote {
                NoteDetailView(title: note.0, content: generateSampleContent(for: note.0), date: note.2)
            }
        }
        .alert("Edit Title", isPresented: $showingEditAlert) {
            TextField("Note title", text: $editingTitle)
            
            Button("Cancel", role: .cancel) {
                editingNoteIndex = nil
                editingTitle = ""
            }
            
            Button("Save") {
                if let index = editingNoteIndex {
                    sampleNotes[index] = (editingTitle, sampleNotes[index].1, sampleNotes[index].2, sampleNotes[index].3)
                }
                editingNoteIndex = nil
                editingTitle = ""
            }
            .disabled(editingTitle.isEmpty)
        } message: {
            Text("Enter a new title for this note")
        }
        .preferredColorScheme(.dark)
    }
    
    private func generateSampleContent(for title: String) -> String {
        // Generate sample content based on the note title
        switch title {
        case "August 2025 HOA Board Meeting":
            return """
            # Financial Review
            
            • Haven invoice disputes resolved
                ○ Credit for pool management payments clarified
                ○ Outstanding invoices pending approval until supporting documentation reviewed
                ○ Invoice #40744 requires backup before approval
            
            • Operating account balance unusually high at $268,785
                ○ Consistently maintained ~$300k since new leadership (previously ~$130k max)
                ○ Attributed to reduced spending and board handling tasks vs. outsourcing
                ○ Excess funds discussion deferred to budget meeting
            
            • Excel Energy gas bill missing
            
            # Maintenance Updates
            
            • Pool resurfacing approved - $5,000 budget allocated
            • New guest parking restrictions effective Sept 1
            • Monthly landscaping budget increased to $800
            
            # Action Items
            
            • Send notice to residents about parking changes
            • Get quotes for pool work
            • Schedule community meeting for October
            • Follow up on missing gas bill
            """
        case let title where title.contains("AI integration"):
            return """
            # AI Integration Strategy Discussion
            
            • Current market analysis
                ○ GPT-4 for content generation capabilities
                ○ Claude for complex analysis tasks
                ○ Custom fine-tuned models for specific use cases
            
            • Implementation timeline
                ○ Q1: Prototype development and testing
                ○ Q2: User testing and feedback collection
                ○ Q3: Full deployment and training
            
            • Budget considerations
                ○ Initial setup costs: $50,000
                ○ Monthly operational costs: $5,000
                ○ ROI expected within 18 months
            
            # Next Steps
            
            • Prototype development begins next week
            • Schedule user testing sessions
            • Present to board for final approval
            """
        case let title where title.contains("AI learning"):
            return """
            # Personal AI Learning Reflection
            
            • Key insights gained
                ○ AI is transforming traditional workflows
                ○ Prompt engineering is becoming essential skill
                ○ Integration requires careful change management
            
            • Skills development priorities
                ○ Advanced prompt engineering techniques
                ○ AI tool evaluation and selection
                ○ Team training and adoption strategies
            
            • Practical applications identified
                ○ Content creation automation
                ○ Data analysis and reporting
                ○ Customer service enhancement
            
            # Goals for Next Month
            
            • Complete AI certification course
            • Implement AI tools in current projects
            • Share learnings with team through workshop
            """
        case let title where title.contains("AI opportunities"):
            return """
            # AI Marketplace Opportunities
            
            • Market size and potential
                ○ Global AI market projected $1.8T by 2030
                ○ Enterprise adoption rate: 85% by 2025
                ○ Our target segment growing 40% annually
            
            • Competitive landscape
                ○ OpenAI leading consumer market
                ○ Microsoft/Google dominating enterprise
                ○ Niche opportunities in specialized verticals
            
            • Strategic recommendations
                ○ Focus on vertical-specific solutions
                ○ Partner with established platforms
                ○ Build proprietary data advantages
            
            # Investment Requirements
            
            • Technical team expansion: $2M
            • Platform development: $5M
            • Marketing and sales: $3M
            """
        default:
            return """
            # Conference Session Notes
            
            • Key discussion points
                ○ Topic overview and context
                ○ Industry trends and implications
                ○ Best practices shared by speakers
            
            • Actionable insights
                ○ Implementation strategies discussed
                ○ Tools and resources recommended
                ○ Common pitfalls to avoid
            
            • Networking connections
                ○ Contact information for follow-up
                ○ Potential collaboration opportunities
                ○ Industry expertise to leverage
            
            # Follow-up Actions
            
            • Schedule follow-up meetings with key contacts
            • Research recommended tools and platforms
            • Share insights with team
            • Plan implementation of new strategies
            """
        }
    }
    
    private var groupedNotes: [(String, [(String, String)])] {
        // Filter out archived notes
        let activeNotes = sampleNotes.filter { !$0.3 }
        let groups = Dictionary(grouping: activeNotes) { $0.2 }
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

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sampleNotes: [(String, String, String, Bool)]
    @Binding var showingArchive: Bool
    
    private var archivedCount: Int {
        sampleNotes.filter { $0.3 }.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Profile Section
                    VStack(spacing: 16) {
                        SettingsRow(
                            icon: "person.fill",
                            title: "Profile",
                            showChevron: true,
                            action: {}
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                    
                    // Archive Section
                    VStack(spacing: 16) {
                        SettingsRow(
                            icon: "archivebox.fill",
                            title: "Archive",
                            subtitle: archivedCount > 0 ? "\(archivedCount) archived notes" : nil,
                            action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingArchive = true
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }
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

struct SettingsRow: View {
    let icon: String
    var iconColor: Color = .gray
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 20))
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sampleNotes: [(String, String, String, Bool)]
    @State private var selectedNote: (String, String, String)? = nil
    @State private var showingNoteDetail = false
    
    private var archivedNotes: [(String, String, String)] {
        sampleNotes.filter { $0.3 }.map { ($0.0, $0.1, $0.2) }
    }
    
    private var groupedArchivedNotes: [(String, [(String, String)])] {
        let groups = Dictionary(grouping: archivedNotes) { $0.2 }
        return groups.sorted { $0.key > $1.key }.map { (key, value) in
            (key, value.map { ($0.0, $0.1) })
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if archivedNotes.isEmpty {
                    VStack {
                        Image(systemName: "archivebox")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Archived Notes")
                            .font(.title2)
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                        
                        Text("Archived notes will appear here")
                            .font(.body)
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.top, 8)
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(groupedArchivedNotes, id: \.0) { dateGroup in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(dateGroup.0)
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 20)
                                    
                                    ForEach(Array(dateGroup.1.enumerated()), id: \.element.0) { index, note in
                                        ArchivedNoteCardView(
                                            title: note.0,
                                            time: note.1,
                                            icon: "archivebox.fill"
                                        )
                                        .padding(.horizontal, 20)
                                        .onTapGesture {
                                            selectedNote = (note.0, note.1, archivedNotes.first { $0.0 == note.0 && $0.1 == note.1 }?.2 ?? "")
                                            showingNoteDetail = true
                                        }
                                        .contextMenu {
                                            Button(action: {
                                                // Find and unarchive the note
                                                if let originalIndex = sampleNotes.firstIndex(where: { $0.0 == note.0 && $0.1 == note.1 && $0.3 == true }) {
                                                    sampleNotes[originalIndex] = (note.0, note.1, sampleNotes[originalIndex].2, false)
                                                }
                                            }) {
                                                Label("Unarchive", systemImage: "arrow.up.bin")
                                            }
                                            
                                            Button(role: .destructive, action: {
                                                // Find and delete the note permanently
                                                if let originalIndex = sampleNotes.firstIndex(where: { $0.0 == note.0 && $0.1 == note.1 && $0.3 == true }) {
                                                    sampleNotes.remove(at: originalIndex)
                                                }
                                            }) {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showingNoteDetail) {
            if let note = selectedNote {
                NoteDetailView(title: note.0, content: generateSampleContent(for: note.0), date: note.2)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func generateSampleContent(for title: String) -> String {
        // Generate sample content based on the note title
        switch title {
        case "August 2025 HOA Board Meeting":
            return """
            Agenda:
            • Budget review for next quarter
            • Pool maintenance discussion
            • New landscaping proposals
            • Parking policy updates
            
            Key decisions:
            - Approved $5000 for pool resurfacing
            - New guest parking restrictions effective Sept 1
            - Monthly landscaping budget increased to $800
            
            Action items:
            • Send notice to residents about parking changes
            • Get quotes for pool work
            • Schedule community meeting for October
            """
        case let title where title.contains("AI integration"):
            return """
            Discussion points:
            • Current AI tools in the market
            • Integration strategies for our platform
            • Cost-benefit analysis
            • Timeline for implementation
            
            Technologies reviewed:
            - GPT-4 for content generation
            - Claude for analysis tasks
            - Custom fine-tuned models
            
            Next steps:
            • Prototype development
            • User testing phase
            • Budget approval process
            """
        case let title where title.contains("AI learning"):
            return """
            Personal reflection on AI learning journey:
            
            What I've learned:
            • AI is transforming how we work
            • Need to stay updated with latest developments
            • Practical applications in daily workflow
            
            Skills to develop:
            - Prompt engineering
            - AI tool evaluation
            - Integration planning
            
            Goals for next month:
            • Complete AI certification course
            • Implement AI tools in current projects
            • Share learnings with team
            """
        default:
            return """
            This is a sample note content for: \(title)
            
            You can add your conference notes, meeting minutes, and insights here.
            
            Key topics discussed:
            • Topic 1
            • Topic 2
            • Topic 3
            
            Action items:
            • Follow up on decisions
            • Schedule next meeting
            • Share notes with team
            """
        }
    }
}

struct ArchivedNoteCardView: View {
    let title: String
    let time: String
    let icon: String
    
    var body: some View {
        HStack {
            // Archive icon
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(1)
                
                Text(time)
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            
            Spacer()
            
            // Archived indicator
            Text("ARCHIVED")
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

enum ContentType {
    case header, bullet, subBullet
}

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: String
    let date: String
    @State private var showingEditTitle = false
    @State private var editedTitle = ""
    @State private var showingTranscript = false
    @State private var showingAISummaryEdit = false
    @State private var showingOptionsMenu = false
    @State private var showingMyNotesOnly = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header with date
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
                        
                        // Content
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(parseContent(content), id: \.0) { item in
                                HStack(alignment: .top, spacing: 8) {
                                    if item.1 == .header {
                                        Text(item.0)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        Text(item.1 == .bullet ? "•" : "○")
                                            .foregroundColor(item.1 == .bullet ? .white : .gray)
                                            .font(.body)
                                            .frame(width: 12, alignment: .leading)
                                        
                                        Text(item.0)
                                            .font(.body)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.leading, item.1 == .subBullet ? 20 : 0)
                            }
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.teal)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingOptionsMenu = true
                    }) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    }
                }
            }
        }
        .sheet(isPresented: $showingTranscript) {
            TranscriptView(title: title)
        }
        .sheet(isPresented: $showingOptionsMenu) {
            NoteOptionsView(
                title: title,
                content: content,
                showingEditTitle: $showingEditTitle,
                showingAISummaryEdit: $showingAISummaryEdit,
                showingTranscript: $showingTranscript,
                showingMyNotesOnly: $showingMyNotesOnly,
                editedTitle: $editedTitle
            )
        }
        .sheet(isPresented: $showingMyNotesOnly) {
            MyNotesView(title: title, content: content)
        }
        .alert("Edit Title", isPresented: $showingEditTitle) {
            TextField("Note title", text: $editedTitle)
            
            Button("Cancel", role: .cancel) {
                editedTitle = ""
            }
            
            Button("Save") {
                // In a real app, this would update the actual note
                // For now, this is just a UI demonstration
            }
            .disabled(editedTitle.isEmpty)
        } message: {
            Text("Enter a new title for this note")
        }
        .alert("Edit AI Summary", isPresented: $showingAISummaryEdit) {
            Button("Generate New Summary") {
                // AI summary generation logic would go here
            }
            
            Button("Edit Existing Summary") {
                // Edit existing summary logic would go here
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose how you'd like to update the AI summary")
        }
        .preferredColorScheme(.dark)
    }
    
    private func parseContent(_ content: String) -> [(String, ContentType)] {
        let lines = content.components(separatedBy: .newlines)
        var result: [(String, ContentType)] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty {
                continue
            } else if trimmed.hasPrefix("# ") {
                // Header
                let headerText = String(trimmed.dropFirst(2))
                result.append((headerText, .header))
            } else if trimmed.hasPrefix("• ") {
                // Main bullet point
                let bulletText = String(trimmed.dropFirst(2))
                result.append((bulletText, .bullet))
            } else if trimmed.hasPrefix("○ ") {
                // Sub bullet point
                let subBulletText = String(trimmed.dropFirst(2))
                result.append((subBulletText, .subBullet))
            } else {
                // Regular text as bullet
                result.append((trimmed, .bullet))
            }
        }
        
        return result
    }
}

struct NoteOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: String
    @Binding var showingEditTitle: Bool
    @Binding var showingAISummaryEdit: Bool
    @Binding var showingTranscript: Bool
    @Binding var showingMyNotesOnly: Bool
    @Binding var editedTitle: String
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Options list
                    VStack(spacing: 0) {
                        NoteOptionRow(
                            icon: "pencil",
                            title: "Edit title",
                            action: {
                                editedTitle = title
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingEditTitle = true
                                }
                            }
                        )
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        NoteOptionRow(
                            icon: "pencil",
                            title: "Edit AI summary",
                            action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingAISummaryEdit = true
                                }
                            }
                        )
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        NoteOptionRow(
                            icon: "doc.text",
                            title: "View transcript",
                            action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingTranscript = true
                                }
                            }
                        )
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        NoteOptionRow(
                            icon: "square.on.square",
                            title: "Show my notes",
                            action: {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    showingMyNotesOnly = true
                                }
                            }
                        )
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        NoteOptionRow(
                            icon: "doc.on.doc",
                            title: "Copy notes",
                            action: {
                                UIPasteboard.general.string = content
                                // Add haptic feedback
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                dismiss()
                            }
                        )
                    }
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle("Options")
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

struct NoteOptionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MyNotesView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let content: String
    
    private var personalNotes: [String] {
        // Extract lines that might be personal notes (action items, personal observations, etc.)
        let lines = content.components(separatedBy: .newlines)
        return lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.contains("Action items") ||
                   trimmed.contains("Follow up") ||
                   trimmed.contains("Goals for") ||
                   trimmed.contains("Next steps") ||
                   trimmed.contains("Personal") ||
                   trimmed.hasPrefix("• Schedule") ||
                   trimmed.hasPrefix("• Complete") ||
                   trimmed.hasPrefix("• Implement") ||
                   trimmed.hasPrefix("• Share") ||
                   trimmed.hasPrefix("○ Schedule") ||
                   trimmed.hasPrefix("○ Get quotes") ||
                   trimmed.hasPrefix("○ Send notice")
        }
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

struct TranscriptView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    
    private var sampleTranscript: String {
        """
        [00:00] Welcome everyone to the August 2025 HOA Board Meeting. I'm Sarah, your board president.
        
        [00:15] First item on our agenda is the financial review. Tom, could you walk us through the numbers?
        
        [00:30] Tom: Absolutely. So we've resolved those Haven invoice disputes. The credit for pool management payments has been clarified, and we're in a much better position now.
        
        [01:15] The outstanding invoices are still pending approval, but that's just because we're waiting for the supporting documentation to be reviewed properly.
        
        [01:45] Invoice #40744 in particular requires backup documentation before we can approve it.
        
        [02:00] Sarah: What about our operating account balance? I noticed it's higher than usual.
        
        [02:10] Tom: Yes, we're at $268,785, which is unusually high. We've consistently maintained around $300k since the new leadership took over, compared to the previous maximum of around $130k.
        
        [02:45] This is attributed to reduced spending and the board handling more tasks internally versus outsourcing everything.
        
        [03:15] We'll defer the excess funds discussion to the budget meeting next month.
        
        [03:30] Sarah: Any other financial items? What about that Excel Energy bill?
        
        [03:40] Tom: Unfortunately, the Excel Energy gas bill is still missing. I'll follow up on that this week.
        
        [04:00] Sarah: Moving on to maintenance updates. The pool resurfacing has been approved with a $5,000 budget allocation.
        
        [04:30] New guest parking restrictions will be effective September 1st, and we've increased the monthly landscaping budget to $800.
        
        [05:00] Action items for next week include sending notices to residents about parking changes, getting quotes for pool work, and scheduling the October community meeting.
        
        [05:30] Meeting adjourned. Thank you everyone.
        """
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Meeting Transcript")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.bottom, 8)
                        
                        Text(sampleTranscript)
                            .font(.body)
                            .foregroundColor(.white)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Transcript")
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
