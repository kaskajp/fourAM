//
//  MetadataExtractor.swift.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

import AVFoundation

struct MetadataExtractor {
    static func extract(from url: URL) -> Track {
        let asset = AVAsset(url: url)
        
        // Default metadata
        var title = url.lastPathComponent
        var artist = "Unknown Artist"
        var albumArtist = "Unknown Album Artist"
        var album = "Unknown Album"
        var artwork: Data?
        var discNumber = -1
        var trackNumber = -1
        let durationSeconds = CMTimeGetSeconds(asset.duration)
        let durationString = formatTime(durationSeconds)
        
        // 1. Parse common metadata for title, artist, albumArtist, album, artwork
        for item in asset.commonMetadata {
            guard let commonKey = item.commonKey?.rawValue else { continue }
            switch commonKey {
            case "title":
                if let val = item.value as? String { title = val }
            case "artist":
                if let val = item.value as? String { artist = val }
            case "albumArtist":
                if let val = item.value as? String { albumArtist = val }
            case "albumName":
                if let val = item.value as? String { album = val }
            case "artwork":
                if let data = item.value as? Data { artwork = data }
            default:
                break
            }
        }
        
        for format in asset.availableMetadataFormats {
            let metadataItems = asset.metadata(forFormat: format)
            for item in metadataItems {
                // Look at item.identifier or item.key to see how track # is stored
                if let identifier = item.identifier?.rawValue {
                    if identifier.contains("trackNumber") || identifier.contains("TRCK") {
                        trackNumber = parseTrackNumber(from: item)
                    } else if identifier.contains("discNumber") || identifier.contains("TPOS") {
                        discNumber = parseDiscNumber(from: item)
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
    private static func parseTrackNumber(from item: AVMetadataItem) -> Int {
        // If it's directly an Int
        if let val = item.value as? Int {
            return val
        }
        // If it's a string
        if let str = item.stringValue {
            // Handle "01", "1", or "1/12"
            let parts = str.split(separator: "/")
            if let firstPart = parts.first, let val = Int(firstPart) {
                return val
            }
        }
        return -1
    }
    
    /// Parse disc number from metadata
    private static func parseDiscNumber(from item: AVMetadataItem) -> Int {
        if let val = item.value as? Int {
            return val
        }
        if let str = item.stringValue {
            let parts = str.split(separator: "/")
            if let firstPart = parts.first, let val = Int(firstPart) {
                return val
            }
        }
        return -1
    }
}
