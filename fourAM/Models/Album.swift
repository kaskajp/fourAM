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
    let thumbnail: Data?
    let tracks: [Track]
    
    init(name: String, albumArtist: String?, artwork: Data?, thumbnail: Data?, tracks: [Track]) {
        self.name = name
        self.albumArtist = albumArtist ?? "Unknown Album Artist"
        self.artwork = artwork
        self.thumbnail = thumbnail
        self.tracks = tracks
    }
}
