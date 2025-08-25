//
//  ContentView.swift
//  Muesli
//
//  Created by Travis Frisinger on 8/25/25.
//  
//  DEPRECATED: This file is kept for backwards compatibility.
//  The app now uses MainView.swift as the primary interface.
//

import SwiftUI

// Legacy ContentView - redirects to MainView
struct ContentView: View {
    var body: some View {
        MainView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}
