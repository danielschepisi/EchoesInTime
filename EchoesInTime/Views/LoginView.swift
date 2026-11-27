//
//  LoginView.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var networkManager = NetworkManager.shared
    // NO COMMIT THIS********
    @State private var emailInput = ""
    @State private var passwordInput = ""

    @State private var isLoading = false
    @State private var isFullyAuthenticated = false

    // Toggle between Sign In and Sign Up modes
    @State private var isSignUpMode = false

    var body: some View {
        let _ = Self._printChanges()

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
                        handleAuthAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)

                    Button(isSignUpMode ? "Already have an account? Sign In" : "Need an account? Sign Up") {
                        isSignUpMode.toggle()
                        networkManager.errorMessage = nil
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                    .disabled(isLoading)
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
            .onAppear {
//                checkAuth()
            }
            .onChange(of: networkManager.token) { _, _ in
                checkAuth()
            }
            .onChange(of: networkManager.localId) { _, _ in
                checkAuth()
            }
            .navigationDestination(isPresented: $isFullyAuthenticated) {
                if let token = networkManager.token, let localId = networkManager.localId {
                    ImageGalleryView(token: token, localId: localId)
                } else {
                    Text("Missing session credentials")
                }
            }
//            .navigationDestination(isPresented: $isFullyAuthenticated) {
//                VStack(spacing: 20) {
//                    Text("NAVIGATION SUCCESSFUL")
//                        .font(.largeTitle)
//                        .bold()
//
//                    Text("Your login screen has successfully navigated.")
//
//                    Button("Test Gallery") {
//                        print("GALLERY TEST BUTTON PRESSED")
//                    }
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .background(Color.green.opacity(0.1))
//            }
        }
    }

    private func checkAuth() {
        let authed = (networkManager.token != nil && networkManager.localId != nil)
        if authed != isFullyAuthenticated {
            print("AUTH_STATE. isFullyAuthenticated -> \(authed)")
        }
        isFullyAuthenticated = authed
    }

    private func handleAuthAction() {
        guard !isLoading else { return }
        print("1. handleAuthAction started")
        withAnimation(.easeInOut(duration: 0.15)) {
            isLoading = true
        }

        Task { @MainActor in
            defer {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isLoading = false
                }
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
