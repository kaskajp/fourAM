import Foundation
import AppKit

actor ThumbnailCache {
    static let shared = ThumbnailCache()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        // Get the application's cache directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("fourAM")
        print("App folder: \(appFolder)")

        cacheDirectory = appFolder.appendingPathComponent("Thumbnails")
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getThumbnail(for album: String) async -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(album.sha256())
        return try? Data(contentsOf: fileURL)
    }
    
    func setThumbnail(_ thumbnail: Data, for album: String) async {
        let fileURL = cacheDirectory.appendingPathComponent(album.sha256())
        try? thumbnail.write(to: fileURL)
    }
    
    func clearCache() async {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        } catch {
            print("Error clearing thumbnail cache: \(error)")
        }
    }
}

// Helper extension to create hash of strings
extension String {
    func sha256() -> String {
        // Use Swift's built-in hashing
        let hash = self.hashValue
        return String(format: "%x", hash)
    }
}
