//
//  MetadataExtractor.swift.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

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
        let durationSeconds = try await CMTimeGetSeconds(asset.load(.duration))
        let durationString = formatTime(durationSeconds)
        
        // 1. Parse common metadata for title, artist, albumArtist, album, artwork
        for item in try await asset.load(.commonMetadata) {
            guard let commonKey = item.commonKey?.rawValue else { continue }
            switch commonKey {
            case "title":
                if let val = try await item.load(.value) as? String { title = val }
            case "artist":
                if let val = try await item.load(.value) as? String { artist = val }
            case "albumName":
                if let val = try await item.load(.value) as? String { album = val }
            case "artwork":
                if let data = try await item.load(.value) as? Data { artwork = data }
            default:
                break
            }
        }
        
        for format in try await asset.load(.availableMetadataFormats) {
            let metadataItems = try await asset.loadMetadata(for: format)
            for item in metadataItems {
                /*if let key = item.key as? String, let value = item.value {
                    print("Format: \(format), Key: \(key), Value: \(value)")
                }*/
                // Look at item.identifier or item.key to see how track # is stored
                if let identifier = item.identifier?.rawValue {
                    if identifier.contains("trackNumber") || identifier.contains("TRCK") {
                        trackNumber = try await parseTrackNumber(from: item)
                    } else if identifier.contains("discNumber") || identifier.contains("TPOS") {
                        discNumber = try await parseDiscNumber(from: item)
                    } else if identifier.contains("TPE2") {
                        albumArtist = try await item.load(.value) as? String ?? albumArtist
                    }
                }
            }
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
            durationString: durationString
        )
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
