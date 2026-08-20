//
//  ImageUploadView.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//
import SwiftUI

struct ImageUploadView: View {
    let token: String
    let localId: String
    
    @State private var statusMessage = "Ready to upload test image."
    @State private var isUploading = false
    @State private var uploadedImageURL: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Image Playground")
                .font(.title)
                .bold()
            
            Text("Authenticated User ID:\n\(localId)")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if isUploading {
                ProgressView("Uploading to Cloud Storage...")
            } else {
                Button("Upload Test SF Symbol") {
                    uploadTestImage()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Text(statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let urlString = uploadedImageURL {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.largeTitle)
                    
                    Link("Open Uploaded Image in Web Browser", destination: URL(string: urlString)!)
                        .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(false)
    }
    
    private func uploadTestImage() {
        Task {
            await MainActor.run {
                isUploading = true
                statusMessage = "Preparing image..."
            }
            
            guard let testImage = UIImage(systemName: "photo.stack.fill") else {
                await MainActor.run {
                    statusMessage = "Failed to load SF Symbol."
                    isUploading = false
                }
                return
            }
            
            let destinationPath = "users/\(localId)/sample_\(UUID().uuidString).jpg"
            
            do {
                let downloadURL = try await NetworkManager.shared.uploadImage(
                    image: testImage,
                    path: destinationPath,
                    idToken: token
                )
                
                await MainActor.run {
                    statusMessage = "Upload Complete!"
                    uploadedImageURL = downloadURL
                    isUploading = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Error: \(error.localizedDescription)"
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
