//
//  Album.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

// Album.swift

import Foundation

struct Album: Identifiable {
    let id = UUID()
    let name: String
    let albumArtist: String
    let artwork: Data? // optional if album art might not exist
    let tracks: [Track]
    
    init(name: String, albumArtist: String?, artwork: Data?, tracks: [Track]) {
        self.name = name
        self.albumArtist = albumArtist ?? "Unknown Album Artist"
        self.artwork = artwork
        // Sort by trackNumber at creation time
        self.tracks = tracks.sorted(by: { $0.trackNumber < $1.trackNumber })
    }
}
