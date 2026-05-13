//
//  MainHeaderView.swift
//  Muesli
//
//  Header component for main view
//

import SwiftUI

struct MainHeaderView: View {
    let onSettingsTap: () -> Void

    var body: some View {
        HStack {
            Text("My Notes")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Spacer()

            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.teal)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
}

#Preview {
    MainHeaderView(onSettingsTap: {})
        .background(Color.black)
        .preferredColorScheme(.dark)
}
