//
//  ImageUploadView.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//

import SwiftUI
import PhotosUI

import SwiftUI
import PhotosUI

// Data structure to link downloaded image to its Cloud Storage path
struct CloudPhoto: Identifiable {
    let id = UUID()
    let path: String
    let image: UIImage
    
    // Checks if the file belongs to the current user
    func isOwnedBy(userId: String) -> Bool {
        return path.hasPrefix("users/\(userId)/")
    }
}

struct ImageUploadView: View {
    let token: String
    let localId: String
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    // Updated state to track CloudPhoto objects (Image + Path)
    @State private var downloadedPhotos: [CloudPhoto] = []
    @State private var isDownloading = false
    
    @State private var statusMessage = "Select or download photos."
    @State private var isUploading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Upload & Download")
                    .font(.title2)
                    .bold()
                
                // Photo Picker & Preview Container
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                    
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .cornerRadius(12)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No Photo Selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Upload Controls
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Select Photo", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Upload to Cloud") {
                        uploadSelectedPhoto()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedImage == nil || isUploading)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // DOWNLOAD BUTTON
                if isDownloading {
                    ProgressView("Fetching images from Cloud...")
                } else {
                    Button(action: downloadAllCloudImages) {
                        Label("Download from Cloud", systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .padding(.horizontal)
                }
                
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // DOWNLOADED GALLERY GRID WITH DELETE UI
                if !downloadedPhotos.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cloud Gallery (\(downloadedPhotos.count))")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 16) {
                            ForEach(downloadedPhotos) { photo in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: photo.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 110, height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    
                                    // Delete Button (Only visible if the photo belongs to current user)
                                    if photo.isOwnedBy(userId: localId) {
                                        Button {
                                            deletePhoto(photo)
                                        } label: {
                                            Image(systemName: "trash.circle.fill")
                                                .font(.title2)
                                                .symbolRenderingMode(.multicolor)
                                                .background(Circle().fill(Color.white))
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            loadSelectedPhoto(from: newValue)
        }
    }
    
    // DOWNLOAD FLOW
    private func downloadAllCloudImages() {
        Task {
            await MainActor.run {
                isDownloading = true
                statusMessage = "Finding all uploaded files..."
                downloadedPhotos.removeAll()
            }
            
            do {
                let paths = try await NetworkManager.shared.listFiles(prefix: "users/", idToken: token)
                let imagePaths = paths.filter { !$0.hasSuffix("/") }
                
                if imagePaths.isEmpty {
                    await MainActor.run {
                        statusMessage = "No images found in cloud storage."
                        isDownloading = false
                    }
                    return
                }
                
                var fetchedPhotos: [CloudPhoto] = []
                for (index, path) in imagePaths.enumerated() {
                    await MainActor.run {
                        statusMessage = "Downloading image \(index + 1) of \(imagePaths.count)..."
                    }
                    let img = try await NetworkManager.shared.downloadImage(path: path, idToken: token)
                    fetchedPhotos.append(CloudPhoto(path: path, image: img))
                }
                
                await MainActor.run {
                    self.downloadedPhotos = fetchedPhotos
                    self.statusMessage = "Successfully loaded \(fetchedPhotos.count) photo(s)!"
                    self.isDownloading = false
                }
                
            } catch {
                await MainActor.run {
                    statusMessage = "Download error: \(error.localizedDescription)"
                    isDownloading = false
                }
            }
        }
    }
    
    // DELETE FLOW
    private func deletePhoto(_ photo: CloudPhoto) {
        Task {
            await MainActor.run {
                statusMessage = "Deleting image..."
            }
            
            do {
                try await NetworkManager.shared.deleteImage(path: photo.path, idToken: token)
                
                await MainActor.run {
                    // Remove photo locally from UI array upon successful deletion
                    self.downloadedPhotos.removeAll { $0.id == photo.id }
                    self.statusMessage = "Image deleted successfully."
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "Deletion error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func loadSelectedPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    self.selectedImage = image
                    self.statusMessage = "Photo ready! Click Upload to Cloud."
                }
            }
        }
    }
    
    private func uploadSelectedPhoto() {
        guard let imageToUpload = selectedImage else { return }
        Task {
            await MainActor.run {
                isUploading = true
                statusMessage = "Uploading image..."
            }
            
            let filename = "photo_\(UUID().uuidString).jpg"
            let destinationPath = "users/\(localId)/\(filename)"
            
            do {
                _ = try await NetworkManager.shared.uploadImage(
                    image: imageToUpload,
                    path: destinationPath,
                    idToken: token
                )
                
                await MainActor.run {
                    statusMessage = "Upload Complete! Click Download to refresh gallery."
                    isUploading = false
                    selectedImage = nil
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Upload Error: \(error.localizedDescription)"
                    isUploading = false
                }
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
