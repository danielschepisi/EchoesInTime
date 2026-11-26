//
//  StorageError.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 24/8/2026.
//

import Foundation

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
