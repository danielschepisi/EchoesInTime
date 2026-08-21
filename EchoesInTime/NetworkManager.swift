//
//  NetworkManager.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 20/8/2026.
//

import Combine
import Foundation
import UIKit

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

enum StorageError: LocalizedError {
    case imageConversionFailed
    case invalidPath
    case invalidURL
    case invalidResponse
    case parseFailed
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert UIImage to JPEG binary data."
        case .invalidPath:
            return "Invalid storage upload path encoding."
        case .invalidURL:
            return "Failed to construct valid Firebase Storage URL."
        case .invalidResponse:
            return "Invalid or non-HTTP network response received."
        case .parseFailed:
            return "Upload succeeded, but failed to parse download URL token."
        }
    }
}

class NetworkManager: ObservableObject {
    
    static let shared = NetworkManager()
    private init() {}
    
    @Published var token: String?
    @Published var localId: String?
    @Published var errorMessage: String?
    
    private let apiKey = Secrets.apiKey
    
    func signUp(email: String, password: String) async {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)") else {
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
                // Parses Firebase REST API error responses (e.g., EMAIL_EXISTS, WEAK_PASSWORD)
                let serverError = String(data: data, encoding: .utf8) ?? "Sign up failed."
                DispatchQueue.main.async { self.errorMessage = serverError }
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
    
    /// Uploads JPEG image binary data directly to Firebase Storage REST API
    /// - Parameters:
    ///   - image: The UIImage to compress and upload
    ///   - path: The desired storage path/filename (e.g., "uploads/my_photo.jpg")
    ///   - idToken: The Firebase Auth ID Token obtained during authentication
    /// - Returns: The download URL string for the uploaded object
    func uploadImage(image: UIImage, path: String, idToken: String) async throws -> String {
        // 1. Convert UIImage to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageConversionFailed
        }
        
        // 2. Encode path
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw StorageError.invalidPath
        }
        
        // 3. Build URL
        let urlString = "https://firebasestorage.googleapis.com/v0/b/\(Secrets.storageBucket)/o?name=\(encodedPath)"
        guard let url = URL(string: urlString) else {
            throw StorageError.invalidURL
        }
        
        // 4. Construct and perform request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.upload(for: request, from: imageData)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let serverError = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(domain: "FirebaseServer", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Upload failed (\(httpResponse.statusCode)): \(serverError)"])
        }
        
        // 5. Parse download URL
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let downloadTokens = json["downloadTokens"] as? String {
            
            // Convert slashes in the path to %2F for the browser link
            let browserEncodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
                .replacingOccurrences(of: "/", with: "%2F") ?? encodedPath
            
            return "https://firebasestorage.googleapis.com/v0/b/\(Secrets.storageBucket)/o/\(browserEncodedPath)?alt=media&token=\(downloadTokens)"
        }
        
        throw StorageError.parseFailed
    }
    

    /// Lists files in Firebase Storage matching a given prefix.
    func listFiles(prefix: String = "users/", idToken: String) async throws -> [String] {
        // 1. Build components to let URLComponents handle query encoding properly
        var components = URLComponents(string: "https://firebasestorage.googleapis.com/v0/b/\(Secrets.storageBucket)/o")
        components?.queryItems = [
            URLQueryItem(name: "prefix", value: prefix)
        ]
        
        guard let url = components?.url else {
            throw StorageError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let serverError = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("ListFiles Failed Status Code: \(httpResponse.statusCode) Error: \(serverError)")
            throw StorageError.invalidResponse
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let items = json["items"] as? [[String: Any]] {
            return items.compactMap { $0["name"] as? String }
        }
        
        return []
    }

    /// Downloads image binary data directly from a Firebase Storage path.
    func downloadImage(path: String, idToken: String) async throws -> UIImage {
        // 1. Replace all forward slashes '/' with '%2F' for Firebase Storage REST API pathing
        let escapedPath = path.replacingOccurrences(of: "/", with: "%2F")
        
        // 2. Build the exact media download URL
        let urlString = "https://firebasestorage.googleapis.com/v0/b/\(Secrets.storageBucket)/o/\(escapedPath)?alt=media"
        
        guard let url = URL(string: urlString) else {
            throw StorageError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let serverError = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("DownloadImage Failed (\(httpResponse.statusCode)): \(serverError)")
            throw StorageError.invalidResponse
        }
        
        guard let downloadedImage = UIImage(data: data) else {
            throw StorageError.imageConversionFailed
        }
        
        return downloadedImage
    }
    
    /// Deletes an image from Firebase Storage REST API
    /// - Parameters:
    ///   - path: The full storage path (e.g., "users/USER_ID/photo.jpg")
    ///   - idToken: The active user's Firebase Auth ID token
    func deleteImage(path: String, idToken: String) async throws {
        // Escapes slashes for Firebase REST endpoint (/ -> %2F)
        let escapedPath = path.replacingOccurrences(of: "/", with: "%2F")
        let urlString = "https://firebasestorage.googleapis.com/v0/b/\(Secrets.storageBucket)/o/\(escapedPath)"
        
        guard let url = URL(string: urlString) else {
            throw StorageError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let serverError = String(data: data, encoding: .utf8) ?? "Delete failed."
            print("Delete Failed (\(httpResponse.statusCode)): \(serverError)")
            throw NSError(
                domain: "FirebaseServer",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Delete failed (\(httpResponse.statusCode)): Permission denied or file missing."]
            )
        }
    }

}


