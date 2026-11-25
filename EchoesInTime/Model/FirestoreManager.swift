//
//  FirestoreManager.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 24/8/2026.
//

import Foundation

class FirestoreManager {
    static let shared = FirestoreManager()
    private init() {}
    
    private var baseURL: String {
        "https://firestore.googleapis.com/v1/projects/\(Secrets.projectId)/databases/(default)/documents"
    }
    
    /// Saves metadata to Firestore via REST PATCH
    func savePhotoMetadata(_ metadata: PhotoMetadata, idToken: String) async throws {
        guard let url = URL(string: "\(baseURL)/photos/\(metadata.id)") else {
            throw StorageError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
        let firestoreFields = metadata.toFirestoreRESTPayload()
        request.httpBody = try JSONSerialization.data(withJSONObject: firestoreFields)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let serverError = String(data: data, encoding: .utf8) ?? "Metadata save failed"
            throw NSError(domain: "FirestoreError", code: 500, userInfo: [NSLocalizedDescriptionKey: serverError])
        }
    }
    
    /// Fetches all metadata documents belonging to user
    /// Fetches all metadata documents belonging to user
    func fetchPhotoMetadata(for userId: String, idToken: String) async throws -> [PhotoMetadata] {
        let cleanToken = idToken.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var components = URLComponents()
        components.scheme = "https"
        components.host = "firestore.googleapis.com"
        components.path = "/v1/projects/\(Secrets.projectId)/databases/(default)/documents/photos"
        
        guard let url = components.url else {
            throw StorageError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        //TODO: should 500 be hardcoded or grabbed from somewhere like httpResponse.statusCode . Or we did start some custom Errors, continue down that pathway?
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Metadata fetch failed"
            throw NSError(domain: "FirestoreError", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "FirestoreError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid Firestore response format"])
        }
        
        guard let documents = json["documents"] as? [[String: Any]] else {
            return []
        }
        
        // Parse complete models and filter for the active user
        return documents
            .compactMap { PhotoMetadata(fromFirestoreREST: $0) }
//            .filter { $0.userId == userId }
    }
}
