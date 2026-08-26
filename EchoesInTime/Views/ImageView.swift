//
//  ImageView.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 25/8/2026.
//

import SwiftUI

struct ImageView: View {
    
    let item : GalleryPhotoItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(uiImage: item.image)
                .resizable()
                .scaledToFill()
                .frame(width: 85, height: 85)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 5) {
                if !item.metadata.location.isEmpty {
                    Label(item.metadata.location, systemImage: "mappin.and.ellipse")
                        .font(.headline)
                }
                
                Text("Taken: \(item.metadata.dateTaken.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !item.metadata.people.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(item.metadata.people.joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(2)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}
