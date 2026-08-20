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
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    // Downloaded Images State
    @State private var downloadedImages: [UIImage] = []
    @State private var isDownloading = false
    
    @State private var statusMessage = "Select or download photos."
    @State private var isUploading = false
    @State private var uploadedImageURL: String?
    
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
                
                // DOWNLOADED GALLERY GRID
                if !downloadedImages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cloud Gallery (\(downloadedImages.count))")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                            ForEach(0..<downloadedImages.count, id: \.self) { index in
                                Image(uiImage: downloadedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .onChange(of: selectedItem) { newItem in
            loadSelectedPhoto(from: newItem)
        }
    }
    
    // DOWNLOAD FLOW
    private func downloadAllCloudImages() {
        Task {
            await MainActor.run {
                isDownloading = true
                statusMessage = "Finding uploaded files..."
                downloadedImages.removeAll()
            }
            
            do {
                // 1. Get list of file paths under users/{localId}/
                let paths = try await NetworkManager.shared.listUserFiles(localId: localId, idToken: token)
                
                if paths.isEmpty {
                    await MainActor.run {
                        statusMessage = "No images found in your cloud storage."
                        isDownloading = false
                    }
                    return
                }
                
                // 2. Fetch binary data for each image
                var fetchedImages: [UIImage] = []
                for (index, path) in paths.enumerated() {
                    await MainActor.run {
                        statusMessage = "Downloading image \(index + 1) of \(paths.count)..."
                    }
                    let img = try await NetworkManager.shared.downloadImage(path: path, idToken: token)
                    fetchedImages.append(img)
                }
                
                await MainActor.run {
                    self.downloadedImages = fetchedImages
                    self.statusMessage = "Successfully downloaded \(fetchedImages.count) image(s)!"
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
                    statusMessage = "Upload Complete! You can now test downloading."
                    isUploading = false
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
