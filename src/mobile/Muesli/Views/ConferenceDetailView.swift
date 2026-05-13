//
//  ConferenceDetailView.swift
//  Muesli
//
//  Hero header for one conference: name, location, date range, description,
//  and a chronological list of talks under it. The Chat CTA is a disabled
//  placeholder until Phase 6 lands ChatView.
//

import SwiftUI
import SwiftData

struct ConferenceDetailView: View {
    let conference: Conference

    @Environment(\.modelContext) private var modelContext
    @State private var chatThread: ChatThread?

    // Mirror MainView's filter: archived talks don't appear on the conference
    // page either. Archived notes can still be found via the archive screen.
    private var notes: [Note] {
        conference.notes
            .filter { !$0.isArchived }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        List {
            Section {
                hero
                    .listRowInsets(EdgeInsets())
                    .padding()
            }

            Section("Talks · \(notes.count)") {
                if notes.isEmpty {
                    Text("No talks yet.").foregroundColor(.secondary)
                } else {
                    ForEach(notes) { note in
                        NavigationLink(value: note) {
                            NoteRow(note: note)
                        }
                    }
                }
            }
        }
        .navigationTitle(conference.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(conference.name)
                .font(.largeTitle.weight(.bold))
            if let loc = conference.location {
                Label(loc, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let range = Self.dateRangeString(conference: conference) {
                Label(range, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if let desc = conference.conferenceDescription, !desc.isEmpty {
                Text(desc)
                    .font(.body)
                    .padding(.top, 4)
            }

            Button {
                openChat()
            } label: {
                Label("Chat with this conference", systemImage: "bubble.left.and.bubble.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .sheet(item: $chatThread) { thread in
            ChatView(
                thread: thread,
                scopeTitle: "\(conference.name) · \(notes.count) talk\(notes.count == 1 ? "" : "s")"
            )
        }
    }

    private func openChat() {
        let confId = conference.id
        let conferenceRaw = ChatScopeKind.conference.rawValue
        let predicate = #Predicate<ChatThread> {
            $0.scopeKindRaw == conferenceRaw && $0.scopeId == confId
        }
        if let existing = try? modelContext.fetch(FetchDescriptor<ChatThread>(predicate: predicate)).first {
            chatThread = existing
        } else {
            let thread = ChatThread(scopeKind: .conference, scopeId: conference.id)
            modelContext.insert(thread)
            try? modelContext.save()
            chatThread = thread
        }
    }

    /// Builds a date-range string from explicit conference dates, falling back
    /// to min/max of attached note timestamps. Same-year ranges drop the start
    /// year ("Mar 14 – May 12, 2026"); cross-year ranges keep both years
    /// ("Dec 30, 2025 – Jan 2, 2026"). Returns nil when no date info exists.
    static func dateRangeString(conference: Conference) -> String? {
        let start = conference.startDate ?? conference.notes.map(\.timestamp).min()
        let end = conference.endDate ?? conference.notes.map(\.timestamp).max()
        guard let start, let end else { return nil }
        let cal = Calendar.current
        if cal.isDate(start, inSameDayAs: end) {
            return DateFormatter.localizedString(from: start, dateStyle: .medium, timeStyle: .none)
        }
        let sameYear = cal.component(.year, from: start) == cal.component(.year, from: end)
        let endString = DateFormatter.localizedString(from: end, dateStyle: .medium, timeStyle: .none)
        let startString: String
        if sameYear {
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            startString = f.string(from: start)
        } else {
            startString = DateFormatter.localizedString(from: start, dateStyle: .medium, timeStyle: .none)
        }
        return "\(startString) – \(endString)"
    }
}
