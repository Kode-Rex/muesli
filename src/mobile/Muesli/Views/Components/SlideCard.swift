//
//  SlideCard.swift
//  Muesli
//
//  Full-width photo card used between text segments in AugmentedNoteView.
//

import SwiftUI

struct SlideCard: View {
    let photo: Photo
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let uiImage = loadImage() {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 180)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundColor(.secondary)
                    )
            }

            if let ocr = photo.ocrText, !ocr.isEmpty {
                Text(ocr)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.footnote)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 8)
    }

    private func loadImage() -> UIImage? {
        let url: URL? = photo.localPath.hasPrefix("/")
            ? URL(fileURLWithPath: photo.localPath)
            : AudioRecordingManager.shared.getRecordingURL(fileName: photo.localPath)
        guard let url else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
