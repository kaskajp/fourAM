import SwiftUI
import AVFoundation

struct MetadataExtractor {
    static func extract(from url: URL) async throws -> Track {
        let asset = AVAsset(url: url)
        
        // Default metadata
        var title = url.lastPathComponent
        var artist = "Unknown Artist"
        var albumArtist = "Unknown Album Artist"
        var album = "Unknown Album"
        var artwork: Data?
        var discNumber = -1
        var trackNumber = -1
        var releaseYear = 0
        let durationSeconds = try await CMTimeGetSeconds(asset.load(.duration))
        let durationString = formatTime(durationSeconds)
        var genre = "Unknown Genre"
        
        // Use TagLibWrapper to extract metadata for all audio files
        let metadata = TagLibWrapper.extractMetadata(from: url)
        
        // Extract metadata from TagLib
        title = metadata["title"] as? String ?? title
        artist = metadata["artist"] as? String ?? artist
        albumArtist = metadata["album artist"] as? String ?? albumArtist
        album = metadata["album"] as? String ?? album
        trackNumber = metadata["track number"] as? Int ?? trackNumber
        discNumber = metadata["disc number"] as? Int ?? discNumber
        releaseYear = metadata["releaseYear"] as? Int ?? releaseYear
        genre = metadata["genre"] as? String ?? genre
        if let artworkData = metadata["artwork"] as? Data {
            artwork = artworkData
        }
        
        // If TagLib didn't provide artwork, try to get it from AVAsset
        if artwork == nil {
            let commonMetadata = try await asset.load(.commonMetadata)
            let metadataValues = try await loadMetadataValues(from: commonMetadata)
            artwork = metadataValues["artwork"] as? Data
        }
        
        return Track(
            path: url.path,
            url: url,
            title: title,
            artist: artist,
            album: album,
            discNumber: discNumber,
            albumArtist: albumArtist,
            artwork: artwork,
            trackNumber: trackNumber,
            durationString: durationString,
            genre: genre,
            releaseYear: releaseYear
        )
    }
    
    private static func loadMetadataValues(from items: [AVMetadataItem]) async throws -> [String: Any] {
        var result: [String: Any] = [:]

        try await withThrowingTaskGroup(of: (String, Any?).self) { group in
            for item in items {
                guard let commonKey = item.commonKey?.rawValue else { continue }
                group.addTask {
                    let value = try? await item.load(.value)
                    return (commonKey, value)
                }
            }
            for try await (key, value) in group {
                if let value = value {
                    result[key] = value
                }
            }
        }
        return result
    }
    
    /// Helper to produce a "mm:ss" string from track duration
    private static func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds > 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainderSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainderSeconds)
    }
    
    // Where parseTrackNumber could handle string or int values:
    private static func parseTrackNumber(from item: AVMetadataItem) async throws -> Int {
        // If it's directly an Int
        if let val = try await item.load(.value) as? Int {
            return val
        }
        // If it's a string
        if let str = try await item.load(.stringValue) {
            // Handle "01", "1", or "1/12"
            let parts = str.split(separator: "/")
            if let firstPart = parts.first, let val = Int(firstPart) {
                return val
            }
        }
        return -1
    }
    
    /// Parse disc number from metadata
    private static func parseDiscNumber(from item: AVMetadataItem) async throws -> Int {
        if let val = try await item.load(.value) as? Int {
            return val
        }
        if let str = try await item.load(.stringValue) {
            let parts = str.split(separator: "/")
            if let firstPart = parts.first, let val = Int(firstPart) {
                return val
            }
        }
        return -1
    }
}
