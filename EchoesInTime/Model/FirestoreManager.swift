//
//  FirestoreManager.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 24/8/2026.
//

import Foundation

class FirestoreManager {
    static let shared = FirestoreManager()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

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
        request.timeoutInterval = 15
        request.assumesHTTP3Capable = false

        request.setValue(
            "Bearer \(idToken)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        let firestoreFields = metadata.toFirestoreRESTPayload()

        request.httpBody = try JSONSerialization.data(
            withJSONObject: firestoreFields
        )

        let start = Date()

        print("FM SAVE: Sending PATCH")

        do {
            let (data, response) = try await session.data(for: request)

            let elapsed = Date().timeIntervalSince(start)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {

                let serverError = String(
                    data: data,
                    encoding: .utf8
                ) ?? "Metadata save failed"

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500

                print("FM SAVE ERROR: HTTP \(statusCode)")
                print("FM SAVE ERROR BODY: \(serverError)")

                throw NSError(
                    domain: "FirestoreError",
                    code: statusCode,
                    userInfo: [
                        NSLocalizedDescriptionKey: serverError
                    ]
                )
            }

            print("FM SAVE SUCCESS: \(elapsed)s")

        } catch {
            print("FM SAVE NETWORK ERROR: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Fetch Photo Metadata

    /// Fetches all metadata documents belonging to user
    func fetchPhotoMetadata(
        for userId: String,
        idToken: String
    ) async throws -> [PhotoMetadata] {

        let cleanToken = idToken.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        var components = URLComponents()

        components.scheme = "https"
        components.host = "firestore.googleapis.com"

        components.path =
            "/v1/projects/\(Secrets.projectId)/databases/(default)/documents/photos"

        guard let url = components.url else {
            throw StorageError.invalidURL
        }

        var request = URLRequest(url: url)

        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.assumesHTTP3Capable = false

        request.setValue(
            "Bearer \(cleanToken)",
            forHTTPHeaderField: "Authorization"
        )

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        let start = Date()

        print("FM1. Sending GET")
        print("FM1. URL: \(url.absoluteString)")
        print("FM1. Token length: \(cleanToken.count)")

        // IMPORTANT:
        // Use the configured session rather than URLSession.shared.
        // This ensures our timeout and connectivity settings apply.

        let data: Data
        let response: URLResponse

        do {
//            (data, response) = try await session.data(for: request) //*****XXXXXX*****X*X*X*X
            var diagnosticRequest = request
            diagnosticRequest.timeoutInterval = 10

            let diagnosticSession = URLSession.shared

            do {
                print("FM1.1 Starting Firestore request: \(Date())")

                (data, response) = try await diagnosticSession.data(for: diagnosticRequest)

                print("FM1.2 Request returned: \(Date())")

            } catch {
                print("FM ERROR: \(error)")
                print("FM ERROR CODE: \((error as NSError).code)")
                print("FM ERROR DOMAIN: \((error as NSError).domain)")
                throw error
            }

        } catch {
            let elapsed = Date().timeIntervalSince(start)

            print("FM NETWORK ERROR: \(error.localizedDescription)")
            print("FM ERROR CODE: \((error as NSError).code)")
            print("FM TIME ELAPSED: \(elapsed)s")

            throw error
        }

        let elapsed = Date().timeIntervalSince(start)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        print("FM2. Received response: \(statusCode)")
        print("FM2. Bytes received: \(data.count)")
        print("FM2. Network time: \(elapsed)s")

        // Check HTTP response

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {

            let errorMsg = String(
                data: data,
                encoding: .utf8
            ) ?? "Metadata fetch failed"

            print("FM HTTP ERROR: \(statusCode)")
            print("FM HTTP ERROR BODY: \(errorMsg)")

            throw NSError(
                domain: "FirestoreError",
                code: statusCode == -1 ? 500 : statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey: errorMsg
                ]
            )
        }

        // Decode JSON response

        let decodeStart = Date()

        guard let json = try JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any] else {

            throw NSError(
                domain: "FirestoreError",
                code: 500,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Invalid Firestore response format"
                ]
            )
        }

        guard let documents = json["documents"] as? [[String: Any]] else {
            print("FM3. No documents returned")
            return []
        }

        let photos = documents.compactMap {
            PhotoMetadata(fromFirestoreREST: $0)
        }

        let decodeElapsed = Date().timeIntervalSince(decodeStart)

        print("FM3. Documents received: \(documents.count)")
        print("FM3. Photos decoded: \(photos.count)")
        print("FM3. Decode time: \(decodeElapsed)s")

        print("FM COMPLETE. Total time: \(Date().timeIntervalSince(start))s")

        return photos
    }
    
    func diagnoseNetwork() async {

        let urls = [
            "https://www.apple.com",
            "https://www.google.com",
            "https://firestore.googleapis.com"
        ]

        for address in urls {

            guard let url = URL(string: address) else {
                continue
            }

            print("\nNETWORK TEST START: \(address)")

            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            let start = Date()

            do {
                let (_, response) = try await URLSession.shared.data(for: request)

                let elapsed = Date().timeIntervalSince(start)

                if let http = response as? HTTPURLResponse {
                    print("NETWORK TEST SUCCESS: \(address)")
                    print("STATUS: \(http.statusCode)")
                    print("TIME: \(elapsed)s")
                }

            } catch {
                let elapsed = Date().timeIntervalSince(start)

                print("NETWORK TEST FAILED: \(address)")
                print("ERROR: \(error.localizedDescription)")
                print("CODE: \((error as NSError).code)")
                print("TIME: \(elapsed)s")
            }
        }
    }
}
