//
//  PhotoMetaData.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 24/8/2026.
//

import Foundation
import UIKit

/// Standardized Swift structure matching the Firestore REST payload
struct PhotoMetadata: Identifiable, Codable {
    var id: String = UUID().uuidString
    var storagePath: String
    var downloadURL: String?
    var dateTaken: Date
    var dateUploaded: Date = Date()
    var serverUpdatedAt: Date = Date()  // Tracks last cloud modification
    var isDeleted: Bool = false         // Soft-delete flag for multi-user sync
    var people: [String]
    var location: String
    var userId: String
}

/// Item state wrapper for multi-photo selection during upload
struct PendingUploadItem: Identifiable {
    let id = UUID()
    let image: UIImage
    var dateTaken: Date = Date()
    var peopleText: String = ""
    var location: String = ""
}

extension PhotoMetadata {
    private static func parseISO8601Date(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractionalFormatter.date(from: value) {
            return parsed
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        return standardFormatter.date(from: value)
    }
    
    /// Decodes a raw Firestore REST document payload into a PhotoMetadata instance
    init?(fromFirestoreREST document: [String: Any]) {
        guard let name = document["name"] as? String,
              let fields = document["fields"] as? [String: Any] else {
            return nil
        }
        
        // Extract the document ID from the full resource path (.../photos/DOC_ID)
        let rawLastComponent = name.components(separatedBy: "/").last
        let docId = (rawLastComponent?.isEmpty == false) ? rawLastComponent! : UUID().uuidString
        
        let serverUpdateTimeString = document["updateTime"] as? String
        let serverUpdatedAt = Self.parseISO8601Date(serverUpdateTimeString) ?? Date()

        let isDeleted = (fields["isDeleted"] as? [String: Any])?["booleanValue"] as? Bool ?? false
        
        // Required Fields
        guard let storagePathDict = fields["storagePath"] as? [String: Any],
              let storagePath = storagePathDict["stringValue"] as? String,
              let userIdDict = fields["userId"] as? [String: Any],
              let userId = userIdDict["stringValue"] as? String else {
            return nil
        }
        
        // Optional String Fields
        let downloadURL = (fields["downloadURL"] as? [String: Any])?["stringValue"] as? String
        let location = (fields["location"] as? [String: Any])?["stringValue"] as? String ?? ""
        
        // Date Parsing (Firestore REST outputs ISO 8601 strings in "timestampValue")
        let dateTakenString = (fields["dateTaken"] as? [String: Any])?["timestampValue"] as? String
        let dateTaken = Self.parseISO8601Date(dateTakenString) ?? Date()

        let dateUploadedString = (fields["dateUploaded"] as? [String: Any])?["timestampValue"] as? String
        let dateUploaded = Self.parseISO8601Date(dateUploadedString) ?? Date()
        
        // Array Parsing (Firestore REST outputs arrays as nested "arrayValue" -> "values")
        var peopleList: [String] = []
        if let arrayDict = fields["people"] as? [String: Any],
           let arrayValue = arrayDict["arrayValue"] as? [String: Any],
           let values = arrayValue["values"] as? [[String: Any]] {
            peopleList = values.compactMap { $0["stringValue"] as? String }
        }
        
        // Initialize full struct
        self.id = docId
        self.storagePath = storagePath
        self.downloadURL = downloadURL
        self.dateTaken = dateTaken
        self.dateUploaded = dateUploaded
        self.serverUpdatedAt = serverUpdatedAt
        self.isDeleted = isDeleted
        self.people = peopleList
        self.location = location
        self.userId = userId
    }
    
    /// Converts a PhotoMetadata instance into a Firestore REST JSON write payload
    func toFirestoreRESTPayload() -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var fields: [String: Any] = [
            "storagePath": ["stringValue": storagePath],
            "userId": ["stringValue": userId],
            "location": ["stringValue": location],
            "dateTaken": ["timestampValue": formatter.string(from: dateTaken)],
            "dateUploaded": ["timestampValue": formatter.string(from: dateUploaded)],
            "people": [
                "arrayValue": [
                    "values": people.map { ["stringValue": $0] }
                ]
            ],
            "isDeleted": ["booleanValue": isDeleted]
        ]
        
        if let downloadURL = downloadURL {
            fields["downloadURL"] = ["stringValue": downloadURL]
        }
        
        return ["fields": fields]
    }
}
