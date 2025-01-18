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
    let releaseYear: Int
    let totalTracks: Int
    let genre: String
    
    init(name: String, albumArtist: String?, artwork: Data?, thumbnail: Data?, tracks: [Track], releaseYear: Int, genre: String, totalTracks: Int = 0) {
        self.name = name
        self.albumArtist = albumArtist ?? "Unknown Album Artist"
        self.artwork = artwork
        self.thumbnail = thumbnail
        self.tracks = tracks
        self.genre = genre
        self.releaseYear = releaseYear
        self.totalTracks = self.tracks.count
    }
}
