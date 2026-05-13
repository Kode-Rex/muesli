//
//  SearchBarView.swift
//  Muesli
//
//  Reusable search bar component
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    let onSearchTextChange: (String) -> Void

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Search", text: $searchText)
                .foregroundColor(.white)
                .font(.system(size: 16))
                .onChange(of: searchText) { _, newValue in
                    onSearchTextChange(newValue)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

#Preview {
    SearchBarView(searchText: .constant("")) { _ in }
        .background(Color.black)
        .preferredColorScheme(.dark)
}
