//
//  LocalImageCache.swift
//  EchoesInTime
//
//  Created by Daniel Schepisi on 26/11/2026.
//

import Foundation
import UIKit

enum LocalImageCache {
    private static var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CachedPhotos", isDirectory: true)
    }

    private static func ensureDirectoryExists() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: cacheDirectory.path) {
            try? fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    /// Saves a UIImage as JPEG on disk and returns the saved filename.
    static func saveImage(_ image: UIImage, id: String) throws -> String {
        ensureDirectoryExists()
        let filename = "\(id).jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw StorageError.imageConversionFailed
        }

        try data.write(to: fileURL, options: .atomic)
        return filename
    }

    /// Loads a cached UIImage from disk if it exists.
    static func loadImage(filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty else { return nil }
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        return UIImage(contentsOfFile: fileURL.path)
    }

    /// Removes a cached image file from disk.
    static func deleteImage(filename: String?) {
        guard let filename, !filename.isEmpty else { return }
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
