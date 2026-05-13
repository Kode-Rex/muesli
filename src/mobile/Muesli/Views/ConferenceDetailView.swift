//
//  ConferenceDetailView.swift
//  Muesli
//
//  Hero header for one conference: name, location, date range, description,
//  and a chronological list of talks under it. The Chat CTA is a disabled
//  placeholder until Phase 6 lands ChatView.
//

import SwiftUI

struct ConferenceDetailView: View {
    let conference: Conference

    private var notes: [Note] {
        conference.notes.sorted { $0.timestamp > $1.timestamp }
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
                // Phase 6 wires this to ChatView scoped to this conference.
            } label: {
                Label("Chat with this conference", systemImage: "bubble.left.and.bubble.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            .disabled(true)
        }
    }

    /// Builds a "Mar 14 – May 12, 2026" string from explicit conference dates,
    /// falling back to min/max of attached note timestamps. Returns nil when
    /// no date information is available.
    static func dateRangeString(conference: Conference) -> String? {
        let start = conference.startDate ?? conference.notes.map(\.timestamp).min()
        let end = conference.endDate ?? conference.notes.map(\.timestamp).max()
        guard let start, let end else { return nil }
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return DateFormatter.localizedString(from: start, dateStyle: .medium, timeStyle: .none)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let s = formatter.string(from: start)
        let e = DateFormatter.localizedString(from: end, dateStyle: .medium, timeStyle: .none)
        return "\(s) – \(e)"
    }
}
