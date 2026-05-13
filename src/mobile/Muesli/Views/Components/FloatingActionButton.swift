//
//  FloatingActionButton.swift
//  Muesli
//
//  Floating action button component
//

import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void
    let systemImage: String
    let backgroundColor: Color

    init(
        action: @escaping () -> Void,
        systemImage: String = "plus",
        backgroundColor: Color = .teal
    ) {
        self.action = action
        self.systemImage = systemImage
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: action) {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(backgroundColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 30)
            }
        }
    }
}

#Preview {
    FloatingActionButton(action: {})
        .background(Color.black)
}
