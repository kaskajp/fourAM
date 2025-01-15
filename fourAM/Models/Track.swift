//
//  Track.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftData
import Foundation

@Model
class Track: Equatable {
    var id: UUID = UUID()
    @Attribute(.unique) var path: String
    var url: URL
    var title: String
    var artist: String
    var album: String
    var discNumber: Int
    var albumArtist: String? // New property
    var artwork: Data?
    var thumbnail: Data? // Resized artwork
    var trackNumber: Int
    var durationString: String

    init(
        path: String,
        url: URL,
        title: String,
        artist: String,
        album: String,
        discNumber: Int = -1,
        albumArtist: String? = nil, // Default value
        artwork: Data? = nil,
        thumbnail: Data? = nil,
        trackNumber: Int = -1,
        durationString: String = "0:00"
    ) {
        self.path = path
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.discNumber = discNumber
        self.albumArtist = albumArtist
        self.artwork = artwork
        self.thumbnail = thumbnail
        self.trackNumber = trackNumber
        self.durationString = durationString
    }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.id == rhs.id // Ensure you're comparing unique identifiers
    }
}
