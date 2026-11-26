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
    @State private var emailInput = ""
    @State private var passwordInput = ""
    @State private var isLoading = false
    @State private var isFullyAuthenticated = false
    
    // Toggle between Sign In and Sign Up modes
    @State private var isSignUpMode = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Echoes In Time")
                    .font(.largeTitle)
                    .bold()
                
                Text(isSignUpMode ? "Create a New Account" : "Sign In to Access Historical Beauty")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    TextField("Your Email", text: $emailInput)
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
                    //TODO: clean email/password first (?whitespaces, newlines, min chars). can make button unavailable with text stating what needs to change. or can present warning on tapping button
                        handleAuthAction()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(isSignUpMode ? "Already have an account? Sign In" : "Need an account? Sign Up") {
                        isSignUpMode.toggle()
                        networkManager.errorMessage = nil
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
            .onChange(of: networkManager.token) { _, _ in
                checkAuth()
            }
            .onChange(of: networkManager.localId) { _, _ in
                checkAuth()
            }
            .navigationDestination(isPresented: $isFullyAuthenticated) {
                //TODO: maybe fatal error
                if let token = networkManager.token, let localId = networkManager.localId {
                    ImageGalleryView(token: token, localId: localId)
                }
            }
        }
    }
    
    //TODO: check if we really need this
    private func checkAuth() {
        isFullyAuthenticated = (networkManager.token != nil && networkManager.localId != nil)
    }
    
    // Calls signUp or signIn depending on the current mode
    private func handleAuthAction() {
        print("1. handleAuthAction started")
        Task {
            isLoading = true
            defer {
                isLoading = false
                print("4. handleAuthAction finished, isLoading reset")
            }
            
            
            if isSignUpMode {
                await networkManager.signUp(email: emailInput, password: passwordInput)
            } else {
                print("2. calling signIn...")

                await networkManager.signIn(email: emailInput, password: passwordInput)
                print("3. signIn returned. token: \(networkManager.token != nil), localId: \(networkManager.localId != nil), error: \(networkManager.errorMessage ?? "none")")
            }
        }
    }
}

#Preview {
    LoginView()
}
