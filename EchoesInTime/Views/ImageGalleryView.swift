//
//  ImageGalleryView.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 24/8/2026.
//

import SwiftUI

struct ImageGalleryView: View {
    let token: String
    let localId: String
    
    @State private var galleryItems: [GalleryPhotoItem] = []
    @State private var isLoading = false
    @State private var statusMessage = "Loading gallery..."
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if galleryItems.isEmpty {
                ContentUnavailableView(
                    "No Memories Found",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Tap upload to save your first memory.")
                )
            } else {
                List(galleryItems) { item in
                    ImageView(item: item)
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Echoes In Time")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: fetchGalleryData) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ImageUploadView(token: token, localId: localId)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            fetchGalleryData()
        }
    }
    
    private func fetchGalleryData() {
        Task {
            await MainActor.run {
                isLoading = true
                statusMessage = "Fetching metadata..."
                galleryItems.removeAll()
            }
            
            do {
                let metadataList = try await FirestoreManager.shared.fetchPhotoMetadata(for: localId, idToken: token)
                var items: [GalleryPhotoItem] = []
                
                for (index, meta) in metadataList.enumerated() {
                    await MainActor.run {
                        statusMessage = "Downloading image \(index + 1) of \(metadataList.count)..."
                    }
                    let image = try await NetworkManager.shared.downloadImage(path: meta.storagePath, idToken: token)
                    items.append(GalleryPhotoItem(id: meta.id, metadata: meta, image: image))
                }
                
                await MainActor.run {
                    self.galleryItems = items
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Failed to load: \(error.localizedDescription)"
                    print("Failed to load: \(error.localizedDescription)")
                    self.isLoading = false
                }
            }
        }
    }
}
