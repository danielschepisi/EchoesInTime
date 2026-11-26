//
//  ImageView.swift
//  EchoesInTime
//

import SwiftUI

struct ImageView: View {
    let photo: CachedPhoto

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let uiImage = LocalImageCache.loadImage(filename: photo.localImageFilename) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 85, height: 85)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                    ProgressView()
                }
                .frame(width: 85, height: 85)
            }

            VStack(alignment: .leading, spacing: 5) {
                if !photo.location.isEmpty {
                    Label(photo.location, systemImage: "mappin.and.ellipse")
                        .font(.headline)
                }

                Text("Taken: \(photo.dateTaken.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !photo.people.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(photo.people.joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}
