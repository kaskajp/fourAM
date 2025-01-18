//
//  MetadataExtractor.swift.swift
//  fourAM
//
//  Created by Jonas on 2025-01-05.
//

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
        
        // Check for FLAC-specific metadata
        if url.pathExtension.lowercased() == "flac" {
            // Use TagLibWrapper to extract metadata for FLAC files
            let flacMetadata = TagLibWrapper.extractMetadata(from: url)
            
            title = flacMetadata["title"] as? String ?? title
            artist = flacMetadata["artist"] as? String ?? artist
            albumArtist = flacMetadata["album artist"] as? String ?? albumArtist
            album = flacMetadata["album"] as? String ?? album
            trackNumber = flacMetadata["track number"] as? Int ?? trackNumber
            discNumber = flacMetadata["disc number"] as? Int ?? discNumber
            releaseYear = flacMetadata["releaseYear"] as? Int ?? releaseYear
            if let artworkData = flacMetadata["artwork"] as? Data {
                artwork = artworkData
            }
        } else {
            // Batch-load common metadata to avoid redundant awaits
            let commonMetadata = try await asset.load(.commonMetadata)
            let metadataValues = try await loadMetadataValues(from: commonMetadata)
            title = metadataValues["title"] as? String ?? title
            artist = metadataValues["artist"] as? String ?? artist
            album = metadataValues["albumName"] as? String ?? album
            artwork = metadataValues["artwork"] as? Data ?? artwork
            releaseYear = metadataValues["year"] as? Int ?? releaseYear
            
            // Batch-load available formats and metadata items
            let availableFormats = try await asset.load(.availableMetadataFormats)
            for format in availableFormats {
                let metadataItems = try await asset.loadMetadata(for: format)
                for item in metadataItems {
                    guard let identifier = item.identifier?.rawValue else { continue }
                    
                    switch identifier {
                    case let id where id.contains("trackNumber") || id.contains("TRCK"):
                        trackNumber = try await parseTrackNumber(from: item)
                    case let id where id.contains("discNumber") || id.contains("TPOS"):
                        discNumber = try await parseDiscNumber(from: item)
                    case let id where id.contains("TPE2"):
                        albumArtist = try await item.load(.value) as? String ?? albumArtist
                    case let id where id.contains("TCON"):
                        if let rawValue = try await item.load(.value) {
                            if let genreString = rawValue as? String {
                                genre = genreString
                            }
                        }
                    case let id where id.contains("TDRC"):
                        if let rawValue = try await item.load(.value) {
                            if let intValue = rawValue as? Int {
                                releaseYear = intValue
                            } else if let stringValue = rawValue as? String {
                                if let year = Int(stringValue.prefix(4)) {
                                    releaseYear = year
                                }
                            }
                        }
                    default:
                        break
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
