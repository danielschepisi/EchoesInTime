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

    // Filtering is done in the view because the #Predicate filter caused a render loop.
    @Query(sort: \CachedPhoto.dateTaken, order: .reverse)
    private var allPhotos: [CachedPhoto]

    private var cachedPhotos: [CachedPhoto] {
        allPhotos.filter { !$0.isSoftDeleted }
    }

    @State private var isSyncing = false
    @State private var statusMessage: String?

    var body: some View {
        Group {
            if cachedPhotos.isEmpty {
                ContentUnavailableView(
                    "No Memories Found",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text(
                        isSyncing
                        ? (statusMessage ?? "Syncing gallery...")
                        : "Tap upload to save your first memory."
                    )
                )
                .overlay {
                    if isSyncing {
                        ProgressView()
                            .padding(.top, 100)
                    }
                }
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
                    Task {
                        await syncAndCacheMissingImages()
                    }
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
                NavigationLink(
                    destination: ImageUploadView(token: token, localId: localId)
                ) {
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
        print("A. entered syncAndCacheMissingImages")
        await SyncCoordinator.shared.pullChanges(
            userId: localId,
            idToken: token,
            in: modelContext
        )
        print("B. pullChanges finished")

        // 2. Download and cache any photo that doesn't have a valid file on disk yet.
        // Fetch everything and filter in memory (avoids #Predicate issues).
        guard let fetched = try? modelContext.fetch(FetchDescriptor<CachedPhoto>()) else {
            print("C. failed to fetch CachedPhoto from modelContext")
            return
        }
        let photosToCache = fetched.filter { !$0.isSoftDeleted }
        print("C. cachedPhotos in context: \(photosToCache.count)")

        statusMessage = "Downloading images..."

        for photo in photosToCache {
            // Skip if file already exists on disk
            if LocalImageCache.loadImage(filename: photo.localImageFilename) != nil {
                continue
            }

            do {
                print("D. downloading image for \(photo.id) from \(photo.storagePath)")
                let image = try await NetworkManager.shared.downloadImage(path: photo.storagePath)
                let filename = try LocalImageCache.saveImage(image, id: photo.id)
                photo.localImageFilename = filename
                print("E. saved image \(filename) for \(photo.id)")
            } catch {
                print("E_ERR. Failed to cache image for \(photo.id): \(error.localizedDescription)")
            }
        }

        try? modelContext.save()
        print("F. syncAndCacheMissingImages completed")
    }
}
