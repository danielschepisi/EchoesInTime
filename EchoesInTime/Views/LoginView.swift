//
//  LoginView.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var networkManager = NetworkManager.shared
    
    @State private var emailInput = "admin@test.com"
    @State private var passwordInput = "youcandoit"
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Echoes In Time")
                    .font(.largeTitle)
                    .bold()
                
                Text("Admin & Developer Sign In")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    TextField("Email", text: $emailInput)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $passwordInput)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                if isLoading {
                    ProgressView("Signing in...")
                } else {
                    Button("Sign In") {
                        handleLogin()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if let errorMessage = networkManager.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            // Automatically navigates when token and localId become non-nil
            .navigationDestination(isPresented: Binding(
                get: { networkManager.token != nil && networkManager.localId != nil },
                set: { _ in }
            )) {
                if let token = networkManager.token, let localId = networkManager.localId {
                    ImageUploadView(token: token, localId: localId)
                }
            }
        }
    }
    
    private func handleLogin() {
        Task {
            await MainActor.run { isLoading = true }
            await networkManager.signIn(email: emailInput, password: passwordInput)
            await MainActor.run { isLoading = false }
        }
    }
}

#Preview {
    LoginView()
}
