//
//  ImageGalleryView.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 24/8/2026.

import SwiftData
import SwiftUI

struct ImageGalleryView: View {
    let token: String
    let localId: String

    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<CachedPhoto> { !$0.isDeleted },
        sort: \CachedPhoto.dateTaken,
        order: .reverse
    )
    private var cachedPhotos: [CachedPhoto]

    @State private var isSyncing = false
    @State private var statusMessage: String?

    var body: some View {
        Group {
            if cachedPhotos.isEmpty && isSyncing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(statusMessage ?? "Syncing gallery...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else if cachedPhotos.isEmpty {
                ContentUnavailableView(
                    "No Memories Found",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Tap upload to save your first memory.")
                )
            } else {
                List(cachedPhotos) { photo in
                    ImageView(photo: photo)
                        .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Echoes In Time")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    Task { await syncAndCacheMissingImages() }
                } label: {
                    if isSyncing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(isSyncing)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ImageUploadView(token: token, localId: localId)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            await syncAndCacheMissingImages()
        }
    }

    private func syncAndCacheMissingImages() async {
        guard !isSyncing else { return }
        isSyncing = true
        statusMessage = "Syncing metadata..."
        defer {
            isSyncing = false
            statusMessage = nil
        }

        // 1. Pull delta metadata into SwiftData
        print("A. entered ImageGalleryView syncAndCacheMissingImages")
        await SyncCoordinator.shared.pullChanges(
            userId: localId,
            idToken: token,
            in: modelContext
        )
        print("B. pullChanges finished")

        // 2. Download and cache any photo that doesn't have a valid file on disk yet
        let descriptor = FetchDescriptor<CachedPhoto>(
            predicate: #Predicate { !$0.isDeleted }
        )

        guard let allPhotos = try? modelContext.fetch(descriptor) else { return }

        for photo in allPhotos {
            // Skip if file already exists on disk
            if LocalImageCache.loadImage(filename: photo.localImageFilename) != nil {
                continue
            }

            do {
                let image = try await NetworkManager.shared.downloadImage(path: photo.storagePath)
                let filename = try LocalImageCache.saveImage(image, id: photo.id)
                photo.localImageFilename = filename
            } catch {
                print("Failed to cache image for \(photo.id): \(error.localizedDescription)")
            }
        }

        try? modelContext.save()
    }
}
