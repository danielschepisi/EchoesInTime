//
//  CachedPhoto.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 26/11/2026.
//

import Foundation
import SwiftData

@Model
final class CachedPhoto {
    @Attribute(.unique) var id: String
    var storagePath: String
    var downloadURL: String?
    var dateTaken: Date
    var dateUploaded: Date
    var serverUpdatedAt: Date
    var isSoftDeleted: Bool
    var people: [String]
    var location: String
    var userId: String
    var localModifiedAt: Date?
    
    // Local-only cache tracking
    var localImageFilename: String?   // Filename in Caches/Documents directory once downloaded
    var needsSync: Bool               // True if created/edited offline and awaiting upload

    init(
        id: String,
        storagePath: String,
        downloadURL: String? = nil,
        dateTaken: Date,
        dateUploaded: Date = Date(),
        serverUpdatedAt: Date = Date(),
        isSoftDeleted: Bool = false,
        people: [String] = [],
        location: String = "",
        userId: String,
        localModifiedAt: Date? = nil,
        localImageFilename: String? = nil,
        needsSync: Bool = false
    ) {
        self.id = id
        self.storagePath = storagePath
        self.downloadURL = downloadURL
        self.dateTaken = dateTaken
        self.dateUploaded = dateUploaded
        self.serverUpdatedAt = serverUpdatedAt
        self.isSoftDeleted = isSoftDeleted
        self.people = people
        self.location = location
        self.userId = userId
        self.localModifiedAt = localModifiedAt
        self.localImageFilename = localImageFilename
        self.needsSync = needsSync
    }
}

// MARK: - Mapping Helpers
extension CachedPhoto {
    convenience init(from dto: PhotoMetadata) {
        self.init(
            id: dto.id,
            storagePath: dto.storagePath,
            downloadURL: dto.downloadURL,
            dateTaken: dto.dateTaken,
            dateUploaded: dto.dateUploaded,
            serverUpdatedAt: dto.serverUpdatedAt,
            isSoftDeleted: dto.isSoftDeleted,
            people: dto.people,
            location: dto.location,
            userId: dto.userId,
            needsSync: false
        )
    }

    func update(from dto: PhotoMetadata) {
        self.storagePath = dto.storagePath
        self.downloadURL = dto.downloadURL
        self.dateTaken = dto.dateTaken
        self.dateUploaded = dto.dateUploaded
        self.serverUpdatedAt = dto.serverUpdatedAt
        self.isSoftDeleted = dto.isSoftDeleted
        self.people = dto.people
        self.location = dto.location
        self.userId = dto.userId
        self.needsSync = false
    }

    func toDTO() -> PhotoMetadata {
        PhotoMetadata(
            id: id,
            storagePath: storagePath,
            downloadURL: downloadURL,
            dateTaken: dateTaken,
            dateUploaded: dateUploaded,
            serverUpdatedAt: serverUpdatedAt,
            isSoftDeleted: isSoftDeleted,
            people: people,
            location: location,
            userId: userId
        )
    }
}
