//
//  ContentView.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//

//TODO: quality check user creds when inputed

import SwiftUI

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager.shared
    
    @State private var emailInput = "admin@test.com"
    @State private var passwordInput = "youcandoit"
    
    @State private var statusMessage = "Enter admin credentials to test upload."
    @State private var isProcessing = false
    @State private var uploadedImageURL: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Admin Upload Test")
                .font(.title2)
                .bold()

            VStack(spacing: 12) {
                TextField("Admin Email", text: $emailInput)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $passwordInput)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            if isProcessing {
                ProgressView()
            }

            Button("1. Sign In & Upload Test Image") {
                runAdminUploadSequence()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing)

            Text(statusMessage)
                .font(.subheadline)
                .foregroundColor(networkManager.errorMessage != nil ? .red : .secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let urlString = uploadedImageURL {
                Link("Open Uploaded Image in Browser", destination: URL(string: urlString)!)
                    .font(.footnote)
                    .padding(.top)
            }
        }
        .padding()
    }

    private func runAdminUploadSequence() {
        Task {
            await MainActor.run {
                isProcessing = true
                statusMessage = "Authenticating admin..."
            }

            // 1. Trigger your existing signIn method
            await networkManager.signIn(email: emailInput, password: passwordInput)

            // Check if signIn succeeded and populated networkManager.token
            guard let validToken = networkManager.token, let localId = networkManager.localId else {
                await MainActor.run {
                    statusMessage = networkManager.errorMessage ?? "Sign in failed."
                    isProcessing = false
                }
                return
            }

            await MainActor.run {
                statusMessage = "Authenticated as \(localId)! Uploading photo..."
            }

            // 2. Prepare test SF Symbol image
            guard let testImage = UIImage(systemName: "globe.americas.fill") else {
                await MainActor.run {
                    statusMessage = "Failed to create test SF Symbol image."
                    isProcessing = false
                }
                return
            }

            // 3. Define path using the authenticated localId
            let uploadPath = "users/\(localId)/admin_test_\(UUID().uuidString).jpg"

            do {
                // 4. Call uploadImage with the token stored in NetworkManager
                let downloadURL = try await networkManager.uploadImage(
                    image: testImage,
                    path: uploadPath,
                    idToken: validToken
                )

                await MainActor.run {
                    statusMessage = "Upload Successful!"
                    uploadedImageURL = downloadURL
                    isProcessing = false
                }
                print("Uploaded Image URL:\n\(downloadURL)")

            } catch {
                await MainActor.run {
                    statusMessage = "Upload Error: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
