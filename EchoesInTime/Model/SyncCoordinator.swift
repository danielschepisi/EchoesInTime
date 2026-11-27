//
//  SyncCoordinator.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 26/11/2026.
//
import Combine
import Foundation
import SwiftData

@MainActor
final class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator()

    @Published var isSyncing = false
    @Published var lastSyncError: String?

    private let defaults = UserDefaults.standard
    private let overlapSeconds: TimeInterval = 5

    private init() {}

    // MARK: - Sync Cursor (`lastCloudSyncAt`)

    private func syncCursorKey(for scopeId: String) -> String {
        "lastCloudSyncAt_\(scopeId)"
    }

    func lastCloudSyncAt(for scopeId: String) -> Date? {
        defaults.object(forKey: syncCursorKey(for: scopeId)) as? Date
    }

    private func setLastCloudSyncAt(_ date: Date, for scopeId: String) {
        defaults.set(date, forKey: syncCursorKey(for: scopeId))
    }

    // MARK: - Pull / Delta Sync

    /// Pulls new or updated photo metadata from Firestore and merges into SwiftData.
    func pullChanges(
        userId: String,
        idToken: String? = nil,
        scopeId: String? = nil,
        filterByUserId: Bool = false,
        in context: ModelContext
    ) async {
        guard !isSyncing else { return }
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }

        let keyScope = scopeId ?? userId

        do {
            print("S1. inside pullChanges do-block")
            let activeToken: String
            if let provided = idToken, !provided.isEmpty {
                activeToken = provided
            } else {
                activeToken = try await NetworkManager.shared.refreshIDToken()
            }

            let cursor = lastCloudSyncAt(for: keyScope)
            print("S2. cursor: \(String(describing: cursor)), fetching metadata...")

            var incoming: [PhotoMetadata]
            if let cursor {
                let sinceDate = cursor.addingTimeInterval(-overlapSeconds)
                incoming = try await fetchUpdatedPhotos(since: sinceDate, idToken: activeToken)
            } else {
                incoming = try await FirestoreManager.shared.fetchPhotoMetadata(
                    for: userId,
                    idToken: activeToken
                )
            }
            print("S3. fetched \(incoming.count) items")

            if filterByUserId {
                incoming = incoming.filter { $0.userId == userId }
            }

            var maxServerTimestamp = cursor

            for dto in incoming {
                if let currentMax = maxServerTimestamp {
                    if dto.serverUpdatedAt > currentMax {
                        maxServerTimestamp = dto.serverUpdatedAt
                    }
                } else {
                    maxServerTimestamp = dto.serverUpdatedAt
                }

                try applyRemoteDTO(dto, in: context)
            }

            try context.save()
            print("S4. saved \(incoming.count) items to SwiftData")

            if let newCursor = maxServerTimestamp {
                setLastCloudSyncAt(newCursor, for: keyScope)
            }
        } catch {
            print("S_ERR. pullChanges error: \(error.localizedDescription)")
            lastSyncError = error.localizedDescription
        }
    }

    private func applyRemoteDTO(_ dto: PhotoMetadata, in context: ModelContext) throws {
        let targetId = dto.id
        let descriptor = FetchDescriptor<CachedPhoto>(
            predicate: #Predicate { $0.id == targetId }
        )
        let existing = try context.fetch(descriptor).first

        guard let local = existing else {
            guard !dto.isSoftDeleted else { return }
            let inserted = CachedPhoto(from: dto)
            context.insert(inserted)
            return
        }

        // If the device has unpushed local edits, check timestamps before overwriting
        if local.needsSync {
            if let localEditTime = local.localModifiedAt, dto.serverUpdatedAt <= localEditTime {
                // Local edit is newer or equal—keep local state for push step
                return
            }
        }

        if dto.isSoftDeleted {
            LocalImageCache.deleteImage(filename: local.localImageFilename)
            context.delete(local)
        } else {
            local.update(from: dto)
        }
    }

    // MARK: - Push Local Changes

    func pushChanges(
        userId: String,
        idToken: String? = nil,
        in context: ModelContext
    ) async {
        let activeToken: String
        do {
            if let provided = idToken, !provided.isEmpty {
                activeToken = provided
            } else {
                activeToken = try await NetworkManager.shared.refreshIDToken()
            }
        } catch {
            print("PUSH_ERR: Token refresh failed: \(error.localizedDescription)")
            return
        }

        let descriptor = FetchDescriptor<CachedPhoto>(
            predicate: #Predicate { $0.needsSync == true }
        )

        guard let dirtyPhotos = try? context.fetch(descriptor) else { return }

        for photo in dirtyPhotos {
            let dto = photo.toDTO()
            do {
                try await FirestoreManager.shared.savePhotoMetadata(dto, idToken: activeToken)
                photo.needsSync = false
            } catch {
                print("PUSH_ERR: Failed to push \(photo.id): \(error.localizedDescription)")
            }
        }

        try? context.save()
    }

    // MARK: - Firestore `:runQuery` Delta Fetch

    private func fetchUpdatedPhotos(since date: Date, idToken: String) async throws -> [PhotoMetadata] {
        let cleanToken = idToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = "https://firestore.googleapis.com/v1/projects/\(Secrets.projectId)/databases/(default)/documents:runQuery"
        guard let url = URL(string: urlString) else {
            throw StorageError.invalidURL
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoString = formatter.string(from: date)

        let queryBody: [String: Any] = [
            "structuredQuery": [
                "from": [
                    ["collectionId": "photos"]
                ],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "updateTime"],
                        "op": "GREATER_THAN_OR_EQUAL",
                        "value": ["timestampValue": isoString]
                    ]
                ],
                "orderBy": [
                    [
                        "field": ["fieldPath": "updateTime"],
                        "direction": "ASCENDING"
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.assumesHTTP3Capable = false
        request.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: queryBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Delta query failed"
            throw NSError(domain: "FirestoreError", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: message])
        }

        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return rows.compactMap { row in
            guard let doc = row["document"] as? [String: Any] else { return nil }
            return PhotoMetadata(fromFirestoreREST: doc)
        }
    }
}
