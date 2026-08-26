//
//  LoginView.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var networkManager = NetworkManager.shared
    //NO COMMIT THIS********
    @State private var emailInput = "XXXXXX"
    @State private var passwordInput = "XXXXXX"
    @State private var isLoading = false
    
    // Toggle between Sign In and Sign Up modes
    @State private var isSignUpMode = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Echoes In Time")
                    .font(.largeTitle)
                    .bold()
                
                Text(isSignUpMode ? "Create a New Account" : "Admin & Developer Sign In")
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
                    ProgressView(isSignUpMode ? "Creating account..." : "Signing in...")
                } else {
                    Button(isSignUpMode ? "Create Account" : "Sign In") {
                        handleAuthAction()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(isSignUpMode ? "Already have an account? Sign In" : "Need an account? Sign Up") {
                        isSignUpMode.toggle()
                        networkManager.errorMessage = nil // Clear previous errors on toggle
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
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
            // Automatically navigates to ImageGalleryView when token and localId become non-nil
            .navigationDestination(isPresented: Binding(
                get: { networkManager.token != nil && networkManager.localId != nil },
                set: { _ in }
            )) {
                if let token = networkManager.token, let localId = networkManager.localId {
                    ImageGalleryView(token: token, localId: localId)
                }
            }
        }
    }
    
    // Calls signUp or signIn depending on the current mode
    private func handleAuthAction() {
        Task {
            await MainActor.run { isLoading = true }
            
            if isSignUpMode {
                await networkManager.signUp(email: emailInput, password: passwordInput)
            } else {
                await networkManager.signIn(email: emailInput, password: passwordInput)
            }
            
            await MainActor.run { isLoading = false }
        }
    }
}

#Preview {
    LoginView()
}
