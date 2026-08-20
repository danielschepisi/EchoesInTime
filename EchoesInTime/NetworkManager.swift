//
//  NetworkManager.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//

import Combine
import Foundation

struct AuthRequestBody: Encodable {
    let email: String
    let password: String
    let returnSecureToken: Bool = true
}

struct AuthResponse: Decodable {
    let idToken: String
    let localId: String
    let email: String
}

class NetworkManager: ObservableObject {
    @Published var token: String?
    @Published var localId: String?
    @Published var errorMessage: String?
    
    private let apiKey = Secrets.apiKey

    func signIn(email: String, password: String) async {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)") else {
            DispatchQueue.main.async { self.errorMessage = "Invalid URL" }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = AuthRequestBody(email: email, password: password)

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                DispatchQueue.main.async { self.errorMessage = "Authentication failed. Check credentials/API key." }
                return
            }

            let authResult = try JSONDecoder().decode(AuthResponse.self, from: data)

            DispatchQueue.main.async {
                self.token = authResult.idToken
                self.localId = authResult.localId
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
