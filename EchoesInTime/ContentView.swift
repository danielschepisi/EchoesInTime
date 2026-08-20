//
//  ContentView.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//

//TODO: quality check user creds when inputed

import SwiftUI

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager()
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Firebase REST Auth")
                .font(.title2)
                .bold()

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button("Sign In") {
                Task {
                    await networkManager.signIn(email: email, password: password)
                }
            }
            .buttonStyle(.borderedProminent)

            if let token = networkManager.token {
                VStack(alignment: .leading, spacing: 5) {
                    Text("JWT Token Acquired:")
                        .font(.caption)
                        .bold()
                    Text(token)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(4)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            if let error = networkManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
