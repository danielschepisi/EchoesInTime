//
//  NetworkManager.swift
//  EchoesInTime
//

import Combine
import Foundation
import UIKit

class NetworkManager: ObservableObject {
    
    static let shared = NetworkManager()
    private init() {}
    
    @Published var token: String?
    @Published var localId: String?
    @Published var errorMessage: String?
    
    private let apiKey = Secrets.apiKey
    
    // MARK: - Auth Methods
    
    func signUp(email: String, password: String) async {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)") else {
            await MainActor.run { self.errorMessage = "Invalid URL" }
            return
        }
        
        await performAuthCall(url: url, email: email, password: password)
    }
    
    func signIn(email: String, password: String) async {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)") else {
            await MainActor.run { self.errorMessage = "Invalid URL" }
            return
        }
        
        await performAuthCall(url: url, email: email, password: password)
    }
    
    private func performAuthCall(url: URL, email: String, password: String) async {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = AuthRequestBody(email: email, password: password)
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let serverError = String(data: data, encoding: .utf8) ?? "Authentication failed."
                await MainActor.run { self.errorMessage = serverError }
                return
            }
            
            let authResult = try JSONDecoder().decode(AuthResponse.self, from: data)
            
            // Save refresh token securely in Keychain
            KeychainManager.saveRefreshToken(authResult.refreshToken)
            
            await MainActor.run {
                self.token = authResult.idToken
                self.localId = authResult.localId
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }
    
    /// Exchanges stored Keychain refresh token for a fresh idToken
    func refreshIDToken() async throws -> String {
        guard let refreshToken = KeychainManager.getRefreshToken() else {
            await MainActor.run { self.logout() }
            throw StorageError.invalidResponse
        }
        
        guard let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(apiKey)") else {
            throw StorageError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        //TODO: could refactor this into helper method. it's incase refreshToken has funny characters
        var formComponents = URLComponents()
        formComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]

        let encodedQuery = formComponents.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B") ?? ""

        let bodyComponents: [String] = encodedQuery
            .split(separator: "&")
            .map(String.init)
        request.httpBody = bodyComponents.joined(separator: "&").data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // Refresh token has expired or been revoked; force relogin
            await MainActor.run { self.logout() }
            throw StorageError.invalidResponse
        }
        
        struct RefreshResponse: Codable {
            let id_token: String
            let refresh_token: String
        }
        
        let refreshResult = try JSONDecoder().decode(RefreshResponse.self, from: data)
        
        // Update both tokens
        KeychainManager.saveRefreshToken(refreshResult.refresh_token)
        await MainActor.run {
            self.token = refreshResult.id_token
        }
        
        return refreshResult.id_token
    }
    
    @MainActor
    func logout() {
        self.token = nil
        self.localId = nil
        KeychainManager.clearRefreshToken()
    }

    // MARK: - Auto-Retrying Network Wrapper
    
    /// Wraps requests to automatically handle 401 Unauthorized responses via silent token refresh.
    func performAuthenticatedRequest(
        buildRequest: (String) -> URLRequest
    ) async throws -> (Data, HTTPURLResponse) {
        
        // Use current token or attempt refresh if empty
        let currentToken: String
        if let activeToken = self.token {
            currentToken = activeToken
        } else {
            currentToken = try await refreshIDToken()
        }
        
        let initialRequest = buildRequest(currentToken)
        let (data, response) = try await URLSession.shared.data(for: initialRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.invalidResponse
        }
        
        // If 401 Unauthorized -> Token expired, attempt refresh and retry once
        if httpResponse.statusCode == 401 {
            let newToken = try await refreshIDToken()
            let retryRequest = buildRequest(newToken)
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw StorageError.invalidResponse
            }
            
            return (retryData, retryHttpResponse)
        }
        
        return (data, httpResponse)
    }

    // MARK: - Storage URL Helpers

    private static func encodeStorageObjectPath(_ path: String) throws -> String {
        var cleanPath = path
        while cleanPath.hasPrefix("/") {
            cleanPath.removeFirst()
        }

        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#&=+")

        guard let encoded = cleanPath.addingPercentEncoding(withAllowedCharacters: allowed),
              !encoded.isEmpty else {
            throw StorageError.invalidURL
        }
        return encoded
    }

    private func makeStorageObjectURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        let encodedPath = try Self.encodeStorageObjectPath(path)
        var components = URLComponents()
        components.scheme = "https"
        components.host = "firebasestorage.googleapis.com"
        components.percentEncodedPath = "/v0/b/\(Secrets.storageBucket)/o/\(encodedPath)"
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw StorageError.invalidURL
        }
        return url
    }

    // MARK: - Storage Operations
    
    func uploadImage(image: UIImage, path: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageConversionFailed
        }

        var components = URLComponents(string: "https://firebasestorage.googleapis.com/v0/b/\(Secrets.storageBucket)/o")
        components?.queryItems = [URLQueryItem(name: "name", value: path)]

        guard let url = components?.url else {
            throw StorageError.invalidURL
        }

        let (data, httpResponse) = try await performAuthenticatedRequest { authToken in
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = imageData
            return request
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverError = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "FirebaseServer", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Upload failed (\(httpResponse.statusCode)): \(serverError)"])
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let downloadTokens = json["downloadTokens"] as? String {
            let downloadURL = try makeStorageObjectURL(
                path: path,
                queryItems: [
                    URLQueryItem(name: "alt", value: "media"),
                    URLQueryItem(name: "token", value: downloadTokens)
                ]
            )
            return downloadURL.absoluteString
        }

        throw StorageError.parseFailed
    }
    
    func listFiles(prefix: String = "users/") async throws -> [String] {
        var components = URLComponents(string: "https://firebasestorage.googleapis.com/v0/b/\(Secrets.storageBucket)/o")
        components?.queryItems = [URLQueryItem(name: "prefix", value: prefix)]
        
        guard let url = components?.url else {
            throw StorageError.invalidURL
        }
        
        let (data, httpResponse) = try await performAuthenticatedRequest { authToken in
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            return request
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw StorageError.invalidResponse
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = json["items"] as? [[String: Any]] {
            return items.compactMap { $0["name"] as? String }
        }
        
        return []
    }

    func downloadImage(path: String) async throws -> UIImage {
        let url = try makeStorageObjectURL(
            path: path,
            queryItems: [URLQueryItem(name: "alt", value: "media")]
        )
        
        let (data, httpResponse) = try await performAuthenticatedRequest { authToken in
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            return request
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw StorageError.invalidResponse
        }
        
        guard let downloadedImage = UIImage(data: data) else {
            throw StorageError.imageConversionFailed
        }
        
        return downloadedImage
    }
    
    func deleteImage(path: String) async throws {
        let url = try makeStorageObjectURL(path: path)
        
        let (_, httpResponse) = try await performAuthenticatedRequest { authToken in
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            return request
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw StorageError.invalidResponse
        }
    }
}
