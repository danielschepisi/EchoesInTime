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
    
    // 1. Add state to toggle between Sign In and Sign Up modes
    @State private var isSignUpMode = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Echoes In Time")
                    .font(.largeTitle)
                    .bold()
                
                // 2. Dynamic header text
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
                    // 3. Primary action button switches function based on mode
                    Button(isSignUpMode ? "Create Account" : "Sign In") {
                        handleAuthAction()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    // 4. Toggle button to switch between Sign In and Sign Up
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
            // Automatically navigates when token and localId become non-nil (works for both Sign In and Sign Up!)
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
    
    // 5. Calls signUp or signIn depending on the current mode
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
