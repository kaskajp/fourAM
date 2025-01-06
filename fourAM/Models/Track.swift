//
//  Track.swift
//  fourAM
//
//  Created by Jonas on 2025-01-06.
//

import SwiftData
import Foundation

@Model
class Track {
    @Attribute(.unique) var path: String
    var title: String
    var artist: String
    var album: String
    var artwork: Data?
    var trackNumber: Int
    var durationString: String
    
    // SwiftData requires an initializer if you want custom logic or defaults
    init(
        path: String,
        title: String,
        artist: String,
        album: String,
        artwork: Data? = nil,
        trackNumber: Int = -1,
        durationString: String = "0:00"
    ) {
        self.path = path
        self.title = title
        self.artist = artist
        self.album = album
        self.artwork = artwork
        self.trackNumber = trackNumber
        self.durationString = durationString
    }
}
