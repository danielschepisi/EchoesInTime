//
//  ImageUploadView.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//

import SwiftUI
import PhotosUI

struct ImageUploadView: View {
    let token: String
    let localId: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var pendingItems: [PendingUploadItem] = []
    @State private var isUploading = false
    @State private var statusMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if pendingItems.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 52))
                        .foregroundColor(.accentColor)
                    
                    Text("Select photos to attach metadata and upload.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    PhotosPicker(
                        selection: $selectedPickerItems,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Select Photos", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: 220)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    Spacer()
                }
            } else {
                List {
                    ForEach($pendingItems) { $item in
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(uiImage: item.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 180)
                                    .cornerRadius(8)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                
                                DatePicker("Date Taken", selection: $item.dateTaken, displayedComponents: [.date, .hourAndMinute])
                                
                                TextField("People (e.g. Sienna, Daniel)", text: $item.peopleText)
                                    .textFieldStyle(.roundedBorder)
                                
                                TextField("Location (e.g. Toronto, ON)", text: $item.location)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                
                VStack(spacing: 10) {
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPickerItems, matching: .images) {
                            Label("Change", systemImage: "photo")
                        }
                        .buttonStyle(.bordered)
                        .disabled(isUploading)
                        
                        Button(action: uploadAllPhotos) {
                            if isUploading {
                                ProgressView()
                            } else {
                                Label("Upload (\(pendingItems.count))", systemImage: "icloud.and.arrow.up")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isUploading)
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Upload Memories")
        .onChange(of: selectedPickerItems) { _, newItems in
            loadSelectedPhotos(from: newItems)
        }
    }
    
    private func loadSelectedPhotos(from items: [PhotosPickerItem]) {
        Task {
            var newPendingItems: [PendingUploadItem] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    newPendingItems.append(PendingUploadItem(image: image))
                }
            }
            await MainActor.run {
                self.pendingItems = newPendingItems
            }
        }
    }
    
    private func uploadAllPhotos() {
        Task {
            await MainActor.run {
                isUploading = true
                statusMessage = "Starting upload..."
            }
            
            for (index, item) in pendingItems.enumerated() {
                let photoId = UUID().uuidString
                let destinationPath = "users/\(localId)/\(photoId).jpg"
                
                do {
                    // 1. Storage Upload
                    _ = try await NetworkManager.shared.uploadImage(
                        image: item.image,
                        path: destinationPath,
                        idToken: token
                    )
                    
                    // 2. People String Parsing
                    let peopleArray = item.peopleText
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    
                    // 3. Metadata Save
                    let metadata = PhotoMetadata(
                        id: photoId,
                        storagePath: destinationPath,
                        dateTaken: item.dateTaken,
                        dateUploaded: Date(),
                        people: peopleArray,
                        location: item.location,
                        userId: localId
                    )
                    
                    try await FirestoreManager.shared.savePhotoMetadata(metadata, idToken: token)
                    
                    await MainActor.run {
                        statusMessage = "Uploaded \(index + 1) of \(pendingItems.count)..."
                    }
                } catch {
                    await MainActor.run {
                        statusMessage = "Error on photo \(index + 1): \(error.localizedDescription)"
                        isUploading = false
                    }
                    return
                }
            }
            
            await MainActor.run {
                isUploading = false
                dismiss() // Return to ImageGalleryView
            }
        }
    }
}


//#Preview("Image Upload Playground") {
//    NavigationStack {
//        ImageUploadView(
//            token: "mock_firebase_id_token_for_preview",
//            localId: "mock_user_12345"
//        )
//    }
//}
