import Foundation

struct TagLibWrapper {
    static func extractMetadata(from fileURL: URL) -> [String: Any] {
        var metadata: [String: Any] = [:]

        let filePath = fileURL.path
        guard let cMetadata = getMetadata(filePath) else {
            // print("Failed to extract metadata for file: \(filePath)")
            return metadata
        }
        defer { freeMetadata(cMetadata) }

        if let title = cMetadata.pointee.title {
            metadata["title"] = String(cString: title)
        }
        if let artist = cMetadata.pointee.artist {
            metadata["artist"] = String(cString: artist)
        }
        if let album = cMetadata.pointee.album {
            metadata["album"] = String(cString: album)
        }
        if let albumArtist = cMetadata.pointee.albumArtist {
            metadata["album artist"] = String(cString: albumArtist)
        }
        if let genre = cMetadata.pointee.genre {
            metadata["genre"] = String(cString: genre)
        }
        metadata["track number"] = Int(cMetadata.pointee.trackNumber)
        metadata["disc number"] = Int(cMetadata.pointee.discNumber)
        
        // Extract artwork
        if let artwork = cMetadata.pointee.artwork, cMetadata.pointee.artworkSize > 0 {
            metadata["artwork"] = Data(bytes: artwork, count: Int(cMetadata.pointee.artworkSize))
        } else {
            // print("No artwork found for file: \(filePath)")
        }

        return metadata
    }
}
