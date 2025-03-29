import Foundation
import AppKit

actor ThumbnailCache {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 10 * 1024 * 1024 * 1024 // 10GB
    private let maxAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    
    init() {
        // Get the application's cache directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("fourAM")
        cacheDirectory = appFolder.appendingPathComponent("Thumbnails")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Clean up old cache entries
        Task {
            await cleanupCacheIfNeeded()
        }
    }
    
    func getThumbnail(for album: String) async -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(album.sha256())
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // Check if file is too old
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let modificationDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) > maxAge {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        return try? Data(contentsOf: fileURL)
    }
    
    func setThumbnail(_ thumbnail: Data, for album: String) async {
        let fileURL = cacheDirectory.appendingPathComponent(album.sha256())
        try? thumbnail.write(to: fileURL)
        
        // Only clean up if we're getting close to the limit
        await cleanupCacheIfNeeded()
    }
    
    private func cleanupCacheIfNeeded() async {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
            
            // Calculate total size
            var totalSize: Int64 = 0
            var fileInfos: [(url: URL, date: Date, size: Int64)] = []
            
            for file in files {
                let attributes = try file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                if let date = attributes.contentModificationDate,
                   let size = attributes.fileSize {
                    totalSize += Int64(size)
                    fileInfos.append((file, date, Int64(size)))
                }
            }
            
            // Only clean up if we're using more than 90% of the cache
            if totalSize > (maxCacheSize * 9 / 10) {
                let sortedFiles = fileInfos.sorted { $0.date < $1.date }
                var currentSize = totalSize
                
                // Remove oldest files until we're under 80% of the limit
                for fileInfo in sortedFiles {
                    if currentSize <= (maxCacheSize * 8 / 10) {
                        break
                    }
                    
                    try? fileManager.removeItem(at: fileInfo.url)
                    currentSize -= fileInfo.size
                }
            }
            
            // Remove files older than maxAge
            for fileInfo in fileInfos {
                if Date().timeIntervalSince(fileInfo.date) > maxAge {
                    try? fileManager.removeItem(at: fileInfo.url)
                }
            }
        } catch {
            print("Error cleaning up thumbnail cache: \(error)")
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
